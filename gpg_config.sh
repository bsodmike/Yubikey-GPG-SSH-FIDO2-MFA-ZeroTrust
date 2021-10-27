#!/usr/bin/env sh
#
## Usage: gpg_config.sh
########################################################################

# Safety and portability
set -eu
set -o posix || true #notably dash doesn't support this
set -o pipefail || true #not technically posix but widely supported

# Define key and yubi parameters
passphrase="$(	dd if=/dev/urandom bs=1k count=1 2>/dev/null	|
		LC_ALL=C tr -dc '\41\43-\46\60-\71\74-\132'	|
		cut -c 1-24						)"

echo "Passphrase: ${passphrase}"

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


