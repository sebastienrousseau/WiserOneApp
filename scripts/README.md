# Scripts

Terminal-only automation for setup, quality, security, git hooks, and release workflows.

## Folder Layout

- `bootstrap/`: repository setup and hook installation.
- `git/`: git-hook orchestration.
- `quality/`: coverage, portability, and docs/content integrity gates.
- `security/`: signature/checksum/scan/SBOM/validation gates.
- `release/`: release packaging and signing workflow.

## Primary Entrypoints

- `bootstrap/init.sh`: local bootstrap (`make init`).
- `quality/test-with-coverage.sh`: coverage gate (`make test`).
- `quality/lint-shell.sh`: shell lint gate (`make shell-lint`).
- `security/security-audit.sh`: full security gate (`make security`).
- `git/pre-push-guard.sh`: pre-push checks (`make prepush-check` or git hook).
- `release/release-macos.sh`: release flow (`make release-github` or `make release-appstore`).
- `release/package-macos-dmg.sh`: macOS installer artifacts (`make release-macos-artifacts VERSION=0.0.3`).
- `release/package-linux.sh`: Linux package artifacts (`make release-linux-packages VERSION=0.0.3`).

## Governance Refresh

Governance artifacts are not regenerated during routine local checks.
Regenerate tracked SBOM and validation records explicitly when needed:

```sh
make governance-refresh
```
