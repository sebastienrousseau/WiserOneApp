#!/usr/bin/env bash
set -euo pipefail

# Two coverage gates, because one number over this codebase means
# nothing.
#
# The old gate reported 100% while measuring seven lines: it scoped to
# sources/core/ and ran only WiserOneCoreTests. Across the whole app the
# real figure was 66.90%.
#
# The split is by testability, not by convenience:
#
#   LOGIC  quote selection, the repository, the cache, the logger, the
#          bundle probe. Pure or filesystem-backed, unit-testable, and
#          where a bug silently shows the wrong quote. Gated hard.
#   UI     AppDelegate and QuoteViewController. AppKit views, status
#          items and popovers, much of it private and several branches
#          reachable only from a real user session. Gated lower and
#          honestly labelled.
#
# main.swift is excluded from both: it starts the AppKit runloop and
# cannot be executed under a test harness.
#
# Both numbers are llvm line coverage as reported by swift test — the
# same metric before and after, so the ratchet is meaningful.

LOGIC_MIN="${LOGIC_COVERAGE_MIN:-92}"
UI_MIN="${UI_COVERAGE_MIN:-74}"

swift test --enable-code-coverage
coverage_json="$(swift test --show-codecov-path)"

python3 - "$coverage_json" "$LOGIC_MIN" "$UI_MIN" <<'PY'
import json, sys

path, logic_min, ui_min = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
UI = {"AppDelegate.swift", "QuoteViewController.swift"}
ENTRY = {"main.swift"}

rows = []
for item in json.load(open(path))["data"]:
    for f in item["files"]:
        name = f["filename"]
        if "/sources/" not in name or "/.build/" in name:
            continue
        summary = f["summary"]["lines"]
        rows.append((name.split("/sources/")[-1],
                     summary["covered"], summary["count"]))

failed = False
for label, members, minimum in (
    ("LOGIC", lambda n: n.split("/")[-1] not in UI | ENTRY, logic_min),
    ("UI", lambda n: n.split("/")[-1] in UI, ui_min),
):
    group = [r for r in rows if members(r[0])]
    covered = sum(r[1] for r in group)
    total = sum(r[2] for r in group)
    if total == 0:
        print(f"{label}: no files measured — is this a non-Cocoa platform?")
        continue
    percent = 100 * covered / total
    print(f"{label}: {percent:.2f}% ({covered}/{total}), floor {minimum:.0f}%")
    for name, c, t in sorted(group, key=lambda r: r[1] / r[2] if r[2] else 1):
        print(f"    {100 * c / t if t else 100:6.2f}%  {c:>4}/{t:<4} {name}")
    if percent + 1e-9 < minimum:
        print(f"    FAIL: {label} coverage {percent:.2f}% is below {minimum:.0f}%")
        failed = True

sys.exit(1 if failed else 0)
PY
