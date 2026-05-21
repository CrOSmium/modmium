variable=$(vpd -i RW_VPD -g modmium_annc_timer 2>/dev/null)
if [[ -n $variable ]]; then
  :
else
  vpd -i RW_VPD -s "modmium_annc_timer"="$(date +%s)"
fi
get_annc() {
  u="https://modmium.dev/announcement.txt" # sorry dmd I forgot the format u wanted ill figure it out later. also: can we do like a list or something and add checks for things later ig
  m="$(curl -fsSL --max-time 5 "$u")"
  echo -e "$m" # can we do colors with this :thinking:
}
tung_tung_tung_sahur() { # I ddont feel like coming up with proper variable names im tired
  t=$(vpd -i RW_VPD -g modmium_annc_timer)
  n=$(date +%s)
  if (( now - t > 10800 )); then
    get_annc
    vpd -i RW_VPD -s "modmium_annc_timer"="$(date +%s)"
  else
    : # is this like "pass" in python right
  fi
}
tung_tung_tung_sahur
