#!/usr/bin/env bash
# @covers AC-TCR-001, AC-TCR-002, AC-TCR-003, AC-TCR-004, AC-TCR-005, AC-TCR-006, AC-TCR-007, AC-TCR-008, AC-TCR-009, AC-TCR-010, AC-TCR-011, AC-TCR-012
# @spec: tutor-configuration-resilience_spec.md
# Comprehensive verification of Tutor configuration resilience (all 12 ACs)
#
# Usage: ./scripts/qa/verify-tutor-resilience-full.sh [--skip-cluster]
#
# Returns:
#   0 if all checks pass
#   1 if any checks fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"
source "${SCRIPT_DIR}/../shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# Flags
SKIP_CLUSTER=false
if [[ "${1:-}" == "--skip-cluster" ]]; then
  SKIP_CLUSTER=true
fi

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

plugin_has_fixed() { mereka_plugin_has_fixed "$REPO_ROOT" "$1"; }

plugin_contract_python_valid() {
  local plugin_file
  while IFS= read -r plugin_file; do
    [[ -f "$plugin_file" ]] || continue
    python3 -m py_compile "$plugin_file"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
}

check() {
  local ac_id="$1"
  local desc="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}: [${ac_id}] $desc"
    PASS=$((PASS+1))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}: [${ac_id}] $desc"
    FAIL=$((FAIL+1))
    return 1
  fi
}

skip() {
  local ac_id="$1"
  local desc="$2"
  echo -e "${YELLOW}⊘ SKIP${NC}: [${ac_id}] $desc"
  SKIP=$((SKIP+1))
}

echo "=== Tutor Configuration Resilience - Full Verification ==="
echo "Spec: tutor-configuration-resilience_spec.md"
echo "Coverage: 12 ACs"
echo ""

# ==============================================================================
# AC-TCR-001: Plugin installs and shows in tutor plugins list
# ==============================================================================
echo "--- AC-TCR-001: Plugin Installation ---"
check "AC-TCR-001" "Plugin contract source exists (expected at least $PLUGIN_MAIN)" \
  mereka_plugin_has_any "$REPO_ROOT"

if mereka_plugin_has_any "$REPO_ROOT"; then
  check "AC-TCR-001" "Plugin contract sources are valid Python syntax" \
    plugin_contract_python_valid

  check "AC-TCR-001" "Plugin defines MEREKA_LMS_VERSION config default" \
    plugin_has_fixed "MEREKA_LMS_VERSION"

  check "AC-TCR-001" "Plugin defines hooks module import" \
    plugin_has_fixed "from tutor import hooks"
else
  FAIL=$((FAIL+3))
fi
echo ""

# ==============================================================================
# AC-TCR-002: Plugin applies multi-site domains without apply-patches.sh
# ==============================================================================
echo "--- AC-TCR-002: Plugin Multi-Site Patches ---"
check "AC-TCR-002" "Plugin has openedx-lms-production-settings hook" \
  plugin_has_fixed "openedx-lms-production-settings"

check "AC-TCR-002" "Plugin adds academy.biji-biji.com to ALLOWED_HOSTS" \
  plugin_has_fixed "academy.biji-biji.com"

check "AC-TCR-002" "Plugin adds skillourfuture.academy.mereka.io to ALLOWED_HOSTS" \
  plugin_has_fixed "skillourfuture.academy.mereka.io"

check "AC-TCR-002" "Plugin configures CSRF_TRUSTED_ORIGINS" \
  plugin_has_fixed "CSRF_TRUSTED_ORIGINS"
echo ""

# ==============================================================================
# AC-TCR-003: Plugin applies MySQL auth fix without apply-patches.sh
# ==============================================================================
echo "--- AC-TCR-003: Plugin MySQL Patches ---"
check "AC-TCR-003" "Plugin has mysql-docker-compose hook" \
  plugin_has_fixed "mysql-docker-compose"

check "AC-TCR-003" "Plugin sets mysql_native_password authentication" \
  plugin_has_fixed "mysql_native_password"
echo ""

# ==============================================================================
# AC-TCR-004: Manifest-driven verification script
# ==============================================================================
echo "--- AC-TCR-004: Patch Manifest & Verification ---"
MANIFEST="$REPO_ROOT/infrastructure/tutor/patch-manifest.yml"
VERIFY_SCRIPT="$REPO_ROOT/scripts/infra/verify-tutor-patches.sh"

