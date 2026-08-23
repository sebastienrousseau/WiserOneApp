#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$repo_root"

failed=0

required_readmes="
README.md
CONTRIBUTING.md
doc/README.md
scripts/README.md
tests/README.md
governance/checksums/README.md
config/README.md
governance/sbom/README.md
governance/security/README.md
governance/compliance/README.md
"

for file in $required_readmes; do
    if [ ! -f "$file" ]; then
        echo "Documentation completeness failed: missing $file" >&2
        failed=1
    fi
done

# Ensure docs index references every markdown file in doc/ except itself.
for doc_path in doc/*.md; do
    [ "$doc_path" = "doc/README.md" ] && continue
    doc_name="$(basename "$doc_path")"
    if ! grep -q "${doc_name}" doc/README.md; then
        echo "Documentation completeness failed: doc/README.md does not reference ${doc_name}" >&2
        failed=1
    fi
done

# Ensure root README includes core onboarding and signed commit guidance.
if ! grep -q 'swift build' README.md; then
    echo "Documentation completeness failed: README.md missing build command." >&2
    failed=1
fi

if ! grep -q 'swift test' README.md; then
    echo "Documentation completeness failed: README.md missing test command." >&2
    failed=1
fi

if ! grep -q 'swift run WiserOne' README.md; then
    echo "Documentation completeness failed: README.md missing app run command." >&2
    failed=1
fi

if ! grep -q 'git commit -S' README.md; then
    echo "Documentation completeness failed: README.md missing signed commit guidance." >&2
    failed=1
fi

if ! grep -q 'git commit -S' CONTRIBUTING.md; then
    echo "Documentation completeness failed: CONTRIBUTING.md missing signed commit guidance." >&2
    failed=1
fi

if [ "$failed" -ne 0 ]; then
    exit 1
fi

echo "Documentation completeness check passed."
