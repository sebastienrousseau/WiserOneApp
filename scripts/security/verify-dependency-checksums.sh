#!/usr/bin/env sh
set -eu

lock_file="${1:-governance/security/dependency-checksums.lock}"

if [ ! -f "$lock_file" ]; then
    echo "Dependency checksum lock file not found: $lock_file" >&2
    exit 1
fi

dep_urls="$(sed -n 's/.*\.package([^)]*url:[[:space:]]*"\([^"]*\)".*/\1/p' Package.swift | LC_ALL=C sort -u)"

if [ -z "$dep_urls" ]; then
    echo "No external SwiftPM dependencies detected."
    echo "Dependency checksum verification passed."
    exit 0
fi

missing=0

for dep_url in $dep_urls; do

    entry="$(awk -F'|' -v url="$dep_url" '
        $1 ~ /^#/ { next }
        NF >= 3 && $1 == url { print $0 }
    ' "$lock_file" | head -n 1)"

    if [ -z "$entry" ]; then
        echo "Missing checksum lock entry for dependency: $dep_url" >&2
        missing=1
        continue
    fi

    checksum_field="$(printf '%s' "$entry" | awk -F'|' '{print $2}')"
    signature_field="$(printf '%s' "$entry" | awk -F'|' '{print $3}')"

    if [ -z "$checksum_field" ] || [ "$checksum_field" = "TBD" ]; then
        echo "Missing or placeholder checksum for dependency: $dep_url" >&2
        missing=1
    fi

    if [ -z "$signature_field" ] || [ "$signature_field" = "TBD" ]; then
        echo "Missing vendor signature evidence for dependency: $dep_url" >&2
        missing=1
    fi

done

if [ "$missing" -ne 0 ]; then
    echo "Dependency checksum verification failed." >&2
    exit 1
fi

echo "Dependency checksum verification passed."
