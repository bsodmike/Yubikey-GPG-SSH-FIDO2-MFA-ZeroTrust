#!/bin/bash
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
# Usage: gpg_gen_yubi.sh name email <all extra emails> [output_path]
#
# Copyright (c) Michael de Silva
# Profile: https://desilva.io/about
# Email: mike.cto@securecloudsolutions.io // PGP: https://bit.ly/3W8u9R8
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
########################################################################

set -eu

NOW="$(date +"%d%m%Y-%H:%M:%S%z")"
HOST_NAME=`hostname`
PROJECT="gpg-gen"
LOG_DIR="./gpg-gen-logs"

yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }

# purpose: to pass msgs and print them to a log file and terminal
#  - with datetime
#  - the type of msg - INFO, ERROR, DEBUG, WARNING
# usage:
# do_log "INFO some info message"
# do_log "ERROR some error message"
# do_log "DEBUG some debug message"
# do_log "WARNING some warning message"
# depts:
#  - PRODUCT_DIR - the root dir of the sfw project
#  - PRODUCT - the name of the software project dir
#  - host_name - the short hostname of the host / container running on
#------------------------------------------------------------------------------

do_log(){
  print_ok() {
      GREEN_COLOR="\033[0;32m"
      DEFAULT="\033[0m"
      echo -e "${GREEN_COLOR} [${timestamp_now}] ✔ [OK] ${1:-} ${DEFAULT}"
  }

  print_warning() {
      YELLOW_COLOR="\033[33m"
      DEFAULT="\033[0m"
      echo -e "${YELLOW_COLOR} ⚠ ${1:-} ${DEFAULT}"
  }

   print_info() {
      BLUE_COLOR="\033[0;34m"
      DEFAULT="\033[0m"
      echo -e "${BLUE_COLOR} ℹ ${1:-} ${DEFAULT}"
  }

  print_fail() {
      RED_COLOR="\033[0;31m"
      DEFAULT="\033[0m"
      echo -e "${RED_COLOR} ❌ [NOK] ${1:-}${DEFAULT}"
  }

  type_of_msg=$(echo $*|cut -d" " -f1)
  msg="$(echo $*|cut -d" " -f2-)"
  log_dir="${LOG_DIR:-}" ; mkdir -p $log_dir
  log_file="$log_dir/${PROJECT:-}."$(date "+%d%m%Y")'.log'
  msg=" [$type_of_msg] `date "+%d-%b-%Y %H:%M:%S %Z"` [${PROJECT:-}][@${HOST_NAME:-}] [$$] $msg "
  case "$type_of_msg" in
    'FATAL') print_fail "$msg" | tee -a $log_file ;;
    'ERROR') print_fail "$msg" | tee -a $log_file ;;
    'WARNING') print_warning "$msg" | tee -a $log_file ;;
    'INFO') print_info "$msg" | tee -a $log_file ;;
    'OK') print_ok "$msg" | tee -a $log_file ;;
    *) echo "$msg" | tee -a $log_file ;;
  esac
}

do_log "INFO Initializing..."

# Backup targets -- set these or the master key will be deleted permanently
output="${@:$#}" #by default, specify as "/mnt"
crypt1="$output/crypt1" #entire GNUPGHOME directory is backed up to $crypt1 and $crypt2
crypt2="$output/crypt2"
pub1="$output/pub1" #public and revocation keys are copied to $pub1 and $pub2
pub2="$output/pub2"

# Define key and yubi parameters
export GNUPGHOME="$(mktemp -d)"
chmod 0700 "$GNUPGHOME"
name="$1"
email="$2"
CERTIFY_PASS=$(LC_ALL=C tr -dc 'A-Z1-9' < /dev/urandom | 		\
  tr -d "1IOS5U" | fold -w 30 | sed "-es/./ /"{1..26..5} | 		\
  cut -c2- | tr " " "-" | head -1)
key_type="ed25519"
enc_key_type="cv25519"
subkey_expire='2y'

cd "$GNUPGHOME"

# Configure gpg using hardened config
# https://github.com/drduh/config/blob/master/gpg.conf
printf	'%s\n'													\
	'personal-cipher-preferences AES256 AES192 AES'				\
	'personal-digest-preferences SHA512 SHA384 SHA256'			\
	'personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed'	\
	'default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed'	\
	'cert-digest-algo SHA512'									\
	's2k-digest-algo SHA512'									\
	's2k-cipher-algo AES256'									\
	'charset utf-8'												\
	'no-comments'												\
	'no-emit-version'											\
	'no-greeting'												\
	'keyid-format 0xlong'										\
	'list-options show-uid-validity'							\
	'verify-options show-uid-validity'							\
	'with-fingerprint'											\
	'require-cross-certification'								\
	'no-symkey-cache'											\
	'armor' 													\
	'use-agent'													\
	'throw-keyids'												\
	>'gpg.conf'

chmod 0600 'gpg.conf'

# Unattended key generation
gpg	--batch														\
	--passphrase	"$CERTIFY_PASS"								\
	--quick-gen-key	"${name} <${email}>"						\
			"$key_type"											\
			'cert'												\
			'0'

fpr="$(gpg --list-options 'show-only-fpr-mbox' --list-secret-keys | awk '{print $1}')"

do_log "INFO Key-id: $fpr"

