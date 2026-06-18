#!/bin/bash
# Written by pilot bell and dmd

source /usr/lib/libmosh.sh

if ! which git &>/dev/null || ! which file &>/dev/null; then
  echo -e "${R}Dependencies not installed, installing...${N}"
  source /etc/profile # required to get emerge working in mosh
  if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
    printf 'y\n\nn' | dev_install --reinstall || fail "${R}Could not install dependencies. Connect to the internet first.${N}"
    touch /mnt/stateful_partition/.devinstall_complete
  fi
  ldconfig # reload shared libraries to include python libs
  emerge git file
  cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
fi
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/usr/bin:/usr/local/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
ldconfig
PY="$(command -v python3 || command -v python)"
[ -n "$PY" ] || {
  echo "no python found :("
  sleep 3
  exit 1
}

# -- user prompts --
clear
echo -e "-------------- ${G}Modmium Local Account Creator${N} --------------"
echo -e "${D}Created by Pilot Bell and DMD${N}"
echo -e "This creates a local account, so ${R}account specific features may not work${N}, or may have major bugs.\nIf you run into any Modmium specific problems, create an issue on the GitHub.\n"
echo -e "What would you like your local account's USERNAME to be?"
echo -ne "[USERNAME]: "
read -re username 
username=$(echo "$username" | tr ' ' '.' | tr '[:upper:]' '[:lower:]')
while true; do
  echo -ne "[CUSTOM DOMAIN (press enter for modmium.dev)]: "
  read -re domain
  domain=${domain:-modmium.dev}
  if [[ "$domain" == *.* && "$domain" != *. ]]; then
    break
  else
    echo "Invalid custom domain, it must contain at least one '.' and cannot end with '.'"
  fi
done
U="$username@$domain"
echo -e "Your account's email will be '${G}$U${N}'"
while true; do
  echo -ne "[PASSWORD]: "
  read -rse pass 
  echo ""
  echo -ne "[CONFIRM PASSWORD]: "
  read -rse passconf
  echo ""
  if [[ "$pass" == "$passconf" ]]; then
    P="$pass"
    break
  else
    echo -e "Passwords do not match! Try again.\n"
    sleep 1
  fi
done
echo -e "What would you like your local account's DISPLAY name to be?"
echo -ne "[DISPLAY NAME]: "
read -re display
N="$display"
G="$username"

while true; do
  echo -ne "Do you want to skip OOBE? (Must be in VT2). ONLY DO THIS IF YOU HAVE NOT COMPLETED OOBE YET [y/N]: "
  read -r skip_oobe
  case "${skip_oobe,,}" in
    y|yes)
      SKIP_OOBE=1
      break
      ;;
    n|no|"")
      SKIP_OOBE=0
      break
      ;;
    *)
      echo "Please enter Y or N."
      ;;
  esac
done

echo -e "Creating local account... (thanks Pilot Bell!)"
sleep 2

# -- actual account making --

# Hey! if you think about removing any output from this, don't. It's very important that the user can see if it fails.
L='gaia'
H="$(cryptohome --action=obfuscate_user --user="$U" 2>/dev/null | tail -1)"

cp -a "/home/chronos/Local State" "/home/chronos/Local State.bak.localacct"

if ! cryptohome --action=is_mounted --user="$U" | grep -q true; then
  OUT="$(cryptohome --action=start_auth_session --user="$U" --auth_intent=AUTH_INTENT_DECRYPT 2>&1)"
  SID="$(printf '%s\n' "$OUT" | awk '/auth_session_id:/ {print $2; exit}' | tr -d '"')"

  if cryptohome --action=list_auth_factors --user="$U" 2>&1 | grep -q 'label: gaia'; then
    cryptohome --action=authenticate_auth_factor \
      --auth_session_id="$SID" \
      --key_label="$L" \
      --password="$P"
  else
    cryptohome --action=create_persistent_user \
      --auth_session_id="$SID"

    cryptohome --action=add_auth_factor \
      --auth_session_id="$SID" \
      --key_label="$L" \
      --password="$P"
  fi

  cryptohome --action=prepare_persistent_vault \
    --auth_session_id="$SID"
fi

