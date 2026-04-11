#!/usr/bin/env sh
set -eu

if rg -n --hidden \
    --glob '!.git' \
    --glob '!.build/**' \
    --glob '!.swiftpm/**' \
    --glob '!sources/assets.xcassets/**' \
    --glob '!sources/resources/logo.svg' \
    --glob '!governance/sbom/**' \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'ASIA[0-9A-Z]{16}' \
    -e 'ghp_[A-Za-z0-9]{36}' \
    -e 'github_pat_[A-Za-z0-9_]{20,}' \
    -e 'AIza[0-9A-Za-z\-_]{35}' \
    -e 'xox[baprs]-[A-Za-z0-9-]+' \
    -e '-----BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY-----' \
    -e '(^|[^A-Za-z])(SECRET|TOKEN|API[_-]?KEY|PASSWORD)\s*[:=]\s*["'"'"'][^"'"'"']+["'"'"']' \
    .
then
    echo "Potential secrets detected." >&2
    exit 1
fi

echo "No high-confidence secrets detected."
