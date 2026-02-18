#!/usr/bin/env bash
# @covers AC-SPEC-201, AC-SPEC-202, AC-SPEC-203
# @spec: bead-23ry
# Verification script for bead 23ry.1: spec AC-ID repair audit
# Checks that top-tier specs have AC IDs, lint passes, and gap/evidence reports exist.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass_check() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

echo "=== AC-SPEC-201: Top-tier spec AC ID and lint checks ==="
echo ""

# ── Lint checks ────────────────────────────────────────────────────────────────

LINT_TOOL="scripts/qa/spec-tools/mereka_spec_lint.py"

for SPEC in \
  specs/ci-cd-pipeline_spec.md \
  specs/k8s-deployment_spec.md \
  specs/ecommerce-purchase-gateway_spec.md \
  specs/analytics-pipeline_spec.md
do
  SPEC_BASENAME="$(basename "$SPEC")"
  if [[ ! -f "$SPEC" ]]; then
    fail_check "Spec file missing: $SPEC"
  else
    LINT_OUT="$(python3 "$LINT_TOOL" "$SPEC" --severity-filter error 2>&1 || true)"
    if echo "$LINT_OUT" | grep -q "^PASS"; then
      pass_check "Lint (error-level) passes: $SPEC_BASENAME"
    else
      fail_check "Lint (error-level) failed for $SPEC_BASENAME: $LINT_OUT"
    fi
  fi
done

echo ""

# ── AC ID presence checks ──────────────────────────────────────────────────────

for SPEC in \
  specs/ci-cd-pipeline_spec.md \
  specs/k8s-deployment_spec.md \
  specs/ecommerce-purchase-gateway_spec.md \
  specs/analytics-pipeline_spec.md
do
  SPEC_BASENAME="$(basename "$SPEC")"
  if [[ -f "$SPEC" ]]; then
    content="$(tr -d '\r' < "$SPEC")"
    AC_COUNT=$(echo "$content" | grep -c '^\- \[ \] AC-' || true)
    if [[ "$AC_COUNT" -gt 0 ]]; then
      pass_check "$SPEC_BASENAME has $AC_COUNT AC IDs in checkbox format"
    else
      fail_check "$SPEC_BASENAME: no AC IDs found in checkbox format (- [ ] AC-)"
    fi
  fi
done

echo ""

# ── Minimum AC count checks ────────────────────────────────────────────────────

CICD_SPEC="specs/ci-cd-pipeline_spec.md"
if [[ -f "$CICD_SPEC" ]]; then
  content="$(tr -d '\r' < "$CICD_SPEC")"
  AC_COUNT=$(echo "$content" | grep -c '^\- \[ \] AC-' || true)
  if [[ "$AC_COUNT" -ge 40 ]]; then
    pass_check "ci-cd-pipeline_spec.md has $AC_COUNT AC IDs (>= 40 required)"
  else
    fail_check "ci-cd-pipeline_spec.md has only $AC_COUNT AC IDs (>= 40 required)"
  fi
fi

K8S_SPEC="specs/k8s-deployment_spec.md"
if [[ -f "$K8S_SPEC" ]]; then
  content="$(tr -d '\r' < "$K8S_SPEC")"
  AC_COUNT=$(echo "$content" | grep -c '^\- \[ \] AC-' || true)
  if [[ "$AC_COUNT" -ge 35 ]]; then
    pass_check "k8s-deployment_spec.md has $AC_COUNT AC IDs (>= 35 required)"
  else
    fail_check "k8s-deployment_spec.md has only $AC_COUNT AC IDs (>= 35 required)"
  fi
fi

ECO_SPEC="specs/ecommerce-purchase-gateway_spec.md"
if [[ -f "$ECO_SPEC" ]]; then
  content="$(tr -d '\r' < "$ECO_SPEC")"
  AC_COUNT=$(echo "$content" | grep -c '^\- \[ \] AC-' || true)
  if [[ "$AC_COUNT" -ge 33 ]]; then
    pass_check "ecommerce-purchase-gateway_spec.md has $AC_COUNT AC IDs (>= 33 required)"
  else
    fail_check "ecommerce-purchase-gateway_spec.md has only $AC_COUNT AC IDs (>= 33 required)"
  fi
