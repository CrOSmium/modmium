# written by lxrd
import sys
import os
import json
import argparse
import subprocess
import re

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import policy_common_definitions_pb2
    from device_management_backend_pb2 import PolicyFetchResponse, PolicyData
    from cloud_policy_pb2 import CloudPolicySettings
    HAS_PROTOS = True
except ImportError as _proto_import_error:
    HAS_PROTOS = False
    _proto_import_reason = str(_proto_import_error)

SESSION_MANAGER_SERVICE   = "org.chromium.SessionManager"
SESSION_MANAGER_PATH      = "/org/chromium/SessionManager"
SESSION_MANAGER_INTERFACE = "org.chromium.SessionManagerInterface"

ACCOUNT_TYPE_USER    = 1
POLICY_DOMAIN_CHROME = 0

POLICY_OPTIONS_MANDATORY   = 0
POLICY_OPTIONS_RECOMMENDED = 1

POLICY_SOURCE = {
    0: "sourceEnterpriseDefault",
    1: "sourceCloud",
    2: "sourceActiveDirectory",
    3: "sourceDeviceOrUserCloudPolicyManager",
    4: "sourcePlatform",
    5: "sourceMerged",
    6: "sourceCloudFromAsh",
    7: "sourceCommandLine",
}

OUTPUT_PATH = "/root/policy.json"

def _varint(value: int) -> bytes:
    out = []
    while True:
        b = value & 0x7F
        value >>= 7
        if value:
            out.append(b | 0x80)
        else:
            out.append(b)
            break
    return bytes(out)

def _field_varint(field_num: int, value: int) -> bytes:
    return _varint((field_num << 3) | 0) + _varint(value)

def _field_bytes(field_num: int, data: bytes) -> bytes:
    return _varint((field_num << 3) | 2) + _varint(len(data)) + data

def build_policy_descriptor(account_id: str) -> bytes:
    blob  = _field_varint(1, ACCOUNT_TYPE_USER)
    blob += _field_bytes(2, account_id.encode("utf-8"))
    return blob

def _run_dbus(method: str, *args) -> str:
    cmd = [
        "dbus-send",
        "--system",
        "--print-reply",
        f"--dest={SESSION_MANAGER_SERVICE}",
        SESSION_MANAGER_PATH,
        f"{SESSION_MANAGER_INTERFACE}.{method}",
        *args,
    ]
    print(f"  dbus-send: {method}")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(
            f"dbus-send {method} failed:\n"
            f"  stderr: {result.stderr.strip()}\n"
            f"  stdout: {result.stdout.strip()}"
        )
    return result.stdout

def _parse_byte_array(output: str) -> bytes:
    start = output.find('[')
    end   = output.rfind(']')
    if start == -1 or end == -1:
        raise RuntimeError(
            f"No byte array in dbus-send output:\n{output}"
        )
    tokens = re.findall(r'[0-9a-fA-F]{2}', output[start + 1:end])
    if not tokens:
        raise RuntimeError(f"Empty byte array in dbus-send output:\n{output}")
    return bytes(int(t, 16) for t in tokens)

def _parse_active_sessions(output: str) -> dict:
    sessions = {}
    pairs = re.findall(r'string\s+"([^"]+)"', output)
    it = iter(pairs)
    for key in it:
        try:
            value = next(it)
            sessions[key] = value
        except StopIteration:
            break
    return sessions

def get_active_account_id() -> str:
    output = _run_dbus("RetrieveActiveSessions")
    sessions = _parse_active_sessions(output)
    if not sessions:
        raise RuntimeError(
            "No active sessions found. Is a user logged in?"
        )
    account_id = next(iter(sessions))
    print(f"  Found active session: {account_id}")
    return account_id

def fetch_policy_blob(account_id: str) -> bytes:
    descriptor_blob = build_policy_descriptor(account_id)
    dbus_arg = "array:byte:" + ",".join(f"0x{b:02x}" for b in descriptor_blob)
    output = _run_dbus("RetrievePolicyEx", dbus_arg)
    return _parse_byte_array(output)

def get_policy_level(policy_proto):
    if not policy_proto.HasField("value"):
        return None
    if not policy_proto.HasField("policy_options"):
        return "mandatory"
    mode = policy_proto.policy_options.mode
    if mode == POLICY_OPTIONS_MANDATORY:
        return "mandatory"
    elif mode == POLICY_OPTIONS_RECOMMENDED:
        return "recommended"
    return None

