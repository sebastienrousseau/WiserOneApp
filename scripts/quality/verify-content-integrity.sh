#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$repo_root"

failed=0
targets="README.md CONTRIBUTING.md"
for doc_file in docs/*.md; do
    [ -f "$doc_file" ] || continue
    targets="${targets} ${doc_file}"
done

# 1) Block arbitrary score claims that are not command-verifiable.
score_hits="$(grep -nE '\b[0-9]+/[0-9]+\b' $targets 2>/dev/null || true)"
if [ -n "$score_hits" ]; then
    echo "Content integrity failed: unverifiable score tokens found." >&2
    echo "$score_hits" >&2
    failed=1
fi

# 2) Block hype/superlative language that inflates claims.
hype_hits="$(grep -nEi '\b(fastest|best in class|world[- ]class|ultimate|perfect|zero[- ]risk|guarantee(d)?|seamless)\b' $targets 2>/dev/null || true)"
if [ -n "$hype_hits" ]; then
    echo "Content integrity failed: hype language found." >&2
    echo "$hype_hits" >&2
    failed=1
fi

# 3) Block stale legacy path casing and pre-governance references.
legacy_path_hits="$(grep -nE '\b(Sources|Tests|Examples|Benchmarks)/|`(sbom|checksums|security|compliance)/' $targets 2>/dev/null || true)"
if [ -n "$legacy_path_hits" ]; then
    echo "Content integrity failed: legacy path references found." >&2
    echo "$legacy_path_hits" >&2
    failed=1
fi

# 4) Validate that local markdown links resolve.
for file in $targets; do
    dir_path="$(dirname "$file")"
    while IFS= read -r entry; do
        line_no="${entry%%:*}"
        token="${entry#*:}"
        link="${token#*](}"
        link="${link%)}"
        link="$(printf '%s' "$link" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^<//; s/>$//')"

        case "$link" in
            http://*|https://*|mailto:*|\#*)
                continue
                ;;
        esac

        link_path="${link%%#*}"
        link_path="${link_path%%\?*}"
        [ -n "$link_path" ] || continue

        target_path="${dir_path}/${link_path}"
        if [ ! -e "$target_path" ]; then
            echo "Content integrity failed: broken local link ${file}:${line_no} -> ${link}" >&2
            failed=1
        fi
    done <<EOF
$(grep -nEo '\[[^][]+\]\([^)]*\)' "$file" || true)
EOF
done

if [ "$failed" -ne 0 ]; then
    exit 1
fi

echo "Content integrity check passed."
