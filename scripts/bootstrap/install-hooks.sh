#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$repo_root"

if [ ! -d .git ]; then
    echo "Not a git repository. Skipping hook installation."
    exit 0
fi

git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/git/pre-push-guard.sh

echo "Installed Git hooks at .githooks"
