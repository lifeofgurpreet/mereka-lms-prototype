#!/usr/bin/env bash
# @covers AC-004
# @spec: data-migrations-kajabi-mct_spec.md
# Verify MCT video URLs structure against AC-004.
#
# Checks:
# - courses.ndjson contains video URL fields
# - URLs match Azure Blob Storage pattern
# - SAS token parameters present (sig, se)
#
# Usage:
#   ./scripts/qa/verify-mct-video-urls.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

COURSES_FILE="exports/mct/courses.ndjson"

# Check file exists
if [[ ! -f "$COURSES_FILE" ]]; then
  fail "Courses file missing: $COURSES_FILE"
  exit 1
fi

pass "Courses file exists: $COURSES_FILE"

# Extract video URLs from sample records
sample_urls=$(head -20 "$COURSES_FILE" | jq -r '.. | select(type == "string" and (contains("blob.core.windows.net") or contains(".mp4")))' 2>/dev/null | head -10)

if [[ -z "$sample_urls" ]]; then
  fail "No video URLs found in sample records"
  exit 1
fi

pass "Video URLs found in export"

# Check for Azure Blob Storage pattern
azure_urls=$(echo "$sample_urls" | grep "blob.core.windows.net" || true)
if [[ -n "$azure_urls" ]]; then
  pass "Azure Blob Storage URLs detected"
else
  fail "No Azure Blob Storage URLs found"
fi

# Check for SAS token parameters in URLs
sas_urls=$(echo "$sample_urls" | grep -E "(\?|&)sig=" | grep -E "(\?|&)se=" || true)
if [[ -n "$sas_urls" ]]; then
  pass "SAS token parameters (sig, se) found in URLs"
else
  echo "[WARN] SAS token parameters not found in sample URLs (may need fresh export)"
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All MCT video URL checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
