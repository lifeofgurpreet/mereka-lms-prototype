#!/usr/bin/env bash
# @spec: data-migrations-kajabi-mct_spec.md
# @covers AC-034
set -euo pipefail

# verify-migration-rollback.sh - Verify migration rollback procedures exist
#
# AC-034: Given a database backup taken before import, when `tutor local do
#          restore-db` runs, then Open edX reverts to pre-migration state
#
# This script verifies:
# 1. Rollback documentation exists for both Kajabi and MCT migrations
# 2. The rollback script (rollback-openedx-imports.py) exists
# 3. Backup scripts/procedures are documented

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

echo "=== Data Migrations: Rollback Procedures Verification ==="
echo "Spec: data-migrations-kajabi-mct_spec.md | AC-034"
echo

# Check 1: Kajabi rollback documentation exists
echo "--- Kajabi Rollback Documentation ---"
kajabi_rollback="$REPO_ROOT/docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md"
if [[ -f "$kajabi_rollback" ]]; then
  pass "Kajabi rollback doc exists: docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md"

  # Check it mentions database restore
  if grep -qiE "(restore-db|restore|database backup|mysql.*dump)" "$kajabi_rollback"; then
    pass "Kajabi rollback doc references database restore procedure"
  else
    fail "Kajabi rollback doc missing database restore procedure"
  fi
else
  fail "Kajabi rollback doc not found: $kajabi_rollback"
fi

# Check 2: Rollback script exists
echo
echo "--- Rollback Script ---"
rollback_script="$REPO_ROOT/scripts/migrations/rollback-openedx-imports.py"
if [[ -f "$rollback_script" ]]; then
  pass "Rollback script exists: scripts/migrations/rollback-openedx-imports.py"

  # Check it supports --dry-run
  if grep -q "dry.run" "$rollback_script"; then
    pass "Rollback script supports --dry-run flag"
  else
    fail "Rollback script missing --dry-run support"
  fi

  # Check it supports unenroll action
  if grep -q "unenroll" "$rollback_script"; then
    pass "Rollback script supports unenroll action"
  else
    fail "Rollback script missing unenroll action"
  fi
else
  fail "Rollback script not found: $rollback_script"
fi

# Check 3: Spec documents rollback steps
echo
echo "--- Spec Rollback Section ---"
spec_file="$REPO_ROOT/specs/data-migrations-kajabi-mct_spec.md"
if [[ -f "$spec_file" ]]; then
  if grep -qE "Rollback Steps|Rollback Plan|Rollback Procedure" "$spec_file"; then
    pass "Spec contains rollback section"
  else
    fail "Spec missing rollback section"
  fi

  # Check spec mentions database backup
  if grep -qE "restore-db|mysqldump|mongodump|mongorestore" "$spec_file"; then
    pass "Spec references database backup/restore commands"
  else
    fail "Spec missing database backup/restore references"
  fi
else
  fail "Migration spec not found: $spec_file"
fi

# Check 4: Backup tooling exists (scripts or documented procedures)
echo
echo "--- Backup Tooling ---"
backup_found=false

# Check for backup-related scripts
if [[ -f "$REPO_ROOT/scripts/qa/list-critical-backup-pvcs.sh" ]]; then
  pass "Backup PVC listing script exists"
  backup_found=true
fi

if [[ -f "$REPO_ROOT/scripts/qa/collect-velero-evidence.sh" ]]; then
  pass "Velero backup evidence collection script exists"
  backup_found=true
fi

if [[ "$backup_found" == "false" ]]; then
  fail "No backup tooling found in scripts/"
fi

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0
