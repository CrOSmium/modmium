variable=$(vpd -i RW_VPD -g modmium_annc_timer 2>/dev/null)
if [[ -n $variable ]]; then
  :
else
  vpd -i RW_VPD -s "modmium_annc_timer"="$(date +%s)"
fi
get_annc() {
  u="https://modmium.dev/announcement.txt"
  m="$(curl -fsSL --max-time 5 "$u")"
  echo -e "$m"
}
tung_tung_tung_sahur() {
  t=$(vpd -i RW_VPD -g modmium_annc_timer)
  n=$(date +%s)
  if (( now - t > 10800 )); then
    get_annc
    vpd -i RW_VPD -s "modmium_annc_timer"="$(date +%s)"
  else
    :
  fi
}
tung_tung_tung_sahur
