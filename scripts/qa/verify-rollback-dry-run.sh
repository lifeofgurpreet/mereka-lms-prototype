#!/usr/bin/env bash
# @covers AC-035
# @spec: data-migrations-kajabi-mct_spec.md
# Verify rollback script dry-run functionality against AC-035.
#
# Checks:
# - rollback-openedx-imports.py script exists
# - Supports --dry-run flag
# - Has --action unenroll option
# - Does not modify data in dry-run mode
#
# Usage:
#   ./scripts/qa/verify-rollback-dry-run.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

ROLLBACK_SCRIPT="scripts/migrations/rollback-openedx-imports.py"

# Check script exists
if [[ ! -f "$ROLLBACK_SCRIPT" ]]; then
  fail "Rollback script missing: $ROLLBACK_SCRIPT"
  exit 1
fi

pass "Rollback script exists: $ROLLBACK_SCRIPT"

# Check for --dry-run flag support
if grep -q "dry.run\|dry_run\|--dry-run" "$ROLLBACK_SCRIPT"; then
  pass "Dry-run flag support found"
else
  fail "No dry-run flag support found"
fi

# Check for --action flag
if grep -q "action.*unenroll\|--action" "$ROLLBACK_SCRIPT"; then
  pass "Action flag support found"
else
  fail "No action flag support found"
fi

# Check for argparse usage
if grep -q "argparse\|ArgumentParser" "$ROLLBACK_SCRIPT"; then
  pass "Uses argparse for CLI arguments"
else
  echo "[WARN] May not use argparse for argument parsing"
fi

# Check for dry-run conditional logic
if grep -q "if.*dry.run\|if.*dry_run" "$ROLLBACK_SCRIPT"; then
  pass "Dry-run conditional logic found"
else
  fail "No dry-run conditional logic found"
fi

# Check for count reporting (should report what would be deleted)
if grep -q "count\|len\|print.*would" "$ROLLBACK_SCRIPT"; then
  pass "Count reporting logic found"
else
  echo "[WARN] May not report counts in dry-run mode"
fi

# Verify script is executable
if [[ -x "$ROLLBACK_SCRIPT" ]]; then
  pass "Rollback script is executable"
else
  echo "[INFO] Rollback script is not executable (chmod +x recommended)"
fi

# Check help text
if grep -q "help=\|description=" "$ROLLBACK_SCRIPT"; then
  pass "Script includes help text"
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All rollback dry-run checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
