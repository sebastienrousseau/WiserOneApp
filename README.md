<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

<p align="center">
  <img src="https://cloudcdn.pro/clients/wiserone/v1/logos/wiserone.svg" alt="The Wiser One logo" width="128" />
</p>

<h1 align="center">WiserOne</h1>

<p align="center">
  A macOS menu-bar app showing one quote a day — the same quote
  <a href="https://wiserone.com">wiserone.com</a> is showing.
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/WiserOneApp/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/WiserOneApp/ci.yml?style=for-the-badge&logo=github" alt="Build" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/swift-5.9%2B-fa7343.svg?style=for-the-badge&logo=swift" alt="Swift" /></a>
  <a href="#platform-support"><img src="https://img.shields.io/badge/macOS-13%2B-000000.svg?style=for-the-badge&logo=apple" alt="macOS 13+" /></a>
  <a href="#quality-gates"><img src="https://img.shields.io/badge/coverage-logic%2092%25%20%7C%20ui%2074%25-66c2a5.svg?style=for-the-badge" alt="Coverage" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg?style=for-the-badge" alt="License" /></a>
</p>

---

## Contents

**Getting started**

- [Quick Start](#quick-start) — build and run in four commands
- [Platform support](#platform-support) — where it builds, tests and runs

**Reference**

- [Using the app](#using-the-app) — what the menu-bar item does
- [How selection works](#how-selection-works) — why it agrees with the website
- [The corpus](#the-corpus) — schema and the rules that matter
- [Repository map](#repository-map) — where everything lives

**Operational**

- [Quality gates](#quality-gates) — tests, coverage, hygiene, security
- [Release artifacts](#release-artifacts) — what a release produces
- [Documentation](#documentation) — all reference docs
- [Contributing](#contributing)
- [License](#license)

---

## Quick Start

```sh
make init
swift build
swift test          # or `make test` for the coverage-gated run
swift run WiserOne
```

The app runs as an accessory: a menu-bar icon, no Dock entry and no main
window.

## Platform support

| Platform | Build | Test | Run |
|---|---|---|---|
| macOS 13+ | ✅ | ✅ | ✅ |
| Linux | ✅ | ✅ | ❌ |
| WSL2 | ✅ | ✅ | ❌ |

The AppKit sources sit behind `#if canImport(Cocoa)`. On Linux the app
target compiles to a stub while the core and its tests still build and
run.

## Using the app

| Action | Result |
|---|---|
| Click the menu-bar icon | Opens the popover with today's quote |
| Click again | Closes it |
| Right-click, or Control-click | Context menu (Quit) |
| Click the logo in the popover | Opens wiserone.com |

VoiceOver announces the quote and attribution as one utterance, and
re-announces when the quote changes.

## How selection works

The corpus is an ordered **pool**, not a calendar:

```swift
let day   = QuoteRotation.dayNumber()   // days since 0001-01-01, UTC
let index = QuoteRotation.index(forDayNumber: day, poolSize: quotes.count)
```

`dayNumber` matches Python's `date.toordinal()`, where 1970-01-01 is
719163 — the ordinal [wiserone.com](https://wiserone.com) rotates on.
The pool is ordered by `id`. Same pool, same order, same ordinal, so the
app and the website show the same quote on the same day.

Two rules follow, and breaking either is silent:

- **`date_added` selects nothing.** It records when a line was written.
- **Order is load-bearing.** Reordering or renumbering shifts which quote
  every future day shows.

See [ADR 0001](doc/adr/0001-quote-pool-and-rotation.md).

## The corpus

`sources/resources/quotes.json`:

```json
{
  "quotes": [
    {
      "id": 0,
      "pillar": "elimination",
      "quote_text": "Say no to a hundred good things.",
      "author": "The Wiser One",
      "date_added": "2024-02-17T06:06:06Z",
      "image_url": "https://cloudcdn.pro/stocks/images/example.webp"
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | Pool position — what selection indexes |
| `pillar` | Thematic block |
| `quote_text` | The line |
| `author` | Attribution |
| `date_added` | Provenance: when it was written |
| `image_url` | Banner image |

The corpus is bundled, so new quotes arrive with a new build. The
canonical pool is published at
[`wiserone.com/quotes.json`](https://wiserone.com/quotes.json), and
`make hygiene` fails if the bundled copy has drifted from it.

## Repository map

```text
sources/
  core/          WiserOneCore — QuoteRotation, pure and portable
  resources/     quotes.json, logos
  *.swift        the macOS app: repository, cache, service, view, logger
tests/
  core-tests/    coverage-gated tests for the core
  ui-tests/      everything else, including the AppKit lifecycle
doc/             reference documentation
governance/      SBOM, checksums, validation records
scripts/         bootstrap, quality, security, release
config/          build and tooling configuration
```

## Quality gates

```sh
make test                    # core coverage gate
make test-coverage-scopes    # whole-app coverage, split by scope (macOS)
make hygiene                 # portability, docs, shell lint, corpus drift
make security                # signatures, checksums, SBOM, codesign
make ci-local                # everything CI runs
```

Coverage is gated in two scopes, because one number over an app that is
half pure logic and half AppKit means nothing:

| Scope | Contents | Floor |
|---|---|---|
| LOGIC | rotation, service, repository, cache, logger, bundle probe | 92% |
| UI | `AppDelegate`, `QuoteViewController` | 74% |

Floors are ratchets. Raise them as coverage improves; never lower one to
turn a red build green. The reasoning, and the list of lines that cannot
be covered by any test, are in [`doc/TESTING.md`](doc/TESTING.md) and
[ADR 0002](doc/adr/0002-coverage-by-scope.md).

## Release artifacts

| Artifact | Produced by |
|---|---|
| Signed macOS app | `make release-macos-artifacts` |
| Linux packages | `make release-linux-packages` |
| CycloneDX SBOM + validation record | `make security` |
| SHA-256 manifest of bundled resources | `./scripts/security/update-artifact-checksums.sh` |

Every commit is signature-verified in CI, and release binaries are
codesign-verified.

## Documentation

| Document | Covers |
|---|---|
| [`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md) | Targets, the pool, selection, the menu-bar lifecycle |
| [`doc/USER-GUIDE.md`](doc/USER-GUIDE.md) | Running the app, the corpus, troubleshooting |
| [`doc/TESTING.md`](doc/TESTING.md) | Suite layout, the two coverage scopes, measurement traps |
| [`doc/POLICIES.md`](doc/POLICIES.md) | Platforms, coverage, corpus rules, supply chain |
| [`doc/REPOSITORY-LAYOUT.md`](doc/REPOSITORY-LAYOUT.md) | Where everything lives |
| [`doc/adr/0001-quote-pool-and-rotation.md`](doc/adr/0001-quote-pool-and-rotation.md) | Why quotes are a pool, and why order matters |
| [`doc/adr/0002-coverage-by-scope.md`](doc/adr/0002-coverage-by-scope.md) | Why coverage is gated in two scopes |

Compliance and supply-chain records live under `governance/`.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

Commits must be signed — CI verifies every signature on push, and an
unsigned commit fails the build:

```sh
git commit -S -m "feat: your change"
```

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE)
or [MIT license](LICENSE-MIT) at your option.
