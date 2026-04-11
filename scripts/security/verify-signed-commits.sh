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

commit_list="$(git rev-list "$range" 2>/dev/null || true)"
if [ -z "$commit_list" ]; then
    echo "No commits in range to verify."
    exit 0
fi

unsigned_commits="$(
    printf '%s\n' "$commit_list" | while IFS= read -r commit_sha; do
        [ -z "$commit_sha" ] && continue
        if ! git cat-file -p "$commit_sha" | grep -q '^gpgsig '; then
            printf '%s\n' "$commit_sha"
        fi
    done
)"

if [ -n "$unsigned_commits" ]; then
    echo "Unsigned commits found:"
    echo "$unsigned_commits"
    exit 1
fi

signature_statuses="$(git log --pretty='%H %G?' "$range" 2>/dev/null || true)"
bad_or_revoked="$(
    printf '%s\n' "$signature_statuses" | awk '
        $2 == "B" || $2 == "R" {
            print $0
        }
    '
)"

if [ -n "$bad_or_revoked" ]; then
    echo "Bad or revoked commit signatures found:"
    echo "$bad_or_revoked"
    exit 1
fi

unknown_trust="$(
    printf '%s\n' "$signature_statuses" | awk '
        $2 == "E" || $2 == "N" {
            print $0
        }
    '
)"

strict_trust="${VERIFY_SIGNATURE_TRUST:-0}"
if [ "$strict_trust" = "1" ] && [ -n "$unknown_trust" ]; then
    echo "Unverified commit signatures found with strict trust enabled:"
    echo "$unknown_trust"
    exit 1
fi

if [ -n "$unknown_trust" ]; then
    echo "Signature trust could not be fully verified for some commits; all commits are signed."
fi

echo "All checked commits are signed."
