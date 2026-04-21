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

manifest_has_patch_id() {
  local manifest="$1"
  local patch_id="$2"
  python3 - "$manifest" "$patch_id" <<'PY'
import sys
from pathlib import Path

import yaml

manifest = Path(sys.argv[1])
patch_id = sys.argv[2]
data = yaml.safe_load(manifest.read_text(encoding="utf-8")) or {}
for patch in data.get("patches", []):
    if patch.get("id") == patch_id and patch.get("required") is True:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

manifest_active_entries_have_fields() {
  local manifest="$1"
  python3 - "$manifest" <<'PY'
import sys
from pathlib import Path

import yaml

required = {
    "id",
    "module",
    "function",
    "target",
    "target_family",
    "authority_class",
    "description",
    "retirement_trigger",
    "required",
}
manifest = Path(sys.argv[1])
data = yaml.safe_load(manifest.read_text(encoding="utf-8")) or {}
patches = data.get("patches", [])
if not isinstance(patches, list) or not patches:
    raise SystemExit(1)
for index, patch in enumerate(patches):
    if not isinstance(patch, dict):
        raise SystemExit(1)
    missing = sorted(field for field in required if field not in patch or patch[field] in ("", None))
    if missing:
        print(f"patch[{index}] missing fields: {', '.join(missing)}", file=sys.stderr)
        raise SystemExit(1)
raise SystemExit(0)
PY
}

manifest_active_entries_have_retirement_metadata() {
  local manifest="$1"
  python3 - "$manifest" <<'PY'
import sys
from pathlib import Path

import yaml

manifest = Path(sys.argv[1])
data = yaml.safe_load(manifest.read_text(encoding="utf-8")) or {}
for patch in data.get("patches", []):
    if not str(patch.get("authority_class", "")).strip():
        raise SystemExit(1)
    if not str(patch.get("retirement_trigger", "")).strip():
        raise SystemExit(1)
raise SystemExit(0)
PY
}

rendered_docker_compose_has_current_mysql_contract() {
  local docker_compose="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/local/docker-compose.yml"
  [[ -f "$docker_compose" ]] || return 2
  grep -q "mysql-native-password=ON" "$docker_compose" &&
    grep -q 'MYSQL_ROOT_HOST: "%"' "$docker_compose"
}

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
# AC-TCR-003: Current rendered MySQL local contract is verified
# ==============================================================================
echo "--- AC-TCR-003: MySQL Render Contract ---"
MYSQL_ROOT_PATCH="$REPO_ROOT/infrastructure/tutor/patches/mysql-root-host.sh"
ACTIVE_RENDERED_VERIFY="$REPO_ROOT/scripts/infra/verify-tutor-config.sh"
QA_RENDERED_VERIFY_ENTRYPOINT="$REPO_ROOT/scripts/qa/verify-tutor-patches.sh"

check "AC-TCR-003" "Active rendered verifier checks Tutor 21 mysql-native-password=ON" \
  grep -q "mysql-native-password=ON" "$ACTIVE_RENDERED_VERIFY"

check "AC-TCR-003" "Active rendered verifier checks MYSQL_ROOT_HOST local compatibility" \
  grep -q "MYSQL_ROOT_HOST" "$ACTIVE_RENDERED_VERIFY"

check "AC-TCR-003" "QA rendered verifier entrypoint delegates to canonical verifier" \
  grep -q "scripts/infra/verify-tutor-config.sh" "$QA_RENDERED_VERIFY_ENTRYPOINT"

check "AC-TCR-003" "MYSQL_ROOT_HOST compatibility patch module exists" \
  test -f "$MYSQL_ROOT_PATCH"

if rendered_docker_compose_has_current_mysql_contract; then
  echo -e "${GREEN}✓ PASS${NC}: [AC-TCR-003] Rendered docker-compose.yml has current MySQL contract"
  PASS=$((PASS+1))
else
  rc=$?
  if [[ "$rc" -eq 2 ]]; then
    skip "AC-TCR-003" "Rendered docker-compose.yml not present; rendered marker proof runs in Tutor Configuration Tests"
  else
    echo -e "${RED}✗ FAIL${NC}: [AC-TCR-003] Rendered docker-compose.yml missing current MySQL contract"
    FAIL=$((FAIL+1))
  fi
fi
echo ""

# ==============================================================================
# AC-TCR-004: Manifest-driven verification script
# ==============================================================================
echo "--- AC-TCR-004: Patch Manifest & Verification ---"
MANIFEST="$REPO_ROOT/infrastructure/tutor/patch-manifest.yml"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-tutor-patches.sh"
CANONICAL_VERIFY_SCRIPT="$REPO_ROOT/scripts/infra/verify-tutor-config.sh"

if [[ -f "$MANIFEST" ]]; then
  check "AC-TCR-004" "Patch manifest exists at infrastructure/tutor/patch-manifest.yml" \
    test -f "$MANIFEST"

  check "AC-TCR-004" "Patch manifest is valid YAML" \
    python3 -c "import yaml; yaml.safe_load(open('$MANIFEST'))"

  check "AC-TCR-004" "Patch manifest active entries have required authority fields" \
    manifest_active_entries_have_fields "$MANIFEST"

  check "AC-TCR-004" "Patch manifest contains mysql-root-host active patch" \
    manifest_has_patch_id "$MANIFEST" "mysql-root-host"

  check "AC-TCR-004" "Patch manifest contains build-optimizations render-delta patch" \
    manifest_has_patch_id "$MANIFEST" "build-optimizations-render-delta"

  check "AC-TCR-004" "Patch manifest contains MFE npm install resilience patch" \
    manifest_has_patch_id "$MANIFEST" "mfe-npm-install-resilience"
else
  skip "AC-TCR-004" "Patch manifest not yet created (planned implementation)"
  SKIP=$((SKIP+4))
fi

if [[ -f "$VERIFY_SCRIPT" ]]; then
  check "AC-TCR-004" "verify-tutor-patches.sh exists" test -f "$VERIFY_SCRIPT"
  check "AC-TCR-004" "verify-tutor-patches.sh is executable" test -x "$VERIFY_SCRIPT"
  check "AC-TCR-004" "verify-tutor-patches.sh delegates to canonical rendered verifier" \
    grep -q "scripts/infra/verify-tutor-config.sh" "$VERIFY_SCRIPT"
else
  skip "AC-TCR-004" "verify-tutor-patches.sh not yet created (planned implementation)"
  SKIP=$((SKIP+1))
fi

check "AC-TCR-004" "Canonical rendered verifier exists" test -f "$CANONICAL_VERIFY_SCRIPT"
check "AC-TCR-004" "Canonical rendered verifier is executable" test -x "$CANONICAL_VERIFY_SCRIPT"
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
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
check "AC-TCR-006" "CI workflow exists" test -f "$CI_WORKFLOW"

if [[ -f "$CI_WORKFLOW" ]]; then
  check "AC-TCR-006" "Workflow triggers on pull_request" \
    grep -q "pull_request" "$CI_WORKFLOW"

  check "AC-TCR-006" "Workflow triggers on push" \
    grep -q "push" "$CI_WORKFLOW"

  check "AC-TCR-006" "Workflow contains Tutor Configuration Tests lane" \
    grep -q "tutor-config-tests" "$CI_WORKFLOW"

  check "AC-TCR-006" "Workflow executes active rendered patch verifier test" \
    grep -q "tests/tutor/test_verify_patches.sh" "$CI_WORKFLOW"

  check "AC-TCR-006" "Workflow executes Tutor idempotency test" \
    grep -q "tests/tutor/test_idempotency.sh" "$CI_WORKFLOW"
else
  FAIL=$((FAIL+4))
fi
echo ""

# ==============================================================================
# AC-TCR-007: Patch manifest entries carry active authority metadata
# ==============================================================================
echo "--- AC-TCR-007: Manifest Authority Metadata ---"
if [[ -f "$MANIFEST" ]]; then
  check "AC-TCR-007" "All active manifest entries carry required fields" \
    manifest_active_entries_have_fields "$MANIFEST"
else
  skip "AC-TCR-007" "Patch manifest not present"
fi
echo ""

# ==============================================================================
# AC-TCR-008: Verification fails when patches missing
# ==============================================================================
echo "--- AC-TCR-008: Failure Detection ---"
check "AC-TCR-008" "Canonical rendered verifier exists" \
  test -f "$CANONICAL_VERIFY_SCRIPT"

if [[ -f "$CANONICAL_VERIFY_SCRIPT" ]]; then
  check "AC-TCR-008" "Canonical rendered verifier emits explicit failure markers" \
    grep -Eq "check_fail|✗|FAILURES" "$CANONICAL_VERIFY_SCRIPT"

  check "AC-TCR-008" "Canonical rendered verifier checks current MySQL marker" \
    grep -q "mysql-native-password=ON" "$CANONICAL_VERIFY_SCRIPT"

  check "AC-TCR-008" "Canonical rendered verifier exits non-zero on failure" \
    grep -q "exit 1" "$CANONICAL_VERIFY_SCRIPT"
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

check "AC-TCR-009" "CI workflow tests idempotency" \
  grep -q "tests/tutor/test_idempotency.sh" "$CI_WORKFLOW"

check "AC-TCR-009" "Dedicated idempotency test exists" \
  test -f "$REPO_ROOT/tests/tutor/test_idempotency.sh"
echo ""

# ==============================================================================
# AC-TCR-010: Version upgrade detection in CI
# ==============================================================================
echo "--- AC-TCR-010: Version Upgrade Handling ---"
check "AC-TCR-010" "Tutor CI lane blocks patch failures during upgrades" \
  grep -q "test_verify_patches.sh" "$CI_WORKFLOW"

skip "AC-TCR-010" "Per-patch Tutor version upgrade adaptation report remains manual per spec"
echo ""

# ==============================================================================
# AC-TCR-011: Critical patch failures highlighted
# ==============================================================================
echo "--- AC-TCR-011: Authority Class & Retirement Triggers ---"
if [[ -f "$MANIFEST" ]]; then
  check "AC-TCR-011" "Active manifest entries include authority class and retirement trigger" \
    manifest_active_entries_have_retirement_metadata "$MANIFEST"
else
  skip "AC-TCR-011" "Patch manifest not present"
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
    check "AC-TCR-012" "Wrapper calls canonical build-context prep" \
      grep -q "prepare-tutor-build-context" "$CONFIG_SAVE"

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
QUICK_START="$REPO_ROOT/docs/guides/onboarding/QUICK_START_LOCAL.md"
check "Infrastructure" "Documentation references canonical Tutor config wrapper" \
  grep -q "tutor-config-save" "$QUICK_START"

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
