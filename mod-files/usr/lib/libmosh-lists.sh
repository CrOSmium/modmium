#!/bin/bash
# written by DMD 

# this is an extension of libmosh, used for lists!

listboxtitle=${listboxtitle:-""} # stupid thing on the top of the list idk i like it leave me alone!
listmenu=${listmenu:-0} # flag to set if this thing actually does anything


# because this is an extension and i need this to add on instead of fully replacing, we can just do this.
eval "og_full_menu() $(declare -f full_menu | tail -n +2)" 
eval "og_centermenu() $(declare -f centermenu | tail -n +2)"
# I honestly doubt these will ever be used, but you never know

# also no, i am never adding real hooks for libmosh extensions.
lbox() {
  local cols rows bx by bw bh inner_h inner_w i idx ncol ccol n c tl tlen lpad rpad r
  IFS=' ' read -r rows cols < <(stty size)
  bx=$(( cols / 7 ))
  by=2
  bw=$(( cols - bx ))
  bh=$(( rows - 3 ))
  inner_h=$(( bh - 2 ))
  inner_w=$(( bw - 4 ))
  ncol=$(( inner_w / 2 ))
  ccol=$(( inner_w - ncol - 2 ))
  tl="$listboxtitle"

  if (( ${#listnames[@]} > 0 )); then
    if (( li - sl >= inner_h )); then
      sl=$(( li - inner_h + 1 ))
    elif (( li < sl )); then
      sl=$li
    fi
  fi

  printf '\e[%d;%dH' $by $bx
  [[ $Lf -eq 1 ]] && printf "${B}" || printf "${D}"
  if [[ -n "$tl" ]] && (( ${#tl} + 6 < bw )); then
    tlen=${#tl}
    lpad=$(( (bw - tlen - 6) / 2 ))
    rpad=$(( bw - tlen - 6 - lpad ))
    printf '┌'
    (( lpad > 0 )) && { printf -v lline '%*s' $lpad ''; printf '%s' "${lline// /─}"; }
    printf "[ %s ]" "$tl"
    (( rpad > 0 )) && { printf -v rline '%*s' $rpad ''; printf '%s' "${rline// /─}"; }
    printf "┐${N}"
  else
    printf '┌'
    printf -v hline '%*s' $(( bw - 2 )) ''; printf '%s' "${hline// /─}"
    printf "┐${N}" # thank you anomalous unicode characters!
  fi

  for (( i = 0; i < inner_h; i++ )); do
    idx=$(( i + sl ))
    r=$(( by + 1 + i ))
    printf '\e[%d;%dH' $r $bx
    [[ $Lf -eq 1 ]] && printf "${B}│${N}" || printf "${D}│${N}"
    if (( idx < ${#listnames[@]} )); then
      n="${listnames[$idx]}"
      d="${listdescs[$idx]}"
      if [[ $idx -eq $li ]] && [[ $Lf -eq 1 ]]; then
        printf " \e[7m%-*s  %-*s\e[0m " "$ncol" "${n:0:$ncol}" "$ccol" "${d:0:$ccol}"
      else
        printf " %-*s  ${D}%-*s${N} " "$ncol" "${n:0:$ncol}" "$ccol" "${d:0:$ccol}"
      fi
    else
      printf "%-$(( inner_w + 2 ))s" ""
    fi
    printf '\e[%d;%dH' $r $(( bx + bw - 1 ))
    [[ $Lf -eq 1 ]] && printf "${B}│${N}" || printf "${D}│${N}"
  done

  printf '\e[%d;%dH' $(( by + bh - 1 )) $bx
  [[ $Lf -eq 1 ]] && printf "${B}" || printf "${D}"
  printf '└' # haha └oser!
  printf -v hline '%*s' $(( bw - 2 )) ''; hline=${hline// /─}
  printf "┘${N}"
}

centermenu() {
  if [[ "$listmenu" != "1" ]]; then
    og_centermenu "$@"
    return 
  fi
  local content="$1" voffset="${2:-0}"
  local rows cols line stripped w start_row start_col row halfcols
  local -a lines
  IFS=' ' read -r rows cols < <(stty size)
  halfcols=$(( cols / 2 ))
  mapfile -t lines <<< "$content"
  start_row=$(( (rows - ${#lines[@]}) / 2 - voffset ))
  (( start_row < 0 )) && start_row=0
  row=$start_row
  tput rmam
  shopt -s extglob
  for line in "${lines[@]}"; do
    (( row >= rows )) && break
    stripped="${line//$'\e['*([0-9;])[a-zA-Z]/}"
    w=${#stripped}
    start_col=$(( (halfcols - w) / 16 ))
    (( start_col < 0 )) && start_col=0
    printf '\e[%d;%dH' "$row" 0
    printf "%-${halfcols}s" ""
    printf '\e[%d;%dH' "$row" "$start_col"
    printf '%s' "$line"
    (( row++ ))
  done
  tput smam
  printf "${N}"
  lbox
}

full_menu() { # oh how i hate making changes to my poor libmosh
  if [[ "$listmenu" != "1" ]]; then
    og_full_menu
    return
  fi
  local key keyseq prefix target_index runcmd
  keymap="1234567890-=qwertyuiopasdfghjklzxcvbnm"
  (( ${#listnames[@]} > 0 && li >= ${#listnames[@]} )) && li=$(( ${#listnames[@]} - 1 ))
  (( li < 0 )) && li=0
  clear
  stty -echo
  tput civis
  trap 'resize=1' WINCH
  while true; do
    display_menu "${voffset:-0}"
    while ! read -rsn1 -t 1 key 2>/dev/null; do
      if [[ $resize -eq 1 ]]; then
        resize=0
        clear
        continue 2
      fi
    done
    
    if [[ "$key" == $'\x1b' ]]; then
      read -rsn2 -t 1 keyseq
      case "$keyseq" in
        '[A')
          if [[ $Lf -eq 0 ]]; then
            selected_index=$(( (selected_index - 1 + num_options) % num_options ))
            tempindex=$selected_index
          elif (( li > 0 )); then
            (( li-- ))
          fi
          ;;
        '[B')
          if [[ $Lf -eq 0 ]]; then
            selected_index=$(( (selected_index + 1) % num_options ))
            tempindex=$selected_index
          else
            (( li < ${#listnames[@]} - 1 )) && (( li++ ))
          fi
          ;;
        '[C') # jump!
          if [[ $Lf -ne 1 ]]; then
            tempindex=$selected_index
            selected_index=99
          fi
          Lf=1
          ;;
        '[D') # jump!
          selected_index=$tempindex
          Lf=0
          ;;
      esac
    elif [[ -n "$key" && "$keymap" == *"$key"* ]] && [[ $Lf -eq 0 ]]; then
      prefix="${keymap%%"$key"*}"
      target_index=${#prefix}
      if (( target_index < num_options )); then
        selected_index=$target_index
      fi
    elif [[ "$key" == "" ]]; then
      if [[ $Lf -eq 0 ]]; then
        break
      elif (( ${#listnames[@]} > 0 )); then
        runcmd="${listcmds[$li]}"
        stty echo
        tput cnorm
        clear
        employ $runcmd
        menu_reset
        full_menu
        return
      fi
    fi
    tput rc
  done
  trap - WINCH
  selector
}
