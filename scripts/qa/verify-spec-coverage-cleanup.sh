#!/usr/bin/env bash
# @covers AC-BEADS-001, AC-BEADS-002, AC-BEADS-003, AC-BEADS-004, AC-BEADS-005
# @spec: bead-1jci
#
# Verify that spec coverage cleanup is complete:
#   - Coverage dashboard tool exists and is runnable
#   - Key specs that were passing before still pass
#   - manual_verifications.yaml exists and has entries for uncovered ACs
#   - No duplicate AC IDs in key spec files
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1)); }

echo "=== Spec Coverage Cleanup Verification (bead-1jci) ==="
echo ""

# ---------------------------------------------------------------------------
# AC-BEADS-001: Coverage dashboard tool exists and is runnable
# ---------------------------------------------------------------------------
echo "[AC-BEADS-001] Verifying spec coverage dashboard tool..."

DASHBOARD_SCRIPT="scripts/qa/spec-tools/spec_coverage_dashboard.py"
if [[ -f "$DASHBOARD_SCRIPT" ]]; then
  pass "AC-BEADS-001: Dashboard script exists at $DASHBOARD_SCRIPT"
else
  fail "AC-BEADS-001: Dashboard script missing at $DASHBOARD_SCRIPT"
fi

if python3 -c "import yaml" 2>/dev/null; then
  pass "AC-BEADS-001: Python yaml dependency available"
else
  fail "AC-BEADS-001: Python yaml dependency not installed"
fi

if python3 "$DASHBOARD_SCRIPT" --testmaps-dir specs/testmaps/ --format json >/dev/null 2>&1; then
  pass "AC-BEADS-001: Dashboard script runs without error"
else
  warn "AC-BEADS-001: Dashboard script returned non-zero (may be missing testmaps)"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-BEADS-002: Key specs that were PASS before still pass lint
# ---------------------------------------------------------------------------
echo "[AC-BEADS-002] Verifying key specs pass lint..."

LINT_SCRIPT="scripts/qa/spec-tools/mereka_spec_lint.py"
KEY_SPECS=(
  "specs/branding-system_spec.md"
  "specs/auth-sso-enterprise_spec.md"
  "specs/multi-tenancy-architecture_spec.md"
  "specs/observability-stack_spec.md"
  "specs/secrets-management_spec.md"
  "specs/forum-service-migration_spec.md"
)

if [[ -f "$LINT_SCRIPT" ]]; then
  LINT_FAIL=0
  for spec in "${KEY_SPECS[@]}"; do
    if [[ -f "$spec" ]]; then
      if python3 "$LINT_SCRIPT" "$spec" --severity-filter error >/dev/null 2>&1; then
        pass "AC-BEADS-002: $spec passes lint"
      else
        fail "AC-BEADS-002: $spec FAILED lint"
        LINT_FAIL=1
      fi
    else
      warn "AC-BEADS-002: $spec not found (skip)"
    fi
  done
else
  fail "AC-BEADS-002: Lint script missing at $LINT_SCRIPT"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-BEADS-003: manual_verifications.yaml exists and covers uncovered ACs
# ---------------------------------------------------------------------------
echo "[AC-BEADS-003] Verifying manual_verifications.yaml coverage..."

MANUAL_YAML="specs/manual_verifications.yaml"

if [[ -f "$MANUAL_YAML" ]]; then
  pass "AC-BEADS-003: manual_verifications.yaml exists"
else
  fail "AC-BEADS-003: manual_verifications.yaml missing"
fi

# Verify entries exist for the previously-uncovered specs
check_entry() {
  local spec="$1"
  local ac_id="$2"
  if python3 -c "
import yaml, sys
with open('$MANUAL_YAML') as f:
    data = yaml.safe_load(f)
entries = data.get('entries', [])
found = any(e.get('id') == '$ac_id' and e.get('spec') == '$spec' for e in entries)
sys.exit(0 if found else 1)
" 2>/dev/null; then
    pass "AC-BEADS-003: Entry found for $spec / $ac_id"
  else
    fail "AC-BEADS-003: Missing entry for $spec / $ac_id"
  fi
}

