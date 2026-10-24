## How it works
We use a set of Google tools named policy-test-tool and fake_dmserver (see [the Chromium docs](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/policy/tools/fake_dmserver/chromeos_instructions.md#8_testing-a-new-unlanded_policy) on them for more information) to serve our modified policies to the user account on login. We hardcode the user policies to be as unrestrictive as possible, but you can modify them if you like (see mod-files/usr/bin/mosh-upol.sh).

## Obtaining your policy file after install
1. Enroll into your district and login to your enterprise account
2. Open `chrome://policy`, go to the "More options" button and select "Export as JSON" to put it in your Downloads folder. Do not rename the file.
> [!NOTE]
> If `chrome://policy` is blocked, instead of downloading the policy file, just press `Extract policies from current account`, and skip to step 5.
3. Open VT-2 and navigate to `Edit User Policies`
4. Select `Grab policy.json from Downloads`
5. Your policy file is now saved (it also survives powerwashes!), it should show the menu that says `Install`, if it doesn't, check that you actually placed your policy file into downloads, and that the name is the same as it was originally. 
6. Remove the user account completely (or powerwash if needed) and continue with the [rest of the steps](#user-policy-editor-instructions) below!

## User policy editor instructions
> [!TIP]
> If you place a policy file in `./mod-files/root/` during building, it will have your policy file in the Modmium image itself!
1. Install and boot Modmium in verified (see [./installation.md](./installation.md).)
2. Obtain your enterprise's policy.json (see [obtaining your policy file after install](#obtaining-your-policy-file-after-install))
3. Open VT2 once you've finished enrollment, a good place to enter is the "Enrollment is complete." screen. If you pressed Continue but haven't signed in yet then you can still use the user policy editor. <br> __DO NOT SIGN IN. IF YOU DID AND WANT TO EDIT USER POLICIES, JUST POWERWASH AND SIGN IN AGAIN.__
4. Navigate to `Edit Policies`.
5. Press `User Policy Editor`.
6. Select `Run Policy Editor` and enter your enterprise email when prompted.
7. When the fake device management server starts, go **back** to VT1 (Ctrl+Alt+F1) and **sign in with the same email**.
8. After you're logged in, return to VT2 and hit Ctrl+C!
- Only ever run `Reinstall` if you want to edit policies for a different account, or update them for the same one with a new file.
