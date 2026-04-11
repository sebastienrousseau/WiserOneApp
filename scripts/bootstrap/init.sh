#!/usr/bin/env sh
set -eu

git config commit.gpgsign true
git config tag.gpgSign true
git config gpg.format openpgp

if command -v swift >/dev/null 2>&1; then
    swift --version
else
    echo "swift is required but not installed or not on PATH" >&2
    exit 1
fi

./scripts/bootstrap/install-hooks.sh
