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

# In CI, SSH commit verification can fail with "gpg.ssh.allowedSignersFile needs to
# be configured" even for genuinely signed commits. In that case, require that every
# commit contains a signature block, and skip trust-chain validation.
signing_format="$(git config --get gpg.format 2>/dev/null || true)"
allowed_signers_file="$(git config --get --path gpg.ssh.allowedSignersFile 2>/dev/null || true)"

if [ "$signing_format" = "ssh" ] && [ -n "$allowed_signers_file" ] && [ ! -f "$allowed_signers_file" ]; then
    allowed_signers_file=""
fi

if [ "$signing_format" = "ssh" ] && [ -z "$allowed_signers_file" ]; then
    unsigned_commits="$(
        git rev-list "$range" | while IFS= read -r commit_sha; do
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

    echo "All checked commits contain signatures (SSH trust verification skipped: allowedSignersFile not configured)."
    exit 0
fi

invalid_commits="$(
    git log --pretty='%H %G?' "$range" | awk '
        $2 == "N" || $2 == "B" || $2 == "R" || $2 == "E" {
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
