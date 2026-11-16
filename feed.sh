#!/bin/sh
# Configure the signed CatOS APK feed. This script does not install packages.
set -eu

base_url='https://aldenclark.github.io/CatOS-apps'
distfeeds_file='/etc/apk/repositories.d/distfeeds.list'
repository_file='/etc/apk/repositories.d/customfeeds.list'
key_file='/etc/apk/keys/catos-apk.pem'

info() { printf 'CatOS: %s\n' "$*"; }
fail() { printf 'CatOS: error: %s\n' "$*" >&2; exit 1; }

usage() {
	printf 'Usage: ash feed.sh [--channel openwrt-25.12|SNAPSHOT]\n'
	printf 'By default the channel comes from the installed OpenWrt base feed.\n'
}

requested_channel=''
case "$#" in
	0) ;;
	1)
		case "$1" in
			--help|-h) usage; exit 0 ;;
			*) usage >&2; exit 2 ;;
		esac
		;;
	2)
		[ "$1" = '--channel' ] || { usage >&2; exit 2; }
		case "$2" in
			openwrt-25.12|SNAPSHOT) requested_channel="$2" ;;
			*) fail "Unsupported channel: $2" ;;
		esac
		;;
	*) usage >&2; exit 2 ;;
esac

[ "$(id -u)" = 0 ] || fail 'Run this script as root on an OpenWrt device.'
[ -r /etc/openwrt_release ] || fail 'Missing /etc/openwrt_release.'
command -v apk >/dev/null 2>&1 || fail 'This binary feed requires apk; opkg is not supported.'
for command_name in wget grep cmp mktemp; do
	command -v "$command_name" >/dev/null 2>&1 || fail "Missing command: $command_name"
done

apk_version=$(apk --version) || fail 'Could not determine the APK version.'
case "$apk_version" in
	*'apk-tools 3.'*) ;;
	*) fail "CatOS requires APK v3; found: $apk_version" ;;
esac

# The installed base repository identifies the userspace ABI branch. Firmware
# branding, apk --print-arch, DISTRIB_ARCH and the kernel release do not.
detected_channel=''
if [ -r "$distfeeds_file" ]; then
	while IFS= read -r feed_line || [ -n "$feed_line" ]; do
		case "$feed_line" in
			''|\#*) continue ;;
			*/snapshots/packages/*/base/packages.adb) feed_channel='SNAPSHOT' ;;
			*/releases/25.12/packages/*/base/packages.adb|*/releases/25.12.[0-9]*/packages/*/base/packages.adb)
				feed_channel='openwrt-25.12' ;;
			*/releases/*/packages/*/base/packages.adb) feed_channel='unsupported' ;;
			*) continue ;;
		esac
		if [ -n "$detected_channel" ] && [ "$detected_channel" != "$feed_channel" ]; then
			fail 'Conflicting OpenWrt base feeds in distfeeds.list.'
		fi
		detected_channel="$feed_channel"
	done < "$distfeeds_file"
fi

[ "$detected_channel" != 'unsupported' ] || fail 'This OpenWrt release is not supported by the signed APK feed.'
if [ -n "$requested_channel" ]; then
	if [ -n "$detected_channel" ] && [ "$detected_channel" != "$requested_channel" ]; then
		fail "Requested $requested_channel conflicts with configured base feed $detected_channel."
	fi
	channel="$requested_channel"
else
	[ -n "$detected_channel" ] || fail 'Cannot identify the base feed. Check distfeeds.list or specify --channel.'
	channel="$detected_channel"
fi

repository_url="$base_url/feeds/$channel/all/packages.adb"
public_key_url="$base_url/keys/catos-apk.pem"
info "Selected channel: $channel (APK v3)."
wget -q -O /dev/null "$repository_url" || fail "Repository index unavailable: $repository_url"

mkdir -p /etc/apk/keys /etc/apk/repositories.d || fail 'Cannot create APK configuration directories.'
[ ! -L "$repository_file" ] || fail 'The custom feed file is a symlink; refusing to replace it.'

temporary_key=$(mktemp /etc/apk/keys/.catos-key.XXXXXX) || fail 'Cannot create a temporary key.'
temporary_repo=''
backup_repo=''
key_installed=0
repo_changed=0
committed=0

cleanup() {
	if [ "$committed" -eq 0 ]; then
		if [ "$repo_changed" -eq 1 ]; then
			if [ -n "$backup_repo" ]; then
				mv -f "$backup_repo" "$repository_file" || info 'WARNING: Could not restore customfeeds.list.'
			else
				rm -f "$repository_file"
			fi
		fi
		if [ "$key_installed" -eq 1 ]; then
			rm -f "$key_file"
		fi
	fi
	rm -f "$temporary_key"
	[ -z "$temporary_repo" ] || rm -f "$temporary_repo"
	[ -z "$backup_repo" ] || rm -f "$backup_repo"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

wget -q -O "$temporary_key" "$public_key_url" || fail "Could not download signing key: $public_key_url"
[ -s "$temporary_key" ] || fail 'Empty signing key.'
grep -q '^-----BEGIN PUBLIC KEY-----$' "$temporary_key" || fail 'Signing key is not PEM encoded.'
grep -q '^-----END PUBLIC KEY-----$' "$temporary_key" || fail 'Signing key is incomplete.'

if [ -e "$key_file" ]; then
	cmp -s "$temporary_key" "$key_file" || fail "Signing key changed: $key_file. Review key rotation first."
	info 'Existing signing key matches.'
else
	chmod 0644 "$temporary_key"
	mv "$temporary_key" "$key_file" || fail 'Cannot install the signing key.'
	key_installed=1
	info 'Signing key installed.'
fi

if grep -Fxq "$repository_url" "$repository_file" 2>/dev/null; then
	info 'Repository is already configured.'
else
	temporary_repo=$(mktemp /etc/apk/repositories.d/.catos-feed.XXXXXX) || fail 'Cannot create a temporary feed file.'
	if [ -f "$repository_file" ]; then
		cp -p "$repository_file" "$temporary_repo" || fail 'Cannot read existing custom feeds.'
		backup_repo=$(mktemp /etc/apk/repositories.d/.catos-backup.XXXXXX) || fail 'Cannot back up existing feeds.'
		cp -p "$repository_file" "$backup_repo" || fail 'Cannot back up existing feeds.'
		# Some firmware-generated feed files do not end with a newline.
		# Keep the new repository on a separate line in either case.
		if [ -s "$temporary_repo" ] && [ "$(tail -c 1 "$temporary_repo" | wc -l)" -eq 0 ]; then
			printf '\n' >> "$temporary_repo"
		fi
	else
		chmod 0644 "$temporary_repo"
	fi
	printf '%s\n' "$repository_url" >> "$temporary_repo"
	mv "$temporary_repo" "$repository_file" || fail 'Cannot configure custom feeds.'
	temporary_repo=''
	repo_changed=1
	info 'Repository configured.'
fi

info 'Updating APK indexes (the signed index is verified by APK)...'
apk update || fail 'APK update failed; this setup is being rolled back.'
committed=1

info 'Done. Install only the applications you need:'
printf '  apk add luci-app-catos-notify\n'
printf '  apk add luci-i18n-catos-notify-zh-cn  # Optional Simplified Chinese\n'
printf '  apk add luci-app-catos-ddns\n'
printf '  apk add luci-app-catos-acme\n'
