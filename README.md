# Yubikey-GPG-SSH-FIDO2-MFA-ZeroTrust

Refer to the original guide "[One Key to Rule It All [YubiKey+GPG-SSH+FIDO2+MFA-ZeroTrust]](https://forum.level1techs.com/t/one-key-to-rule-it-all-yubikey-gpg-ssh-fido2-mfa-zerotrust/173872/1)".

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

