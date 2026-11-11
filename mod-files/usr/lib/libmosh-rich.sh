#!/bin/bash
# written by pilot bell

declare -F rich_run >/dev/null && return
source "${BASH_SOURCE[0]%/*}/libmosh-mouse.sh"

rich_reset() {
  rich_ids=() rich_types=() rich_x=() rich_y=() rich_w=() rich_h=()
  rich_text=() rich_value=() rich_choices=() rich_descs=() rich_cmds=()
  rich_disabled=() rich_hidden=() rich_tip=() rich_align=() rich_columns=() rich_cardheight=() rich_shortcuts=()
  rich_caret=() rich_scroll=() rich_left=() rich_group=()
  rich_layer_w=() rich_layer_h=()
  rich_lastpaint=() rich_lastrect=() rich_laststart=() rich_lastcache=()
  rich_gridstamp=() rich_gridpos=() rich_gridhover=()
  rich_oldrows=0 rich_oldcols=0 rich_lastviewport=""
  rich_focus=-1 rich_hover=-1 rich_pressed=-1 rich_press_row=-1 rich_first=0 rich_layer=0
}

rich_trim() {
  local field j
  for field in ids types x y w h text value choices descs cmds disabled hidden tip align columns cardheight shortcuts caret scroll left group; do
    local -n prop="rich_$field"
    for (( j=${#prop[@]}-1; j>=$1; j-- )); do unset 'prop[j]'; done
  done
}

rich_find() {
  local i
  for i in "${!rich_ids[@]}"; do
    [[ ${rich_ids[$i]} == "$1" ]] && { rich_index=$i; return 0; }
  done
  echo "Unknown rich element: $1" >&2
  return 1
}

rich_add() {
  local LC_ALL=C.UTF-8
  local type=$1 id=$2 x=$3 y=$4 w=$5 h=$6 text=${7:-} cmd=${8:-} i
  case "$type" in
    label|panel|rule|button|textbox|password|textarea|checkbox|radio|select|tabs|list|grid|progress|slider) ;;
    *) echo "Unknown rich element type: $type" >&2; return 1 ;;
  esac
  [[ $id =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ && $x =~ ^-?(0|[1-9][0-9]*)$ && $y =~ ^-?(0|[1-9][0-9]*)$ && $w =~ ^-?(0|[1-9][0-9]*)$ && $h =~ ^-?(0|[1-9][0-9]*)$ ]] || {
    echo "Invalid rich element: $id" >&2; return 1;
  }
  (( w != 0 && h != 0 )) || { echo "Element dimensions cannot be zero" >&2; return 1; }
  [[ -z $cmd || $cmd =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ ]] || { echo "Use a callback function name" >&2; return 1; }
  for i in "${!rich_ids[@]}"; do
    [[ ${rich_ids[$i]} == "$id" ]] && { echo "Duplicate rich element: $id" >&2; return 1; }
  done
  i=${#rich_ids[@]}
  rich_ids[$i]=$id rich_types[$i]=$type rich_x[$i]=$x rich_y[$i]=$y
  rich_w[$i]=$w rich_h[$i]=$h rich_text[$i]=$text rich_cmds[$i]=$cmd
  rich_value[$i]=0 rich_caret[$i]=0 rich_scroll[$i]=0 rich_left[$i]=0
  rich_disabled[$i]=0 rich_hidden[$i]=0 rich_group[$i]=$rich_layer
  rich_choices[$i]="" rich_descs[$i]="" rich_tip[$i]="" rich_align[$i]=left rich_columns[$i]=0 rich_cardheight[$i]=6 rich_shortcuts[$i]=""
  case "$type" in
    textbox|password|textarea) rich_value[$i]=$text; rich_caret[$i]=${#text} ;;
  esac
}

rich_set() {
  local LC_ALL=C.UTF-8
  rich_find "$1" || return
  local i=$rich_index field=$2 text=$3
  case "$field" in
    x|y|w|h|columns|cardheight|disabled|hidden)
      [[ $text =~ ^-?(0|[1-9][0-9]*)$ ]] || { echo "Expected a number for $field" >&2; return 1; }
      case "$field" in
        w|h) (( text != 0 )) || return 1 ;;
        columns) (( text >= 0 )) || return 1 ;;
        cardheight) (( text >= 3 )) || return 1 ;;
        disabled|hidden) [[ $text == 0 || $text == 1 ]] || return 1 ;;
      esac
      ;;
    value)
      case "${rich_types[$i]}" in
        textbox|password|textarea) ;;
        *)
          [[ $text =~ ^(0|[1-9][0-9]*)$ ]] || { echo "Expected a numeric selection" >&2; return 1; }
          case "${rich_types[$i]}" in
            checkbox) [[ $text == 0 || $text == 1 ]] || return 1 ;;
            progress|slider) (( text <= 100 )) || return 1 ;;
          esac
          ;;
      esac
      ;;
    align) [[ $text == left || $text == center || $text == right ]] || return 1 ;;
    text|choices|descs|tip|shortcuts) ;;
    *) echo "Unknown rich property: $field" >&2; return 1 ;;
  esac
  local -n prop="rich_$field"
  prop[$i]=$text
  if [[ $field == value ]]; then
    rich_caret[$i]=${#text}
  fi
}

