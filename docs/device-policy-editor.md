## How it works
Policies are signed by a private key, and the corresponding public key is used to verify them. For testing new policies, Google created the flag `--disable-policy-key-verification` (which modmium automatically places into /etc/chrome_dev.conf). With this, we can dump the device policy to a JSON file, edit it, and use the modified JSON to create a new device policy file with new values.

## Device policy editor instructions
0. Enroll to automatically create the device policies.
1. Open MOSH (see [./usage.md](usage.md) if you don't know how)
2. Find the policy you wish to edit (see the Google [policy list](https://chromeenterprise.google/policies) to search for policy names)
> [!NOTE]
> The policy categories of Restrictions, Reporting, Enterprise Settings, and Misc are not official, it's just how we organize them.

> [!Caution]
> If you modify *any* device policies, it'll stop sending new reports to the GAC and appear as offline. 
> Use `Reset All Changes` to send reports to the GAC again.
* For most users, the relevant policies are:
    * Restrictions/DeviceAllowNewUsers (Allows you to add new accounts when toggled on)
    * Restrictions/DeviceUnaffiliatedCrostiniAllowed (Enables Crostini, the Linux container/VM)
    * Restrictions/DeviceUserAllowlist (More specific than DeviceAllowNewUsers, such as allowing a specific user account without the wildcard. For most people, adding `"*@gmail.com",` is good enough)
    * Restrictions/DeviceBorealisAllowed (Enables the Steam for Chromebook beta, also needs to be turned on in `chrome://flags`)
    * Restrictions/VirtualMachinesAllowed (REQUIRED for Borealis/Crostini)
    * Restrictions/UnaffiliatedArcAllowed (Enable Play store, it DOES function if you set user policies, this reduces jank/odds of it breaking)
    * Enterprise Settings/DeviceOpenNetworkConfiguration (May contain `"DisableNetworkTypes": [ "VPN" ]` and/or `[ "Cellular" ]`  modify to be blank `"DisableNetworkTypes": []` if you want to use VPN/Mobile data)
* When done editing, either press **[Ctrl+C]** to return to MOSH, then you can press `Apply Policies` to apply your changes!
