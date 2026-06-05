## How it works
Policies are signed by a private key, and the corresponding public key is used to verify them. For testing new policies, Google created the flag `--disable-policy-key-verification` (which modmium automatically places into /etc/chrome_dev.conf). With this, we can dump the device policy to a JSON file, edit it, and use the modified JSON to create a new device policy file with new values.

## Device policy editor instructions
0. Enroll (how can you edit device policies if none exist, after all)
1. Open MOSH (see [./usage.md](usage.md) if you don't know how)
2. Find the policy you wish to edit (see the Google [policy list](https://chromeenterprise.google/policies) to search for policy names)
> [!NOTE]
> The policy categories of Restrictions, Reporting, Enterprise Settings, and Misc are not official, it's just how we organize them.

> [!Caution]
> If you modify *any* device policies, it'll stop sending new reports to the GAC and appear as offline. 
> Use `Reset All Changes` to send reports to the GAC again.
* For most users, relevant ones are:
    * Restrictions/DeviceAllowNewUsers (if true, will allow any Google account to sign in)
    * Restrictions/DeviceUnaffiliatedCrostiniAllowed (enabling the linux container)
    * Restrictions/DeviceUserAllowlist (can be used to be more specific than DeviceAllowNewUsers, (for example specifying a specific account instead of using a wildcard) for most people, adding `"*@gmail.com",` is good enough)
    * Restrictions/DeviceBorealisAllowed (enabling steam, also needs to be turned on in chrome://flags)
    * Restrictions/VirtualMachinesAllowed (required for Borealis and Crostini)
    * Restrictions/UnaffiliatedArcAllowed (enabling play store)
    * Enterprise Settings/DeviceOpenNetworkConfiguration (may contain `"DisableNetworkTypes": [ "VPN" ]`, remove if you want to use a VPN)
* When done editing, either press **[Ctrl+C]** to return to MOSH without applying policies (but saving the configuration in the JSON file) or `Apply Policies` to apply your changes
