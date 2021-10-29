# Yubikey-GPG-SSH-FIDO2-MFA-ZeroTrust

Refer to the original guide "[One Key to Rule It All [YubiKey+GPG-SSH+FIDO2+MFA-ZeroTrust]](https://forum.level1techs.com/t/one-key-to-rule-it-all-yubikey-gpg-ssh-fido2-mfa-zerotrust/173872/1)".

The [Yubikey-Guide](https://github.com/drduh/YubiKey-Guide) is also an excellent
resource, covering further advanced topics such as key-rotation etc.

## Overview

The approach taken here is to setup three (x3) Yubikeys as (i) a current key
(main security key), (ii) a hot spare, and (iii) a last resort cold spare key,
stored securely off-site.

## Setup

Install the following:

```
# Fedora 34
sudo dnf install gnupg pinentry ccid yubikey-manager-qt yubikey-manager yubikey-personalization-gui pam-u2f libfido2

# Arch
sudo pacman -S gnupg pinentry libusb-compat pcsclite ccid yubikey-manager-qt yubikey-manager yubikey-personalization yubikey-personalization-gui yubico-pam pam-u2f libfido2
```

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

## Exporting the SSH public-key from the Yubikey
Now you tell the SSH auth socket to connect to gpg agent in your shell config.
Use the appropriate configuration, depending on your choice of shell:

```
# fish: ~/.config/fish/config.fish
gpgconf --launch gpg-agent
set gpg_socket (gpgconf --list-dirs agent-ssh-socket)
set -x SSH_AUTH_SOCK $gpg_socket

# Z-shell: ~/.zshrc
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
```

In order to use SSH, you need to share your public key with the remote host. You
can run `ssh-add -L` to list your public keys and copy it manually, as shown
below:

```
$ ssh-add -l
256 SHA256:osIdSEalN4U4ib8wTqpdu1OWKvNTPzIDSZNi58s6AAs cardno:000605762380 (ED25519)
```

OR you can run `ssh-add -L >> ~/public_ssh_keys.txt` and copy the key that
references your Yubikey with the correct card no.

## Switching between two or more Yubikeys

When you add a GPG key to a Yubikey using the keytocard command, GPG deletes the
key from your keyring and adds a stub pointing to that exact Yubikey (the stub
identifies the GPG KeyID and the Yubikey's serial number). Therefore, the last
Yubikey written to, is the key the stub will point at.

Run the following command to allow the currently inserted key to be used. [Refer to this guide](https://github.com/drduh/YubiKey-Guide#switching-between-two-or-more-yubikeys) for further details.

```
gpg-connect-agent "scd serialno" "learn --force" /bye
```
