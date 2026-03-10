#!/usr/bin/env bash
# @covers AC-ADGATE-001, AC-ADGATE-002, AC-ADGATE-003
# @spec: analytics-pipeline_spec.md
# Verify analytics decision gate contract compliance.
#
# This script verifies that the analytics deployment deferral decision is
# properly documented, tracked, and not stale. It ensures:
# - Decision gate document exists and is complete
# - ADR-017 status matches current deployment state
# - All 5 revisit conditions are documented
# - Decision review date is within 90 days (warns if stale)
# - Aspects infrastructure exists but is NOT deployed
#
# Usage:
#   ./scripts/qa/verify-analytics-decision-gate.sh
#
# Exit codes:
#   0 = all checks pass (warnings don't fail)
#   1 = one or more checks failed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== Analytics Decision Gate Verification ==="
echo ""

# --- 1. Decision gate document exists ---
echo "--- Decision Gate Document ---"
DECISION_GATE="docs/policies/architecture/ANALYTICS_DECISION_GATE.md"
if [[ -f "$DECISION_GATE" ]]; then
  do_pass "Decision gate document exists: $DECISION_GATE"
else
  do_fail "Decision gate document missing: $DECISION_GATE"
fi

# --- 2. ADR-017 exists ---
echo ""
echo "--- ADR-017: Analytics Target Decision ---"
ADR="docs/programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md"
if [[ ! -f "$ADR" ]]; then
  do_fail "ADR-017 missing: $ADR"
