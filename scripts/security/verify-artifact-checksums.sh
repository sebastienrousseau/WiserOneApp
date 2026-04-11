#!/usr/bin/env sh
set -eu

manifest_path="${1:-governance/checksums/sha256sums.txt}"

if [ ! -f "$manifest_path" ]; then
    echo "Checksum manifest not found: $manifest_path" >&2
    exit 1
fi

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

failed=0
line_number=0

while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))

    case "$line" in
        ""|\#*)
            continue
            ;;
    esac

    case "$line" in
        *"  "*)
            expected="${line%%  *}"
            path="${line#*  }"
            ;;
        *)
            echo "Invalid checksum manifest line ${line_number}: $line" >&2
            failed=1
            continue
            ;;
    esac

    if [ ! -f "$path" ]; then
        echo "Missing file referenced by checksum manifest: $path" >&2
        failed=1
        continue
    fi

    actual="$(checksum_file "$path")"
    if [ "$actual" != "$expected" ]; then
        echo "Checksum mismatch: $path" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        failed=1
    fi
done < "$manifest_path"

if [ "$failed" -ne 0 ]; then
    echo "Artifact checksum verification failed." >&2
    exit 1
fi

echo "Artifact checksum verification passed."
