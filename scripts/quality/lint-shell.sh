#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$repo_root"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck not installed; skipping shell lint."
    exit 0
fi

shell_targets="$(find scripts -type f -name '*.sh' | LC_ALL=C sort)"

if [ -z "$shell_targets" ]; then
    echo "No shell scripts found to lint."
    exit 0
fi

# shellcheck disable=SC2086
shellcheck -x $shell_targets .githooks/pre-push

echo "Shell lint passed."
