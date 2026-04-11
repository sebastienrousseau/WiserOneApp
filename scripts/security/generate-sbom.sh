#!/usr/bin/env sh
set -eu

lock_file="${1:-governance/security/dependency-checksums.lock}"
output_path="${2:-governance/sbom/cyclonedx-sbom.json}"

if [ ! -f "$lock_file" ]; then
    echo "Dependency checksum lock file not found: $lock_file" >&2
    exit 1
fi

mkdir -p "$(dirname "$output_path")"

repo_name="WiserOne"
repo_version="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/wiserone-sbom.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT INT TERM

{
    printf '{\n'
    printf '  "bomFormat": "CycloneDX",\n'
    printf '  "specVersion": "1.5",\n'
    printf '  "version": 1,\n'
    printf '  "metadata": {\n'
    printf '    "component": {\n'
    printf '      "type": "application",\n'
    printf '      "name": "%s",\n' "$repo_name"
    printf '      "version": "%s",\n' "$repo_version"
    printf '      "licenses": [\n'
    printf '        { "license": { "id": "MIT" } },\n'
    printf '        { "license": { "id": "Apache-2.0" } }\n'
    printf '      ]\n'
    printf '    }\n'
    printf '  },\n'
    printf '  "components": [\n'
    printf '    { "type": "library", "name": "WiserOneCore", "version": "%s" },\n' "$repo_version"
    printf '    { "type": "application", "name": "WiserOne", "version": "%s" }' "$repo_version"

    dep_count="$(awk -F'|' '$1 !~ /^#/ && NF >= 3 { count += 1 } END { print count + 0 }' "$lock_file")"

    if [ "$dep_count" -gt 0 ]; then
        awk -F'|' '
            $1 ~ /^#/ || NF < 3 { next }
            {
                url = $1
                checksum = $2
                n = split(url, parts, "/")
                name = parts[n]
                sub(/\.git$/, "", name)
                printf ",\n    { \"type\": \"library\", \"name\": \"%s\", \"version\": \"external\", \"externalReferences\": [{\"type\": \"distribution\", \"url\": \"%s\"}], \"hashes\": [{\"alg\": \"SHA-256\", \"content\": \"%s\"}] }", name, url, checksum
            }
        ' "$lock_file"
    fi

    printf '\n  ],\n'
    printf '  "dependencies": [\n'
    printf '    { "ref": "WiserOne", "dependsOn": ["WiserOneCore"] },\n'
    printf '    { "ref": "WiserOneCore", "dependsOn": [] }\n'
    printf '  ]\n'
    printf '}\n'
} > "$tmp_file"

mv "$tmp_file" "$output_path"
chmod 644 "$output_path"

echo "SBOM generated at $output_path"
