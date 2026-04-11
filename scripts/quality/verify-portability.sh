#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$repo_root"

failed=0

file_list="$(find . -type f \
    -not -path './.git/*' \
    -not -path './.build/*' \
    -not -path './dist/*' \
    | sed 's#^\./##' | LC_ALL=C sort)"

# 1) Spaces in file names create shell portability issues.
space_paths="$(printf '%s\n' "$file_list" | awk '/ / {print}')"
if [ -n "$space_paths" ]; then
    echo "Portability check failed: tracked paths contain spaces:" >&2
    echo "$space_paths" >&2
    failed=1
fi

# 2) Case-only path collisions break across case-insensitive/case-sensitive filesystems.
case_collision_output="$(printf '%s\n' "$file_list" | awk '
{
    lower = tolower($0)
    if (seen[lower] && seen[lower] != $0) {
        print seen[lower]
        print $0
        collision = 1
    }
    seen[lower] = $0
}
END {
    if (!collision) {
        exit 0
    }
    exit 1
}
' 2>/dev/null || true)"
if [ -n "$case_collision_output" ]; then
    echo "Portability check failed: case-collision risk detected:" >&2
    echo "$case_collision_output" >&2
    failed=1
fi

# 3) Hardcoded absolute local paths are not portable.
absolute_path_hits="$(
    grep -RInE "/Users/|/home/|[A-Za-z]:\\\\" \
        README.md CONTRIBUTING.md Package.swift Makefile docs scripts sources tests governance .github \
        2>/dev/null \
        | grep -v '^scripts/quality/verify-portability.sh:' \
        || true
)"
if [ -n "$absolute_path_hits" ]; then
    echo "Portability check failed: hardcoded absolute paths found:" >&2
    echo "$absolute_path_hits" >&2
    failed=1
fi

# 4) Detect CRLF in text files.
crlf_paths=""
while IFS= read -r path; do
    case "$path" in
        *.md|*.swift|*.sh|*.yml|*.yaml|*.json|*.toml|*.txt|*.plist|*.html|Makefile|.gitignore|.gitattributes|.dockerignore)
            if LC_ALL=C grep -q "$(printf '\r')" "$path"; then
                crlf_paths="${crlf_paths}${path}\n"
            fi
            ;;
    esac
done <<FILES
$(printf '%s\n' "$file_list")
FILES

if [ -n "$crlf_paths" ]; then
    echo "Portability check failed: CRLF detected in text files:" >&2
    printf "%b" "$crlf_paths" >&2
    failed=1
fi

if [ "$failed" -ne 0 ]; then
    exit 1
fi

echo "Portability check passed."
