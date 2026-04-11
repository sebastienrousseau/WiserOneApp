#!/usr/bin/env sh
set -eu

manifest_path="${1:-governance/checksums/sha256sums.txt}"

checksum_file() {
    path="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$path" | awk '{print $NF}'
    else
        echo "No SHA-256 utility found (shasum, sha256sum, or openssl required)." >&2
        exit 1
    fi
}

mkdir -p "$(dirname "$manifest_path")"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/wiserone-checksums.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT INT TERM

printf '# SHA-256 checksums for release artifacts\n' > "$tmp_file"
printf '# Regenerate with: ./scripts/security/update-artifact-checksums.sh\n' >> "$tmp_file"

find sources/resources -type f | LC_ALL=C sort | while IFS= read -r path; do
    hash="$(checksum_file "$path")"
    printf '%s  %s\n' "$hash" "$path" >> "$tmp_file"
done

mv "$tmp_file" "$manifest_path"

echo "Updated checksum manifest: $manifest_path"
