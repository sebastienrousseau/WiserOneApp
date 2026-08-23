#!/usr/bin/env bash
set -euo pipefail

# Validates the bundled quote corpus, and checks it against the pool
# wiserone.com publishes.
#
# The corpus is duplicated across three repositories and was, until now,
# synced by hand. That failed silently once already: this app ordered
# its pool by `date_added` while the site ordered by `id`, so the two
# showed different quotes on the same day and every test stayed green.
# There was no shared source to check against. Now there is.
#
# Structural checks are hard failures. The drift check is a hard failure
# on mismatch and a warning when the endpoint cannot be reached, so a
# flaky network does not redden an otherwise good build.

CORPUS="${1:-sources/resources/quotes.json}"
UPSTREAM="${WISERONE_POOL_URL:-https://wiserone.com/quotes.json}"

if [ ! -f "$CORPUS" ]; then
  echo "No corpus at $CORPUS" >&2
  exit 1
fi

python3 - "$CORPUS" <<'PY'
import json, sys, pathlib

path = pathlib.Path(sys.argv[1])
quotes = json.loads(path.read_text())["quotes"]
problems = []

if len(quotes) < 100:
    problems.append(f"only {len(quotes)} quotes; the rotation is visible below ~100")

ids = [q.get("id") for q in quotes]
if any(i is None for i in ids):
    problems.append(f"{sum(i is None for i in ids)} quote(s) with no id")
elif sorted(ids) != list(range(len(quotes))):
    problems.append("ids are not contiguous from zero")

texts = [q.get("quote_text", "") for q in quotes]
if len(set(texts)) != len(texts):
    problems.append(f"{len(texts) - len(set(texts))} duplicate quote(s)")

for i, q in enumerate(quotes):
    for field in ("quote_text", "author", "date_added", "image_url"):
        if not str(q.get(field, "")).strip():
            problems.append(f"quote {i} is missing {field}")
    if not str(q.get("image_url", "")).startswith("https://"):
        problems.append(f"quote {i} has a non-HTTPS image URL")

if problems:
    print("Corpus validation failed:")
    for p in problems[:10]:
        print(f"  - {p}")
    sys.exit(1)
print(f"Corpus validation passed: {len(quotes)} quotes, ids 0..{len(quotes) - 1}")
PY

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT INT TERM

if ! curl -fsSL --max-time 20 "$UPSTREAM" -o "$tmp" 2>/dev/null; then
  echo "WARNING: could not fetch $UPSTREAM; drift against the site is unverified."
  exit 0
fi

python3 - "$CORPUS" "$tmp" <<'PY'
import json, sys, pathlib

def load(p):
    data = json.loads(pathlib.Path(p).read_text())
    q = data["quotes"]
    q.sort(key=lambda x: x.get("id", 1 << 30))
    return [(x.get("id"), x.get("quote_text")) for x in q]

local, upstream = load(sys.argv[1]), load(sys.argv[2])
if local == upstream:
    print(f"Corpus matches wiserone.com: {len(local)} quotes, no drift.")
    sys.exit(0)

print("Corpus has drifted from wiserone.com:")
print(f"  bundled {len(local)} quotes, site {len(upstream)}")
lt, ut = {t for _, t in local}, {t for _, t in upstream}
for t in list(ut - lt)[:5]:
    print(f"  + on the site, missing here: {t[:64]}")
for t in list(lt - ut)[:5]:
    print(f"  - bundled here, gone from the site: {t[:64]}")
if lt == ut:
    print("  same quotes, different order — the daily selection will disagree")
sys.exit(1)
PY
