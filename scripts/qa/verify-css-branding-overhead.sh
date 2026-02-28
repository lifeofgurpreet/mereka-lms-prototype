#!/usr/bin/env bash
# @covers AC-PERF-014
# @spec: frontend-performance-budgets_spec.md
# Verify custom Mereka MFE styling overhead budget.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MEREKA_SOURCE_CSS="${MEREKA_SOURCE_CSS:-$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss}"
BUDGET_BYTES="${BUDGET_BYTES:-5120}" # 5 KB gzipped

if [[ ! -f "$MEREKA_SOURCE_CSS" ]]; then
  echo "FAIL: Missing source stylesheet: ${MEREKA_SOURCE_CSS#$REPO_ROOT/}" >&2
  exit 1
fi

if [[ "$BUDGET_BYTES" -lt 1 ]]; then
  echo "FAIL: Invalid BUDGET_BYTES=$BUDGET_BYTES" >&2
  exit 1
fi

gz_size="$(gzip -c "$MEREKA_SOURCE_CSS" | wc -c | tr -d ' ')"
echo "Mereka CSS source: ${MEREKA_SOURCE_CSS#$REPO_ROOT/}"
echo "Gzipped size: ${gz_size} bytes"
echo "Budget: ${BUDGET_BYTES} bytes"

if [[ "$gz_size" -le "$BUDGET_BYTES" ]]; then
  echo "PASS: CSS branding overhead is within budget"
  exit 0
fi

echo "FAIL: CSS branding overhead exceeds budget by $((gz_size - BUDGET_BYTES)) bytes" >&2
exit 1

