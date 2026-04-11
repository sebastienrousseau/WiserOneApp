#!/usr/bin/env sh
set -eu

dep_urls="$(sed -n 's/.*\.package([^)]*url:[[:space:]]*"\([^"]*\)".*/\1/p' Package.swift | LC_ALL=C sort -u)"

if [ -z "$dep_urls" ]; then
    echo "No external SwiftPM dependencies detected. CVE scan not required."
    exit 0
fi

if command -v osv-scanner >/dev/null 2>&1; then
    ./scripts/security/generate-sbom.sh
    osv-scanner --sbom=governance/sbom/cyclonedx-sbom.json
    echo "Vulnerability scan completed with osv-scanner."
    exit 0
fi

echo "External dependencies detected, but osv-scanner is not installed." >&2
echo "Install osv-scanner to perform CVE/GHSA checks for third-party packages." >&2
exit 1
