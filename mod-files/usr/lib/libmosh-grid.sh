#!/bin/bash
# written by pilot bell

declare -F grid_run >/dev/null && return
declare -F full_menu >/dev/null || { echo "Source libmosh.sh before libmosh-grid.sh" >&2; return 1; }
source "${BASH_SOURCE[0]%/*}/libmosh-rich.sh"

eval "grid_base_menu() $(declare -f full_menu | tail -n +2)"

full_menu() {
  if [[ ${listmenu:-0} != 1 ]]; then
    grid_base_menu "$@"
    return
  fi
  grid_run
}

grid_layout() {
  local columns=$((rich_screenw/18)) rows height cell i left buttonwidth pagewidth footer=0
  (( columns < 1 )) && columns=1
  (( columns > ${#options[@]} && ${#options[@]} > 0 )) && columns=${#options[@]}
  rows=$(( (${#options[@]}+columns-1)/columns ))
  (( grid_hint >= 0 )) && footer=2
  height=$((rich_screenh-rows-footer-4))
  (( height < 1 )) && height=1
  rich_w[$grid_title]=$rich_screenw
  rich_x[$grid_cards]=1 rich_y[$grid_cards]=4 rich_w[$grid_cards]=$rich_screenw rich_h[$grid_cards]=$height
  rich_cardheight[$grid_cards]=${gridcardheight:-$((height/2))}
  (( rich_cardheight[$grid_cards] < 3 )) && rich_cardheight[$grid_cards]=3
  if (( grid_hint >= 0 )); then rich_y[$grid_hint]=$rich_screenh; rich_w[$grid_hint]=$rich_screenw; fi
  cell=$((rich_screenw/columns))
  (( cell > 24 )) && cell=24
  left=$(( (rich_screenw-cell*columns)/2+1 ))
  for i in "${!options[@]}"; do
    rich_x[$((grid_actions+i))]=$((left+i%columns*cell))
    rich_y[$((grid_actions+i))]=$((rich_screenh-rows-footer+1+i/columns))
    rich_w[$((grid_actions+i))]=$((cell-2))
  done
  grid_pager
  buttonwidth=$((rich_screenw/3)) pagewidth=$((rich_screenw/3))
  (( buttonwidth > 14 )) && buttonwidth=14
  (( pagewidth > 10 )) && pagewidth=10
  (( buttonwidth < 1 )) && buttonwidth=1
  (( pagewidth < 1 )) && pagewidth=1
  left=$(( (rich_screenw-2*buttonwidth-pagewidth)/2+1 ))
  rich_set grid_previous x "$left"
  rich_set grid_previous w "$buttonwidth"
  rich_set grid_page x "$((left+buttonwidth))"
  rich_set grid_page w "$pagewidth"
  rich_set grid_next x "$((left+buttonwidth+pagewidth))"
  rich_set grid_next w "$buttonwidth"
  if (( buttonwidth < 14 )); then
    rich_set grid_previous text '<'; rich_set grid_next text '>'
  else
    rich_set grid_previous text Previous; rich_set grid_next text Next
  fi
}

grid_pager() {
  local bx by bw bh columns cell rows cardheight capacity page pages
  rich_bounds "$grid_cards"
  rich_grid_size "$grid_cards" "$bw" "$bh"
  capacity=$((columns*rows))
  pages=$(( (${#listnames[@]}+capacity-1)/capacity ))
  (( pages < 1 )) && pages=1
  (( rich_value[$grid_cards] >= ${#listnames[@]} )) && rich_value[$grid_cards]=$((${#listnames[@]}-1))
  (( rich_value[$grid_cards] < 0 )) && rich_value[$grid_cards]=0
  page=$((rich_value[$grid_cards]/capacity))
  rich_scroll[$grid_cards]=$((page*rows))
  rich_set grid_page text "$((page+1)) / $pages"
  rich_set grid_previous disabled "$((page==0))"
  rich_set grid_next disabled "$((page>=pages-1))"
  return 0
}

grid_page() {
  [[ $2 == activate ]] || return 0
  local bx by bw bh columns cell rows cardheight page capacity
  rich_bounds "$grid_cards"
  rich_grid_size "$grid_cards" "$bw" "$bh"
  capacity=$((columns*rows))
  page=$((rich_value[$grid_cards]/capacity))
  if [[ $1 == grid_next ]]; then (( page++ )); else (( page-- )); fi
  (( page < 0 || page*capacity >= ${#listnames[@]} )) && return 0
  rich_value[$grid_cards]=$((page*capacity)) rich_scroll[$grid_cards]=$((page*rows))
  li=${rich_value[$grid_cards]} rich_focus=$grid_cards
  grid_pager
  return 0
}

grid_pick() {
  case "$1" in
    grid_option_*)
      selected_index=${1#grid_option_}
      [[ $2 == activate ]] && { grid_action=menu; rich_close; }
      ;;
    grid_entries)
      li=${rich_value[$grid_cards]}
      grid_pager
      [[ $2 == activate ]] && { grid_action=entry; rich_close; }
      ;;
  esac
  return 0
}

grid_run() {
  local rich_width=${gridwidth:-100} rich_height=${gridheight:-28} rich_center=${gridcenter:-1}
  local rich_layout=grid_layout grid_action="" text desc status i
  local grid_title=0 grid_cards=1 grid_hint=-1 grid_actions
  rich_reset
  rich_add label grid_title 1 1 "$rich_width" 1 "${listboxtitle:-}"
  rich_set grid_title align center
  rich_add grid grid_entries 1 4 "$rich_width" 18 '' grid_pick
  if [[ -n ${gridhint:-} ]]; then
    grid_hint=${#rich_ids[@]}
    rich_add label grid_hint 1 -1 "$rich_width" 1 "$gridhint"
  fi
  grid_actions=${#rich_ids[@]}
  for i in "${!options[@]}"; do
    rich_add button "grid_option_$i" 1 -3 22 1 "${options[$i]}" grid_pick
  done
  rich_add button grid_previous 1 2 14 1 Previous grid_page
  rich_add label grid_page 15 2 10 1 ''
  rich_set grid_page align center
  rich_add button grid_next 25 2 14 1 Next grid_page
  printf -v text '%s\n' "${listnames[@]}"
  printf -v desc '%s\n' "${listdescs[@]}"
  rich_set grid_entries choices "${text%$'\n'}"
  rich_set grid_entries descs "${desc%$'\n'}"
  rich_set grid_entries value "${li:-0}"
  rich_set grid_entries columns "${gridcolumns:-0}"
  rich_set grid_entries cardheight "${gridcardheight:-10}"
  rich_focus=$grid_cards
  [[ ${Lf:-1} == 0 && ${#options[@]} -gt 0 ]] && rich_focus=$((grid_actions+${selected_index:-0}))
  if rich_run; then status=0; else status=$?; fi
  li=${rich_value[$grid_cards]} sl=${rich_scroll[$grid_cards]}
  [[ $rich_focus == "$grid_cards" ]] && Lf=1 || Lf=0
  case "$grid_action" in
    menu) selector ;;
    entry)
      # listcmds uses the same word splitting as libmosh-lists.
      employ ${listcmds[$li]}
      menu_reset
      full_menu
      ;;
    *) return "$status" ;;
  esac
}
