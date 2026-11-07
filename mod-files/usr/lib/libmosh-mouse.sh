#!/bin/bash
# written by pilot bell

declare -F mouse_read >/dev/null && return
mouse_mode=0

mouse_start() {
  case "${1:-1003}" in
    1000|1002|1003) mouse_mode=${1:-1003} ;;
    *) echo "Unknown mouse mode: $1" >&2; return 1 ;;
  esac
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006h\e[?%sh' "$mouse_mode"
}

if declare -F full_menu >/dev/null; then
  eval "mouse_base_menu() $(declare -f full_menu | tail -n +2)"
  full_menu() {
    if [[ ${mouse_enabled:-1} == 0 ]]; then
      mouse_base_menu "$@"
      return
    fi
    mouse_menu_run
  }
fi

mouse_stop() {
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
  mouse_mode=0
}

mouse_menu_geometry() {
  local view=$1 frame line stripped row col width i start half
  local -a lines
  menu_x=() menu_y=() menu_w=()
  IFS=' ' read -r menu_rows menu_cols < <(stty size)
  frame=$(local center_menu=0; display_menu)
  frame=${frame#$(tput sc)}
  mapfile -t lines <<< "$frame"
  start=1
  if [[ $center_menu == 1 ]]; then
    start=$(((menu_rows-${#lines[@]})/2-${voffset:-0}))
    (( start < 0 )) && start=0
  fi
  for i in "${!options[@]}"; do
    row=$((start+${#lines[@]}-${#options[@]}+i))
    (( row < 1 )) && row=1
    line=${lines[$((${#lines[@]}-${#options[@]}+i))]}
    stripped=$line
    while [[ $stripped =~ $'\e'\[[0-9\;]*[a-zA-Z] ]]; do stripped=${stripped/"${BASH_REMATCH[0]}"/}; done
    width=${#stripped} col=1
    if [[ $center_menu == 1 ]]; then
      if [[ $view == list ]]; then half=$((menu_cols/2)); col=$(((half-width)/16))
      else col=$(((menu_cols-width)/2)); fi
      (( col < 1 )) && col=1
    fi
    menu_x[$i]=$col menu_y[$i]=$row menu_w[$i]=$width
  done
}

mouse_menu_hit() {
  local view=$1 i
  mouse_target=-1 mouse_area=menu
  if [[ $view == list && $center_menu == 1 ]]; then
    if (( mouse_x > menu_cols/7 && mouse_x < menu_cols && mouse_y >= 3 && mouse_y < menu_rows-3 )); then
      i=$((mouse_y-3+sl))
      if (( i < ${#listnames[@]} )); then mouse_target=$i mouse_area=list; fi
      return
    fi
  fi
  for i in "${!menu_x[@]}"; do
    if (( mouse_y == menu_y[i] && mouse_x >= menu_x[i] && mouse_x < menu_x[i]+menu_w[i] )); then mouse_target=$i; return; fi
  done
}

mouse_menu_draw() {
  local view=$1 frame height=$((menu_rows-5))
  if [[ $view != list ]]; then display_menu "${voffset:-0}"; return; fi
  if (( height > 0 )); then
    (( li-sl >= height )) && sl=$((li-height+1))
    (( li < sl )) && sl=$li
  fi
  if [[ ${2:-} == box ]]; then frame=$(lbox)
  else frame=$(display_menu "${voffset:-0}"); fi
  printf '%s' "$frame"
}

mouse_menu_restore() {
  local tty=$1 mode=$2 traps=$3
  stty "$tty"
  if (( mode > 0 )); then mouse_start "$mode"; else mouse_stop; fi
  tput cnorm
  trap - INT TERM HUP WINCH
  [[ -n $traps ]] && eval "$traps"
}

mouse_menu_run() {
  local view=${1:-menu} menu_tty menu_traps menu_mouse=$mouse_mode
  local signal="" resize=0 pressed="" target old_index old_li old_focus key prefix status=0 action=""
  local menu_rows menu_cols
  local -a menu_x menu_y menu_w mouse_pending=()
  menu_tty=$(stty -g) || return 1
  menu_traps=$(trap -p INT TERM HUP WINCH)
  trap 'signal=INT' INT
  trap 'signal=TERM' TERM
  trap 'signal=HUP' HUP
  trap 'resize=1' WINCH
  keymap="1234567890-=qwertyuiopasdfghjklzxcvbnm"
  if [[ $view == list ]]; then
    (( li >= ${#listnames[@]} )) && li=$((${#listnames[@]}-1))
    (( li < 0 )) && li=0
  fi
  clear
  stty -echo -icanon min 1 time 0
  tput civis
  mouse_start
  mouse_menu_geometry "$view"
  mouse_menu_draw "$view"
  while [[ -z $signal ]]; do
    if (( resize )); then
      resize=0
      clear
      mouse_menu_geometry "$view"
      mouse_menu_draw "$view"
    fi
    if ! mouse_read_latest; then
      [[ $mouse_key == eof ]] && { status=1; break; }
      continue
    fi
    old_index=$selected_index old_li=${li:-0} old_focus=${Lf:-0}
    key=$mouse_key
    if [[ $key == mouse ]]; then
      case "$mouse_action" in
        wheelup) key=up ;;
        wheeldown) key=down ;;
        *)
          mouse_menu_hit "$view"
          target=$mouse_area:$mouse_target
          if (( mouse_target >= 0 )); then
            if [[ $mouse_area == list ]]; then
              [[ ${Lf:-0} == 0 ]] && tempindex=$selected_index
              Lf=1 li=$mouse_target selected_index=99
            else
              Lf=0 selected_index=$mouse_target tempindex=$mouse_target
            fi
          fi
          if [[ $mouse_action == press && $mouse_button == 0 ]]; then pressed=$target; fi
          if [[ $mouse_action == release && $mouse_button == 0 ]]; then
            [[ $pressed == "$target" && $mouse_target -ge 0 ]] && key=enter
            pressed=""
          fi
          ;;
      esac
    fi
    case "$key" in
      up|down)
        if [[ $view == list && ${Lf:-0} == 1 ]]; then
          if [[ $key == up ]]; then (( li > 0 )) && (( li-- ))
          else (( li < ${#listnames[@]}-1 )) && (( li++ )); fi
        elif (( num_options > 0 )); then
          [[ $key == up ]] && target=-1 || target=1
          selected_index=$(((selected_index+target+num_options)%num_options))
          tempindex=$selected_index
        fi
        ;;
      right|tab)
        if [[ $view == list && ${Lf:-0} == 0 ]]; then tempindex=$selected_index; selected_index=99; Lf=1; fi
        ;;
      left|backtab)
        [[ $view == list ]] && { selected_index=${tempindex:-0}; Lf=0; }
        ;;
      text)
        if [[ ${Lf:-0} == 0 || $view != list ]] && [[ $keymap == *"$mouse_text"* ]]; then
          prefix=${keymap%%"$mouse_text"*}
          (( ${#prefix} < num_options )) && selected_index=${#prefix}
        fi
        ;;
      enter)
        if [[ $view == list && ${Lf:-0} == 1 ]]; then
          (( ${#listnames[@]} > 0 )) && { action=entry; break; }
        else action=menu; break; fi
        ;;
      interrupt) signal=INT ;;
    esac
    if [[ $old_index != "$selected_index" || $old_li != "${li:-0}" || $old_focus != "${Lf:-0}" ]]; then
      if [[ $view == list && $center_menu == 1 && $old_focus == 1 && ${Lf:-0} == 1 ]]; then
        mouse_menu_draw "$view" box
      else
        tput rc
        mouse_menu_draw "$view"
        mouse_menu_geometry "$view"
      fi
    fi
  done
  mouse_menu_restore "$menu_tty" "$menu_mouse" "$menu_traps"
  if [[ -n $signal ]]; then
    kill -s "$signal" "$BASHPID"
    case "$signal" in INT) return 130 ;; TERM) return 143 ;; HUP) return 129 ;; esac
  fi
  case "$action" in
    menu) selector ;;
    entry) employ ${listcmds[$li]}; menu_reset; full_menu ;;
    *) return "$status" ;;
  esac
}

mouse_read_latest() {
  local fd=${1:-0} x y button mods
  if (( ${#mouse_pending[@]} > 0 )); then
    mouse_key=${mouse_pending[0]} mouse_text=${mouse_pending[1]}
    mouse_action=${mouse_pending[2]}
    mouse_button=${mouse_pending[3]} mouse_mods=${mouse_pending[4]}
    mouse_x=${mouse_pending[5]} mouse_y=${mouse_pending[6]}
    mouse_pending=()
    return 0
  fi
  mouse_read "$fd" || return
  [[ $mouse_key == mouse && $mouse_action == move ]] || return 0
  while IFS= read -r -t 0 -u "$fd"; do
    x=$mouse_x y=$mouse_y button=$mouse_button mods=$mouse_mods
    if ! mouse_read "$fd"; then break; fi
    if [[ $mouse_key != mouse || $mouse_action != move ]]; then
      # Save the first non-motion event without reading past it.
      mouse_pending=("$mouse_key" "$mouse_text" "$mouse_action"
        "${mouse_button:-0}" "${mouse_mods:-0}" "${mouse_x:-0}" "${mouse_y:-0}")
      break
    fi
    x=$mouse_x y=$mouse_y button=$mouse_button mods=$mouse_mods
  done
  mouse_key=mouse mouse_text="" mouse_action=move
  [[ -n $x ]] && { mouse_x=$x mouse_y=$y mouse_button=$button mouse_mods=$mods; }
  return 0
}

mouse_read() {
  local LC_ALL=C.UTF-8
  local fd=${1:-0} ch seq="" code status overflow=0
  mouse_key=""
  mouse_text=""
  mouse_action=""
  if IFS= read -rsn1 -u "$fd" -t "${2:-0.1}" ch; then
    :
  else
    status=$?
    [[ $status -eq 1 ]] && mouse_key=eof
    return 1
  fi
  case "$ch" in
    $'\e')
      if ! IFS= read -rsn1 -u "$fd" -t 0.05 ch; then
        mouse_key=escape
        return 0
      fi
      [[ $ch == '[' || $ch == O ]] || { mouse_key=escape; return 0; }
      seq=$ch
      while IFS= read -rsn1 -u "$fd" -t 0.1 ch; do
        seq+=$ch
        [[ $ch == [a-zA-Z~] ]] && break
        (( ${#seq} >= 64 )) && return 1
      done
      case "$seq" in
        '[A'|OA) mouse_key=up ;;
        '[B'|OB) mouse_key=down ;;
        '[C'|OC) mouse_key=right ;;
        '[D'|OD) mouse_key=left ;;
        '[H'|OH|'[1~'|'[7~') mouse_key=home ;;
        '[F'|OF|'[4~'|'[8~') mouse_key=end ;;
        '[3~') mouse_key=delete ;;
        '[5~') mouse_key=pageup ;;
        '[6~') mouse_key=pagedown ;;
        '[Z') mouse_key=backtab ;;
        '[200~')
          seq=""
          # Paste is text, even when it looks like terminal input.
          while IFS= read -rsn1 -u "$fd" -t 1 ch; do
            seq+=$ch
            if [[ $seq == *$'\e[201~' ]]; then
              (( overflow )) && return 1
              mouse_text=${seq%$'\e[201~'}
              mouse_key='paste'
              return 0
            fi
            (( ${#seq} > 65536 )) && overflow=1
            (( overflow )) && seq=${seq: -6}
          done
          return 1
          ;;
        *)
          if [[ $seq =~ ^\[\<([0-9]{1,6})\;([0-9]{1,6})\;([0-9]{1,6})([Mm])$ ]]; then
            code=$((10#${BASH_REMATCH[1]}))
            mouse_x=$((10#${BASH_REMATCH[2]}))
            mouse_y=$((10#${BASH_REMATCH[3]}))
            (( code <= 255 && mouse_x > 0 && mouse_y > 0 )) || return 1
            mouse_button=$((code & 3))
            mouse_mods=$((code & 28))
            if [[ ${BASH_REMATCH[4]} == m ]]; then
              mouse_action=release
            elif (( code & 64 )); then
              (( code & 1 )) && mouse_action=wheeldown || mouse_action=wheelup
            elif (( code & 32 )); then
              mouse_action=move
            else
              mouse_action=press
            fi
            mouse_key=mouse
          fi
          ;;
      esac
      ;;
    ''|$'\r') mouse_key=enter ;;
    $'\t') mouse_key=tab ;;
    $'\177'|$'\b') mouse_key=backspace ;;
    $'\003') mouse_key=interrupt ;;
    *)
      [[ $ch == [[:cntrl:]] ]] && return 1
      mouse_key=text
      mouse_text=$ch
      ;;
  esac
}
