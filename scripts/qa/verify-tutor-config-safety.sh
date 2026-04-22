#!/usr/bin/env bash
# @covers AC-TCR-005, AC-TCR-009, AC-TCR-012
# @spec: tutor-configuration-resilience_spec.md
# Verify that Tutor configuration safety mechanisms are in place:
#   - .gitignore blocks tutor_env/config.yml
#   - Pre-commit hook exists and is configured
#   - tutor-config-save.sh creates backups before config save
#   - prepare-tutor-build-context.sh is called after config save
#   - verify-tutor-config.sh validates patches
#
# Usage: ./scripts/qa/verify-tutor-config-safety.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $desc"; PASS=$((PASS+1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL+1))
  fi
}

echo "=== Tutor Config Safety Verification ==="
echo ""

# --- .gitignore blocks tutor_env ---
echo "--- .gitignore ---"
check ".gitignore exists" test -f "$REPO_ROOT/.gitignore"
check ".gitignore ignores tutor_env/" grep -q "^tutor_env/" "$REPO_ROOT/.gitignore"
# Verify git would actually ignore tutor_env/config.yml
check "git ignores tutor_env/config.yml" git -C "$REPO_ROOT" check-ignore -q "tutor_env/config.yml"
echo ""

# --- Pre-commit hook ---
echo "--- Pre-commit hooks ---"
HOOK="$REPO_ROOT/.githooks/pre-commit"
check "pre-commit hook exists" test -f "$HOOK"
check "pre-commit hook is executable" test -x "$HOOK"
check "pre-commit hook detects tutor_env/ changes" grep -q "tutor_env/" "$HOOK"

TUTOR_HOOK="$REPO_ROOT/.githooks/pre-tutor-config"
check "pre-tutor-config hook exists" test -f "$TUTOR_HOOK"
check "pre-tutor-config hook is executable" test -x "$TUTOR_HOOK"
check "pre-tutor-config hook warns about config.yml secrets" grep -q "config.yml" "$TUTOR_HOOK"
check "pre-tutor-config hook prompts for canonical build-context prep" grep -Eq "apply-patches\\.sh|prepare-tutor-build-context\\.sh" "$TUTOR_HOOK"
echo ""

# --- tutor-config-save.sh safety ---
echo "--- tutor-config-save.sh ---"
SAVE_SCRIPT="$REPO_ROOT/scripts/infra/tutor-config-save.sh"
PREP_SCRIPT="$REPO_ROOT/scripts/infra/prepare-tutor-build-context.sh"
check "tutor-config-save.sh exists" test -f "$SAVE_SCRIPT"
check "tutor-config-save.sh is executable" test -x "$SAVE_SCRIPT"
check "tutor-config-save.sh uses set -euo pipefail" grep -q "set -euo pipefail" "$SAVE_SCRIPT"
check "tutor-config-save.sh creates timestamped backup" grep -q "backup.*date" "$SAVE_SCRIPT"
check "prepare-tutor-build-context.sh exists" test -f "$PREP_SCRIPT"
check "prepare-tutor-build-context.sh is executable" test -x "$PREP_SCRIPT"
check "tutor-config-save.sh calls prepare-tutor-build-context.sh" grep -q "prepare-tutor-build-context.sh" "$SAVE_SCRIPT"
check "tutor-config-save.sh calls verify-tutor-config.sh" grep -q "verify-tutor-config" "$SAVE_SCRIPT"
check "tutor-config-save.sh restores backup on failure" grep -q "Restoring backup" "$SAVE_SCRIPT"
echo ""

# --- apply-patches.sh compatibility ---
echo "--- apply-patches.sh ---"
PATCHES_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
check "apply-patches.sh exists" test -f "$PATCHES_SCRIPT"
check "apply-patches.sh is executable" test -x "$PATCHES_SCRIPT"
check "apply-patches.sh supports target-aware compatibility" grep -q -- "--target" "$PATCHES_SCRIPT"
echo ""

# --- verify-tutor-config.sh ---
echo "--- verify-tutor-config.sh ---"
VERIFY_SCRIPT="$REPO_ROOT/scripts/infra/verify-tutor-config.sh"
check "verify-tutor-config.sh exists" test -f "$VERIFY_SCRIPT"
check "verify-tutor-config.sh is executable" test -x "$VERIFY_SCRIPT"
check "verify-tutor-config.sh uses set -euo pipefail" grep -q "set -euo pipefail" "$VERIFY_SCRIPT"
check "verify-tutor-config.sh checks multi-site domains" grep -q "academy.biji-biji.com" "$VERIFY_SCRIPT"
check "verify-tutor-config.sh checks current MySQL native-password flag" grep -q "mysql-native-password=ON" "$VERIFY_SCRIPT"
check "verify-tutor-config.sh checks MFE configuration" grep -q "MFE" "$VERIFY_SCRIPT"
echo ""

# --- Rollback script ---
echo "--- tutor-config-rollback.sh ---"
ROLLBACK_SCRIPT="$REPO_ROOT/scripts/infra/tutor-config-rollback.sh"
check "tutor-config-rollback.sh exists" test -f "$ROLLBACK_SCRIPT"
check "tutor-config-rollback.sh is executable" test -x "$ROLLBACK_SCRIPT"
echo ""

# --- Summary ---
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
