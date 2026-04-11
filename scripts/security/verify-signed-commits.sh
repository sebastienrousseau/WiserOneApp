#!/usr/bin/env sh
set -eu

if [ "${1:-}" != "" ]; then
    range="$1"
elif git rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
    base_commit="$(git merge-base HEAD '@{upstream}')"
    range="${base_commit}..HEAD"
else
    range="HEAD"
fi

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "No commits to verify."
    exit 0
fi

if ! git log --pretty='%H %G?' "$range" >/dev/null 2>&1; then
    range="HEAD"
fi

invalid_commits="$(
    git log --pretty='%H %G?' "$range" | awk '
        $2 == "N" || $2 == "B" || $2 == "R" {
            print $0
        }
    '
)"

if [ -n "$invalid_commits" ]; then
    echo "Unsigned or untrusted commits found:"
    echo "$invalid_commits"
    exit 1
fi

echo "All checked commits are signed."
