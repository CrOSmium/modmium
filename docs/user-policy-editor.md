## How it works
We use a set of Google tools named policy-test-tool and fake_dmserver (see [the Chromium docs](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/policy/tools/fake_dmserver/chromeos_instructions.md#8_testing-a-new-unlanded_policy) on them for more information) to serve custom policies to a user account on login. We hardcode the user policies to be as unrestrictive as possible, but you can modify them if you like (see mod-files/usr/bin/mosh-upol.sh).

## User policy editor instructions
> [!TIP]
> If you place a policy file in `./mod-files/root/` during building, it will have your policy file in the Modmium image itself!
1. Install and boot modmium in verified (see [./installation.md](./installation.md).)
2. Obtain your enterprise's policy.json (see [obtaining your policy file after install](#obtaining-your-policy-file-after-install))
3. Open VT2 once you've finished enrollment, a good place to enter is the "Enrollment is complete." screen. <br> __DO NOT SIGN IN. IF YOU DID AND WANT TO EDIT USER POLICIES, POWERWASH AND TRY AGAIN.__
4. Navigate to `Edit User Policies`.
5. Select `Run Policy Editor` and enter your enterprise email when prompted.
6. When the fake device management server starts, go **back** to VT1 and **sign in with the same email**.
7. After you're logged in, return to VT2 and hit Ctrl+C
- Only ever run `Reinstall` if you want to edit policies for a different account, or update them for the same one with a new file.

## Obtaining your policy file after install
1. Enroll into your enterprise and login to your enterprise account
2. Open `chrome://policy` and export your policy file to your Downloads folder, do not rename the file, it must be in the root of your `Downloads` folder.
3. Open VT-2 and navigate to `Edit User Policies`
4. Select `Grab policy.json from Downloads`
5. Your policy file is now saved, it should show the menu that says `Install`, if it doesn't, check that you actually placed your policy file into downloads, and that the name is the same as it was originally. 
6. Remove the user account completely (or powerwash if needed) and continue with the [rest of the steps](#user-policy-editor-instructions) below!
