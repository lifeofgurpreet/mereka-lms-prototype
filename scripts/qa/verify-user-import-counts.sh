#!/usr/bin/env bash
# @covers AC-011, AC-012
# @spec: data-migrations-kajabi-mct_spec.md
# Verify user import CSV files against AC-011 and AC-012.
#
# Checks:
# - Kajabi users.csv has ~73K rows
# - MCT users.csv has ~69K rows
# - CSV format and headers
#
# Note: This only checks the CSV files, not database state.
# For database verification, use scripts/migrations/run-verification-pipeline.sh
#
# Usage:
#   ./scripts/qa/verify-user-import-counts.sh --source kajabi|mct
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

SOURCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$SOURCE" ]]; then
  echo "Usage: $0 --source kajabi|mct"
  exit 1
fi

if [[ "$SOURCE" == "kajabi" ]]; then
  USERS_CSV="scripts/migrations/kajabi/output/users.csv"
  MIN_ROWS=70000
  MAX_ROWS=80000
  EXPECTED="~73K"
elif [[ "$SOURCE" == "mct" ]]; then
  USERS_CSV="exports/mct/users.csv"
  # Fallback to NDJSON if CSV doesn't exist
  if [[ ! -f "$USERS_CSV" ]]; then
    USERS_CSV="exports/mct/users.ndjson"
  fi
  MIN_ROWS=68000
  MAX_ROWS=72000
  EXPECTED="~69K"
else
  fail "Invalid source: $SOURCE (must be kajabi or mct)"
  exit 1
fi

# Check file exists
if [[ ! -f "$USERS_CSV" ]]; then
  fail "Users file missing: $USERS_CSV"
  exit 1
fi

pass "Users file exists: $USERS_CSV"

# Count rows
if [[ "$USERS_CSV" =~ \.csv$ ]]; then
  row_count=$(tail -n +2 "$USERS_CSV" | wc -l | tr -d ' ')
elif [[ "$USERS_CSV" =~ \.ndjson$ ]]; then
  row_count=$(wc -l < "$USERS_CSV" | tr -d ' ')
else
  fail "Unknown file format: $USERS_CSV"
  exit 1
fi

# Check row count
if [[ "$row_count" -lt "$MIN_ROWS" ]]; then
  fail "$SOURCE users: $row_count rows (expected $EXPECTED)"
elif [[ "$row_count" -gt "$MAX_ROWS" ]]; then
  fail "$SOURCE users: $row_count rows (expected $EXPECTED)"
else
  pass "$SOURCE users: $row_count rows (within expected range)"
fi

# Check CSV header
if [[ "$USERS_CSV" =~ \.csv$ ]]; then
  header=$(head -1 "$USERS_CSV")
  if [[ "$header" =~ email ]]; then
    pass "Users CSV has email column"
  else
    fail "Users CSV missing email column"
  fi
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All user import count checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
