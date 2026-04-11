#!/usr/bin/env sh
set -eu

./scripts/security/verify-signed-commits.sh
./scripts/security/verify-dependency-checksums.sh
./scripts/security/verify-artifact-checksums.sh
./scripts/security/scan-secrets.sh
./scripts/security/scan-security-patterns.sh
./scripts/security/scan-vulnerabilities.sh
./scripts/security/verify-macos-binary-signature.sh

refresh_governance="${REFRESH_GOVERNANCE_ARTIFACTS:-0}"
if [ "${CI:-}" = "true" ]; then
    refresh_governance=1
fi

if [ "$refresh_governance" = "1" ]; then
    ./scripts/security/generate-sbom.sh
    ./scripts/security/generate-validation-record.sh
else
    echo "Skipping governance artifact regeneration. Set REFRESH_GOVERNANCE_ARTIFACTS=1 to refresh."
fi

echo "Security audit passed."
