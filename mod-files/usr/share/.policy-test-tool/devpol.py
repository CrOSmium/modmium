# written by lxrd
# Note: add policies that aren't in manual_device_policy_proto_map.yaml accordingly whenever you find one. It is not up to date and policies without a proper mapping will not parse correctly.
import json
import os
import shutil
import subprocess
import sys
import time
import yaml
from google.protobuf import json_format
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.backends import default_backend

POLICY_TEST_TOOL_PATH = "/usr/share/.policy-test-tool"
sys.path.insert(0, POLICY_TEST_TOOL_PATH)

import chrome_device_policy_pb2
import device_management_backend_pb2 as dm
from blob_generator import generate_device_policy_schema, apply_device_policies

MANUAL_MAP_PATH = f"{POLICY_TEST_TOOL_PATH}/manual_device_policy_proto_map.yaml"
DEVICESETTINGS_DIR = "/var/lib/devicesettings"
OWNER_KEY_PATH = f"{DEVICESETTINGS_DIR}/owner.key"
POLICY_PATH = f"{DEVICESETTINGS_DIR}/policy.1"

STRING_ENUM_PREFIXES = {"allowed_connection_types": "CONNECTION_TYPE_"}

BOOL_TRUE_DEFAULTS = {"DeviceWiFiAllowed", "DeviceAllowBluetooth", "DevicePowerwashAllowed", "DeviceHardwareVideoDecodingEnabled", "DeviceUserInitiatedFirmwareUpdatesEnabled"}


def generate_keypair():
    pk = rsa.generate_private_key(65537, 2048, default_backend())
    return pk, pk.public_key()


def public_key_to_der(pub):
    return pub.public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)


def sign_data(pk, data: bytes) -> bytes:
    return pk.sign(data, padding.PKCS1v15(), hashes.SHA256())


def read_existing_policy(path: str):
    resp = dm.PolicyFetchResponse()
    resp.ParseFromString(open(path, "rb").read())
    pd = dm.PolicyData()
    pd.ParseFromString(resp.policy_data)
    ds = chrome_device_policy_pb2.ChromeDeviceSettingsProto()
    ds.ParseFromString(pd.policy_value)
    return pd, ds


def load_map() -> dict:
    return yaml.safe_load(open(MANUAL_MAP_PATH)) or {}


def build_field_to_policy(proto_map: dict) -> dict:
    return {v: k for k, v in proto_map.items() if isinstance(v, str)}


def build_policy_fetch_response(pk, device_settings, policy_data) -> bytes:
    pd = dm.PolicyData()
    pd.CopyFrom(policy_data)
    pd.policy_value = device_settings.SerializeToString()
    pd.timestamp = int(time.time() * 1000)
    pd_bytes = pd.SerializeToString()
    resp = dm.PolicyFetchResponse()
    resp.policy_data = pd_bytes
    resp.policy_data_signature = sign_data(pk, pd_bytes)
    resp.policy_data_signature_type = dm.PolicyFetchRequest.SHA256_RSA
    return resp.SerializeToString()


def write_devicesettings(owner_key_der: bytes, policy_fetch_response: bytes):
    os.makedirs(DEVICESETTINGS_DIR, exist_ok=True)
    for f in [OWNER_KEY_PATH, POLICY_PATH]:
        if os.path.exists(f) and not os.path.exists(f + ".bak.enterprise"):
            shutil.copy2(f, f + ".bak.enterprise")
            print(f"backed up {f}")
    for path, data in [(OWNER_KEY_PATH, owner_key_der), (POLICY_PATH, policy_fetch_response)]:
        open(path, "wb").write(data)
        os.chown(path, 0, 0)
        os.chmod(path, 0o644)


def unquote_numbers(d: dict) -> dict:
    for k, v in d.items():
        if isinstance(v, str):
            try:
                d[k] = int(v)
            except ValueError:
                try:
                    d[k] = float(v)
                except ValueError:
                    pass
        elif isinstance(v, dict):
            unquote_numbers(v)
        elif isinstance(v, list):
            d[k] = [unquote_numbers(i) if isinstance(i, dict) else i for i in v]
    return d