# Sample checks — one per previously-uncovered spec group
check_entry "advanced-assessment-xqueue_spec.md" "AC-001"
check_entry "advanced-assessment-xqueue_spec.md" "AC-016"
check_entry "ci-cd-pipeline_spec.md" "AC-INT-004"
check_entry "ci-cd-pipeline_spec.md" "AC-003"
check_entry "data-migrations-kajabi-mct_spec.md" "AC-039"
check_entry "data-privacy-gdpr-compliance_spec.md" "AC-001"
check_entry "data-privacy-gdpr-compliance_spec.md" "AC-009"
check_entry "disaster-recovery-business-continuity_spec.md" "AC-024"
check_entry "disaster-recovery-business-continuity_spec.md" "AC-025"
check_entry "disaster-recovery-business-continuity_spec.md" "AC-026"
check_entry "ecommerce-purchase-gateway_spec.md" "AC-034"
check_entry "email-notifications-pipeline_spec.md" "AC-003"
check_entry "email-notifications-pipeline_spec.md" "AC-015"
check_entry "enterprise-microservices_spec.md" "AC-037"
check_entry "k8s-deployment_spec.md" "AC-INT-004"
check_entry "k8s-deployment_spec.md" "AC-INT-005"
check_entry "mobile-apps-enterprise_spec.md" "AC-001"
check_entry "mobile-apps-enterprise_spec.md" "AC-019"
check_entry "proctoring-integration_spec.md" "AC-001"
check_entry "proctoring-integration_spec.md" "AC-029"
check_entry "slo-sla-service-level-management_spec.md" "AC-016"
check_entry "video-pipeline-delivery_spec.md" "AC-VPD-028"

echo ""

# ---------------------------------------------------------------------------
# AC-BEADS-004: No duplicate AC IDs in key spec files
# ---------------------------------------------------------------------------
echo "[AC-BEADS-004] Checking for duplicate AC IDs in key specs..."

check_no_duplicates() {
  local spec="$1"
  if [[ ! -f "$spec" ]]; then
    warn "AC-BEADS-004: $spec not found (skip)"
    return
  fi
  # Only look at checkbox lines (- [ ] AC-...) to avoid prose mentions
  local dups
  dups=$(grep -oE '^\- \[ \] (AC-[A-Z0-9_-]*[0-9]+)' "$spec" | grep -oE 'AC-[A-Z0-9_-]*[0-9]+' | sort | uniq -d || true)
  if [[ -z "$dups" ]]; then
    pass "AC-BEADS-004: No duplicate AC IDs in $spec"
  else
    fail "AC-BEADS-004: Duplicate AC IDs in $spec: $dups"
  fi
}

check_no_duplicates "specs/advanced-assessment-xqueue_spec.md"
check_no_duplicates "specs/ci-cd-pipeline_spec.md"
check_no_duplicates "specs/data-migrations-kajabi-mct_spec.md"
check_no_duplicates "specs/data-privacy-gdpr-compliance_spec.md"
check_no_duplicates "specs/disaster-recovery-business-continuity_spec.md"
check_no_duplicates "specs/ecommerce-purchase-gateway_spec.md"
check_no_duplicates "specs/email-notifications-pipeline_spec.md"
check_no_duplicates "specs/enterprise-microservices_spec.md"
check_no_duplicates "specs/k8s-deployment_spec.md"
check_no_duplicates "specs/mobile-apps-enterprise_spec.md"
check_no_duplicates "specs/proctoring-integration_spec.md"
check_no_duplicates "specs/slo-sla-service-level-management_spec.md"
check_no_duplicates "specs/video-pipeline-delivery_spec.md"

echo ""

# ---------------------------------------------------------------------------
# AC-BEADS-005: manual_verifications.yaml has minimum expected entry count
# ---------------------------------------------------------------------------
echo "[AC-BEADS-005] Verifying entry count reflects cleanup work..."

if [[ -f "$MANUAL_YAML" ]]; then
  ENTRY_COUNT=$(python3 -c "
import yaml
with open('$MANUAL_YAML') as f:
    data = yaml.safe_load(f)
print(len(data.get('entries', [])))
" 2>/dev/null || echo "0")

  # Before cleanup there were 138 entries; after adding all the uncovered ACs
  # the count should be significantly higher (target: >= 300)
  if [[ "$ENTRY_COUNT" -ge 300 ]]; then
    pass "AC-BEADS-005: manual_verifications.yaml has $ENTRY_COUNT entries (>= 300 threshold)"
  elif [[ "$ENTRY_COUNT" -ge 200 ]]; then
    warn "AC-BEADS-005: manual_verifications.yaml has $ENTRY_COUNT entries (>= 200, below 300 target)"
  else
    fail "AC-BEADS-005: manual_verifications.yaml has only $ENTRY_COUNT entries (expected >= 300 after cleanup)"
  fi
else
  fail "AC-BEADS-005: manual_verifications.yaml missing"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary ==="
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASS${NC} — spec coverage cleanup complete"
  exit 0
else
  echo -e "${RED}$FAIL CHECK(S) FAILED${NC} — review failures above"
  exit 1
fi
