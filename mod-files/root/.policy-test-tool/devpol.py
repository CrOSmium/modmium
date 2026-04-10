# written by lxrd
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

POLICY_TEST_TOOL_PATH = "/usr/local/share/policy-test-tool"
sys.path.insert(0, POLICY_TEST_TOOL_PATH)

import chrome_device_policy_pb2
import device_management_backend_pb2 as dm
from blob_generator import generate_device_policy_schema, apply_device_policies

MANUAL_MAP_PATH = f"{POLICY_TEST_TOOL_PATH}/manual_device_policy_proto_map.yaml"
DEVICESETTINGS_DIR = "/var/lib/devicesettings"
OWNER_KEY_PATH = f"{DEVICESETTINGS_DIR}/owner.key"
POLICY_PATH = f"{DEVICESETTINGS_DIR}/policy.1"


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
        if os.path.exists(f) and not os.path.exists(f + ".bak.school"):
            shutil.copy2(f, f + ".bak.school")
            print(f"backed up {f}")
    for path, data in [(OWNER_KEY_PATH, owner_key_der), (POLICY_PATH, policy_fetch_response)]:
        open(path, "wb").write(data)
        os.chown(path, 0, 0)
        os.chmod(path, 0o644)


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
            if field.message_type and isinstance(val, dict):
                walk(getattr(msg, field.name), val, f"{path}.")
            else:
                device_dict[f2p.get(path, path)] = val

    walk(ds, raw)
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
    apply_device_policies(simple_policies["device"], ds, device_schema)

    pk, pub = generate_keypair()
    write_devicesettings(public_key_to_der(pub), build_policy_fetch_response(pk, ds, policy_data))
    subprocess.run(["initctl", "restart", "ui"], check=True)


if __name__ == "__main__":
    main()