<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

# Testing

## Contents

- [Running the suite](#running-the-suite)
- [What each file covers](#what-each-file-covers)
- [Two coverage scopes](#two-coverage-scopes)
- [What cannot be covered](#what-cannot-be-covered)
- [Corpus drift](#corpus-drift)
- [Traps worth knowing](#traps-worth-knowing)

## Running the suite

```sh
make test                    # core coverage gate
make test-coverage-scopes    # whole-app coverage, split by scope (macOS)
make hygiene                 # portability, docs, shell lint, corpus
make security                # signatures, checksums, SBOM, codesign
swift test                   # 73 tests
```

## What each file covers

| File | Covers |
|---|---|
| `tests/core-tests/QuoteRotationTests.swift` | The rotation: epoch, monotonicity, UTC day boundaries, wraparound, negative ordinals, full-cycle reachability |
| `tests/ui-tests/QuoteRotationTests.swift` | Bundle resolution, website parity for a known day, year-boundary continuity, corpus ids |
| `tests/ui-tests/QuoteServiceTests.swift` | Cycling, wraparound, empty-pool guards, cache partitioning |
| `tests/ui-tests/QuoteRepositoryColdLoadTests.swift` | Cold loads against purpose-built bundles: discovery, decoding, size bounds, priority, id ordering |
| `tests/ui-tests/ErrorLoggerTests.swift` | Create and append paths, the size bound, unwritable destinations |
| `tests/ui-tests/AppDelegateTests.swift` | Status item, popover presentation, icon fallback, context menu |
| `tests/ui-tests/WiserOneUITests.swift` | View controller rendering and fixed sizing |

## Two coverage scopes

One number over this codebase means nothing, so there are two:

| Scope | Contents | Floor |
|---|---|---|
| **LOGIC** | rotation, service, repository, cache, logger, bundle probe | 92% |
| **UI** | `AppDelegate`, `QuoteViewController` | 74% |

`sources/main.swift` is excluded from both: it starts the AppKit
runloop and cannot be executed under a test harness.

The split is by testability. LOGIC is where a bug silently shows the
wrong quote, so it is gated hard. UI is AppKit views and status items,
much of it private, with branches reachable only from a real user
session.

Both floors are ratchets set just under the measured figure. Raise them
as coverage improves; never lower one to turn a red build green.

The gate runs on macOS only. `AppDelegate` and `QuoteViewController` sit
behind `#if canImport(Cocoa)` and measure as nothing on Linux, so a
shared threshold would compare two different codebases. Test files
exercising those types carry the same guard, or the Linux build fails to
compile the test target.

## What cannot be covered

Some lines cannot be entered by a passing test:

- **`assert(...)` failure branches.** Eight in the LOGIC scope. A
  passing assertion never enters its failure arm.
- **Defensive guards whose else-branch the surrounding invariants make
  unreachable** — for example the empty-pool guard after a load that
  already throws on empty.

They are documented rather than excluded, so the gap stays visible.
Reaching 95% on LOGIC would mean deleting defensive assertions to
satisfy a number.

## Corpus drift

`scripts/quality/verify-corpus.sh` validates the bundled corpus and
compares it against
[`wiserone.com/quotes.json`](https://wiserone.com/quotes.json), the
canonical pool. It fails on any divergence in content or order, and
warns rather than failing when the endpoint is unreachable.

It exists because a divergence shipped here undetected: this app ordered
its pool by `date_added` while the site ordered by `id`, and nothing
compared the two.

## Traps worth knowing

**A headless session cannot present a popover** anchored to the status
bar button, so `popover.isShown` stays false while the show path runs.
`AppDelegateTests` hosts the anchor in a real `NSWindow` so the
assertion means something.

**Testing through `resolve()` cannot guard the bundle probe.** When the
probe is wrong, `resolve()` falls through to a candidate that happens to
be correct in the SwiftPM layout, and every test still passes.
`isLikelyResourceBundle` is therefore internal and tested directly — a
test that was verified to fail when the probe is broken.

**`QuoteCache.shared` is process-wide.** Tests that need a cold load
must clear their bundle's partition first.