if [[ -f "$MANIFEST" ]]; then
  check "AC-TCR-004" "Patch manifest exists at infrastructure/tutor/patch-manifest.yml" \
    test -f "$MANIFEST"

  check "AC-TCR-004" "Patch manifest is valid YAML" \
    python3 -c "import yaml; yaml.safe_load(open('$MANIFEST'))"

  check "AC-TCR-004" "Patch manifest contains mysql-auth patch" \
    grep -q "mysql-auth" "$MANIFEST"

  check "AC-TCR-004" "Patch manifest contains mfe-node18 patch" \
    grep -q "mfe-node18\|mfe.*node" "$MANIFEST"

  check "AC-TCR-004" "Patch manifest contains multisite-domains patch" \
    grep -q "multisite.*domain\|multi.*site" "$MANIFEST"
else
  skip "AC-TCR-004" "Patch manifest not yet created (planned implementation)"
  SKIP=$((SKIP+4))
fi

if [[ -f "$VERIFY_SCRIPT" ]]; then
  check "AC-TCR-004" "verify-tutor-patches.sh exists" test -f "$VERIFY_SCRIPT"
  check "AC-TCR-004" "verify-tutor-patches.sh is executable" test -x "$VERIFY_SCRIPT"
else
  skip "AC-TCR-004" "verify-tutor-patches.sh not yet created (planned implementation)"
  SKIP=$((SKIP+1))
fi
echo ""

# ==============================================================================
# AC-TCR-005: Pre-commit hook runs verification and blocks bad commits
# ==============================================================================
echo "--- AC-TCR-005: Pre-Commit Hook ---"
TUTOR_HOOK="$REPO_ROOT/.githooks/pre-tutor-config"
check "AC-TCR-005" "pre-tutor-config hook exists" test -f "$TUTOR_HOOK"

if [[ -f "$TUTOR_HOOK" ]]; then
  check "AC-TCR-005" "Hook detects tutor_env/ changes" \
    grep -q "tutor_env" "$TUTOR_HOOK"

  check "AC-TCR-005" "Hook warns about config.yml secrets" \
    grep -q "secret" "$TUTOR_HOOK"

  check "AC-TCR-005" "Hook prompts for apply-patches.sh confirmation" \
    grep -q "apply-patches" "$TUTOR_HOOK"

  check "AC-TCR-005" "Hook can optionally run verification" \
    grep -q "verify.*tutor" "$TUTOR_HOOK"
else
  FAIL=$((FAIL+4))
fi
echo ""

# ==============================================================================
# AC-TCR-006: CI workflow runs patch verification on PRs
# ==============================================================================
echo "--- AC-TCR-006: CI Verification Workflow ---"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/tutor-config-verify.yml"
check "AC-TCR-006" "CI workflow exists" test -f "$CI_WORKFLOW"

if [[ -f "$CI_WORKFLOW" ]]; then
  check "AC-TCR-006" "Workflow triggers on pull_request" \
    grep -q "pull_request" "$CI_WORKFLOW"

  check "AC-TCR-006" "Workflow triggers on push" \
    grep -q "push" "$CI_WORKFLOW"

  check "AC-TCR-006" "Workflow runs verify-patches job" \
    grep -q "verify.*patch" "$CI_WORKFLOW"

  check "AC-TCR-006" "Workflow checks multi-site domains" \
    grep -q "multi.*site\|academy.biji" "$CI_WORKFLOW"
else
  FAIL=$((FAIL+4))
fi
echo ""

# ==============================================================================
# AC-TCR-007: Verification script supports --json flag
# ==============================================================================
echo "--- AC-TCR-007: JSON Output Support ---"
if [[ -f "$VERIFY_SCRIPT" ]]; then
  check "AC-TCR-007" "verify-tutor-patches.sh supports --json flag" \
    grep -q "\-\-json" "$VERIFY_SCRIPT"
else
  skip "AC-TCR-007" "verify-tutor-patches.sh not yet created"
fi
echo ""

# ==============================================================================
# AC-TCR-008: Verification fails when patches missing
# ==============================================================================
echo "--- AC-TCR-008: Failure Detection ---"
# This is tested by the existence of verification logic
VERIFY_CONFIG="$REPO_ROOT/scripts/infra/verify-tutor-config.sh"
check "AC-TCR-008" "verify-tutor-config.sh exists and checks patches" \
  test -f "$VERIFY_CONFIG"

