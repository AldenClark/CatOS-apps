#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

sdk_feed="$temp_dir/sdk/bin/packages/aarch64_generic/catos"
mkdir -p "$sdk_feed"

packages=(
  catos-notify catos-ddns catos-acme
  luci-app-catos-notify luci-app-catos-ddns luci-app-catos-acme
)

printf 'SDK index fixture\n' > "$sdk_feed/packages.adb"
for package in "${packages[@]}"; do
  printf 'APK fixture: %s\n' "$package" > "$sdk_feed/${package}-0.1.0-r1.apk"
done

bash scripts/assemble-apk-feed.sh "$temp_dir/sdk/bin/packages" "$temp_dir/site" 25.12.6 aarch64_generic

test -s "$temp_dir/site/releases/25.12.6/aarch64_generic/packages.adb"
test "$(find "$temp_dir/site/releases/25.12.6/aarch64_generic" -name '*.apk' | wc -l | tr -d ' ')" -eq 6

# Publishing an architecture-independent alias must preserve the signed bytes.
mkdir -p "$temp_dir/site/universal"
cp -a "$temp_dir/site/releases/25.12.6/aarch64_generic/." "$temp_dir/site/universal/"
(cd "$temp_dir/site/universal" && sha256sum --check SHA256SUMS)

if bash scripts/assemble-apk-feed.sh "$temp_dir/sdk/bin/packages" "$temp_dir/site" 25.12.6 aarch64_generic 2>/dev/null; then
  printf 'Duplicate destination should be rejected.\n' >&2
  exit 1
fi

printf 'Unexpected package\n' > "$sdk_feed/unrelated-package-1.apk"
if bash scripts/assemble-apk-feed.sh "$temp_dir/sdk/bin/packages" "$temp_dir/site2" 25.12.6 aarch64_generic 2>/dev/null; then
  printf 'Unrelated package should be rejected.\n' >&2
  exit 1
fi

rm "$sdk_feed/unrelated-package-1.apk"
rm "$sdk_feed/catos-acme-0.1.0-r1.apk"
if bash scripts/assemble-apk-feed.sh "$temp_dir/sdk/bin/packages" "$temp_dir/site3" 25.12.6 aarch64_generic 2>/dev/null; then
  printf 'Incomplete CatOS package set should be rejected.\n' >&2
  exit 1
fi

printf 'APK feed assembly checks passed.\n'
