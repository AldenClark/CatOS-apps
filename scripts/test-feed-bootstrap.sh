#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/etc/apk/keys" "$test_root/etc/apk/repositories.d" "$test_root/bin"

# Replace only on-device paths; all feed URL checks remain realistic.
sed \
  -e "s|/etc/openwrt_release|$test_root/etc/openwrt_release|g" \
  -e "s|/etc/apk/keys|$test_root/etc/apk/keys|g" \
  -e "s|/etc/apk/repositories.d|$test_root/etc/apk/repositories.d|g" \
  feed.sh > "$test_root/feed.sh"

cat > "$test_root/bin/id" <<'MOCK'
#!/bin/sh
[ "${1:-}" = '-u' ] && printf '0\n'
MOCK

cat > "$test_root/bin/apk" <<'MOCK'
#!/bin/sh
case "${1:-}" in
  --version) printf '%s\n' "${TEST_APK_VERSION:-apk-tools 3.0.5, compiled for aarch64.}" ;;
  --print-arch) printf 'aarch64\n' ;;
  update)
    printf 'update\n' >> "$TEST_APK_LOG"
    [ "${TEST_UPDATE_FAIL:-0}" = '0' ]
    ;;
  *) exit 1 ;;
esac
MOCK

cat > "$test_root/bin/wget" <<'MOCK'
#!/bin/sh
[ "${1:-}" = '-q' ] && [ "${2:-}" = '-O' ] || exit 2
destination=$3
url=$4
printf '%s\n' "$url" >> "$TEST_WGET_LOG"
case "$url" in
  */packages.adb)
    [ "${TEST_INDEX_FAIL:-0}" = '0' ] || exit 1
    printf 'signed-index-fixture\n' > "$destination"
    ;;
  */keys/catos-apk.pem)
    printf '%s\n' '-----BEGIN PUBLIC KEY-----' "${TEST_KEY_BODY:-valid-key}" '-----END PUBLIC KEY-----' > "$destination"
    ;;
  *) exit 1 ;;
esac
MOCK

chmod +x "$test_root/bin/id" "$test_root/bin/apk" "$test_root/bin/wget"
printf "DISTRIB_RELEASE='0.8.5-beta'\nDISTRIB_ARCH='aarch64_cortex-a55'\n" > "$test_root/etc/openwrt_release"

export TEST_APK_LOG="$test_root/apk.log"
export TEST_WGET_LOG="$test_root/wget.log"
export PATH="$test_root/bin:$PATH"
distfeeds="$test_root/etc/apk/repositories.d/distfeeds.list"
repository="$test_root/etc/apk/repositories.d/customfeeds.list"
key="$test_root/etc/apk/keys/catos-apk.pem"
base='https://aldenclark.github.io/CatOS-apps'
snapshot="$base/feeds/SNAPSHOT/all/packages.adb"
stable="$base/feeds/openwrt-25.12/all/packages.adb"

# A branded RTL9617C firmware takes its dependency ABI from the official
# A53 userspace SNAPSHOT base feed, not from its version or CPU metadata.
printf '%s\n' \
  '# Official A53 userspace feeds' \
  'https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/base/packages.adb' \
  'https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/luci/packages.adb' > "$distfeeds"
sh "$test_root/feed.sh" >/dev/null
grep -Fxq "$snapshot" "$repository"
grep -Fxq "$snapshot" "$TEST_WGET_LOG"
test -s "$key"
test "$(wc -l < "$TEST_APK_LOG")" -eq 1

# Idempotent configuration does not change the repository file.
sh "$test_root/feed.sh" >/dev/null
test "$(wc -l < "$repository")" -eq 1
test "$(wc -l < "$TEST_APK_LOG")" -eq 2

# Stable 25.12 is selected from the base feed, not marketing version.
printf '%s\n' 'https://downloads.openwrt.org/releases/25.12/packages/x86_64/base/packages.adb' > "$distfeeds"
rm "$repository"
sh "$test_root/feed.sh" >/dev/null
grep -Fxq "$stable" "$repository"

