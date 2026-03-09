#!/bin/bash

# this is just part of mosh i had to move to a seperate file cuz of weird perms :/

B='\033[1;36m'
G='\033[1;32m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'
D='\033[1;90m'

menu_logo() {
    echo -ne "\033]0;MOSH\007"
    echo -e "Welcome to MOSH, the Modmium developer shell

If you got here by mistake, don't panic! Just close this tab and carry on.

This shell contains a list of utilities for performing various actions on a chromebook running Modmium.
"
}

extlist() {
    clear
    menu_logo
    echo -e "-- ${G}Re-enable disabled extentions${N} --"
    echo ""
    ids=()
    count=0
    declare -A checked
    for manifest in $(find /home/user/*/Extensions/*/*/manifest.json -maxdepth 0); do
        [[ -e "$manifest" ]] || continue
        ext_id=$(echo "$manifest" | awk -F'/' '{print $(NF-2)}')
        if [[ -n "${checked[$ext_id]}" ]]; then
        continue
        fi
        checked[$ext_id]=1
        name=$(jq -r '.name' "$manifest")

        if [[ $name == __MSG_* ]]; then
            key=$(echo "$name" | sed 's/__MSG_//;s/__//')
            default_lang=$(jq -r '.default_locale' "$manifest")
            locale_file="$(dirname "$manifest")/_locales/$default_lang/messages.json"
        
            if [ -f "$locale_file" ]; then
                name=$(jq -r ".\"$key\".message // .\"${key,,}\".message // .\"${key^^}\".message" "$locale_file")
            fi
        fi

        ids+=("$ext_id")
        names+=("$name")
        ((count++))

        printf "[%2d] %s (%s)\n" "$count" "$name" "$ext_id"

    done
    echo ""
    echo -e "Enter the number to the left of an extention to enable it!"
    read -p "Extention number (or 'q' to quit): " choice
    if [[ "$choice" == [Qq] ]]; then
        return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "$count" ] && [ "$choice" -gt 0 ]; then
        index=$((choice-1))
    
        selected_id=${ids[$index]}
        selected_name=${names[$index]}
        echo -e "Enabling $selected_name..."
    
        chmod 700 /home/user/*/Extensions/$selected_id
        sleep 1
        echo -e "$selected_name ($selected_id) was enabled!"
        sleep 1.67
        extlist
    else
        echo -e "Invalid selection, returning to menu..."
        sleep 2
        return
    fi
}
extlist