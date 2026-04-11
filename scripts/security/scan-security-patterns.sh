#!/usr/bin/env sh
set -eu

if grep -RInE --binary-files=without-match \
    --include='*.sh' \
    --include='*.yml' \
    --include='*.yaml' \
    --exclude='scan-security-patterns.sh' \
    -e 'curl[^|]*\|[[:space:]]*(sh|bash)' \
    -e 'chmod[[:space:]]+777' \
    -e 'mktemp[[:space:]]+-u' \
    -e '(^|[[:space:]])eval[[:space:]]' \
    -e '--insecure' \
    scripts .github/workflows
then
    echo "Insecure automation pattern detected." >&2
    exit 1
fi

echo "Security pattern scan passed."
