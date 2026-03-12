#!/bin/bash
echo -ne "If your school has a custom sign-in page, you can use this to remove an account without powerwashing (requires reboot). \
${D}(Ctrl+C to cancel)
${G}Enter target email: ${N}"
read -rep "" email
hash=$(cryptohome --action=obfuscate_user --user=$email)
if [[ -d /home/.shadow/$hash ]]; then
  echo -e "${G}User directory found! Preparing to delete on reboot...${N}"
  echo $hash >/.delete_user
  echo -e "${G}Done! Reboot when ready...${N}"
  sleep 2
  return
else
  echo -e "${R}User directory not found :(${N} \
Exiting..."
  sleep 2
  return
fi 
