#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s OUTPUT_DIRECTORY_OUTSIDE_THE_REPOSITORY\n' "$0" >&2
  exit 2
fi

repository_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
output_dir="$1"

umask 077
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd -P)"

case "$output_dir" in
  "$repository_dir"|"$repository_dir"/*)
    printf 'The signing keys must be generated outside the Git repository.\n' >&2
    exit 1
    ;;
esac

private_key="$output_dir/catos-apk-private.pem"
public_key="$output_dir/catos-apk.pem"

if [[ -e "$private_key" || -e "$public_key" ]]; then
  printf 'Refusing to overwrite an existing signing key.\n' >&2
  exit 1
fi

openssl ecparam -name prime256v1 -genkey -noout -out "$private_key"
openssl ec -in "$private_key" -pubout -out "$public_key" 2>/dev/null
chmod 600 "$private_key"
chmod 644 "$public_key"

printf 'Private key: %s\n' "$private_key"
printf 'Public key:  %s\n' "$public_key"
printf 'Public key SHA-256 (DER): '
openssl pkey -pubin -in "$public_key" -outform DER | openssl dgst -sha256
