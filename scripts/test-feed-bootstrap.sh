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
  --version) printf '%s\n' "${TEST_APK_VERSION:-apk-tools 3.0.5, compiled for aarch64.}" ;;
  --print-arch) printf '%s\n' "${TEST_ARCH:-aarch64}" ;;
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
printf "DISTRIB_RELEASE='0.8.5-beta'\nDISTRIB_ARCH='aarch64_cortex-a55'\n" > "$test_root/etc/openwrt_release"

export TEST_APK_LOG="$test_root/apk.log"
export PATH="$test_root/bin:$PATH"
repository="$test_root/etc/apk/repositories.d/customfeeds.list"
key="$test_root/etc/apk/keys/catos-apk.pem"
expected='https://aldenclark.github.io/CatOS-apps/universal/packages.adb'

sh "$test_root/feed.sh" >/dev/null
grep -Fxq "$expected" "$repository"
test -s "$key"
test "$(wc -l < "$TEST_APK_LOG")" -eq 1

# Running the bootstrap again must not add another repository entry.
sh "$test_root/feed.sh" >/dev/null
test "$(wc -l < "$repository")" -eq 1
test "$(wc -l < "$TEST_APK_LOG")" -eq 2

# Custom branding and CPU subtargets must not block architecture-independent APKs.
printf "DISTRIB_RELEASE='24.10.7'\n" > "$test_root/etc/openwrt_release"
TEST_ARCH='aarch64_cortex-a53' sh "$test_root/feed.sh" >/dev/null
test "$(wc -l < "$repository")" -eq 1
test "$(wc -l < "$TEST_APK_LOG")" -eq 3

# APK v2 cannot consume the v3 signed-index format.
if TEST_APK_VERSION='apk-tools 2.14.6' sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Unsupported APK format unexpectedly succeeded.' >&2
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

# Migrate obsolete CatOS URLs without touching unrelated custom feeds.
printf '%s\n' 'https://aldenclark.github.io/CatOS-apps/releases/25.12.5/aarch64_generic/packages.adb' >> "$repository"
printf '%s\n' 'https://example.org/custom/packages.adb' >> "$repository"
sh "$test_root/feed.sh" >/dev/null
test "$(wc -l < "$repository")" -eq 2
grep -Fxq "$expected" "$repository"
grep -Fxq 'https://example.org/custom/packages.adb' "$repository"
! grep -Fq '/releases/25.12.5/' "$repository"

# No failing preflight may invoke an APK update.
test "$(wc -l < "$TEST_APK_LOG")" -eq 4

# An APK index update failure must be reported, not treated as successful setup.
printf '%s\n' "$expected" > "$repository"
if TEST_UPDATE_FAIL=1 sh "$test_root/feed.sh" >/dev/null 2>&1; then
  echo 'Failed APK index update unexpectedly succeeded.' >&2
  exit 1
fi
test "$(wc -l < "$TEST_APK_LOG")" -eq 5

echo 'CatOS feed bootstrap tests passed.'
