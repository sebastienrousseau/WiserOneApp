#!/usr/bin/env sh
set -eu

./scripts/security/verify-signed-commits.sh
./scripts/security/verify-dependency-checksums.sh
./scripts/security/verify-artifact-checksums.sh
./scripts/security/scan-secrets.sh
./scripts/security/scan-security-patterns.sh
./scripts/security/scan-vulnerabilities.sh
./scripts/security/verify-macos-binary-signature.sh
./scripts/security/generate-sbom.sh
./scripts/security/generate-validation-record.sh

echo "Security audit passed."
