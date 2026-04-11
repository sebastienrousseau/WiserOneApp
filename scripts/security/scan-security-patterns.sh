#!/usr/bin/env sh
set -eu

if rg -n \
    --glob '.github/workflows/**' \
    --glob 'scripts/**' \
    --glob '*.sh' \
    --glob '!scripts/security/scan-security-patterns.sh' \
    -e 'curl[^\n|]*\|\s*(sh|bash)' \
    -e 'chmod\s+777' \
    -e 'mktemp\s+-u' \
    -e '(^|[[:space:]])eval[[:space:]]' \
    -e '--insecure' \
    .
then
    echo "Insecure automation pattern detected." >&2
    exit 1
fi

echo "Security pattern scan passed."