rich_get() {
  rich_find "$1" || return
  case "$2" in
    x|y|w|h|columns|cardheight|shortcuts|disabled|hidden|value|align|text|choices|descs|tip)
      local -n prop="rich_$2"
      printf '%s' "${prop[$rich_index]}"
      ;;
    *) echo "Unknown rich property: $2" >&2; return 1 ;;
  esac
}

rich_measure() {
  IFS=' ' read -r rich_rows rich_cols < <(stty size)
  (( rich_rows > 0 && rich_cols > 0 )) || return 1
  rich_screenw=${rich_width:-70}
  rich_screenh=${rich_height:-20}
  (( rich_screenw > rich_cols )) && rich_screenw=$rich_cols
  (( rich_screenh > rich_rows )) && rich_screenh=$rich_rows
  rich_originx=0 rich_originy=0
  if [[ ${rich_center:-${center_menu:-0}} == 1 ]]; then
    rich_originx=$(( (rich_cols - rich_screenw) / 2 ))
    rich_originy=$(( (rich_rows - rich_screenh) / 2 - ${voffset:-0} ))
    (( rich_originy < 0 )) && rich_originy=0
  fi
  return 0
}

rich_bounds() {
  local i=$1 g=${rich_group[$1]} cw=$rich_screenw ch=$rich_screenh ox=$rich_originx oy=$rich_originy
  if (( g > 0 )); then
    cw=${rich_layer_w[$g]} ch=${rich_layer_h[$g]}
    (( cw > rich_cols )) && cw=$rich_cols
    (( ch > rich_rows )) && ch=$rich_rows
    ox=$(( (rich_cols - cw) / 2 )) oy=$(( (rich_rows - ch) / 2 ))
  fi
  bw=${rich_w[$i]} bh=${rich_h[$i]}
  (( bw < 0 )) && bw=$((cw + bw))
  (( bh < 0 )) && bh=$((ch + bh))
  (( bw > cw )) && bw=$cw
  (( bh > ch )) && bh=$ch
  bx=${rich_x[$i]} by=${rich_y[$i]}
  (( bx == 0 )) && bx=$(( (cw - bw) / 2 + 1 ))
  (( by == 0 )) && by=$(( (ch - bh) / 2 + 1 ))
  (( bx < 0 )) && bx=$((cw - bw + bx + 1))
  (( by < 0 )) && by=$((ch - bh + by + 1))
  (( bw > cw - bx + 1 )) && bw=$((cw - bx + 1))
  (( bh > ch - by + 1 )) && bh=$((ch - by + 1))
  bx=$((bx + ox)) by=$((by + oy))
}

