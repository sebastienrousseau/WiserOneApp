# Repository Layout

## Runtime Code

- `sources/`: app runtime entry points and UI logic.
- `sources/core/`: portable logic.
- `sources/resources/`: quote JSON and menu bar SVG assets.

## Verification

- `tests/`: unit and UI tests.
- `scripts/`: automation for build, test, security, portability, and release tasks.

## Governance

- `governance/checksums/`: release checksum manifest.
- `governance/security/`: dependency integrity policy.
- `governance/sbom/`: generated SBOM and validation artifacts.
- `governance/compliance/`: validation templates and procedure docs.

## Local Generated Output

- `.build/`: SwiftPM build cache (untracked).
