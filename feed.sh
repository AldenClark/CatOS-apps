#!/bin/sh
# Configure the signed CatOS APK feed. Does not install application packages.
set -eu

base_url='https://aldenclark.github.io/CatOS-apps'
key_file='/etc/apk/keys/catos-apk.pem'
repository_file='/etc/apk/repositories.d/customfeeds.list'

info() {
	printf 'CatOS: %s\n' "$*"
}

fail() {
	printf 'CatOS: error: %s\n' "$*" >&2
	exit 1
}

[ "$(id -u)" = 0 ] || fail 'Run this script as root on the OpenWrt device.'
[ -r /etc/openwrt_release ] || fail 'Missing /etc/openwrt_release; an OpenWrt device is required.'
command -v apk >/dev/null 2>&1 || fail 'APK is required; opkg-based systems are not supported by this binary feed.'
command -v wget >/dev/null 2>&1 || fail 'wget is required.'
command -v cmp >/dev/null 2>&1 || fail 'cmp is required.'
command -v awk >/dev/null 2>&1 || fail 'awk is required.'

. /etc/openwrt_release
release=${DISTRIB_RELEASE:-unknown}
apk_version=$(apk --version) || fail 'Could not determine the APK package-manager version.'
case "$apk_version" in
	*'apk-tools 3.'*) ;;
	*) fail "The signed CatOS feed requires APK v3; found: $apk_version" ;;
esac
architecture=$(apk --print-arch) || fail 'Could not determine the APK package architecture.'
[ -n "$architecture" ] || fail 'APK returned an empty package architecture.'

# All current CatOS packages are architecture-independent (PKGARCH=all).
# Keep this URL independent of branded firmware versions and CPU subtargets.
repository_url="$base_url/universal/packages.adb"
public_key_url="$base_url/keys/catos-apk.pem"

info "Firmware $release / APK v3 / $architecture"
info 'Checking that the signed repository is available...'
wget -q -O /dev/null "$repository_url" || fail "Cannot download the repository index: $repository_url"

mkdir -p /etc/apk/keys /etc/apk/repositories.d || fail 'Cannot create APK configuration directories.'
temporary_key=$(mktemp /etc/apk/keys/.catos-apk.XXXXXX) || fail 'Cannot create a temporary public-key file.'
temporary_repo=''
cleanup() {
	rm -f "$temporary_key"
	[ -z "$temporary_repo" ] || rm -f "$temporary_repo"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

info 'Downloading the repository public key...'
wget -q -O "$temporary_key" "$public_key_url" || fail "Cannot download the public key: $public_key_url"
[ -s "$temporary_key" ] || fail 'The downloaded public key is empty.'
grep -q '^-----BEGIN PUBLIC KEY-----$' "$temporary_key" || fail 'The downloaded public key is not PEM encoded.'
grep -q '^-----END PUBLIC KEY-----$' "$temporary_key" || fail 'The downloaded public key is incomplete.'

if [ -e "$key_file" ]; then
	cmp -s "$temporary_key" "$key_file" || fail "The published signing key differs from $key_file. Review the key rotation before proceeding."
	info 'Existing signing key matches.'
else
	chmod 0644 "$temporary_key"
	mv "$temporary_key" "$key_file" || fail 'Cannot install the public key.'
	info 'Signing key installed.'
fi

# Migrate only CatOS's previous release-specific URLs; preserve other feeds.
if [ -f "$repository_file" ] && grep -Fq "$base_url/releases/" "$repository_file"; then
	temporary_repo=$(mktemp /etc/apk/repositories.d/.catos-feed.XXXXXX) || fail 'Cannot create a temporary repository file.'
	awk -v prefix="$base_url/releases/" 'index($0, prefix) != 1' "$repository_file" > "$temporary_repo" || fail 'Cannot read the existing repository configuration.'
	if ! grep -Fxq "$repository_url" "$temporary_repo"; then
		printf '%s\n' "$repository_url" >> "$temporary_repo" || fail 'Cannot update the repository configuration.'
	fi
	chmod 0644 "$temporary_repo"
	mv "$temporary_repo" "$repository_file" || fail 'Cannot update the repository configuration.'
	info 'Migrated an older CatOS repository entry.'
elif grep -Fxq "$repository_url" "$repository_file" 2>/dev/null; then
	info 'Repository is already configured.'
else
	printf '%s\n' "$repository_url" >> "$repository_file" || fail 'Cannot add the repository to APK configuration.'
	info 'Repository configured.'
fi

info 'Updating APK indexes (signatures are verified by APK)...'
apk update || fail 'APK index update failed. Check network connectivity, repository compatibility, and signature verification.'

info 'Done. Install only the applications you need, for example:'
printf '  apk add luci-app-catos-notify\n'
printf '  apk add luci-app-catos-ddns\n'
printf '  apk add luci-app-catos-acme\n'
