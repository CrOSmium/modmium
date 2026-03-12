#!/bin/bash
B='\033[1;36m' 
G='\033[1;32m' 
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'    
D='\033[1;90m'

echo -e "If your school has a custom sign-in page, you can use this to remove an account without powerwashing (requires reboot). \
${D}(Ctrl+C to cancel)"
echo -ne "${G}Enter target email: ${N}"
read -rep "" email
echo $email >/.delete_user
echo -e "${G}Done setting up, reboot to finish!${N}"
sleep 2
return