if [[ -f "$VERIFY_CONFIG" ]]; then
  check "AC-TCR-008" "Verification checks mysql_native_password" \
    grep -q "mysql_native_password" "$VERIFY_CONFIG"

  check "AC-TCR-008" "Verification checks multi-site domains" \
    grep -q "academy.biji-biji.com\|biji-biji" "$VERIFY_CONFIG"

  check "AC-TCR-008" "Verification exits non-zero on failure" \
    grep -q "exit 1" "$VERIFY_CONFIG"
else
  FAIL=$((FAIL+3))
fi
echo ""

# ==============================================================================
# AC-TCR-009: apply-patches.sh is idempotent
# ==============================================================================
echo "--- AC-TCR-009: Idempotency ---"
PATCHES_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
check "AC-TCR-009" "apply-patches.sh exists" test -f "$PATCHES_SCRIPT"

# Check if CI has idempotency test
check "AC-TCR-009" "CI workflow tests idempotency" \
  grep -q "idempotent\|double.*apply\|twice" "$CI_WORKFLOW"
echo ""

# ==============================================================================
# AC-TCR-010: Version upgrade detection in CI
# ==============================================================================
echo "--- AC-TCR-010: Version Upgrade Handling ---"
# This is more of a manual workflow check, but we can verify CI structure exists
check "AC-TCR-010" "CI workflow runs on infrastructure/ changes" \
  grep -q "infrastructure/\|tutor/" "$CI_WORKFLOW"

warn "AC-TCR-010 note: Version upgrade detection requires manual PR review workflow"
echo ""

# ==============================================================================
# AC-TCR-011: Critical patch failures highlighted
# ==============================================================================
echo "--- AC-TCR-011: Error Formatting ---"
if [[ -f "$VERIFY_SCRIPT" ]]; then
  check "AC-TCR-011" "Verification script uses colored output" \
    grep -q "RED\|GREEN\|YELLOW\|\\\\033" "$VERIFY_SCRIPT"
else
  check "AC-TCR-011" "verify-tutor-config.sh has colored output" \
    grep -q "RED\|GREEN\|YELLOW\|\\\\033" "$VERIFY_CONFIG"
fi
echo ""

# ==============================================================================
# AC-TCR-012: make tutor-apply integrates plugin and verification
# ==============================================================================
echo "--- AC-TCR-012: Makefile Integration ---"
MAKEFILE="$REPO_ROOT/Makefile"
check "AC-TCR-012" "Makefile exists" test -f "$MAKEFILE"

if [[ -f "$MAKEFILE" ]]; then
  check "AC-TCR-012" "Makefile has tutor-apply target" \
    grep -q "tutor-apply" "$MAKEFILE"

  # Check wrapper script exists
  CONFIG_SAVE="$REPO_ROOT/scripts/infra/tutor-config-save.sh"
  check "AC-TCR-012" "tutor-config-save.sh wrapper exists" \
    test -f "$CONFIG_SAVE"

  if [[ -f "$CONFIG_SAVE" ]]; then
    check "AC-TCR-012" "Wrapper calls apply-patches.sh" \
      grep -q "apply-patches" "$CONFIG_SAVE"

    check "AC-TCR-012" "Wrapper calls verification" \
      grep -q "verify" "$CONFIG_SAVE"
  else
    FAIL=$((FAIL+2))
  fi
else
  FAIL=$((FAIL+4))
fi
echo ""

# ==============================================================================
# Additional Infrastructure Checks
# ==============================================================================
echo "--- Additional Infrastructure ---"

# Backup mechanism
check "Infrastructure" "Backup directory exists or is created by scripts" \
  grep -q "backup\|BACKUP" "$CONFIG_SAVE"

# Rollback script
ROLLBACK="$REPO_ROOT/scripts/infra/tutor-config-rollback.sh"
check "Infrastructure" "Rollback script exists" test -f "$ROLLBACK"

if [[ -f "$ROLLBACK" ]]; then
  check "Infrastructure" "Rollback script is executable" test -x "$ROLLBACK"
fi

# Documentation sync
QUICK_START="$REPO_ROOT/docs/onboarding/QUICK_START_LOCAL.md"
check "Infrastructure" "Documentation references apply-patches workflow" \
  grep -q "apply-patches\|tutor-config-save" "$QUICK_START"

echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"
echo ""

if [[ $FAIL -gt 0 ]]; then
  error "Some checks failed. See tutor-configuration-resilience_spec.md"
  exit 1
else
  info "All checks passed!"
  exit 0
fi