do_log "INFO Adding additional UID to card, if provided..."
for ((i=3; i<=$# - 1; i++))
do
	do_log "INFO Processing email: ${!i}"
	gpg	--batch														\
		--pinentry-mode	'loopback'									\
		--passphrase	"$CERTIFY_PASS"								\
		--quick-add-uid	"$fpr"										\
			"${name} <${!i}>"
done

do_log "INFO Generating sub-keys to Sign (S), Encrypt (E), and Authenticate (A)..."

gpg	--batch														\
	--pinentry-mode	'loopback'									\
	--passphrase	"$CERTIFY_PASS"								\
	--quick-add-key	"$fpr"										\
			"$key_type"											\
			'sign'												\
			"$subkey_expire"

gpg	--batch														\
	--pinentry-mode	'loopback'									\
	--passphrase	"$CERTIFY_PASS"								\
	--quick-add-key	"$fpr"										\
			"$enc_key_type"										\
			'encrypt'											\
			"$subkey_expire"

gpg	--batch														\
	--pinentry-mode	'loopback'									\
	--passphrase	"$CERTIFY_PASS"								\
	--quick-add-key	"$fpr"										\
			"$key_type"											\
			'auth'												\
			"$subkey_expire"

do_log "INFO Completed creating sub-keys."
do_log "INFO Creating revocaton certificates..."

# Exports
printf	'%s\n'													\
	'y'															\
	'0'															\
	'This revocation certificate was created pre-emptively'		\
	''															\
	'y'															\
	'y'	|
gpg	--output	"revoke-no-reason-$fpr-$(date +"%d%m%Y-%H:%M:%S%z").asc"						\
	--pinentry-mode	'loopback'									\
	--passphrase	"$CERTIFY_PASS"								\
	--command-fd	0											\
	--gen-revoke	"$fpr"

printf	'%s\n'													\
	'y'															\
	'1'															\
	'This revocation certificate was created pre-emptively'		\
	''															\
	'y'															\
	'y'	|
gpg	--output	"revoke-compromised-$fpr-$(date +"%d%m%Y-%H:%M:%S%z").asc"					\
	--pinentry-mode	'loopback'									\
	--passphrase	"$CERTIFY_PASS"								\
	--command-fd	0											\
	--gen-revoke	"$fpr"

printf	'%s\n'													\
	'y'															\
	'2'															\
	'This revocation certificate was created pre-emptively'		\
	''															\
	'y'															\
	'y'	|
gpg	--output	"revoke-superseded-$fpr-$(date +"%d%m%Y-%H:%M:%S%z").asc"					\
	--pinentry-mode	'loopback'									\
	--passphrase	"$CERTIFY_PASS"								\
	--command-fd	0											\
	--gen-revoke	"$fpr"

printf	'%s\n'													\
	'y'															\
	'3'															\
	'This revocation certificate was created pre-emptively'		\
	''															\
	'y'															\
	'y'	|
gpg	--output	"revoke-no-longer-used-$fpr-$(date +"%d%m%Y-%H:%M:%S%z").asc"				\
	--pinentry-mode	'loopback'									\
	--passphrase	"$CERTIFY_PASS"								\
	--command-fd	0											\
	--gen-revoke	"$fpr"

do_log "INFO Exporting keys to disk..."

gpg	--pinentry-mode		'loopback'								\
	--passphrase		"$CERTIFY_PASS"							\
	--armor														\
	--export-secret-keys	"$fpr"								\
	>"gpg-$fpr-mastersub-$(date +"%d%m%Y-%H:%M:%S%z").key"

gpg	--pinentry-mode		'loopback'								\
	--passphrase		"$CERTIFY_PASS"							\
	--armor														\
	--export-secret-subkeys	"$fpr"								\
	>"gpg-$fpr-sub-$(date +"%d%m%Y-%H:%M:%S%z").key"

gpg	--armor														\
	--export	"$fpr"											\
	>"gpg-${fpr}-$(date +"%d%m%Y-%H:%M:%S%z")-public.asc"


do_log "INFO Preparing to archive generated files..."

# Disabled as I do not like the idea of using `rm -rf` in a publicly available script.
# Use this at your own peril!
#
# if test -d $output; then
# 	read -p "Delete $output? (Y/N) - Choose "N" to delete it manually: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
#
# 	# rm -rf $output
# fi

if test -d $output; then
	do_log "ERROR Manually delete $output and run this script again.  Good bye!"
	exit 1
fi

mkdir "$output"
mkdir -p "$pub1"
mkdir -p "$pub2"
mkdir -p "$crypt1"
mkdir -p "$crypt2"

# Change to target dir
cd "$output"

# Copy public key to unencrypted store
for pub_key in "$GNUPGHOME/gpg-${fpr}-"*"-public.asc"; do
	cp "$pub_key" "$pub1"
	cp "$pub_key" "$pub2"
done

# Copy revocation certificates to unencrypted store
for rev_cert in "$GNUPGHOME/revoke-"*"-${fpr}-"*".asc"; do
	cp "$rev_cert" "$pub1"
	cp "$rev_cert" "$pub2"
done

do_log "INFO Intermediary pre-archival copy completed..."
tree -L 2 "$output"

# Must back up to encrypted store before copying to yubi
cp -r "$pub1" $GNUPGHOME
tree -L 2 $GNUPGHOME

tar -czf "$output/backup-${fpr}-$(date +"%d%m%Y-%H:%M:%S%z").tar.gz" $GNUPGHOME

do_log "INFO Compressed archive created."

echo ""
echo "WRITE THIS DOWN IN A SECURE PLACE: $CERTIFY_PASS"
echo ""

# Print gpg key details
gpg -K
gpg --delete-secret-key

cd

rm -rf "$GNUPGHOME"

printf	'%s\n'								\
	'WRITE THIS DOWN IN A SECURE PLACE' "$CERTIFY_PASS"		\
	'Reboot soon and before restoring network connectivity.'	1>&2

# Just cause
unset fpr GNUPGHOME passphrase

# vim: ts=8:sw=8:sts=8:noet:ft=sh