# Both a dotted release URL and a branded firmware work with 25.12.
printf '%s\n' 'https://downloads.openwrt.org/releases/25.12.6/packages/x86_64/base/packages.adb' > "$distfeeds"
sh "$test_root/feed.sh" >/dev/null
grep -Fxq "$stable" "$repository"

# No guessed fallback for an unsupported or mixed base repository.
printf '%s\n' 'https://downloads.openwrt.org/releases/24.10/packages/x86_64/base/packages.adb' > "$distfeeds"
if sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Unsupported base feed unexpectedly succeeded.' >&2
  exit 1
fi
printf '%s\n' \
  'https://downloads.openwrt.org/snapshots/packages/x86_64/base/packages.adb' \
  'https://downloads.openwrt.org/releases/25.12/packages/x86_64/base/packages.adb' > "$distfeeds"
if sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Conflicting base feeds unexpectedly succeeded.' >&2
  exit 1
fi

# An explicit override is accepted only when it does not contradict known base feeds.
printf '%s\n' 'https://downloads.openwrt.org/snapshots/packages/x86_64/base/packages.adb' > "$distfeeds"
if sh "$test_root/feed.sh" --channel openwrt-25.12 >/dev/null 2>&1; then
  echo 'Contradictory channel override unexpectedly succeeded.' >&2
  exit 1
fi
printf '%s\n' '# Custom firmware: no recognizable official base feed' > "$distfeeds"
if sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Unrecognized base feed unexpectedly succeeded without an override.' >&2
  exit 1
fi
rm "$repository"
sh "$test_root/feed.sh" --channel SNAPSHOT >/dev/null
grep -Fxq "$snapshot" "$repository"

# APK v2, a changed key, and a missing index fail before changing the feed.
if TEST_APK_VERSION='apk-tools 2.14.6' sh "$test_root/feed.sh" --channel SNAPSHOT >/dev/null 2>&1; then
  echo 'APK v2 unexpectedly succeeded.' >&2
  exit 1
fi
if TEST_KEY_BODY='different-key' sh "$test_root/feed.sh" --channel SNAPSHOT >/dev/null 2>&1; then
  echo 'Changed key unexpectedly succeeded.' >&2
  exit 1
fi
grep -Fxq 'valid-key' "$key"
if TEST_INDEX_FAIL=1 sh "$test_root/feed.sh" --channel SNAPSHOT >/dev/null 2>&1; then
  echo 'Missing signed index unexpectedly succeeded.' >&2
  exit 1
fi
test "$(wc -l < "$repository")" -eq 1

# An APK update failure restores unrelated feeds and a newly-added key.
printf '%s\n' '# existing repositories' 'https://example.org/custom/packages.adb' > "$repository"
cp "$repository" "$test_root/prior-feeds"
rm "$key"
if TEST_UPDATE_FAIL=1 sh "$test_root/feed.sh" --channel SNAPSHOT >/dev/null 2>&1; then
  echo 'Failed APK update unexpectedly succeeded.' >&2
  exit 1
fi
cmp -s "$repository" "$test_root/prior-feeds"
test ! -e "$key"

# Normal setup after a transient failure must succeed without losing other repos.
sh "$test_root/feed.sh" --channel SNAPSHOT >/dev/null
grep -Fxq "$snapshot" "$repository"
grep -Fxq 'https://example.org/custom/packages.adb' "$repository"
test "$(grep -Fc "$snapshot" "$repository")" -eq 1

# Preserve an existing feed even when the file has no trailing newline.
printf '%s' 'https://example.org/no-final-newline/packages.adb' > "$repository"
sh "$test_root/feed.sh" --channel SNAPSHOT >/dev/null
grep -Fxq 'https://example.org/no-final-newline/packages.adb' "$repository"
grep -Fxq "$snapshot" "$repository"

echo 'CatOS signed feed bootstrap tests passed.'
