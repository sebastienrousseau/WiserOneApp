#!/usr/bin/env sh
set -eu

zero_sha="0000000000000000000000000000000000000000"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$repo_root"

verify_range() {
    range="$1"
    ./scripts/security/verify-signed-commits.sh "$range"
}

run_security_checks() {
    ./scripts/security/verify-dependency-checksums.sh
    ./scripts/security/verify-artifact-checksums.sh
    ./scripts/security/scan-secrets.sh
    ./scripts/security/scan-security-patterns.sh
    ./scripts/security/scan-vulnerabilities.sh
    ./scripts/security/verify-macos-binary-signature.sh
    ./scripts/security/generate-sbom.sh
    ./scripts/security/generate-validation-record.sh
}

if [ "${1:-}" = "--no-stdin" ]; then
    verify_range "HEAD"
    run_security_checks
    make test
    exit 0
fi

saw_ref=0
while IFS=' ' read -r local_ref local_sha remote_ref remote_sha; do
    if [ -z "${local_sha:-}" ]; then
        continue
    fi

    saw_ref=1

    if [ "$local_sha" = "$zero_sha" ]; then
        continue
    fi

    if [ "${remote_sha:-$zero_sha}" = "$zero_sha" ]; then
        verify_range "$local_sha"
    else
        verify_range "$remote_sha..$local_sha"
    fi
done

if [ "$saw_ref" -eq 0 ]; then
    verify_range "HEAD"
fi

run_security_checks
make test
