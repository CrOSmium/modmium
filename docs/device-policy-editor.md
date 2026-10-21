## How it works
Device policies are signed using a private key, and the corresponding public key is used to verify them. For testing new policies, Google provides the `--disable-policy-key-verification` flag, which Modmium adds to `/etc/chrome_dev.conf`.

With verification disabled, we can dump the device policy to a JSON file, make the selected edits, and use the modified JSON to generate a new device policy file!

## Device policy editor instructions
1. Enroll into your district and sign in
2. Open MOSH or VT-MOSH and press the Edit Device Policies button
3. Make your desired edits to device policy
4. When done, go back and select "Apply All Changes", your Chromebook will reboot and your new policies will be applied!
5. profit
   
> [!Caution]
> If you modify *any* device policies, it'll stop sending new reports to the GAC and appear as offline. 
> Use `Reset All Changes` to send reports to the GAC again.

- **Restrictions**
  - `DeviceAllowNewUsers` — Allows you to add new accounts.
  - `DeviceUnaffiliatedCrostiniAllowed` — Enables Crostini (the Linux container/VM).
  - `DeviceUserAllowlist` — Allows users outside of your district domain to be on the Chromebook. Usually you can just add `"*@*"` or `"@gmail.com"` here.
  - `DeviceBorealisAllowed` — Enables Steam for Chromebook beta. (You also need to enable `#borealis-enable-unsupported-hardware` in `chrome://flags` if you want to use steam on unsupported hardware!
  - `VirtualMachinesAllowed` — Required for Borealis (Steam) and Crostini.
  - `UnaffiliatedArcAllowed` — Enables the Play Store.

- **Enterprise Settings**
  - `DeviceOpenNetworkConfiguration` — Disables VPN or cellular connections. Usually setting `"DisableNetworkTypes": []` allows them.