fi

ANALYTICS_SPEC="specs/analytics-pipeline_spec.md"
if [[ -f "$ANALYTICS_SPEC" ]]; then
  content="$(tr -d '\r' < "$ANALYTICS_SPEC")"
  AC_COUNT=$(echo "$content" | grep -c '^\- \[ \] AC-' || true)
  if [[ "$AC_COUNT" -ge 8 ]]; then
    pass_check "analytics-pipeline_spec.md has $AC_COUNT AC IDs (>= 8 required)"
  else
    fail_check "analytics-pipeline_spec.md has only $AC_COUNT AC IDs (>= 8 required)"
  fi
fi

echo ""
echo "=== AC-SPEC-202: Coverage dashboard and evidence report checks ==="
echo ""

# ── Coverage dashboard exists and is runnable ──────────────────────────────────

DASHBOARD_TOOL="scripts/qa/spec-tools/spec_coverage_dashboard.py"
if [[ -f "$DASHBOARD_TOOL" ]]; then
  pass_check "Coverage dashboard script exists: $DASHBOARD_TOOL"
else
  fail_check "Coverage dashboard script missing: $DASHBOARD_TOOL"
fi

if [[ -f "$DASHBOARD_TOOL" ]]; then
  DASHBOARD_OUT="$(python3 "$DASHBOARD_TOOL" --testmaps-dir specs/testmaps --specs-dir specs 2>&1 || true)"
  if echo "$DASHBOARD_OUT" | grep -q "Overall coverage:"; then
    pass_check "Coverage dashboard runs successfully"
  else
    fail_check "Coverage dashboard failed to produce output"
  fi

  # Extract overall coverage percentage
  COVERAGE_LINE="$(echo "$DASHBOARD_OUT" | grep 'Overall coverage:' || true)"
  COVERAGE_PCT="$(echo "$COVERAGE_LINE" | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
  if [[ -n "$COVERAGE_PCT" ]]; then
    # Compare as integer (strip decimal)
    COV_INT="${COVERAGE_PCT%%.*}"
    if [[ "$COV_INT" -ge 80 ]]; then
      pass_check "Overall coverage is ${COVERAGE_PCT}% (>= 80% required)"
    else
      fail_check "Overall coverage is ${COVERAGE_PCT}% (< 80% threshold)"
    fi
  else
    warn_check "Could not parse overall coverage percentage from dashboard output"
  fi
fi

# ── Evidence report exists ─────────────────────────────────────────────────────

EVIDENCE_REPORT="docs/operations/evidence/spec-ac-id-repair-report.md"
if [[ -f "$EVIDENCE_REPORT" ]]; then
  pass_check "Evidence report exists: $EVIDENCE_REPORT"
else
  fail_check "Evidence report missing: $EVIDENCE_REPORT"
fi

echo ""
echo "=== AC-SPEC-203: Gap report checks ==="
echo ""

# ── Gap report exists ──────────────────────────────────────────────────────────

GAP_REPORT="docs/qa/SPEC_AC_GAP_REPORT.md"
if [[ -f "$GAP_REPORT" ]]; then
  pass_check "Gap report exists: $GAP_REPORT"
else
  fail_check "Gap report missing: $GAP_REPORT"
fi

if [[ -f "$GAP_REPORT" ]]; then
  gap_content="$(tr -d '\r' < "$GAP_REPORT")"

  # Check report lists residual unmapped ACs by spec
  if echo "$gap_content" | grep -q 'Unmapped'; then
    pass_check "Gap report contains unmapped AC information"
  else
    fail_check "Gap report does not contain unmapped AC information"
  fi

  # Check priority/domain column is present
  if echo "$gap_content" | grep -qiE 'Priority|Domain|P1|P2|P3'; then
    pass_check "Gap report includes priority/domain column"
  else
    fail_check "Gap report missing priority/domain column"
  fi
fi

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
echo -e "${GREEN}All checks passed.${NC}"
exit 0
