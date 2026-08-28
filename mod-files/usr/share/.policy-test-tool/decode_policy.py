import sys
import os
import json
import argparse
import subprocess
import re
import hashlib

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

ACCOUNT_TYPE_DEVICE  = 0
ACCOUNT_TYPE_USER    = 1

POLICY_DOMAIN_CHROME     = 0
POLICY_DOMAIN_EXTENSIONS = 1

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

def build_policy_descriptor(account_type: int, account_id: str = "", domain: int = POLICY_DOMAIN_CHROME, component_id: str = "") -> bytes:
    blob  = _field_varint(1, account_type)
    if account_id:
        blob += _field_bytes(2, account_id.encode("utf-8"))
    if domain != POLICY_DOMAIN_CHROME:
        blob += _field_varint(3, domain)
    if component_id:
        blob += _field_bytes(4, component_id.encode("utf-8"))
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

def get_user_hash(account_id: str) -> str:
    for salt_path in ["/home/.shadow/salt", "/var/lib/system_salt"]:
        if os.path.exists(salt_path):
            with open(salt_path, "rb") as f:
                system_salt = f.read()
            break
    else:
        raise RuntimeError("No system salt file found at /home/.shadow/salt or /var/lib/system_salt")
    username_lower = account_id.lower().encode("utf-8")
    user_hash = hashlib.sha1(system_salt + username_lower).hexdigest()
    print(f"  User hash: {user_hash}")
    return user_hash

def get_extension_ids(user_hash: str) -> list:
    ext_dir = f"/home/user/{user_hash}/Extensions"
    if not os.path.isdir(ext_dir):
        print(f"  Extensions directory not found: {ext_dir}")
        return []
    ids = [
        name for name in os.listdir(ext_dir)
        if os.path.isdir(os.path.join(ext_dir, name))
        and re.fullmatch(r'[a-p]{32}', name)
    ]
    print(f"  Found {len(ids)} extensions")
    return ids

def fetch_policy_blob(account_type: int, account_id: str = "", domain: int = POLICY_DOMAIN_CHROME, component_id: str = "") -> bytes:
    descriptor_blob = build_policy_descriptor(account_type, account_id, domain, component_id)
    dbus_arg = "array:byte:" + ",".join(f"0x{b:02x}" for b in descriptor_blob)
    output = _run_dbus("RetrievePolicyEx", dbus_arg)
    return _parse_byte_array(output)

def fetch_extension_policy(account_id: str, ext_id: str) -> dict | None:
    try:
        blob = fetch_policy_blob(ACCOUNT_TYPE_USER, account_id, POLICY_DOMAIN_EXTENSIONS, ext_id)
    except RuntimeError:
        return None

    try:
        fetch_response = PolicyFetchResponse()
        fetch_response.ParseFromString(blob)
        if not fetch_response.policy_data:
            return None

        policy_data = PolicyData()
        policy_data.ParseFromString(fetch_response.policy_data)
        if not policy_data.policy_value:
            return None

        raw = policy_data.policy_value.decode("utf-8", errors="replace")
        parsed = json.loads(raw)
        if not parsed:
            return None
        return parsed
    except Exception:
        return None

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
            value = proto.value
        else:
            value = str(proto)

        entry = {"value": value, "scope": scope,
                 "level": level, "source": source}
        if error:
            entry["error"] = error
        policies[policy_name] = entry

    return policies

def decode_policy_fetch_response(blob: bytes, scope="user", source="sourceCloud") -> dict:
    if not HAS_PROTOS:
        raise RuntimeError(
            f"Chromium proto _pb2 files not found or failed to import.\n"
            f"Reason: {_proto_import_reason}\n\n"
            "Make sure all four files are in the same directory as this script:\n"
            "  policy_common_definitions_pb2.py\n"
            "  device_management_backend_pb2.py\n"
            "  cloud_policy_pb2.py\n\n"
            "And that protobuf is installed:\n"
            "  emerge protobuf-python"
        )

    fetch_response = PolicyFetchResponse()
    fetch_response.ParseFromString(blob)

    policy_data = PolicyData()
    policy_data.ParseFromString(fetch_response.policy_data)

    is_managed = (policy_data.state == PolicyData.ACTIVE)

    settings = CloudPolicySettings()
    settings.ParseFromString(policy_data.policy_value)

    policies = decode_cloud_policy_settings(settings, scope, source)

    return policies, policy_data, is_managed

def main():
    parser = argparse.ArgumentParser(
        description=f"Fetch ChromeOS user and device policy via D-Bus and write to {OUTPUT_PATH}"
    )
    parser.add_argument("--account-id")
    parser.add_argument("--input")
    parser.add_argument("--source", default="sourceCloud", choices=list(POLICY_SOURCE.values()))
    parser.add_argument("--no-extensions", action="store_true")
    args = parser.parse_args()

    if args.input:
        print(f"Reading binary blob from {args.input}")
        with open(args.input, "rb") as f:
            blob = f.read()
        user_policies, policy_data, is_managed = decode_policy_fetch_response(blob, "user", args.source)
        device_policies = {}
        identity = {}
        account_id = args.account_id
        user_hash = None
    else:
        print("Fetching policy via D-Bus...")
        account_id = args.account_id or get_active_account_id()
        print(f"  Using account: {account_id}")

        print("  Fetching user policy...")
        user_blob = fetch_policy_blob(ACCOUNT_TYPE_USER, account_id)
        print(f"  Received {len(user_blob)} bytes")
        user_policies, policy_data, is_managed = decode_policy_fetch_response(user_blob, "user", args.source)
        print(f"  Decoded {len(user_policies)} user policies")

        print("  Fetching device policy...")
        device_policies = {}
        try:
            device_blob = fetch_policy_blob(ACCOUNT_TYPE_DEVICE)
            print(f"  Received {len(device_blob)} bytes")
            device_policies, _, _ = decode_policy_fetch_response(device_blob, "machine", args.source)
            print(f"  Decoded {len(device_policies)} device policies")
        except Exception as e:
            print(f"  Warning: could not fetch device policy: {e}")

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

        user_hash = None
        if not args.no_extensions:
            try:
                user_hash = get_user_hash(account_id)
            except Exception as e:
                print(f"  Warning: could not get user hash: {e}")

    all_policies = {**user_policies, **device_policies}

    result = {
        "chromePolicies": {
            "name":     "Chrome Policies",
            "policies": all_policies,
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
        "extensionPolicies": {},
    }

    if not args.input and not args.no_extensions and user_hash and account_id:
        print("Fetching extension policies...")
        ext_ids = get_extension_ids(user_hash)
        for ext_id in ext_ids:
            print(f"  Fetching policy for {ext_id}...")
            ext_policy = fetch_extension_policy(account_id, ext_id)
            if ext_policy:
                result["extensionPolicies"][ext_id] = ext_policy
                print(f"    Got {len(ext_policy)} entries")
            else:
                print(f"    No policy")
        print(f"  Extension policies fetched: {len(result['extensionPolicies'])}")

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    print(f"Written to {OUTPUT_PATH}")

if __name__ == "__main__":
    main()
