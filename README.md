# Yubikey-GPG-SSH-FIDO2-MFA-ZeroTrust

Refer to the original guide "[One Key to Rule It All [YubiKey+GPG-SSH+FIDO2+MFA-ZeroTrust]](https://forum.level1techs.com/t/one-key-to-rule-it-all-yubikey-gpg-ssh-fido2-mfa-zerotrust/173872/1)".

The [Yubikey-Guide](https://github.com/drduh/YubiKey-Guide) is also an excellent
resource, covering further advanced topics such as key-rotation etc.

## Overview

The approach taken here is to setup three (x3) Yubikeys as (i) a current key,
(ii) a spare, and (iii) a last resort backup key, stored securely off-site.



## Generating a GPG Key

Make sure you replace the placeholders below to generate the GPG key, 

```
./gpg_gen_yubi.sh "Your Name" "your.email@gmail.com" "/mnt"
```

This script will print the `passphrase` that's automatically generated.  You
will need to store this securely; if you loose this passphrase, you will not be
able to use your key anymore.

Make sure you backup both the contents in `crypt1` and `pub1`, especially the
revocation certificates.

## Uploading your key

Use `gpg2 --list-signatures` to obtain the <HEX> key-id,

```
gpg2 --keyserver keys.openpgp.org --send-keys EBC48BA7843592C3

# validate your email on the keyserver, check your email for the validation
# link
gpg2 --export your.email@gmail.com |curl -T - https://keys.openpgp.org
```

## Copying GPG keys to your Yubikeys

### Removing the local (private) secret key

Once all the keys are prepared, make sure to delete the `secrete key`, held
locally.

```
gpg2 --delete-secret-key EBC48BA7843592C3
```

## Switching between two or more Yubikeys

When you add a GPG key to a Yubikey using the keytocard command, GPG deletes the
key from your keyring and adds a stub pointing to that exact Yubikey (the stub
identifies the GPG KeyID and the Yubikey's serial number). Therefore, the last
Yubikey written to, is the key the stub will point at.

Run the following command to allow the currently inserted key to be used. [Refer to this guide](https://github.com/drduh/YubiKey-Guide#switching-between-two-or-more-yubikeys) for further details.

```
gpg-connect-agent "scd serialno" "learn --force" /bye
```
