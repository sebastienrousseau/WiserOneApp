#!/usr/bin/env sh
set -eu

if grep -RInE --binary-files=without-match \
    --exclude-dir=.git \
    --exclude-dir=.build \
    --exclude-dir=.swiftpm \
    --exclude-dir=assets.xcassets \
    --exclude-dir=sbom \
    --exclude=logo.svg \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'ASIA[0-9A-Z]{16}' \
    -e 'ghp_[A-Za-z0-9]{36}' \
    -e 'github_pat_[A-Za-z0-9_]{20,}' \
    -e 'AIza[0-9A-Za-z\-_]{35}' \
    -e 'xox[baprs]-[A-Za-z0-9-]+' \
    -e '-----BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY-----' \
    -e '(^|[^A-Za-z])(SECRET|TOKEN|API[_-]?KEY|PASSWORD)[[:space:]]*=[[:space:]]*[^[:space:]]+' \
    .
then
    echo "Potential secrets detected." >&2
    exit 1
fi

echo "No high-confidence secrets detected."
