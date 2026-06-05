# Usage instructions
## Policy editors
* User policy editor 
    * See [./user-policy-editor.md](https://github.com/CrOSmium/modmium/blob/nightly/docs/user-policy-editor.md)
* Device policy editor
    * See [./device-policy-editor.md](https://github.com/CrOSmium/modmium/blob/nightly/docs/device-policy-editor.md)
## MOSH
To open MOSH, log into a user session, then press **[Ctrl+Alt+T]**<br>
MOSH is a terminal UI (TUI) very similar to [Cr3nroll](https://github.com/crosmium/cr3nroll).
* Navigation is done with arrow or number keys
* To return from a submenu to the main menu, either use the given `Exit` button or press **[Ctrl+C]**
* To open a new tab, press **[Ctrl+Shift+T]**; to close the tab press `Exit` in the main menu
    * To close all tabs, press **[Ctrl+Shift+W]**
<br>

## VT-MOSH
To open VT-MOSH via VT-2, press **[Ctrl+Alt+F2]**\* on any menu and login as `root` or `chronos`.<br>
VT-MOSH is a terminal UI (TUI) nearly identical to regular MOSH.
* Navigation is done with arrow or number keys
* To return from a submenu to the main menu, either use the given `Exit` button or press **[Ctrl+C]**<br>

-- VT-MOSH does not have tabs --<br>
\**F2 is often the forward arrow, but it may vary by device)*<br>

------------------------------------------------------------------------

*Tip: You can put a password on MOSH, VT-MOSH, and all VT(s) by running the command `chromeos-setdevpasswd` as `root`.*
## Troubleshooting
* Unable to use a modmium recovery image due to FWMP
    * See [./unbricking.md](https://github.com/CrOSmium/modmium/blob/nightly/docs/unbricking.md)
* Disabling VT-MOSH
     * Run this command as `root` in MOSH: `touch /usr/local/.defaultvt`
