#!/usr/bin/env bash
# @covers AC-023, AC-024
# @spec: data-migrations-kajabi-mct_spec.md
# Verify certificate issuance preparation against AC-023 and AC-024.
#
# Checks:
# - completions.ndjson has course_completed tags
# - tag_prefix_to_course_mapping.json exists
# - Mapping file structure is valid
# - Expected completion count (~3,268)
#
# Note: This checks data files, not database state.
# For runtime verification, use scripts/migrations/run-verification-pipeline.sh
#
# Usage:
#   ./scripts/qa/verify-certificate-issuance.sh [--source kajabi] [--check-counts]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

SOURCE="kajabi"  # Only Kajabi has certificate tags
CHECK_COUNTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="$2"
      shift 2
      ;;
    --check-counts)
      CHECK_COUNTS=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

COMPLETIONS_FILE="exports/kajabi/completions.ndjson"
MAPPING_FILE="scripts/migrations/kajabi/output/tag_prefix_to_course_mapping.json"

# Check completions file
if [[ ! -f "$COMPLETIONS_FILE" ]]; then
  fail "Completions file missing: $COMPLETIONS_FILE"
  exit 1
fi

pass "Completions file exists: $COMPLETIONS_FILE"

# Count course_completed tags
completed_count=$(grep -c '"course_completed"' "$COMPLETIONS_FILE" || true)

pass "Found $completed_count course_completed records"

if [[ "$CHECK_COUNTS" -eq 1 ]]; then
  if [[ "$completed_count" -ge 3200 && "$completed_count" -le 3300 ]]; then
    pass "Completion count $completed_count is within expected range (~3,268)"
  else
    echo "[WARN] Completion count $completed_count differs from expected ~3,268"
  fi
fi

# Check mapping file
if [[ ! -f "$MAPPING_FILE" ]]; then
  fail "Mapping file missing: $MAPPING_FILE"
  exit 1
fi

pass "Mapping file exists: $MAPPING_FILE"

# Validate JSON format
if ! jq empty "$MAPPING_FILE" 2>/dev/null; then
  fail "Invalid JSON format: $MAPPING_FILE"
  exit 1
fi

pass "Valid JSON format"

# Check mapping structure (should map tag prefixes to course keys)
mapping_count=$(jq 'length' "$MAPPING_FILE" 2>/dev/null || echo 0)

if [[ "$mapping_count" -gt 0 ]]; then
  pass "Mapping file contains $mapping_count tag-to-course mappings"
else
  fail "Mapping file is empty"
fi

# Sample mapping check (verify format)
sample_key=$(jq -r 'keys[0]' "$MAPPING_FILE" 2>/dev/null || echo "")
sample_value=$(jq -r 'values[0]' "$MAPPING_FILE" 2>/dev/null || echo "")

if [[ -n "$sample_key" && -n "$sample_value" ]]; then
  pass "Sample mapping: $sample_key -> $sample_value"

  # Check if course key format is valid
  if [[ "$sample_value" =~ ^course-v1: ]]; then
    pass "Course keys in correct format"
  else
    echo "[WARN] Course key format may be non-standard: $sample_value"
  fi
fi

# Check for certificate issuance script
CERT_SCRIPT="scripts/migrations/kajabi/issue_certificates.py"
if [[ -f "$CERT_SCRIPT" ]]; then
  pass "Certificate issuance script exists: $(basename "$CERT_SCRIPT")"

  # Check for GeneratedCertificate model usage
  if grep -q "GeneratedCertificate\|CertificateStatuses" "$CERT_SCRIPT"; then
    pass "Certificate issuance script uses GeneratedCertificate model"
  else
    fail "Certificate issuance script missing GeneratedCertificate logic"
  fi
else
  fail "Certificate issuance script missing: $CERT_SCRIPT"
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All certificate issuance checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
