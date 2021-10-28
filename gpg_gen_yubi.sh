#!/usr/bin/env sh
# Run this on an air-gapped computer with an encrypted hard drive to set up GPG keys on your yubikey.
# Derived from https://github.com/drduh/YubiKey-Guide
# Assumes OS has already been prepared (packages, services, etc) -- see dr duh guide.
# Does not configure PINs on the yubikey.
# 
# This has been tested with Yubikey 5 NFC and ED25519 and Curve25519.
# Refer to https://gist.github.com/o0-o/61e11c9928fd7698f1aaae55473e6456 for
# rsa4096 (or rsa2048 for older Yubikeys) support.
# 
# The GPG key passphrase is randomly generated and printed to stderr at the end of the script.
# Copy the backup tar.gz file to an encrypted drive.
#
# Usage: gpg_gen_yubi.sh name email [output_path]
########################################################################

# Safety and portability
set -eu
set -o posix || true #notably dash doesn't support this
set -o pipefail || true #not technically posix but widely supported

# Backup targets -- set these or the master key will be deleted permanently
output="$3" #by default, specify as "/mnt"
crypt1="$output/crypt1" #entire GNUPGHOME directory is backed up to $crypt1 and $crypt2
crypt2="$output/crypt2"
pub1="$output/pub1" #public and revocation keys are copied to $pub1 and $pub2
pub2="$output/pub2"

# Define key and yubi parameters
export GNUPGHOME="$(mktemp -d)"
chmod 0700 "$GNUPGHOME"
name="$1"
email="$2"
passphrase="$(	dd if=/dev/urandom bs=1k count=1 2>/dev/null	|
		LC_ALL=C tr -dc '\41\43-\46\60-\71\74-\132'	|
		cut -c 1-24						)"
key_type="ed25519"
enc_key_type="cv25519"
subkey_expire='2y'

cd "$GNUPGHOME"

# Configure gpg based on dr duh guide
printf	'%s\n'												\
	'personal-cipher-preferences AES256 AES192 AES'							\
	'personal-digest-preferences SHA512 SHA384 SHA256'						\
	'personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed'					\
	'default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed'	\
	'cert-digest-algo SHA512'									\
	's2k-digest-algo SHA512'									\
	's2k-cipher-algo AES256'									\
	'charset utf-8'											\
	'fixed-list-mode'										\
	'no-comments'											\
	'no-emit-version'										\
	'keyid-format 0xlong'										\
	'list-options show-uid-validity'								\
	'verify-options show-uid-validity'								\
	'with-fingerprint'										\
	'require-cross-certification'									\
	'no-symkey-cache'										\
	'use-agent'											\
	'throw-keyids'											\
	>'gpg.conf'

chmod 0600 'gpg.conf'

# Unattended key generation
gpg	--batch					\
	--passphrase	"$passphrase"		\
	--quick-gen-key	"${name} <${email}>"	\
			"$key_type"		\
			'cert'			\
			'0'

fpr="$(gpg --list-options 'show-only-fpr-mbox' --list-secret-keys | awk '{print $1}')"

echo "Key-id: $fpr"

gpg	--batch				\
	--pinentry-mode	'loopback'	\
	--passphrase	"$passphrase"	\
	--quick-add-key	"$fpr"		\
			"$key_type"	\
			'sign'		\
			"$subkey_expire"

gpg	--batch				\
	--pinentry-mode	'loopback'	\
	--passphrase	"$passphrase"	\
	--quick-add-key	"$fpr"		\
			"$enc_key_type"	\
			'encrypt'	\
			"$subkey_expire"

gpg	--batch				\
	--pinentry-mode	'loopback'	\
	--passphrase	"$passphrase"	\
	--quick-add-key	"$fpr"		\
			"$key_type"	\
			'auth'		\
			"$subkey_expire"

echo "Created sub-keys"

# Exports
printf	'%s\n'							\
	'y'							\
	'0'							\
	'This revocation certificate was created pre-emptively'	\
	''							\
	'y'							\
	'y'							|
gpg	--output	"revoke-no-reason-$fpr.asc"		\
	--pinentry-mode	'loopback'				\
	--passphrase	"$passphrase"				\
	--command-fd	0					\
	--gen-revoke	"$fpr"

printf	'%s\n'							\
	'y'							\
	'1'							\
	'This revocation certificate was created pre-emptively'	\
	''							\
	'y'							\
	'y'							|
gpg	--output	"revoke-compromised-$fpr.asc"		\
	--pinentry-mode	'loopback'				\
	--passphrase	"$passphrase"				\
	--command-fd	0					\
	--gen-revoke	"$fpr"

printf	'%s\n'							\
	'y'							\
	'2'							\
	'This revocation certificate was created pre-emptively'	\
	''							\
	'y'							\
	'y'							|
gpg	--output	"revoke-superseded-$fpr.asc"		\
	--pinentry-mode	'loopback'				\
	--passphrase	"$passphrase"				\
	--command-fd	0					\
	--gen-revoke	"$fpr"

printf	'%s\n'							\
	'y'							\
	'3'							\
	'This revocation certificate was created pre-emptively'	\
	''							\
	'y'							\
	'y'							|
gpg	--output	"revoke-no-longer-used-$fpr.asc"	\
	--pinentry-mode	'loopback'				\
	--passphrase	"$passphrase"				\
	--command-fd	0					\
	--gen-revoke	"$fpr"

gpg	--pinentry-mode		'loopback'	\
	--passphrase		"$passphrase"	\
	--armor					\
	--export-secret-keys	"$fpr"		\
	>'master.key'

gpg	--pinentry-mode		'loopback'	\
	--passphrase		"$passphrase"	\
	--armor					\
	--export-secret-subkeys	"$fpr"		\
	>'sub.key'

gpg	--armor				\
	--export	"$fpr"		\
	>"gpg-${fpr}-$(date +%F).asc"

# Copy public key to unencrypted store
for pub_key in "gpg-${fpr}-"*".asc"; do
	cp "$pub_key" "$pub1/$pub_key"
	cp "$pub_key" "$pub2/$pub_key"
done

# Copy revocation certificates to unencrypted store
for rev_cert in "revoke-"*"-${fpr}.asc"; do
	cp "$rev_cert" "$pub1/$rev_cert"
	cp "$rev_cert" "$pub2/$rev_cert"
done

# Must back up to encrypted store before copying to yubi
tar -czf "backup-$(date +%F).tar.gz" *
cp "backup-"*".tar.gz" "$crypt1/backup_$(date +%F).tar.gz"
cp "backup-"*".tar.gz" "$crypt2/backup-$(date +%F).tar.gz"

echo ""
echo "WRITE THIS DOWN IN A SECURE PLACE: $passphrase"
echo ""

# Print gpg key details
gpg -K
gpg --delete-secret-key

cd

rm -rf "$GNUPGHOME"

printf	'%s\n'								\
	'WRITE THIS DOWN IN A SECURE PLACE' "$passphrase"		\
	'Reboot soon and before restoring network connectivity.'	1>&2

# Just cause
unset fpr GNUPGHOME passphrase

# vim: ts=8:sw=8:sts=8:noet:ft=sh
