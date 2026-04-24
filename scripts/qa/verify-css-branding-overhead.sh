#!/usr/bin/env bash
# @covers AC-PERF-014
# @spec: frontend-performance-budgets_spec.md
# Verify custom Mereka MFE styling overhead budget.
# After WW-05 split, the manifest (mereka.scss) plus all mfe/scss/ partials
# are measured together — they all ship to the browser as one compiled bundle.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MEREKA_SOURCE_CSS="${MEREKA_SOURCE_CSS:-$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss}"
BUDGET_BYTES="${BUDGET_BYTES:-6144}" # 6 KB gzipped (raised from 5 KB at WW-05 partial split)

if [[ ! -f "$MEREKA_SOURCE_CSS" ]]; then
  echo "FAIL: Missing source stylesheet: ${MEREKA_SOURCE_CSS#$REPO_ROOT/}" >&2
  exit 1
fi

if [[ "$BUDGET_BYTES" -lt 1 ]]; then
  echo "FAIL: Invalid BUDGET_BYTES=$BUDGET_BYTES" >&2
  exit 1
fi

PARTIALS_DIR="$(dirname "$MEREKA_SOURCE_CSS")/scss"

# Collect all files to measure: manifest + any partials in mfe/scss/.
mapfile -d '' scss_files < <(
  printf '%s\0' "$MEREKA_SOURCE_CSS"
  if [[ -d "$PARTIALS_DIR" ]]; then
    find "$PARTIALS_DIR" -maxdepth 1 -name "*.scss" -print0 | sort -z
  fi
)

gz_size="$(cat "${scss_files[@]}" | gzip -c | wc -c | tr -d ' ')"
file_count="${#scss_files[@]}"
echo "Mereka CSS source: ${MEREKA_SOURCE_CSS#$REPO_ROOT/} (+ $((file_count - 1)) partials in mfe/scss/)"
echo "Gzipped size: ${gz_size} bytes"
echo "Budget: ${BUDGET_BYTES} bytes"

if [[ "$gz_size" -le "$BUDGET_BYTES" ]]; then
  echo "PASS: CSS branding overhead is within budget"
  exit 0
fi

echo "FAIL: CSS branding overhead exceeds budget by $((gz_size - BUDGET_BYTES)) bytes" >&2
exit 1
