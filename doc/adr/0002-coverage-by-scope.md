<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

# ADR 0002 — Coverage is gated in two scopes

**Status:** Accepted · **Date:** 2026-08-23

## Context

The repository advertised a 100% coverage gate. It scoped to
`sources/core/` and ran only `WiserOneCoreTests`, so it measured seven
lines — and `sources/core/` at the time contained only
`QuoteResourceResolver`, which was dead code called from nowhere. The
gate was protecting a decoy.

Measured across the whole app, coverage was 66.90%. `ErrorLogger` was at
0/74: the entire logging path, with nothing verifying that a logged
error ever reached disk.

A single whole-app threshold does not work either. `AppDelegate` and
`QuoteViewController` are AppKit: status items, popovers, view
lifecycles, much of it private, with branches reachable only from a real
user session. Holding them to the same bar as pure arithmetic would
either force the bar down or push visibility open across a UI class for
no reason but the metric.

## Decision

Two scopes, gated separately, with `main.swift` excluded from both
because it starts the AppKit runloop.

| Scope | Contents | Floor |
|---|---|---|
| LOGIC | rotation, service, repository, cache, logger, bundle probe | 92% |
| UI | `AppDelegate`, `QuoteViewController` | 74% |

The rotation moved into `WiserOneCore`, replacing the dead resolver, so
the strictest gate now covers the code that decides what a reader sees.

## Consequences

**The numbers mean something.** 66.90% became 92.87% on logic and 74.55%
on UI, both honestly labelled.

**95% on LOGIC is not attainable by testing.** Eight of the remaining
uncovered lines are `assert(...)` failure regions, which a passing suite
cannot enter, and most of the rest are guards the surrounding invariants
make unreachable. Reaching 95 would mean deleting defensive assertions
to satisfy a number.

**The gate is macOS-only.** The AppKit sources measure as nothing on
Linux, so a shared threshold would compare two different codebases. Test
files touching those types need `#if canImport(Cocoa)` or the Linux
build fails to compile.

## Alternatives considered

**One threshold over everything.** Would have to sit at the UI level,
making it meaningless for the logic.

**Widen visibility on the private AppKit methods until 95% is
reachable.** Loosens encapsulation for measurement — optimising into the
instrument rather than improving the code.
