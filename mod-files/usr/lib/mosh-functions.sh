rootsh(){
	runscript "sudo -i -u root"
}
chronosh(){
	runscript "sudo -i -u chronos"
}
crosh(){
	runscriptnoroot "exec /usr/bin/crosh.old"
}
update(){
	runscript "bash /usr/bin/update-modmium.sh"
}
devpol(){
	runscript "bash /usr/bin/devpolicy-editor.sh"
}
apps(){
	exec /usr/bin/mosh-apps.sh
}
misc(){
	exec /usr/bin/mosh-misc.sh
}
exit(){
	stty echo
	tput cnorm
	clear
	command exit 0
}
modsplash(){
	runscript "bash /usr/bin/modify-bootsplash.sh"
}
toggleEnrollment(){
	runscript "bash /usr/bin/toggle-enrollment.sh"
}
cr3nroll(){
	runscript "bash /usr/bin/cr3nroll.sh"
}
erevert(){
	runscript "bash /usr/bin/emergencyrevert.sh"
}
prenix(){
	exec /usr/bin/nix-preinstall.sh
}
return(){
	stty echo
	tput cnorm
	clear
	exec /usr/bin/crosh
}
