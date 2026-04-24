#!/usr/bin/env bash
# Verify that visual-regression-test.sh covers at least 18 page entries.
set -euo pipefail

SCRIPT="scripts/qa/visual-regression-test.sh"
MIN_PAGES=18

PAGE_COUNT=$(grep -c '^\s*\["' "$SCRIPT" || echo 0)
echo "Visual regression covers ${PAGE_COUNT} page entries"
if [[ $PAGE_COUNT -lt $MIN_PAGES ]]; then
  echo "ERROR: Expected at least ${MIN_PAGES} page entries, found ${PAGE_COUNT}"
  exit 1
fi
echo "Page count verification passed (${PAGE_COUNT} pages)"
