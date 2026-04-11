# Software Validation Procedure

## Purpose

Define a repeatable validation path for release decisions.

## Procedure

1. Capture traceability context.
   - Record commit SHA and branch.
2. Verify author integrity.
   - Run `make verify-signatures`.
3. Verify dependency integrity.
   - Run `make verify-dependency-checksums`.
4. Verify artifact integrity.
   - Run `make verify-checksums`.
5. Verify security baseline.
   - Run `make scan-secrets`.
   - Run `make scan-security-patterns`.
   - Run `make scan-vulnerabilities`.
6. Verify functional baseline.
   - Run `make test-all`.
7. Generate evidence artifacts.
   - Run `make sbom`.
   - Run `make generate-validation-record`.

## Acceptance Criteria

- All gates pass.
- Signed commit verification passes for release commit range.
- SBOM and validation record artifacts are generated.
