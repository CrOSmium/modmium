## How it works
We use a set of Google tools named policy-test-tool and fake_dmserver (see [the Chromium docs](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/policy/tools/fake_dmserver/chromeos_instructions.md#8_testing-a-new-unlanded_policy) on them for more information) to serve custom policies to a user account on login. We hardcode the user policies to be as unrestrictve as possible, but you can modify them if you like (see mod-files/root/policy.sh).
## User policy editor instructions
0. (Optional) Before installing modmium, enroll and login to your enterprise account, then export json from chrome://policy. Either add `-j /path/to/policies.json` to the flags when building the image, or name the file `policy.json` and place it in `mod-files/root` 
You'll want to do this if you want your enterprise's extensions to install, for example if they have monitoring software and would get suspicious if you didn't have it.
1. Install and boot modmium in verified (see docs/installation.md).
2. Open VT2 once __fully enrolled__.
3. Run `bash policy.sh` and enter your enterprise email when prompted.
4. When the fake device management server starts, go back to VT1 and sign in with the same email.
5. After you're logged in, go back to VT2 and hit Ctrl+C
