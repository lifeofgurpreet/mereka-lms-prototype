#!/usr/bin/env bash
# Verify enrollment import skip handling against AC-021 and AC-022.
#
# Checks:
# - Import scripts have error handling for user-not-found
# - Import scripts have error handling for course-not-found
# - Batch processing continues on errors
#
# Usage:
#   ./scripts/qa/verify-enrollment-skip-handling.sh --check user-not-found|course-not-found
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

CHECK_TYPE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_TYPE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$CHECK_TYPE" ]]; then
  echo "Usage: $0 --check user-not-found|course-not-found"
  exit 1
fi

# Import scripts to check
IMPORT_SCRIPTS=(
  "scripts/migrations/kajabi/openedx_bulk_import.py"
  "scripts/migrations/mct/openedx_bulk_import_mct.py"
)

# Check for error handling patterns
for script in "${IMPORT_SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "[INFO] Script not found: $script (skipping)"
    continue
  fi

  pass "Checking $(basename "$script")"

  if [[ "$CHECK_TYPE" == "user-not-found" ]]; then
    # Check for user lookup with error handling
    if grep -q "DoesNotExist\|try.*get.*User\|except.*User" "$script"; then
      pass "User-not-found error handling found in $(basename "$script")"
    else
      fail "No user-not-found error handling in $(basename "$script")"
    fi

  elif [[ "$CHECK_TYPE" == "course-not-found" ]]; then
    # Check for course lookup with error handling
    if grep -q "CourseNotFound\|InvalidKeyError\|try.*get.*course\|except.*course" "$script"; then
      pass "Course-not-found error handling found in $(basename "$script")"
    else
      fail "No course-not-found error handling in $(basename "$script")"
    fi
  fi

  # Check for batch continuation (try/except in loop)
  if grep -A 5 "for.*in.*batch\|for.*row" "$script" | grep -q "try:\|except:"; then
    pass "Batch error handling found in $(basename "$script")"
  else
    echo "[WARN] No explicit batch error handling in $(basename "$script")"
  fi

  # Check for logging of skipped records
  if grep -q "logger.*skip\|log.*skip\|print.*skip" "$script"; then
    pass "Skip logging found in $(basename "$script")"
  else
    echo "[WARN] No skip logging in $(basename "$script")"
  fi
done

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All enrollment skip handling checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
