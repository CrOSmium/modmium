## How it works
We use a set of Google tools named policy-test-tool and fake_dmserver (see [the Chromium docs](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/policy/tools/fake_dmserver/chromeos_instructions.md#8_testing-a-new-unlanded_policy) on them for more information) to serve custom policies to a user account on login. We hardcode the user policies to be as unrestrictve as possible, but you can modify them if you like (see mod-files/root/policy.sh).
## User policy editor instructions
- (Optional) Before installing Modmium, enroll and login to your enterprise account, then export json from chrome://policy. Either add `-j /path/to/policies.json` to the flags when building the image, or name the file `policy.json` and place it in `mod-files/root` 
You'll want to do this if you want your enterprise's extensions to install, for example if they have monitoring software and would get suspicious if you didn't have it (Note: the extensions won't be force-installed, meaning you'll be able to toggle enterprise extensions on and off like a normal extension in `chrome://extensions`).

1. Install and boot modmium in verified (see docs/installation.md).
2. Obtain your policy file (see #obtaining-your-policy-file-after-install)
3. Open VT2 once __fully enrolled__, DO NOT SIGN IN YET.
5. Navigate to `Edit User Policies`.
4. Run `Install` and enter your enterprise email when prompted.
5. When the fake device management server starts, go **back** to VT1 and **sign in with the same email**.
6. After you're logged in, go back to VT2 and hit Ctrl+C
- Only ever run `Reinstall` if you want to edit policies for a different account, or update them for the same one with a new file.
## Obtaining your policy file after install
1. Enroll into your enterprise and login to your enterprise account
2. Open `chrome://policy` and export your policy file to your Downloads folder, do not change the name.
3. Open VT-2 and navigate to Edit User Policies
4. Press the button that says `Grab policy.json from downloads`
5. Your policy file is now saved!
6. Remove the user account completely (or powerwash) and continue with the rest of the steps above!
