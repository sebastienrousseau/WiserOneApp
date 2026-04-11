#!/usr/bin/env sh
set -eu

min_percent="${1:-${COVERAGE_THRESHOLD:-100}}"
include_path="${2:-${COVERAGE_INCLUDE_PATH:-/sources/core/}}"

swift test --enable-code-coverage
coverage_json_path="$(swift test --show-codecov-path)"
swift ./scripts/quality/check-coverage.swift "$coverage_json_path" "$min_percent" "$include_path"