U="$U" N="$N" G="$G" "$PY" - <<'PY'
import json, os

path = '/home/chronos/Local State'
user = os.environ['U']
display_name = os.environ['N']
given_name = os.environ['G']

with open(path) as f:
    data = json.load(f)

known_users = data.setdefault('KnownUsers', [])
entry = next(
    (
        x for x in known_users
        if isinstance(x, dict) and x.get('email', '').lower() == user.lower()
    ),
    None,
)

if entry is None:
    entry = {'email': user}
    known_users.append(entry)

entry.update({
    'email': user,
    'profile_requires_policy': False,
    'using_saml': False,
    'using_saml_principals_api': False,
    'is_enterprise_managed': False,
    'last_input_method': 'xkb:us::eng',
    'reauth_reason': 0,
})

for key in ('gaps_cookie', 'enterprise_account_manager', 'onboarding_screen_pending'):
    entry.pop(key, None)

logged_in = [x for x in data.setdefault('LoggedInUsers', []) if x != user]
data['LoggedInUsers'] = [user] + logged_in

data.setdefault('UserDisplayName', {})[user] = display_name
data.setdefault('UserGivenName', {})[user] = given_name
data.setdefault('UserDisplayEmail', {})[user] = user
data.setdefault('UserForceOnlineSignin', {})[user] = False
data.setdefault('OAuthTokenStatus', {})[user] = 1
data.setdefault('UserType', {})[user] = 0

data['LastActiveUser'] = user
data['LastLoggedInRegularUser'] = user

with open(path, 'w') as f:
    json.dump(data, f, separators=(',', ':'))
PY

mkdir -p "/home/user/$H/.pki/nssdb"
[ -f "/home/user/$H/Preferences" ] || printf '{}\n' >"/home/user/$H/Preferences"
chown -R chronos:chronos "/home/user/$H" 2>/dev/null

cp -a /etc/chrome_dev.conf /etc/chrome_dev.conf.bak.localacct 2>/dev/null || true

for f in \
  --disable-gaia-services \
  --skip-force-online-signin-for-testing \
  --allow-failed-policy-fetch-for-test
do
  grep -qx -- "$f" /etc/chrome_dev.conf 2>/dev/null || echo "$f" >>/etc/chrome_dev.conf
done
RE=$'\033[0m'
if [[ "$TERM" == "xterm-256color" ]]; then
  echo -e "${R}Local account will be added to your current session, this may close MOSH.${RE}"
  sleep 2
fi
if [[ "$SKIP_OOBE" -eq 1 ]]; then
  grep -qx -- "--oobe-skip-to-login" /etc/chrome_dev.conf 2>/dev/null || \
    echo "--oobe-skip-to-login" >> /etc/chrome_dev.conf
    touch /root/.removeskipoobeflag
fi
dbus-send \
  --system \
  --print-reply \
  --dest=org.chromium.SessionManager \
  /org/chromium/SessionManager \
  org.chromium.SessionManagerInterface.EnableChromeTesting \
  boolean:true \
  array:string:"--login-user=$U","--login-profile=$H","--oobe-skip-postlogin","--disable-gaia-services","--skip-force-online-signin-for-testing","--allow-failed-policy-fetch-for-test" \
  array:string:

sync
GR=$'\033[38;5;46m'
[[ $TERM == "xterm-256color" ]] || initctl restart ui # this fixes a bug where it refuses to let you sign in if this is ran on the lock screen
echo -e "\n${GR}Done! '$U' has been added as a local account${RE} \nIf logging in doesn't work, remove the account (or powerwash) and try again."
if [[ "$SKIP_OOBE" -eq 1 ]]; then
  initctl restart ui

  echo "UI restarted. Switch back to VT1 (Ctrl+Alt+F1) to continue..."

  while true; do
    cur="$(basename "$(readlink /run/frecon/current 2>/dev/null)")"

    if [[ "$cur" != "vt1" && "$cur" != "vt2" && "$cur" != "vt3" ]]; then
      echo "Detected $cur, restarting UI again..."
      sleep 5
      initctl restart ui
      break
    fi

    sleep 0.25
  done
else
  sleep 3
  exit 0
fi
