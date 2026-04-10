# written by lxrd
import json
import os
import shutil
import subprocess
import sys
from google.protobuf import json_format
POLICY_TEST_TOOL_PATH = "/usr/local/share/policy-test-tool"
sys.path.insert(0, POLICY_TEST_TOOL_PATH)
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.backends import default_backend
import chrome_device_policy_pb2
import device_management_backend_pb2 as dm
from blob_generator import generate_device_policy_schema, apply_device_policies, POLICY_TEST_TOOL_PATH
MANUAL_MAP_PATH = f"{POLICY_TEST_TOOL_PATH}/manual_device_policy_proto_map.yaml"
DEVICESETTINGS_DIR = "/var/lib/devicesettings"
OWNER_KEY_PATH = os.path.join(DEVICESETTINGS_DIR, "owner.key")
POLICY_PATH = os.path.join(DEVICESETTINGS_DIR, "policy.1")
def generate_keypair():
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend(),
    )
    return private_key, private_key.public_key()
def public_key_to_der(public_key):
    return public_key.public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
def sign_data(private_key, data: bytes) -> bytes:
    return private_key.sign(data, padding.PKCS1v15(), hashes.SHA256())
def read_existing_policy(policy_path: str):
    with open(policy_path, "rb") as f:
        raw = f.read()
    response = dm.PolicyFetchResponse()
    response.ParseFromString(raw)
    policy_data = dm.PolicyData()
    policy_data.ParseFromString(response.policy_data)
    device_settings = chrome_device_policy_pb2.ChromeDeviceSettingsProto()
    device_settings.ParseFromString(policy_data.policy_value)
    return policy_data, device_settings
def build_policy_fetch_response(private_key, device_settings, policy_data) -> bytes:
    pd = dm.PolicyData()
    pd.CopyFrom(policy_data)
    pd.policy_value = device_settings.SerializeToString()
    pd.timestamp = int(__import__("time").time() * 1000)
    pd_bytes = pd.SerializeToString()
    response = dm.PolicyFetchResponse()
    response.policy_data = pd_bytes
    response.policy_data_signature = sign_data(private_key, pd_bytes)
    response.policy_data_signature_type = dm.PolicyFetchRequest.SHA256_RSA
    return response.SerializeToString()
def write_devicesettings(owner_key_der: bytes, policy_fetch_response: bytes):
    os.makedirs(DEVICESETTINGS_DIR, exist_ok=True)
    if not any(os.path.exists(f + ".bak.school") for f in [OWNER_KEY_PATH, POLICY_PATH]):
        for f in [OWNER_KEY_PATH, POLICY_PATH]:
            if os.path.exists(f):
                shutil.copy2(f, f + ".bak.school")
                print(f"backed up {f}")
    with open(OWNER_KEY_PATH, "wb") as f:
        f.write(owner_key_der)
    os.chown(OWNER_KEY_PATH, 0, 0)
    os.chmod(OWNER_KEY_PATH, 0o644)
    with open(POLICY_PATH, "wb") as f:
        f.write(policy_fetch_response)
    os.chown(POLICY_PATH, 0, 0)
    os.chmod(POLICY_PATH, 0o644)
def dump_policy(input_path: str, output_path: str):
    policy_data, device_settings = read_existing_policy(input_path)
    raw = json_format.MessageToDict(
        device_settings,
        preserving_proto_field_name=True,
        including_default_value_fields=False,
    )
    device_dict = {}
    for field in device_settings.DESCRIPTOR.fields:
        if field.name not in raw:
            continue
        value = raw[field.name]
        if isinstance(value, dict) and field.name in value and len(value) == 1:
            device_dict[field.name] = value[field.name]
        else:
            device_dict[field.name] = value
    output = {
        "policy_user": policy_data.username,
        "managed_users": ["*"],
        "device": device_dict,
    }
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2)
def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <policy_file>")
        print(f"       {sys.argv[0]} --dump --input <policy.1 path> --output <output_file>")
        sys.exit(1)
    if sys.argv[1] == "--dump":
        if "--input" not in sys.argv or "--output" not in sys.argv:
            print(f"Usage: {sys.argv[0]} --dump --input <policy.1 path> --output <output_file>")
            sys.exit(1)
        input_path = sys.argv[sys.argv.index("--input") + 1]
        output_path = sys.argv[sys.argv.index("--output") + 1]
        dump_policy(input_path, output_path)
        sys.exit(0)
    if os.geteuid() != 0:
        sys.exit(1)
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        simple_policies = json.load(f)
    device_schema = generate_device_policy_schema(MANUAL_MAP_PATH)
    policy_data, device_settings = read_existing_policy(POLICY_PATH)
    apply_device_policies(simple_policies["device"], device_settings, device_schema)
    private_key, public_key = generate_keypair()
    policy_fetch_response = build_policy_fetch_response(private_key, device_settings, policy_data)
    write_devicesettings(
        owner_key_der=public_key_to_der(public_key),
        policy_fetch_response=policy_fetch_response,
    )
    subprocess.run(["initctl", "restart", "ui"], check=True)
if __name__ == "__main__":
    main()
