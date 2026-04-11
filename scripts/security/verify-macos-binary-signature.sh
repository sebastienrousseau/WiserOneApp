#!/usr/bin/env sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Skipping macOS binary signature verification on non-macOS platform."
    exit 0
fi

swift build -c release --product WiserOne

bin_path="$(swift build -c release --show-bin-path)/WiserOne"

if [ ! -x "$bin_path" ]; then
    echo "Release binary not found: $bin_path" >&2
    exit 1
fi

if ! codesign --verify --deep --strict --verbose=2 "$bin_path" >/dev/null 2>&1; then
    # Apply ad-hoc signature when a local identity is not configured.
    codesign --force --sign - "$bin_path"
fi

codesign --verify --deep --strict --verbose=2 "$bin_path"

if ! codesign -dv --verbose=4 "$bin_path" 2>&1 | rg -q '^Identifier='; then
    echo "Code signature metadata missing identifier for $bin_path" >&2
    exit 1
fi

echo "macOS binary signature verification passed: $bin_path"
