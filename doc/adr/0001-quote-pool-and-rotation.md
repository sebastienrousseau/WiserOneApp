<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

# ADR 0001 — Quotes are a pool, and order is load-bearing

**Status:** Accepted · **Date:** 2026-08-23

## Context

The corpus shipped as twelve `MM-quotes.json` files, one per month, and
the app selected with `(dayOfYear - 1) % quotes.count`.

Two problems, discovered together.

**The corpus was the wrong corpus.** The website cut its pool from 1,033
quotes to 136 hand-calibrated ones; the rest were machine-generated
backfill in a register the project had abandoned. This app shipped 366
of the legacy lines and none of the calibrated ones.

**The rotation was not a rotation.** `dayOfYear` resets every January.
With 136 quotes and `365 % 136 == 93`, the first 93 surfaced twice a
year and the rest once, and the sequence jumped at the year boundary
rather than advancing by one.

## Decision

One `quotes.json` pool, ordered by `id`, selected by a continuous day
count on the website's epoch:

```swift
QuoteRotation.dayNumber()        // days since 0001-01-01, UTC
QuoteRotation.index(forDayNumber:poolSize:)
```

`date_added` is retained as provenance and selects nothing.

## Consequences

**The app and the website agree.** Same pool, same order, same ordinal —
same quote on the same day. A test pins it against a known date.

**Order became load-bearing, and that broke something immediately.** The
repository sorted the merged corpus by `date_added`, which was correct
when twelve files merged in arbitrary order. Under a pool it shuffled
the order the index reads from: the app and the site agreed on the index
and disagreed on the quote. Every test stayed green, because nothing
compared the two. Ordering is now by `id`.

**Filenames stopped mattering, but the probe still checked them.**
`ResourceBundleLocator` identified the resource bundle by looking for
`01-quotes.json`, with a fallback matching the substring
`"-quotes.json"` — which `quotes.json` does not contain. Both were
repointed.

**Drift needs a build-time check.** The corpus lives in three
repositories and the app makes no network requests, so nothing at
runtime can notice a divergence. The website publishes the canonical
pool at `/quotes.json` and `make hygiene` compares against it.

## Alternatives considered

**Keep the month files and mirror the new corpus into them.** Preserves
a layout whose only remaining function was to confuse the bundle probe.

**Fetch the pool at runtime.** Removes the drift problem entirely and
lets new quotes ship without a release. Rejected for now: it introduces
a network dependency and an offline-fallback path into an app whose
entire job is to show one sentence. Worth revisiting.
