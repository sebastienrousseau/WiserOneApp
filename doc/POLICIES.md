<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

# Policies

## Contents

- [Platform support](#platform-support)
- [Coverage](#coverage)
- [Corpus changes](#corpus-changes)
- [Supply chain](#supply-chain)
- [Security](#security)

## Platform support

| Platform | Build | Test | Run |
|---|---|---|---|
| macOS 13+ | `swift build` | `swift test` | `swift run WiserOne` |
| Linux | `swift build` | `swift test` | Not supported |
| WSL2 | `swift build` | `swift test` | Not supported |

The AppKit sources are behind `#if canImport(Cocoa)`. On Linux the app
target compiles to a stub; the core and its tests still build and run.

## Coverage

Two floors, enforced by `make test-coverage-scopes` on macOS:

| Scope | Floor |
|---|---|
| LOGIC | 92% |
| UI | 74% |

Ratchets, not targets. Raise them when coverage genuinely improves. If a
change cannot clear a floor, the answer is a test, not a smaller number.

Structurally uncoverable lines — assertion failure branches, guards the
surrounding invariants make unreachable — are documented in
[TESTING.md](TESTING.md) rather than excluded, so the gap stays visible.

## Corpus changes

`sources/resources/quotes.json` is a mirror. The canonical pool is
published by the website at
[`wiserone.com/quotes.json`](https://wiserone.com/quotes.json).

- Change the website's pool first, then mirror here.
- Never reorder or renumber ids. `id` is the rotation index; shifting it
  changes which quote every future day shows, silently, in this app and
  in the CLI.
- Every entry needs an `id`. Entries without one sort last and log
  `unorderedCorpus`, and the app will disagree with the website.
- `make hygiene` runs the drift check; `governance/checksums/` pins the
  bundled resources by hash and is regenerated with
  `./scripts/security/update-artifact-checksums.sh`.

## Supply chain

- Every commit is signature-verified in CI.
- Resource files are pinned by SHA-256 in
  `governance/checksums/sha256sums.txt`.
- A CycloneDX SBOM and a validation record are produced per build and
  uploaded as artefacts.
- Release binaries are codesign-verified.

## Security

Report vulnerabilities via [`.github/SECURITY.md`](../.github/SECURITY.md).

The app reads only files inside its own bundle and writes only its log.
It makes no network requests: the corpus ships with the binary, which is
why drift against the website is a build-time check rather than a
runtime one.
