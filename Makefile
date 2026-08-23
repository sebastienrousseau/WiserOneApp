SHELL := /bin/sh

.PHONY: init build clean test test-all test-unit test-ui test-coverage lint shell-lint verify-signatures verify-checksums update-checksums verify-dependency-checksums scan-secrets scan-security-patterns scan-vulnerabilities verify-binary-signature sbom generate-validation-record governance-refresh security portability docs-check content-integrity verify-corpus hygiene install-hooks prepush-check ci-local release-github release-appstore release-macos-artifacts release-linux-packages

init:
	./scripts/bootstrap/init.sh

build:
	swift build

clean:
	rm -rf .build

test:
	./scripts/quality/test-with-coverage.sh 100

# Coverage over the whole app, split by testability. The core-only gate
# above reports 100% while measuring seven lines; this one measures all
# of sources/. macOS only: AppDelegate and QuoteViewController are
# behind `#if canImport(Cocoa)` and compile to nothing on Linux.
test-coverage-scopes:
	./scripts/quality/check-coverage-scopes.sh

test-all: test test-ui

test-unit:
	swift test

test-ui:
	swift test --filter WiserOneUITests

test-coverage:
	./scripts/quality/test-with-coverage.sh 100

lint:
	if command -v swiftlint >/dev/null 2>&1; then swiftlint; else echo "swiftlint not installed; skipping"; fi

shell-lint:
	./scripts/quality/lint-shell.sh

verify-signatures:
	./scripts/security/verify-signed-commits.sh

verify-checksums:
	./scripts/security/verify-artifact-checksums.sh

update-checksums:
	./scripts/security/update-artifact-checksums.sh

verify-dependency-checksums:
	./scripts/security/verify-dependency-checksums.sh

scan-secrets:
	./scripts/security/scan-secrets.sh

scan-security-patterns:
	./scripts/security/scan-security-patterns.sh

scan-vulnerabilities:
	./scripts/security/scan-vulnerabilities.sh

verify-binary-signature:
	./scripts/security/verify-macos-binary-signature.sh

sbom:
	./scripts/security/generate-sbom.sh

generate-validation-record:
	./scripts/security/generate-validation-record.sh

governance-refresh:
	./scripts/security/generate-sbom.sh
	./scripts/security/generate-validation-record.sh
	./scripts/security/update-artifact-checksums.sh

security:
	./scripts/security/security-audit.sh

portability:
	./scripts/quality/verify-portability.sh

docs-check:
	./scripts/quality/verify-docs-completeness.sh
	./scripts/quality/verify-content-integrity.sh

content-integrity:
	./scripts/quality/verify-content-integrity.sh

verify-corpus:
	./scripts/quality/verify-corpus.sh

hygiene: portability docs-check shell-lint verify-corpus

install-hooks:
	./scripts/bootstrap/install-hooks.sh

prepush-check:
	./scripts/git/pre-push-guard.sh --no-stdin

ci-local: security test hygiene

release-github:
	./scripts/release/release-macos.sh github

release-appstore:
	./scripts/release/release-macos.sh appstore

release-macos-artifacts:
	./scripts/release/package-macos-dmg.sh "${VERSION:-0.0.0}"

release-linux-packages:
	./scripts/release/package-linux.sh "${VERSION:-0.0.0}"
