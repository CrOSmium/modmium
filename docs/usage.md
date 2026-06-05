# Usage instructions
## Policy editors
* User policy editor 
    * See [./user-policy-editor.md](user-policy-editor.md)
* Device policy editor
    * See [./device-policy-editor.md](device-policy-editor.md)
## MOSH
To open MOSH, log into a user session, then press **[Ctrl+Alt+T]**<br>
MOSH is a terminal UI (TUI) very similar to [Cr3nroll](https://github.com/crosmium/cr3nroll).
* Navigation is done with arrow or number keys
* To return from a submenu to the main menu, either use the given `Exit` button or press **[Ctrl+C]**
* To open a new tab, press **[Ctrl+Shift+T]**; to close the tab press `Exit` in the main menu
    * To close all tabs, press **[Ctrl+Shift+W]**
> [!WARNING]
> EXTENSIONS CAN SEE MOSH, they cannot see VT-MOSH though. Use the [user policy editor](user-policy-editor.md) to be able to toggle them off in chrome://extensions

<br>

> [!NOTE]
> if you dislike MOSH, or need to turn it into regular crosh, just run the command `touch /root/.givemecrosh` as `root`.
<br>

## VT-MOSH
To open VT-MOSH via VT-2, press **[Ctrl+Alt+F2]**\* on any menu and login as `root` or `chronos`.<br>
VT-MOSH is a terminal UI (TUI) nearly identical to regular MOSH.
* Navigation is done with arrow or number keys
* To return from a submenu to the main menu, either use the given `Exit` button or press **[Ctrl+C]**<br>

-- VT-MOSH does not have tabs --<br>
\**(F2 is often the forward arrow, but it may vary by device)*<br>

> [!tip]
> You can put a password on MOSH, VT-MOSH, and all VT(s) by running the command `chromeos-setdevpasswd` as `root`.
## Troubleshooting
* Unable to use a modmium recovery image due to FWMP
    * See [./unbricking.md](unbricking.md)
* Disabling VT-MOSH
     * Run this command as `root` in MOSH: `touch /usr/local/.defaultvt`
