import argparse
import json
import logging
import sys

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def find_deep_value(data):
    if isinstance(data, dict):
        if 'value' in data:
            return data['value']
        for key in data:
            result = find_deep_value(data[key])
            if result is not None:
                return result
    return None

def load_policy_list(policy_dump):
    if 'chromePolicies' in policy_dump:
        policies = policy_dump['chromePolicies'].get('policies', {})
        policy_list = []
        for name, details in policies.items():
            policy_list.append({
                'name': name,
                'value': details.get('value'),
                'scope': details.get('scope', 'user'),
            })
        for ext_id, ext_policies in policy_dump.get('extensionPolicies', {}).items():
            for p_name, p_value in ext_policies.items():
                policy_list.append({
                    'name': p_name,
                    'value': p_value,
                    'scope': 'extensions',
                    'ext_id': ext_id,
                })
        return policy_list, {}

    policy_list_raw = policy_dump.get('policyValues', {}).get('chrome', {}).get('policies')
    ext_list = policy_dump.get('policyValues', {}).get('extensions', {})

    if not policy_list_raw:
        logging.critical("Could not find policies in input JSON.")
        sys.exit(1)

    policy_list = []
    for name, details in policy_list_raw.items():
        policy_list.append({
            'name': name,
            'value': details.get('value'),
            'scope': details.get('scope'),
        })

    for ext_id, ext_content in ext_list.items():
        inner_policies = ext_content.get('policies', {})
        for p_name, p_details in inner_policies.items():
            val = find_deep_value(p_details)
            if val is not None:
                policy_list.append({
                    'name': p_name,
                    'value': val,
                    'scope': 'extensions',
                    'ext_id': ext_id,
                })

    return policy_list, ext_list

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dump", required=True)
    parser.add_argument("--output-policies", required=True)
    parser.add_argument("--policy-user", required=True)
    args = parser.parse_args()

    try:
        with open(args.input_dump, "r", encoding="utf-8") as f:
            policy_dump = json.load(f)
    except (IOError, json.JSONDecodeError) as e:
        logging.critical(f"Failed to read or parse input file '{args.input_dump}': {e}")
        sys.exit(1)

    simple_policies = {
        "policy_user": args.policy_user,
        "managed_users": ["*"],
        "user": {},
        "extensions": {},
        "device": {}
    }

    policy_list, _ = load_policy_list(policy_dump)

    for policy in policy_list:
        name = policy.get('name')
        value = policy.get('value')
        scope = policy.get('scope')

        if not name or not scope:
            logging.warning(f"Skipping entry with missing name or scope: {policy}")
            continue
        if value is None:
            logging.warning(f"Skipping policy '{name}' with a None value.")
            continue

        if scope == 'user':
            simple_policies['user'][name] = value
        elif scope in ('device', 'machine'):
            simple_policies['device'][name] = value
        elif scope == 'extensions':
            eid = policy.get('ext_id')
            if eid not in simple_policies['extensions']:
                simple_policies['extensions'][eid] = {}
            simple_policies['extensions'][eid][name] = value
        else:
            logging.warning(f"Skipping policy '{name}' with unknown scope: '{scope}'")

    try:
        with open(args.output_policies, "w", encoding="utf-8") as f:
            json.dump(simple_policies, f, indent=2)
        logging.info(f"Successfully converted policies to {args.output_policies}")
    except IOError as e:
        logging.critical(f"Failed to write output file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