else
  do_pass "ADR-017 exists: $ADR"

  # --- 3. ADR status is Deferred or Accepted ---
  status_line=$(grep -i '^**Status' "$ADR" || grep -i '^Status:' "$ADR" || true)
  if [[ -z "$status_line" ]]; then
    do_fail "ADR-017 missing status line"
  elif [[ "$status_line" =~ Deferred ]] || [[ "$status_line" =~ Accepted ]]; then
    do_pass "ADR-017 status valid: $status_line"
  else
    do_fail "ADR-017 status invalid (expected Deferred or Accepted): $status_line"
  fi

  # --- 4. ADR has "Last verified" comment ---
  last_verified=$(grep -i 'Last verified:' "$ADR" || true)
  if [[ -z "$last_verified" ]]; then
    do_warn "ADR-017 missing 'Last verified' comment (add: <!-- Last verified: YYYY-MM-DD -->)"
  else
    do_pass "ADR-017 has 'Last verified' comment"

    # --- 5. Extract date and check if stale (>90 days) ---
    verified_date=$(echo "$last_verified" | grep -oP '\d{4}-\d{2}-\d{2}' || true)
    if [[ -n "$verified_date" ]]; then
      # Convert date to epoch seconds (portable way)
      if date --version >/dev/null 2>&1; then
        # GNU date
        verified_epoch=$(date -d "$verified_date" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
      else
        # BSD/macOS date
        verified_epoch=$(date -j -f "%Y-%m-%d" "$verified_date" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
      fi

      if [[ "$verified_epoch" -gt 0 ]]; then
        age_days=$(( (now_epoch - verified_epoch) / 86400 ))
        if [[ "$age_days" -gt 90 ]]; then
          do_warn "ADR-017 last verified $age_days days ago (>90 days stale) - recommend review"
        else
          do_pass "ADR-017 last verified $age_days days ago (within 90-day threshold)"
        fi
      else
        do_warn "Could not parse verified date: $verified_date"
      fi
    fi
  fi
fi

# --- 6. Decision matrix table present in decision gate ---
echo ""
echo "--- Decision Gate Content ---"
if [[ -f "$DECISION_GATE" ]]; then
  if grep -q '| # | Condition | Status | Evidence |' "$DECISION_GATE"; then
    do_pass "Decision matrix table present"
  else
    do_fail "Decision matrix table missing from decision gate"
  fi

  # --- 7. All 5 revisit conditions documented ---
  condition_count=$(grep -c '^| [1-5] |' "$DECISION_GATE" || echo 0)
  if [[ "$condition_count" -ge 5 ]]; then
    do_pass "All 5 revisit conditions documented (found $condition_count rows)"
  else
    do_fail "Decision matrix incomplete (expected 5 conditions, found $condition_count)"
  fi

  # --- 8. Next review date present ---
  if grep -qi 'Next Review' "$DECISION_GATE"; then
    do_pass "Next review date documented"
  else
    do_warn "Next review date missing (add to frontmatter)"
  fi
fi

# --- 9. Aspects NOT deployed to production ---
echo ""
echo "--- Aspects Deployment Status ---"
# Check if kubectl is available and cluster is accessible
if command -v kubectl >/dev/null 2>&1; then
  if kubectl cluster-info >/dev/null 2>&1; then
    # Check for aspects pods in production namespace
    # Capture output to variable first to avoid SIGPIPE with grep -c
    pod_list=$(kubectl get pods -n mereka-lms 2>/dev/null || echo "")
    aspects_pods=$(echo "$pod_list" | grep -c 'aspects\|clickhouse\|superset\|ralph' || echo 0)
    aspects_pods=$(echo "$aspects_pods" | tr -d '\n' | tr -d ' ')
    # Determine ADR status
    adr_pod_accepted=0
    if [[ -f "$ADR" ]]; then
      if grep -qi "Accepted" "$ADR"; then
        adr_pod_accepted=1
      fi
    fi
    if [[ "$aspects_pods" -eq 0 ]]; then
      if [[ "$adr_pod_accepted" -eq 1 ]]; then
        do_warn "No Aspects pods deployed yet (ADR-017 Accepted — deployment pending)"
      else
        do_pass "No Aspects pods deployed in production (expected state for deferral)"
      fi
    else
      if [[ "$adr_pod_accepted" -eq 1 ]]; then
        do_pass "Found $aspects_pods Aspects-related pods (ADR-017 Accepted — deployment active)"
      else
        do_fail "Found $aspects_pods Aspects-related pods in production (should be 0 if deferred)"
      fi
    fi
  else
    do_warn "kubectl configured but cluster not accessible (skip deployment check)"
  fi
else
  do_warn "kubectl not available (skip deployment check)"
fi

# --- 10. K8s manifests exist ---
echo ""
echo "--- K8s Manifests (Infrastructure Readiness) ---"
ASPECTS_DIR="deploy/k8s/base/plugins/aspects"
if [[ -d "$ASPECTS_DIR" ]]; then
  manifest_count=$(find "$ASPECTS_DIR" -name '*.yml' -o -name '*.yaml' | wc -l | tr -d ' ')
  if [[ "$manifest_count" -gt 0 ]]; then
    do_pass "Aspects K8s manifests exist ($manifest_count files in $ASPECTS_DIR/)"
  else
    do_warn "Aspects directory exists but no YAML manifests found"
  fi

  # --- 11. Manifests in active kustomization match ADR status ---
  kustomize_file="deploy/k8s/overlays/production/kustomization.yaml"
  if [[ -f "$kustomize_file" ]]; then
    # Determine ADR status to validate expected kustomization state
    adr_is_accepted=0
    if [[ -f "$ADR" ]]; then
      adr_check=$(grep -i '^**Status' "$ADR" || true)
      if echo "$adr_check" | grep -qi "Accepted"; then
        adr_is_accepted=1
      fi
    fi
    kustomize_content=$(cat "$kustomize_file")
    if echo "$kustomize_content" | grep -q 'plugins/aspects'; then
      if [[ "$adr_is_accepted" -eq 1 ]]; then
        do_pass "Aspects in production kustomization (correct — ADR-017 Accepted)"
      else
        do_fail "Aspects referenced in production kustomization (should NOT be active if deferred)"
      fi
    else
      if [[ "$adr_is_accepted" -eq 1 ]]; then
        do_fail "Aspects NOT in production kustomization (ADR-017 Accepted — should be wired)"
      else
        do_pass "Aspects NOT in production kustomization (correct for deferred state)"
      fi
    fi
  else
    do_warn "Production kustomization file not found (skip active deployment check)"
  fi
else
  do_warn "Aspects K8s manifests directory missing: $ASPECTS_DIR/"
fi

# --- 12. Analytics spec exists ---
echo ""
echo "--- Analytics Spec ---"
SPEC="specs/analytics-pipeline_spec.md"
if [[ -f "$SPEC" ]]; then
  do_pass "Analytics spec exists: $SPEC"

  # Check spec status (should be "in_progress" or "approved")
  spec_status=$(grep '^status:' "$SPEC" | awk '{print $2}' | tr -d '"' || true)
  if [[ -n "$spec_status" ]]; then
    do_pass "Analytics spec status: $spec_status"
  else
    do_warn "Analytics spec missing status field"
  fi
else
  do_fail "Analytics spec missing: $SPEC"
fi

# --- 13. Documentation exists ---
echo ""
echo "--- Documentation ---"
analytics_docs=(
  "docs/concepts/analytics/README.md"
  "docs/concepts/analytics/CURRENT_ANALYTICS_STATE.md"
  "docs/concepts/analytics/ASPECTS_TARGET_STATE.md"
)
for doc in "${analytics_docs[@]}"; do
  if [[ -f "$doc" ]]; then
    do_pass "Documentation exists: $doc"
  else
    do_warn "Documentation missing: $doc"
  fi
done

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  WARN: $WARN"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ All analytics decision gate checks passed"
  if [[ $WARN -gt 0 ]]; then
    echo "⚠️  $WARN warning(s) - review recommended but not blocking"
  fi
  exit 0
else
  echo "❌ $FAIL check(s) failed"
  exit 1
fi