def convert_scalar(field, val):
    if field.type == field.TYPE_ENUM and field.name in STRING_ENUM_PREFIXES:
        pfx = STRING_ENUM_PREFIXES[field.name]
        if isinstance(val, list):
            converted = []
            for item in val:
                if isinstance(item, str):
                    enum_val = field.enum_type.values_by_name.get(pfx + item.upper())
                    converted.append(enum_val.number if enum_val else item)
                else:
                    converted.append(item)
            return converted
        elif isinstance(val, str):
            enum_val = field.enum_type.values_by_name.get(pfx + val.upper())
            return enum_val.number if enum_val else val
    elif field.type == field.TYPE_ENUM:
        if isinstance(val, str):
            enum_val = field.enum_type.values_by_name.get(val.upper())
            if enum_val is not None:
                return enum_val.number
        elif isinstance(val, list):
            converted = []
            for item in val:
                if isinstance(item, str):
                    enum_val = field.enum_type.values_by_name.get(item.upper())
                    converted.append(enum_val.number if enum_val else item)
                else:
                    converted.append(item)
            return converted
    elif isinstance(val, str):
        try:
            return int(val)
        except ValueError:
            try:
                return float(val)
            except ValueError:
                pass
    return val


def convert_scalar_for_dump(field, val):
    if field.type == field.TYPE_ENUM and field.name in STRING_ENUM_PREFIXES:
        pfx = STRING_ENUM_PREFIXES[field.name]
        if isinstance(val, list):
            return [item.upper().removeprefix(pfx).lower() if isinstance(item, str) else item for item in val]
        elif isinstance(val, str):
            return val.upper().removeprefix(pfx).lower()
    return convert_scalar(field, val)


def convert_message_by_desc(desc, d):
    result = {}
    for field in desc.fields:
        if field.name not in d:
            continue
        val = d[field.name]
        if field.message_type and field.label == field.LABEL_REPEATED and isinstance(val, list):
            converted = []
            for item in val:
                if isinstance(item, dict):
                    converted.append(convert_message_by_desc(field.message_type, item))
                else:
                    converted.append(item)
            result[field.name] = converted
        elif field.message_type and isinstance(val, dict):
            result[field.name] = convert_message_by_desc(field.message_type, val)
        else:
            result[field.name] = convert_scalar(field, val)
    return result


def populate_message_from_dict(message, data_dict):
    for key, value in data_dict.items():
        field_descriptor = message.DESCRIPTOR.fields_by_name.get(key)
        if not field_descriptor:
            continue
        if field_descriptor.type == field_descriptor.TYPE_MESSAGE:
            nested_message = getattr(message, key)
            if field_descriptor.label == field_descriptor.LABEL_REPEATED:
                for sub_dict in value:
                    new_item = nested_message.add()
                    populate_message_from_dict(new_item, sub_dict)
            else:
                populate_message_from_dict(nested_message, value)
        else:
            setattr(message, key, convert_scalar(field_descriptor, value))


def get_proto_default(policy_name, field_desc):
    if field_desc.label == field_desc.LABEL_REPEATED:
        return []
    elif field_desc.type == field_desc.TYPE_BOOL:
        return True if policy_name in BOOL_TRUE_DEFAULTS else False
    elif field_desc.type == field_desc.TYPE_STRING:
        return ""
    elif field_desc.type in (field_desc.TYPE_INT32, field_desc.TYPE_INT64,
                              field_desc.TYPE_UINT32, field_desc.TYPE_UINT64,
                              field_desc.TYPE_SINT32, field_desc.TYPE_SINT64,
                              field_desc.TYPE_FIXED32, field_desc.TYPE_FIXED64):
        return 0
    elif field_desc.type == field_desc.TYPE_ENUM:
        values = [v for v in field_desc.enum_type.values
                  if "unspecified" not in v.name.lower() and "unknown" not in v.name.lower()]
        if not values:
            return field_desc.enum_type.values[0].number
        return values[0].number
    else:
        return None