rich_line() {
  local LC_ALL=C.UTF-8
  local x=$1 y=$2 w=$3 text=$4 align=${5:-left} out="" ch n=0 pad=0 sgr="" lead="" segment tail=""
  rich_tail=""
  (( y >= 1 && y <= rich_rows && x >= 1 && w > 0 )) || return 0
  (( w > rich_cols - x + 1 )) && w=$((rich_cols - x + 1))
  # Leave the last cell alone. Some terminals scroll even with wrap disabled.
  (( y == rich_rows && x + w > rich_cols )) && (( w-- ))
  (( w > 0 )) || return 0
  while [[ -n $text ]] && (( n < w )); do
    if [[ $text =~ ^$'\e'\[[0-9\;]*m ]]; then
      out+=${BASH_REMATCH[0]}
      sgr+=${BASH_REMATCH[0]}
      (( n == 0 )) && lead+=${BASH_REMATCH[0]}
      text=${text:${#BASH_REMATCH[0]}}
      continue
    fi
    if [[ $text != *[[:cntrl:]]* ]]; then
      ch=${text:0:$((w-n))}
      out+=$ch text=${text:${#ch}}
      (( n+=${#ch} ))
      break
    fi
    ch=${text:0:1} text=${text:1}
    [[ $ch == [[:cntrl:]] ]] && continue
    out+=$ch
    (( n++ ))
  done
  [[ -n $text ]] && rich_tail=$sgr$text
  case "$align" in
    center) pad=$(( (w - n) / 2 )) ;;
    right) pad=$((w - n)) ;;
  esac
  (( pad == 0 )) && lead=""
  (( w-n-pad > 0 )) && tail=$sgr
  printf -v segment '\e[%d;%dH%s%*s%s%s%*s\e[0m' "$y" "$x" "$lead" "$pad" '' "$out" "$tail" "$((w - n - pad))" ''
  if [[ ${rich_buffering:-0} == 1 ]]; then
    rich_paint+=("$segment") rich_rect+=("$x:$y:$w")
  else printf '%s' "$segment"; fi
}

rich_focusable() {
  [[ ${rich_hidden[$1]} == 0 && ${rich_disabled[$1]} == 0 ]] || return 1
  case "${rich_types[$1]}" in label|panel|rule|progress) return 1 ;; esac
}

rich_box() {
  local x=$1 y=$2 w=$3 h=$4 style=$5 line j
  (( w >= 2 && h >= 2 )) || return 0
  printf -v line '%*s' "$((w-2))" ''
  rich_line "$x" "$y" "$w" "${style}┌${line// /─}┐"
  rich_line "$x" "$((y+h-1))" "$w" "${style}└${line// /─}┘"
  for (( j=1; j<h-1; j++ )); do
    rich_line "$x" "$((y+j))" "$w" "${style}│$line│"
  done
}

rich_grid_size() {
  columns=${rich_columns[$1]}
  (( columns == 0 )) && columns=$(($2/24))
  (( columns < 1 )) && columns=1
  (( columns > $2 )) && columns=$2
  (( columns < 1 )) && columns=1
  cell=$(($2/columns))
  cardheight=${rich_cardheight[$1]}
  (( cardheight > $3 )) && cardheight=$3
  (( cardheight < 1 )) && cardheight=1
  rows=$(($3/cardheight))
  (( rows < 1 )) && rows=1
}

rich_next() {
  local step=$1 n=${#rich_ids[@]} i=$rich_focus j
  (( n > rich_first )) || { rich_focus=-1; return; }
  for (( j=rich_first; j<n; j++ )); do
    i=$(( rich_first + (i - rich_first + step + n - rich_first) % (n - rich_first) ))
    if rich_focusable "$i"; then
      rich_focus=$i
      return
    fi
  done
  rich_focus=-1
}

rich_draw_choices() {
  local i=$1 x=$2 y=$3 w=$4 h=$5 style=$6 pos=${rich_value[$1]}
  local n j k start count columns cell rows cardheight line border r stamp
  local grid_reuse=0 grid_ops grid_from grid_oldpos grid_oldhover
  local border_color=$'\e[38;2;105;125;135m' text_color=$'\e[38;2;230;235;238m'
  local hover_bg=$'\e[48;2;42;62;70m' selected=$'\e[38;2;16;16;16;48;2;255;255;255m'
  local disabled=$'\e[38;2;130;140;145m' description=$'\e[38;2;165;180;188m' selected_description=$'\e[38;2;80;80;80m'
  if (( rich_ansi )); then
    border_color=$'\e[37;40m' text_color=$'\e[97;40m' hover_bg=$'\e[100m'
    selected=$'\e[30;107m' disabled=$'\e[90;40m' description=$'\e[37m' selected_description=$'\e[30m'
  fi
  local -a entries=() descs=()
  [[ -n ${rich_choices[$i]} ]] && mapfile -t entries <<< "${rich_choices[$i]}"
  [[ -n ${rich_descs[$i]} ]] && mapfile -t descs <<< "${rich_descs[$i]}"
  n=${#entries[@]}
  (( pos >= n )) && pos=$((n-1))
  (( pos < 0 )) && pos=0
  rich_value[$i]=$pos
  columns=1 cell=$w rows=$h
  [[ ${rich_types[$i]} == grid ]] && rich_grid_size "$i" "$w" "$h"
  if [[ ${rich_types[$i]} == tabs ]] && (( n > 0 )); then
    cell=$((w/n)); (( cell < 1 )) && cell=1
    for j in "${!entries[@]}"; do
      [[ $j == "$pos" ]] && style=$'\e[7m' || style=""
      rich_line "$((x+j*cell))" "$y" "$cell" "$style${entries[$j]}" center
    done
    return 0
  fi
  if [[ ${rich_types[$i]} == select ]]; then
    rich_line "$x" "$y" "$w" "$style< ${entries[$pos]:-} >" center
    return 0
  fi
  start=${rich_scroll[$i]}
  (( start > pos/columns )) && start=$((pos/columns))
  (( pos/columns >= start+rows )) && start=$((pos/columns-rows+1))
  rich_scroll[$i]=$start
  if [[ ${rich_types[$i]} == grid ]]; then
    printf -v stamp '%q|' "$x" "$y" "$w" "$h" "$columns" "$cardheight" "$start" "${rich_choices[$i]}" "${rich_descs[$i]}" "${rich_disabled[$i]}" "$rich_ansi"
    [[ ${#rich_lastpaint[@]} -gt 0 && $stamp == "${rich_gridstamp[$i]:-}" ]] && grid_reuse=1
    grid_oldpos=${rich_gridpos[$i]:--1} grid_oldhover=${rich_gridhover[$i]:--1}
    rich_gridstamp[$i]=$stamp rich_gridpos[$i]=$pos
    rich_gridhover[$i]=-1
    [[ $i == "$rich_hover" ]] && rich_gridhover[$i]=${rich_hover_row:--1}
    # A card paints its box rows, title, and description when there is room.
    grid_ops=$((cardheight+1))
    (( cardheight == 3 )) && grid_ops=$cardheight
    (( cardheight < 3 || cell < 4 )) && grid_ops=1
  fi
  for (( j=0; j<rows; j++ )); do
    for (( k=0; k<columns; k++ )); do
      count=$(((start+j)*columns+k))
      if (( grid_reuse && count < n && count != pos && count != grid_oldpos && count != grid_oldhover && count != rich_gridhover[i] )); then
        grid_from=$((rich_laststart[i]+(j*columns+k)*grid_ops))
        rich_paint+=("${rich_lastpaint[@]:grid_from:grid_ops}") rich_rect+=("${rich_lastrect[@]:grid_from:grid_ops}")
        continue
      fi
      line="" style=""
      if (( count < n )); then
        if [[ $i == "$rich_focus" && $count == "$pos" ]]; then
          style=$'\e[7m'
        elif [[ $i == "$rich_hover" && $count == "${rich_hover_row:--1}" ]]; then
          if (( rich_ansi )); then style=$'\e[36;100m'
          else style=${B:-$'\e[36m'}$'\e[48;5;236m'; fi
        fi
        [[ ${rich_disabled[$i]} == 1 ]] && style=${D:-$'\e[90m'}
        line=${entries[$count]}
        [[ ${rich_types[$i]} == list && -n ${descs[$count]:-} ]] && line+="   ${descs[$count]}"
        if [[ ${rich_types[$i]} == radio ]]; then
          [[ $count == "$pos" ]] && line="(*) $line" || line="( ) $line"
        fi
      fi
      if [[ ${rich_types[$i]} == grid ]]; then
        (( count < n )) || continue
        border=$border_color
        style=$text_color
        if [[ $i == "$rich_hover" && $count == "${rich_hover_row:--1}" ]]; then
          border+=$hover_bg
          style+=$hover_bg
        fi
        if [[ $i == "$rich_focus" && $count == "$pos" ]]; then
          border=$selected
          style=$border
        fi
        [[ ${rich_disabled[$i]} == 1 ]] && style=$disabled
        if (( cardheight < 3 || cell < 4 )); then
          rich_line "$((x+k*cell))" "$((y+j*cardheight))" "$cell" "$style$line"
          continue
        fi
        if [[ $i == "$rich_focus" && $count == "$pos" ]]; then
          for (( r=0; r<cardheight-1; r++ )); do
            rich_line "$((x+k*cell))" "$((y+j*cardheight+r))" "$((cell-1))" "$border"
          done
        else
          rich_box "$((x+k*cell))" "$((y+j*cardheight))" "$((cell-1))" "$((cardheight-1))" "$border"
        fi
        rich_line "$((x+k*cell+1))" "$((y+j*cardheight+cardheight/2-1))" "$((cell-3))" "$style${line:+$'\e[1m'}$line" center
        if (( cardheight > 3 )); then
          [[ $i == "$rich_focus" && $count == "$pos" ]] && style+=$selected_description || style+=$description
          rich_line "$((x+k*cell+1))" "$((y+j*cardheight+cardheight/2))" "$((cell-3))" "$style${descs[$count]:-}" center
        fi
      else
        rich_line "$x" "$((y+j))" "$w" "$style$line" "${rich_align[$i]}"
      fi
    done
  done
  return 0
}

rich_present() {
  local -n paint=$2 rects=$3 starts=$4 stamps=$5
  local i frame="" refresh=0 repaint dx dy dw ox oy ow rect blank
  local -a damage dirty_left dirty_right
  if [[ ${#rich_lastpaint[@]} == 0 || $rich_rows != "$rich_oldrows" || $rich_cols != "$rich_oldcols" ]]; then
    refresh=1
  else
    for i in "${!rich_lastrect[@]}"; do
      if [[ ${rects[$i]:-} != "${rich_lastrect[$i]}" ]]; then
        damage+=("${rich_lastrect[$i]}")
        [[ -n ${rects[$i]:-} ]] && refresh=2
      fi
    done
  fi
  if (( refresh == 1 )); then frame=$'\e[H\e[2J'
  else
    for rect in "${damage[@]}"; do
      IFS=: read -r dx dy dw <<< "$rect"
      printf -v blank '\e[0m\e[%d;%dH%*s' "$dy" "$dx" "$dw" ''
      frame+=$blank
      if [[ -z ${dirty_left[$dy]:-} ]] || (( dx < dirty_left[dy] )); then dirty_left[$dy]=$dx; fi
      if (( dx+dw > ${dirty_right[$dy]:-0} )); then dirty_right[$dy]=$((dx+dw)); fi
    done
  fi
  for i in "${!paint[@]}"; do
    repaint=$refresh
    if [[ ${paint[$i]} != "${rich_lastpaint[$i]:-}" ]]; then repaint=1; fi
    (( repaint == 0 && ${#dirty_left[@]} == 0 )) && continue
    IFS=: read -r ox oy ow <<< "${rects[$i]}"
    if (( repaint == 0 )) && [[ -n ${dirty_left[$oy]:-} ]]; then
      (( ox < dirty_right[oy] && dirty_left[oy] < ox+ow )) && repaint=1
    fi
    if (( repaint )); then
      frame+=${paint[$i]}
      if [[ -z ${dirty_left[$oy]:-} ]] || (( ox < dirty_left[oy] )); then dirty_left[$oy]=$ox; fi
      if (( ox+ow > ${dirty_right[$oy]:-0} )); then dirty_right[$oy]=$((ox+ow)); fi
    fi
  done
  printf '\e[?25l%s%s' "$frame" "$1"
  rich_lastpaint=("${paint[@]}") rich_lastrect=("${rects[@]}") rich_laststart=("${starts[@]}") rich_lastcache=("${stamps[@]}")
  rich_oldrows=$rich_rows rich_oldcols=$rich_cols
  return 0
}

rich_draw() {
  local LC_ALL=C.UTF-8 viewport layout=0 rich_ansi=0
  # frecon sets TERM=xterm and does not support RGB SGR sequences.
  case ${TERM:-dumb} in xterm|linux|vt*|dumb) rich_ansi=1 ;; esac
  printf -v viewport '%q|' "${rich_width:-70}" "${rich_height:-20}" "${rich_center:-${center_menu:-0}}" "${voffset:-0}" "${TERM:-dumb}"
  if [[ ${#rich_lastpaint[@]} == 0 || $viewport != "$rich_lastviewport" || ${1:-} != hover && ${1:-} != update ]]; then
    rich_measure || return
    layout=1
  fi
  rich_lastviewport=$viewport
  if [[ -n ${rich_layout:-} && ( ${1:-} != hover || $layout == 1 ) ]]; then "$rich_layout"; fi
  local i j x y w h bx by bw bh text style line pos start count rows n caret prefix stamp
  # rich_line appends to this frame while buffering is enabled.
  local rich_buffering=1 cursor=""
  local -a lines rich_paint rich_rect rich_paintstart rich_cache
  for i in "${!rich_ids[@]}"; do
    rich_paintstart[$i]=${#rich_paint[@]}
    [[ ${rich_hidden[$i]} == 1 ]] && continue
    rich_bounds "$i"
    (( bw > 0 && bh > 0 )) || continue
    x=$bx y=$by w=$bw h=$bh
    printf -v stamp '%q|' "$x" "$y" "$w" "$h" "${rich_types[$i]}" "${rich_text[$i]}" "${rich_value[$i]}" \
      "${rich_choices[$i]}" "${rich_descs[$i]}" "${rich_disabled[$i]}" "${rich_align[$i]}" "${rich_columns[$i]}" \
      "${rich_cardheight[$i]}" "${rich_caret[$i]}" "${rich_scroll[$i]}" "${rich_left[$i]}" \
      "$((rich_focus==i))" "$((rich_hover==i ? ${rich_hover_row:--1} : -2))" "$B" "$D" "$rich_ansi"
    rich_cache[$i]=$stamp
    if [[ ${#rich_lastpaint[@]} -gt 0 && $stamp == "${rich_lastcache[$i]:-}" ]]; then
      start=${rich_laststart[$i]} count=$((rich_laststart[i+1]-start))
      rich_paint+=("${rich_lastpaint[@]:start:count}") rich_rect+=("${rich_lastrect[@]:start:count}")
      continue
    fi
    text=${rich_text[$i]} pos=${rich_value[$i]}
    style=""
    if [[ ${rich_disabled[$i]} == 1 ]]; then
      style=${D:-$'\e[90m'}
    elif [[ $i == "$rich_focus" ]]; then
      style=$'\e[7m'
    elif [[ $i == "$rich_hover" ]]; then
      if (( rich_ansi )); then style=$'\e[36;100m'
      else style=${B:-$'\e[36m'}$'\e[48;5;236m'; fi
    fi
    case "${rich_types[$i]}" in
      panel)
        rich_box "$x" "$y" "$w" "$h" "$B"
        if [[ -n $text ]]; then
          n=$((${#text}+4)); (( n > w-4 )) && n=$((w-4))
          rich_line "$((x+2))" "$y" "$n" "${B}[ $text ]"
        fi
        ;;
      rule)
        printf -v line '%*s' "$w" ''; rich_line "$x" "$y" "$w" "${D}${line// /─}"
        ;;
      label)
        mapfile -t lines <<< "$text"
        j=0
        for line in "${lines[@]}"; do
          while (( j < h )); do
            rich_line "$x" "$((y+j))" "$w" "$style$line" "${rich_align[$i]}"
            (( j++ ))
            [[ -n $rich_tail ]] || break
            line=$rich_tail
          done
          (( j >= h )) && break
        done
        ;;
      button) rich_line "$x" "$y" "$w" "${style}[ $text ]" center ;;
      checkbox)
        [[ $pos == 0 ]] && line='[ ]' || line='[x]'
        rich_line "$x" "$y" "$w" "$style$line $text"
        ;;
      progress|slider)
        (( pos > 100 )) && pos=100
        n=$((w-7)); (( n < 1 )) && n=1
        count=$((n * pos / 100))
        printf -v line '%*s' "$count" ''; line=${line// /#}
        printf -v prefix '%*s' "$((n-count))" ''
        rich_line "$x" "$y" "$w" "${style}[$line$prefix] $pos%"
        ;;
      textbox|password|textarea)
        text=$pos caret=${rich_caret[$i]}
        (( caret > ${#text} )) && caret=${#text}
        rich_caret[$i]=$caret
        prefix=${text:0:caret}
        rows=0
        if [[ ${rich_types[$i]} == textarea ]]; then
          line=$prefix
          while [[ $line == *$'\n'* ]]; do line=${line#*$'\n'}; (( rows++ )); done
          caret=${#line}
        fi
        start=${rich_scroll[$i]}
        (( rows < start )) && start=$rows
        (( rows >= start+h )) && start=$((rows-h+1))
        rich_scroll[$i]=$start
        count=${rich_left[$i]}
        (( caret < count )) && count=$caret
        (( caret >= count+w )) && count=$((caret-w+1))
        rich_left[$i]=$count
        if [[ ${rich_types[$i]} == password ]]; then
          printf -v text '%*s' "${#text}" ''; text=${text// /*}
        fi
        mapfile -t lines <<< "$text"
        for (( j=0; j<h; j++ )); do
          line=${lines[$((start+j))]:-}
          rich_line "$x" "$((y+j))" "$w" "$style${line:count}"
        done
        ;;
      select|tabs|radio|list|grid)
        rich_draw_choices "$i" "$x" "$y" "$w" "$h" "$style"
        ;;
    esac
  done
  rich_paintstart[${#rich_ids[@]}]=${#rich_paint[@]}
  if (( rich_hover >= rich_first )) && [[ -n ${rich_tip[$rich_hover]} ]]; then
    x=$((mouse_x+1)) y=$((mouse_y+1))
    (( y >= rich_rows )) && y=$((rich_rows-1))
    w=${#rich_tip[$rich_hover]}
    (( w > rich_cols-2 )) && w=$((rich_cols-2))
    (( x+w > rich_cols )) && x=$((rich_cols-w))
    rich_line "$x" "$y" "$w" "${Y}${rich_tip[$rich_hover]}"
  fi
  if (( rich_focus >= rich_first )); then
    i=$rich_focus
    case "${rich_types[$i]}" in
      textbox|password|textarea)
        rich_bounds "$i"
        text=${rich_value[$i]:0:${rich_caret[$i]}} rows=0
        while [[ $text == *$'\n'* ]]; do text=${text#*$'\n'}; (( rows++ )); done
        x=$((bx+${#text}-${rich_left[$i]})) y=$((by+rows-${rich_scroll[$i]}))
        (( x >= bx && x < bx+bw && y >= by && y < by+bh && x < rich_cols )) && printf -v cursor '\e[%d;%dH\e[?25h' "$y" "$x"
        ;;
    esac
  fi
  rich_present "$cursor" rich_paint rich_rect rich_paintstart rich_cache

}

rich_notify() {
  local status
  rich_target=${rich_ids[$1]} rich_event=$2
  if [[ -n ${rich_cmds[$1]} ]]; then
    if "${rich_cmds[$1]}" "$rich_target" "$rich_event"; then
      :
    else
      status=$?
      rich_close "$status"
      return "$status"
    fi
  fi
  return 0
}

rich_close() {
  rich_status=${1:-0}
  rich_running=0
}

rich_edit() {
  local LC_ALL=C.UTF-8
  local i=$1 key=$2 text=${rich_value[$1]} pos=${rich_caret[$1]} before after line col start ch insert="" j
  before=${text:0:pos} after=${text:pos}
  case "$key" in
    left) (( pos > 0 )) && (( pos-- )) ;;
    right) (( pos < ${#text} )) && (( pos++ )) ;;
    home) line=${before##*$'\n'}; pos=$((pos-${#line})) ;;
    end) line=${after%%$'\n'*}; pos=$((pos+${#line})) ;;
    up|down)
      [[ ${rich_types[$i]} == textarea ]] || return 0
      line=${before##*$'\n'} col=${#line} start=$((pos-col))
      if [[ $key == up ]] && (( start > 0 )); then
        before=${text:0:start-1} line=${before##*$'\n'}
        (( col > ${#line} )) && col=${#line}
        pos=$((start-1-${#line}+col))
      elif [[ $key == down && $after == *$'\n'* ]]; then
        line=${after%%$'\n'*} start=$((pos+${#line}+1))
        line=${text:start} line=${line%%$'\n'*}
        (( col > ${#line} )) && col=${#line}
        pos=$((start+col))
      fi
      ;;
    backspace)
      if (( pos > 0 )); then text=${text:0:pos-1}$after; (( pos-- )); fi
      ;;
    delete) text=$before${after:1} ;;
    enter)
      if [[ ${rich_types[$i]} == textarea ]]; then insert=$'\n'; else rich_notify "$i" activate; return; fi
      ;;
    text|paste)
      for (( j=0; j<${#mouse_text}; j++ )); do
        ch=${mouse_text:j:1}
        if [[ $ch == $'\n' && ${rich_types[$i]} == textarea ]]; then insert+=$ch
        elif [[ $ch != [[:cntrl:]] ]]; then insert+=$ch; fi
      done
      ;;
  esac
  if [[ -n $insert ]]; then text=$before$insert$after; pos=$((pos+${#insert})); fi
  rich_caret[$i]=$pos
  if [[ $text != "${rich_value[$i]}" ]]; then
    rich_value[$i]=$text
    rich_notify "$i" change
  fi
}

rich_input() {
  local i=$rich_focus j bx by bw bh columns cell rows cardheight n pos step=0 row old
  local -a entries
  case "$mouse_key" in
    escape) rich_close 1; return ;;
    eof) rich_close 1; return ;;
    interrupt) rich_close 130; return ;;
    tab) rich_next 1; return ;;
    backtab) rich_next -1; return ;;
    mouse)
      rich_hover=-1 rich_hover_row=-1
      for (( j=${#rich_ids[@]}-1; j>=rich_first; j-- )); do
        rich_focusable "$j" || continue
        rich_bounds "$j"
        if (( mouse_x >= bx && mouse_x < bx+bw && mouse_y >= by && mouse_y < by+bh )); then
          rich_hover=$j
          break
        fi
      done
      i=$rich_hover
      if (( i < 0 )); then rich_pressed=-1; return; fi
      rich_bounds "$i"
      case "${rich_types[$i]}" in
        list|radio) rich_hover_row=$((mouse_y-by+${rich_scroll[$i]})) ;;
        tabs)
          entries=(); [[ -n ${rich_choices[$i]} ]] && mapfile -t entries <<< "${rich_choices[$i]}"
          n=${#entries[@]}
          (( n > 0 )) && rich_hover_row=$(( (mouse_x-bx) / (bw/n > 0 ? bw/n : 1) ))
          ;;
        grid)
          rich_grid_size "$i" "$bw" "$bh"
          rich_hover_row=$((( (mouse_y-by)/cardheight+${rich_scroll[$i]} )*columns+(mouse_x-bx)/cell))
          (( rich_hover_row/columns != (mouse_y-by)/cardheight+${rich_scroll[$i]} || (cell > 3 && (mouse_x-bx)%cell == cell-1) || (cardheight >= 3 && (mouse_y-by)%cardheight == cardheight-1) )) && rich_hover_row=-1
          ;;
      esac
      [[ $mouse_action == move ]] && return
      if [[ $mouse_action == wheelup || $mouse_action == wheeldown ]]; then
        case "${rich_types[$i]}" in list|grid|select|radio|tabs|slider|textarea) ;; *) return ;; esac
        [[ $mouse_action == wheelup ]] && mouse_key=up || mouse_key=down
      elif [[ $mouse_action == press && $mouse_button == 0 ]]; then
        rich_focus=$i rich_pressed=$i rich_press_row=$rich_hover_row
        case "${rich_types[$i]}" in
          textbox|password|textarea)
            pos=$((mouse_x-bx+${rich_left[$i]}))
            if [[ ${rich_types[$i]} == textarea ]]; then
              mapfile -t entries <<< "${rich_value[$i]}"
              row=$((mouse_y-by+${rich_scroll[$i]}))
              (( row >= ${#entries[@]} )) && row=$((${#entries[@]}-1))
              (( pos > ${#entries[$row]} )) && pos=${#entries[$row]}
              for (( j=0; j<row; j++ )); do pos=$((pos+${#entries[$j]}+1)); done
            fi
            (( pos > ${#rich_value[$i]} )) && pos=${#rich_value[$i]}
            rich_caret[$i]=$pos
            ;;
          list|grid|radio|tabs)
            entries=(); [[ -n ${rich_choices[$i]} ]] && mapfile -t entries <<< "${rich_choices[$i]}"
            if (( rich_hover_row >= 0 && rich_hover_row < ${#entries[@]} )); then
              rich_value[$i]=$rich_hover_row
              rich_notify "$i" change
            else rich_pressed=-1; fi
            ;;
          slider)
            pos=$(( (mouse_x-bx)*100 / (bw>1 ? bw-1 : 1) ))
            rich_value[$i]=$pos; rich_notify "$i" change
            ;;
        esac
        return
      elif [[ $mouse_action == release && $mouse_button == 0 ]]; then
        [[ $rich_pressed == "$i" ]] || { rich_pressed=-1; return; }
        rich_pressed=-1
        case "${rich_types[$i]}" in
          textbox|password|textarea|slider|radio) return ;;
          list|grid|tabs) [[ $rich_press_row == "$rich_hover_row" ]] || return ;;
        esac
        mouse_key=enter
      else return; fi
      ;;
  esac
  (( i >= rich_first )) && rich_focusable "$i" || return 0
  if [[ $mouse_key == text && -n ${rich_shortcuts[$i]} && ${rich_shortcuts[$i]} == *"$mouse_text"* ]]; then
    old=${rich_shortcuts[$i]%%"$mouse_text"*}
    pos=${#old}
    entries=(); [[ -n ${rich_choices[$i]} ]] && mapfile -t entries <<< "${rich_choices[$i]}"
    if (( pos < ${#entries[@]} )); then rich_value[$i]=$pos; rich_notify "$i" change; fi
    return 0
  fi
  case "${rich_types[$i]}" in
    textbox|password|textarea) rich_edit "$i" "$mouse_key" ;;
    checkbox)
      if [[ $mouse_key == enter || $mouse_key == text && $mouse_text == ' ' ]]; then
        rich_value[$i]=$((1-${rich_value[$i]})); rich_notify "$i" change
      fi
      ;;
    slider)
      case "$mouse_key" in left|down) step=-1 ;; right|up) step=1 ;; home) rich_value[$i]=0 ;; end) rich_value[$i]=100 ;; *) return ;; esac
      pos=$(( ${rich_value[$i]}+step )); (( pos < 0 )) && pos=0; (( pos > 100 )) && pos=100
      rich_value[$i]=$pos; rich_notify "$i" change
      ;;
    select|tabs|list|grid|radio)
      if [[ ${rich_types[$i]} == list ]]; then
        case "$mouse_key" in left) rich_next -1; return ;; right) rich_next 1; return ;; esac
      fi
      entries=(); [[ -n ${rich_choices[$i]} ]] && mapfile -t entries <<< "${rich_choices[$i]}"
      n=${#entries[@]}; (( n > 0 )) || return 0
      columns=1
      if [[ ${rich_types[$i]} == grid ]]; then
        rich_bounds "$i"; rich_grid_size "$i" "$bw" "$bh"
      fi
      old=${rich_value[$i]} pos=$old
      case "$mouse_key" in
        left) (( pos-- )) ;;
        right) (( pos++ )) ;;
        up) pos=$((pos-columns)) ;;
        down) pos=$((pos+columns)) ;;
        home) pos=0 ;;
        end) pos=$((n-1)) ;;
        pageup|pagedown)
          rich_bounds "$i"; step=$bh
          [[ ${rich_types[$i]} == grid ]] && step=$((rows*columns))
          [[ $mouse_key == pageup ]] && pos=$((pos-step)) || pos=$((pos+step))
          ;;
        enter) rich_notify "$i" activate; return ;;
        *) return ;;
      esac
      (( pos < 0 )) && pos=0
      (( pos >= n )) && pos=$((n-1))
      rich_value[$i]=$pos
      [[ $old != "$pos" ]] && rich_notify "$i" change
      ;;
    button) [[ $mouse_key == enter || $mouse_key == text && $mouse_text == ' ' ]] && rich_notify "$i" activate ;;
  esac
  return 0
}

rich_restore() {
  stty "$rich_tty" <&"$rich_fd"
  if (( rich_saved_mouse > 0 )); then mouse_start "$rich_saved_mouse"; else mouse_stop; fi
  printf '\e[0m\e[?25h'
  (( rich_depth == 1 )) && printf '\e[?2004l'
  trap - INT TERM HUP WINCH EXIT
  [[ -n $rich_traps ]] && eval "$rich_traps"
  return 0
}

rich_onexit() {
  local status=$?
  stty "$rich_outer_tty" <&"$rich_outer_fd"
  mouse_stop
  printf '\e[0m\e[?25h\e[?2004l'
  trap - EXIT
  if [[ -n $rich_outer_exit ]]; then
    ( eval "$rich_outer_exit"; exit "$status" )
  fi
}

rich_exec() {
  local status active_traps active_mouse=$mouse_mode
  active_traps=$(trap -p INT TERM HUP WINCH EXIT)
  rich_restore
  if "$@"; then status=0; else status=$?; fi
  eval "$active_traps"
  stty -echo -icanon min 1 time 0 <&"$rich_fd"
  printf '\e[?2004h'
  (( active_mouse > 0 )) && mouse_start "$active_mouse"
  rich_lastpaint=() rich_lastrect=()
  return "$status"
}

rich_run() {
  local LC_ALL=C.UTF-8
  local rich_fd rich_tty rich_traps rich_saved_mouse=$mouse_mode rich_depth=$(( ${rich_depth:-0}+1 ))
  local rich_running=1 rich_status=0 rich_signal="" resize=0 hover hover_row
  local -a mouse_pending=()
  exec {rich_fd}</dev/tty || return 1
  rich_tty=$(stty -g <&"$rich_fd") || { exec {rich_fd}<&-; return 1; }
  rich_traps=$(trap -p INT TERM HUP WINCH EXIT)
  if (( rich_depth == 1 )); then
    local rich_outer_tty=$rich_tty rich_outer_fd=$rich_fd rich_outer_exit
    rich_outer_exit=$(trap -p EXIT)
    trap 'rich_onexit' EXIT
  fi
  trap 'rich_close 130; rich_signal=INT' INT
  trap 'rich_close 143; rich_signal=TERM' TERM
  trap 'rich_close 129; rich_signal=HUP' HUP
  trap 'resize=1' WINCH
  stty -echo -icanon min 1 time 0 <&"$rich_fd"
  printf '\e[?2004h'
  if [[ ${rich_mouse:-1} == 1 ]]; then
    if ! mouse_start "${rich_mouse_mode:-1003}"; then
      rich_restore; exec {rich_fd}<&-; return 1
    fi
  else mouse_stop; fi
  if (( rich_focus < rich_first )) || ! rich_focusable "$rich_focus"; then rich_focus=$((rich_first-1)); rich_next 1; fi
  rich_draw || rich_close 1
  while (( rich_running )); do
    if mouse_read_latest "$rich_fd"; then
      hover=$rich_hover hover_row=${rich_hover_row:--1}
      rich_input
      if (( rich_running )); then
        if (( resize == 0 )) && { (( ${#mouse_pending[@]} > 0 )) || IFS= read -r -t 0 -u "$rich_fd"; }; then continue; fi
        if [[ $mouse_key == mouse && $mouse_action == move && $rich_hover == "$hover" && ${rich_hover_row:--1} == "$hover_row" && $resize == 0 ]]; then continue; fi
        if [[ $mouse_key == mouse && $mouse_action == move && $resize == 0 ]]; then
          rich_draw hover "$hover" || rich_close 1
        else
          if (( resize )); then resize=0; rich_draw || rich_close 1
          else rich_draw update || rich_close 1; fi
        fi
      fi
    elif [[ $mouse_key == eof ]]; then
      rich_close 1
    elif (( resize )); then
      resize=0; rich_draw || rich_close 1
    fi
  done
  rich_restore
  exec {rich_fd}<&-
  [[ -n $rich_signal ]] && kill -s "$rich_signal" "${BASHPID}"
  return "$rich_status"
}


rich_reset
