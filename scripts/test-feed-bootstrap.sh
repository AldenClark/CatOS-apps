#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/etc/apk/keys" "$test_root/etc/apk/repositories.d" "$test_root/bin"

# Redirect only the on-device paths; keep the public URLs unchanged.
sed \
  -e "s|/etc/openwrt_release|$test_root/etc/openwrt_release|g" \
  -e "s|/etc/apk/keys|$test_root/etc/apk/keys|g" \
  -e "s|/etc/apk/repositories.d|$test_root/etc/apk/repositories.d|g" \
  feed.sh > "$test_root/feed.sh"

cat > "$test_root/bin/id" <<'MOCK'
#!/bin/sh
if [ "${1:-}" = '-u' ]; then
  printf '0\n'
else
  exit 1
fi
MOCK

cat > "$test_root/bin/apk" <<'MOCK'
#!/bin/sh
case "${1:-}" in
  --print-arch) printf '%s\n' "${TEST_ARCH:-aarch64_generic}" ;;
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
case "$url" in
  */packages.adb)
    [ "${TEST_INDEX_FAIL:-0}" = '0' ] || exit 1
    printf 'signed-index-test\n' > "$destination"
    ;;
  */keys/catos-apk.pem)
    printf '%s\n' '-----BEGIN PUBLIC KEY-----' "${TEST_KEY_BODY:-valid-key}" '-----END PUBLIC KEY-----' > "$destination"
    ;;
  *) exit 1 ;;
esac
MOCK

chmod +x "$test_root/bin/id" "$test_root/bin/apk" "$test_root/bin/wget"
printf "DISTRIB_RELEASE='25.12.6'\n" > "$test_root/etc/openwrt_release"

export TEST_APK_LOG="$test_root/apk.log"
export PATH="$test_root/bin:$PATH"
repository="$test_root/etc/apk/repositories.d/customfeeds.list"
key="$test_root/etc/apk/keys/catos-apk.pem"
expected='https://aldenclark.github.io/CatOS-apps/releases/25.12.6/aarch64_generic/packages.adb'

sh "$test_root/feed.sh" >/dev/null
grep -Fxq "$expected" "$repository"
test -s "$key"
test "$(wc -l < "$TEST_APK_LOG")" -eq 1

# Running the bootstrap again must not add another repository entry.
sh "$test_root/feed.sh" >/dev/null
test "$(wc -l < "$repository")" -eq 1
test "$(wc -l < "$TEST_APK_LOG")" -eq 2

# Fail closed for an unsupported release or architecture.
printf "DISTRIB_RELEASE='24.10.7'\n" > "$test_root/etc/openwrt_release"
if sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Unsupported OpenWrt release unexpectedly succeeded.' >&2
  exit 1
fi
printf "DISTRIB_RELEASE='25.12.6'\n" > "$test_root/etc/openwrt_release"
if TEST_ARCH='aarch64_cortex-a53' sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Unsupported package architecture unexpectedly succeeded.' >&2
  exit 1
fi

# Reject a changed public key rather than silently replacing a trust anchor.
if TEST_KEY_BODY='different-key' sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Changed signing key unexpectedly succeeded.' >&2
  exit 1
fi
grep -Fxq 'valid-key' "$key"

# A missing remote index must not change the current repository or key.
if TEST_INDEX_FAIL=1 sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Missing repository index unexpectedly succeeded.' >&2
  exit 1
fi
test "$(wc -l < "$repository")" -eq 1

# Reject obsolete CatOS URLs while leaving user configuration untouched.
printf '%s\n' 'https://aldenclark.github.io/CatOS-apps/releases/25.12.5/aarch64_generic/packages.adb' >> "$repository"
if sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Stale repository entry unexpectedly succeeded.' >&2
  exit 1
fi
test "$(wc -l < "$repository")" -eq 2

# No failing preflight may invoke an APK update.
test "$(wc -l < "$TEST_APK_LOG")" -eq 2

# An APK index update failure must be reported, not treated as successful setup.
printf '%s\n' "$expected" > "$repository"
if TEST_UPDATE_FAIL=1 sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Failed APK index update unexpectedly succeeded.' >&2
  exit 1
fi
test "$(wc -l < "$TEST_APK_LOG")" -eq 3

echo 'CatOS feed bootstrap tests passed.'