def decode_integer_proto(proto):
    value = proto.value
    INT32_MIN, INT32_MAX = -(2 ** 31), 2 ** 31 - 1
    if value < INT32_MIN or value > INT32_MAX:
        return str(value), f"Number out of range - invalid int32: {value}"
    return int(value), None

def decode_string_list_proto(proto):
    return list(proto.value.entries)

def decode_cloud_policy_settings(settings, scope="user", source="sourceCloud"):
    policies = {}
    for field in settings.DESCRIPTOR.fields:
        policy_name = field.name
        try:
            has = settings.HasField(policy_name)
        except ValueError:
            continue
        if not has:
            continue

        proto     = getattr(settings, policy_name)
        type_name = type(proto).__name__
        level     = get_policy_level(proto)
        if level is None:
            continue

        error = None
        if type_name == "BooleanPolicyProto":
            value = proto.value
        elif type_name == "IntegerPolicyProto":
            value, error = decode_integer_proto(proto)
        elif type_name == "StringListPolicyProto":
            value = decode_string_list_proto(proto)
        elif type_name == "StringPolicyProto":
            raw = proto.value
            try:
                parsed = json.loads(raw)
                value = parsed if isinstance(parsed, (dict, list)) else raw
            except (json.JSONDecodeError, ValueError):
                value = raw
        else:
            value = str(proto)

        entry = {"value": value, "scope": scope,
                 "level": level, "source": source}
        if error:
            entry["error"] = error
        policies[policy_name] = entry

    return policies

def decode_policy_fetch_response(blob: bytes, scope="user",
                                  source="sourceCloud") -> dict:
    if not HAS_PROTOS:
        raise RuntimeError(
            f"Chromium proto _pb2 files not found or failed to import.\n"
            f"Reason: {_proto_import_reason}\n\n"
            "Make sure all four files are in the same directory as this script:\n"
            "  policy_common_definitions_pb2.py\n"
            "  device_management_backend_pb2.py\n"
            "  cloud_policy_pb2.py\n\n"
            "And that protobuf 4.x is installed:\n"
            "  pip install 'protobuf>=4.23,<5'"
        )

    fetch_response = PolicyFetchResponse()
    fetch_response.ParseFromString(blob)

    policy_data = PolicyData()
    policy_data.ParseFromString(fetch_response.policy_data)

    identity = {}
    for attr, key in [
        ("device_id",          "client_id"),
        ("annotated_location", "device_location"),
        ("annotated_asset_id", "asset_id"),
        ("display_domain",     "display_domain"),
        ("machine_name",       "machine_name"),
    ]:
        try:
            if policy_data.HasField(attr):
                identity[key] = getattr(policy_data, attr)
        except ValueError:
            pass

    is_managed = (policy_data.state == PolicyData.ACTIVE)

    settings = CloudPolicySettings()
    settings.ParseFromString(policy_data.policy_value)

    policies = decode_cloud_policy_settings(settings, scope, source)

    return {
        "chromePolicies": {
            "name":     "Chrome Policies",
            "policies": policies,
        },
        "status": {
            "user": {
                "is_managed":  is_managed,
                "policy_type": policy_data.policy_type,
                "username":    getattr(policy_data, "username", ""),
                "gaia_id":     getattr(policy_data, "gaia_id", ""),
            }
        },
        "identity": identity,
    }

def main():
    parser = argparse.ArgumentParser(
        description=f"Fetch ChromeOS user policy via D-Bus and write to {OUTPUT_PATH}"
    )
    parser.add_argument(
        "--account-id",
        help="User account email. If omitted, auto-detected from active session."
    )
    parser.add_argument(
        "--input",
        help="Skip D-Bus, decode this binary blob file instead."
    )
    parser.add_argument(
        "--scope", default="user", choices=["user", "machine"],
    )
    parser.add_argument(
        "--source", default="sourceCloud", choices=list(POLICY_SOURCE.values()),
    )
    args = parser.parse_args()

    if args.input:
        print(f"Reading binary blob from {args.input}")
        with open(args.input, "rb") as f:
            blob = f.read()
    else:
        print("Fetching policy via D-Bus...")
        account_id = args.account_id or get_active_account_id()
        print(f"  Using account: {account_id}")
        blob = fetch_policy_blob(account_id)
        print(f"  Received {len(blob)} bytes")

    print("Decoding PolicyFetchResponse...")
    result = decode_policy_fetch_response(blob, args.scope, args.source)
    print(f"  Decoded {len(result['chromePolicies']['policies'])} policies")

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    print(f"Written to {OUTPUT_PATH}")

if __name__ == "__main__":
    main()