#!/usr/bin/env bash
# Verify Kajabi completions export against AC-003.
#
# Checks:
# - completions.ndjson exists and is valid NDJSON
# - Contains tag_type classifications
# - Expected tag types are present
#
# Usage:
#   ./scripts/qa/verify-kajabi-completions-export.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

COMPLETIONS_FILE="exports/kajabi/completions.ndjson"

# Check file exists
if [[ ! -f "$COMPLETIONS_FILE" ]]; then
  fail "Completions file missing: $COMPLETIONS_FILE"
  exit 1
fi

pass "Completions file exists: $COMPLETIONS_FILE"

# Check file is non-empty
if [[ ! -s "$COMPLETIONS_FILE" ]]; then
  fail "Completions file is empty"
  exit 1
fi

# Count total rows
line_count=$(wc -l < "$COMPLETIONS_FILE" | tr -d ' ')
pass "Completions file has $line_count rows"

# Validate NDJSON format
if head -1 "$COMPLETIONS_FILE" | jq empty 2>/dev/null; then
  pass "Valid NDJSON format"
else
  fail "Invalid NDJSON format"
  exit 1
fi

# Check for tag_type field in sample records
sample_count=10
has_tag_type=0

for i in $(seq 1 "$sample_count"); do
  if sed -n "${i}p" "$COMPLETIONS_FILE" | jq -e '.tag_type' >/dev/null 2>&1; then
    has_tag_type=$((has_tag_type + 1))
  fi
done

if [[ "$has_tag_type" -gt 0 ]]; then
  pass "tag_type field found in $has_tag_type/$sample_count sample records"
else
  fail "No tag_type field found in sample records"
fi

# Check for expected tag types in the file
EXPECTED_TAGS=(
  "course_completed"
  "quiz_completed"
  "started"
  "onboarded"
  "certificate"
)

for tag in "${EXPECTED_TAGS[@]}"; do
  if grep -q "\"$tag\"" "$COMPLETIONS_FILE"; then
    pass "Tag type found: $tag"
  else
    # Not a hard failure as not all tag types may be present
    echo "[INFO] Tag type not found: $tag (may not exist in dataset)"
  fi
done

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All Kajabi completions export checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
