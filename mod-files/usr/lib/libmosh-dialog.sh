#!/bin/bash
# written by pilot bell

declare -F dialog >/dev/null && return
source "${BASH_SOURCE[0]%/*}/libmosh-rich.sh"

dialog_pick() {
  [[ $2 == activate ]] || return
  dialog_answer=${1##*_}
  rich_close
}

dialog_open() {
  local LC_ALL=C.UTF-8
  local type=$1 title=$2 message=$3 initial=$4
  shift 4
  local rich_first=${#rich_ids[@]} rich_layer=$((rich_layer+1)) rich_focus=-1 rich_hover=-1 rich_pressed=-1
  local rich_hover_row=-1 width=${dialogwidth:-54} text="" line chunk name i buttonwidth row=0 x=3 y status
  local -a lines buttons=("$@") button_x button_y button_w
  (( width < 16 )) && width=16
  mapfile -t lines <<< "$message"
  for line in "${lines[@]}"; do
    while (( ${#line} > width-4 )); do
      chunk=${line:0:width-4}
      [[ $chunk == *' '* ]] && chunk=${chunk% *}
      text+="$chunk"$'\n'
      line=${line:${#chunk}} line=${line# }
      (( row++ ))
    done
    text+="$line"$'\n'
    (( row++ ))
  done
  (( ${#buttons[@]} == 0 )) && buttons=("OK")
  rich_layer_w[$rich_layer]=$width
  y=$((row+3))
  [[ $type != none ]] && y=$((y+2))
  for i in "${!buttons[@]}"; do
    buttonwidth=$((${#buttons[$i]}+4))
    (( buttonwidth > width-4 )) && buttonwidth=$((width-4))
    if (( x+buttonwidth > width-1 )); then x=3; (( y+=2 )); fi
    button_x[$i]=$x button_y[$i]=$y button_w[$i]=$buttonwidth
    x=$((x+buttonwidth+1))
  done
  rich_layer_h[$rich_layer]=$((y+2))
  rich_add panel "dialog_${rich_layer}_frame" 1 1 "$width" "$((y+2))" "$title"
  rich_add label "dialog_${rich_layer}_message" 3 2 "$((width-4))" "$row" "${text%$'\n'}"
  if [[ $type != none ]]; then
    name="dialog_${rich_layer}_input"
    rich_add "$type" "$name" 3 "$((row+2))" "$((width-4))" 1 "$initial"
  fi
  for i in "${!buttons[@]}"; do
    rich_add button "dialog_${rich_layer}_$i" "${button_x[$i]}" "${button_y[$i]}" "${button_w[$i]}" 1 "${buttons[$i]}" dialog_pick
  done
  dialog_answer=-1
  if rich_run; then status=0; else status=$?; fi
  [[ $type != none ]] && dialog_value=$(rich_get "$name" value)
  rich_trim "$rich_first"
  unset 'rich_layer_w[rich_layer]' 'rich_layer_h[rich_layer]'
  return "$status"
}

dialog() {
  local title=$1 message=$2
  shift 2
  dialog_open none "$title" "$message" '' "$@"
}

dialog_input() {
  dialog_open textbox "$1" "$2" "${3:-}" "OK" "Cancel"
}

dialog_password() {
  dialog_open password "$1" "$2" '' "OK" "Cancel"
}
