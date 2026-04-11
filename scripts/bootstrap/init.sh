#!/usr/bin/env sh
set -eu

git config commit.gpgsign true
git config tag.gpgSign true

if ! git config --get gpg.format >/dev/null 2>&1; then
    signing_key="$(git config --get user.signingkey 2>/dev/null || true)"
    case "$signing_key" in
        *".ssh/"*|ssh-*)
            git config gpg.format ssh
            ;;
        *)
            git config gpg.format openpgp
            ;;
    esac
fi

if command -v swift >/dev/null 2>&1; then
    swift --version
else
    echo "swift is required but not installed or not on PATH" >&2
    exit 1
fi

./scripts/bootstrap/install-hooks.sh