def dump_policy(input_path: str, output_path: str):
    policy_data, ds = read_existing_policy(input_path)
    f2p = build_field_to_policy(load_map())
    raw = json_format.MessageToDict(ds, preserving_proto_field_name=True, including_default_value_fields=False)
    device_dict = {}

    def walk(msg, d, prefix=""):
        for field in msg.DESCRIPTOR.fields:
            if field.name not in d:
                continue
            val = d[field.name]
            path = f"{prefix}{field.name}" if prefix else field.name
            if field.message_type and field.label == field.LABEL_REPEATED and isinstance(val, list):
                converted = []
                for item in val:
                    if isinstance(item, dict):
                        converted.append(convert_message_by_desc(field.message_type, item))
                    else:
                        converted.append(item)
                device_dict[f2p.get(path, path)] = converted
            elif field.message_type and isinstance(val, dict) and path not in f2p:
                walk(getattr(msg, field.name), val, f"{path}.")
            else:
                device_dict[f2p.get(path, path)] = convert_scalar_for_dump(field, val)

    walk(ds, raw)

    device_schema = generate_device_policy_schema(MANUAL_MAP_PATH)
    for policy_name, proto_path in device_schema.items():
        if policy_name in device_dict:
            continue
        parts = proto_path.split(".")
        message = ds
        for part in parts[:-1]:
            message = getattr(message, part)
        field_desc = message.DESCRIPTOR.fields_by_name.get(parts[-1])
        if field_desc:
            device_dict[policy_name] = get_proto_default(policy_name, field_desc)

    output = {"policy_user": policy_data.username, "managed_users": ["*"], "device": device_dict}
    json.dump(output, open(output_path, "w", encoding="utf-8"), indent=2)
    print(f"dumped {len(device_dict)} policies to {output_path}")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <policy_file>")
        print(f"       {sys.argv[0]} --dump --input <policy.1 path> --output <output_file>")
        sys.exit(1)

    if sys.argv[1] == "--dump":
        if "--input" not in sys.argv or "--output" not in sys.argv:
            print(f"Usage: {sys.argv[0]} --dump --input <policy.1 path> --output <output_file>")
            sys.exit(1)
        dump_policy(sys.argv[sys.argv.index("--input") + 1], sys.argv[sys.argv.index("--output") + 1])
        sys.exit(0)

    if os.geteuid() != 0:
        print("must run as root")
        sys.exit(1)

    simple_policies = json.load(open(sys.argv[1], encoding="utf-8"))
    device_schema = generate_device_policy_schema(MANUAL_MAP_PATH)
    policy_data, ds = read_existing_policy(POLICY_PATH)

    for key, value in unquote_numbers(simple_policies["device"]).items():
        if value is None:
            continue
        proto_path = device_schema.get(key)
        if not proto_path:
            print(f"Warning: device policy '{key}' not found in schema, skipping.")
            continue
        parts = proto_path.split(".")
        message = ds
        for part in parts[:-1]:
            message = getattr(message, part)
        final_field = parts[-1]
        field_desc = message.DESCRIPTOR.fields_by_name.get(final_field)
        if not field_desc:
            print(f"Warning: field '{final_field}' not found, skipping.")
            continue
        if isinstance(value, list) and value and isinstance(value[0], dict):
            repeated = getattr(message, final_field)
            del repeated[:]
            for item_dict in value:
                populate_message_from_dict(repeated.add(), convert_message_by_desc(field_desc.message_type, item_dict))
        elif isinstance(value, list):
            repeated = getattr(message, final_field)
            del repeated[:]
            repeated.extend(convert_scalar(field_desc, value))
        elif isinstance(value, dict):
            setattr(message, final_field, json.dumps(value))
        else:
            setattr(message, final_field, convert_scalar(field_desc, value))

    pk, pub = generate_keypair()
    write_devicesettings(public_key_to_der(pub), build_policy_fetch_response(pk, ds, policy_data))
    with open("/root/dmtoken.txt", "w") as f:
        f.write(policy_data.request_token)
    subprocess.run(["initctl", "restart", "ui"], check=True)


if __name__ == "__main__":
    main()