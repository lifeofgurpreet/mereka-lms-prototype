#!/usr/bin/env bash
# @covers AC-DEP-001, AC-DEP-002, AC-DEP-003, AC-DEP-004
# @spec: k8s-deployment_spec.md
#
# verify-staging-activation.sh — Verify the nonprod → staging → production promotion path.
#
# This script documents and verifies the staging activation prerequisites.
# Staging is NOT yet a live environment; it is a formalized promotion lane
# that sits between rke2-nonprod (RKE2 on VPS) and production (GKE).
#
# Modes:
#   --offline  Check source manifests only (no cluster access). Default.
#   --online   Live cluster checks via kubectl (requires cluster access and --context).
#   --context  kubectl context to use for online checks (default: gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster)
#
# Usage:
#   ./scripts/qa/verify-staging-activation.sh --offline
#   ./scripts/qa/verify-staging-activation.sh --online --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
#   ./scripts/qa/verify-staging-activation.sh --offline --online --context rke2-nonprod

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass_check() { echo -e "  ${GREEN}PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "  ${RED}FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
skip_check() { echo -e "  ${YELLOW}SKIP${NC}: $1"; SKIP=$((SKIP + 1)); }

# ── Argument parsing ──────────────────────────────────────────────────────────
MODE_OFFLINE=false
MODE_ONLINE=false
KUBECONTEXT="${KUBECONTEXT:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}}"
NS="${NS:-mereka-lms}"
ARGOCD_NS="${ARGOCD_NS:-argocd}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline)  MODE_OFFLINE=true; shift ;;
    --online)   MODE_ONLINE=true;  shift ;;
    --context)  KUBECONTEXT="$2";  shift 2 ;;
    --help|-h)
      grep '^# ' "$0" | head -20 | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Default to offline if neither specified
if [[ "$MODE_OFFLINE" == false && "$MODE_ONLINE" == false ]]; then
  MODE_OFFLINE=true
fi

KC() { kubectl --context "$KUBECONTEXT" "$@"; }

echo "========================================================"
echo "Staging Activation Path Verifier"
echo "  offline=${MODE_OFFLINE}  online=${MODE_ONLINE}  context=${KUBECONTEXT}  ns=${NS}"
echo "========================================================"
echo ""

# ── Locate bbi-infrastructure repo ───────────────────────────────────────────
BBI_INFRA=""
for candidate in \
  "${BBI_INFRA_PATH:-}" \
  "${WORKSPACE_ROOT}/bbi-infrastructure" \
  "${WORKSPACE_ROOT}/infrastructure" \
  "${HOME}/projects/k8s/bbi-infrastructure" \
  "${HOME}/projects/k8s/infrastructure"; do
  if [[ -n "$candidate" && -d "$candidate" ]]; then
    BBI_INFRA="$candidate"
    break
  fi
done

# =============================================================================
# S1: Source manifest checks (offline)
# =============================================================================
if [[ "$MODE_OFFLINE" == true ]]; then
  echo "S1: Source Manifest Checks (Offline)"
  echo ""

  # ── 1a. mereka-lms repo: staging overlay ─────────────────────────────────
  STAGING_OVERLAY="$REPO_ROOT/deploy/k8s/overlays/staging"
  if [[ -d "$STAGING_OVERLAY" ]]; then
    pass_check "staging overlay directory exists: deploy/k8s/overlays/staging/"
  else
    fail_check "staging overlay directory missing: deploy/k8s/overlays/staging/"
  fi

  if [[ -f "$STAGING_OVERLAY/kustomization.yaml" ]]; then
    pass_check "staging kustomization.yaml present"

    # Verify it has image overrides (not pinned to deprecated latest tags)
    if grep -q "newTag:" "$STAGING_OVERLAY/kustomization.yaml" 2>/dev/null; then
      pass_check "staging kustomization.yaml defines image tag overrides"
    else
      fail_check "staging kustomization.yaml has no image tag overrides (images unpinned)"
    fi

    # Verify it extends base
    if grep -q '../../base' "$STAGING_OVERLAY/kustomization.yaml" 2>/dev/null; then
      pass_check "staging overlay references ../../base"
    else
      fail_check "staging overlay does not reference ../../base"
    fi

    # Check it is NOT still marked deprecated-only
    if grep -q 'DEPRECATED' "$STAGING_OVERLAY/kustomization.yaml" 2>/dev/null; then
      skip_check "staging/kustomization.yaml has DEPRECATED comment — staging not yet activated (expected until staging is formalized)"
    else
      pass_check "staging overlay is not marked deprecated"
    fi
  else
    fail_check "staging kustomization.yaml missing"
  fi

  # Check production overlay exists (required for promotion target)
  PROD_OVERLAY="$REPO_ROOT/deploy/k8s/overlays/production"
  if [[ -d "$PROD_OVERLAY" ]]; then
    pass_check "production overlay directory exists: deploy/k8s/overlays/production/"
  else
    fail_check "production overlay directory missing: deploy/k8s/overlays/production/"
  fi

  if [[ -f "$PROD_OVERLAY/kustomization.yaml" ]]; then
    pass_check "production kustomization.yaml present"
  else
    fail_check "production kustomization.yaml missing"
  fi

  # Verify no latest tags in production overlay
  if grep -q "newTag: latest" "$PROD_OVERLAY/kustomization.yaml" 2>/dev/null; then
    fail_check "production kustomization.yaml contains 'latest' tag — use pinned SHA tags only"
  else
    pass_check "production kustomization.yaml: no 'latest' image tags"
  fi

  echo ""

  # ── 1b. bbi-infrastructure repo: staging ArgoCD definitions ──────────────
  echo "  -- bbi-infrastructure checks --"
  if [[ -z "$BBI_INFRA" ]]; then
    skip_check "bbi-infrastructure repo not found — skipping GitOps overlay checks (set BBI_INFRA_PATH env var)"
  else
    pass_check "bbi-infrastructure repo found at: ${BBI_INFRA}"

    # Staging overlay in bbi-infrastructure
    BBI_STAGING_OVERLAY="$BBI_INFRA/apps/mereka-lms/overlays/staging"
    if [[ -d "$BBI_STAGING_OVERLAY" ]]; then
      pass_check "bbi-infrastructure: staging overlay exists (apps/mereka-lms/overlays/staging/)"
    else
      skip_check "bbi-infrastructure: staging overlay not yet created (apps/mereka-lms/overlays/staging/) — required for activation"
    fi

    if [[ -f "$BBI_STAGING_OVERLAY/kustomization.yaml" ]]; then
      pass_check "bbi-infrastructure: staging kustomization.yaml present"

      # Verify staging overlay references bbi-infra base
      if grep -q '../../base' "$BBI_STAGING_OVERLAY/kustomization.yaml" 2>/dev/null; then
        pass_check "bbi-infrastructure: staging overlay references ../../base"
      else
        fail_check "bbi-infrastructure: staging overlay does not reference ../../base"
      fi

      # Verify staging has ingress patch (different domain from prod)
      if grep -qi 'ingress' "$BBI_STAGING_OVERLAY/kustomization.yaml" 2>/dev/null; then
        pass_check "bbi-infrastructure: staging overlay includes ingress configuration"
      else
        skip_check "bbi-infrastructure: staging overlay has no ingress config (required for staging domain routing)"
      fi
    else
      skip_check "bbi-infrastructure: staging kustomization.yaml not present (required for ArgoCD activation)"
    fi

    # Production ArgoCD Application definition
    PROD_APP_MANIFEST="$BBI_INFRA/applicationsets/mereka-lms-prod.yaml"
    if [[ -f "$PROD_APP_MANIFEST" ]]; then
      pass_check "ArgoCD Application manifest exists: applicationsets/mereka-lms-prod.yaml"

      # Verify prod source path
      if grep -q "apps/mereka-lms/overlays/prod" "$PROD_APP_MANIFEST" 2>/dev/null; then
        pass_check "production ArgoCD app source path: apps/mereka-lms/overlays/prod"
      else
        fail_check "production ArgoCD app source path does not reference overlays/prod"
      fi

      # Verify automated sync policy
      if grep -q "automated:" "$PROD_APP_MANIFEST" 2>/dev/null; then
        pass_check "production ArgoCD app has automated sync policy"
      else
        fail_check "production ArgoCD app is missing automated sync policy"
      fi

      # Verify prune and selfHeal
      if grep -q "prune: true" "$PROD_APP_MANIFEST" 2>/dev/null; then
        pass_check "production ArgoCD app: prune: true"
      else
        fail_check "production ArgoCD app: prune not set to true"
      fi

      if grep -q "selfHeal: true" "$PROD_APP_MANIFEST" 2>/dev/null; then
        pass_check "production ArgoCD app: selfHeal: true"
      else
        fail_check "production ArgoCD app: selfHeal not set to true"
      fi
    else
      fail_check "production ArgoCD Application manifest missing: ${PROD_APP_MANIFEST}"
    fi

    # ApplicationSet with staging entry (mereka-lms staging not yet activated)
    APPSET_MANIFEST="$BBI_INFRA/applicationsets/kustomize-apps.yaml"
    if [[ -f "$APPSET_MANIFEST" ]]; then
      pass_check "ApplicationSet manifest exists: applicationsets/kustomize-apps.yaml"

      if grep -q "app: mereka-lms" "$APPSET_MANIFEST" 2>/dev/null; then
        pass_check "ApplicationSet includes mereka-lms entry"
      else
        fail_check "ApplicationSet missing mereka-lms entry"
      fi

      # Staging entry may be commented out — that is expected pre-activation
      if grep -q "env: staging" "$APPSET_MANIFEST" 2>/dev/null; then
        pass_check "ApplicationSet: staging environment entry is active"
      elif grep -q "staging" "$APPSET_MANIFEST" 2>/dev/null; then
        skip_check "ApplicationSet: staging entry exists but is commented out (uncomment to activate)"
      else
        skip_check "ApplicationSet: no staging entry found — add staging block to activate promotion lane"
      fi

      if grep -q "env: dev" "$APPSET_MANIFEST" 2>/dev/null; then
        pass_check "ApplicationSet: dev/nonprod environment entry is active"
      else
        fail_check "ApplicationSet: dev/nonprod environment entry missing"
      fi
    else
      fail_check "ApplicationSet manifest missing: ${APPSET_MANIFEST}"
    fi

    # Verify prod overlay in bbi-infrastructure
    BBI_PROD_OVERLAY="$BBI_INFRA/apps/mereka-lms/overlays/prod"
    if [[ -d "$BBI_PROD_OVERLAY" ]]; then
      pass_check "bbi-infrastructure: production overlay exists (apps/mereka-lms/overlays/prod/)"
    else
      fail_check "bbi-infrastructure: production overlay missing (apps/mereka-lms/overlays/prod/)"
    fi
  fi

  echo ""

  # ── 1c. Image tag hygiene (promotion readiness) ───────────────────────────
  echo "  -- Image tag hygiene --"

  # Verify production overlay has no 'latest' tags
  for overlay_dir in "$REPO_ROOT/deploy/k8s/overlays/production" "$REPO_ROOT/deploy/k8s/overlays/staging"; do
    overlay_name=$(basename "$overlay_dir")
    if [[ -f "$overlay_dir/kustomization.yaml" ]]; then
      latest_count=$(grep -c "newTag: latest" "$overlay_dir/kustomization.yaml" 2>/dev/null || true)
      if [[ "$latest_count" -eq 0 ]]; then
        pass_check "${overlay_name} overlay: no 'latest' tags (promotion-safe)"
      else
        fail_check "${overlay_name} overlay: ${latest_count} 'latest' tag(s) found — pin images before promotion"
      fi
    fi
  done

  # Check Oscar ecommerce deprecation — ensure staging doesn't reference removed services
  if [[ -f "$REPO_ROOT/deploy/k8s/overlays/staging/kustomization.yaml" ]]; then
    if grep -qi "ecommerce\b" "$REPO_ROOT/deploy/k8s/overlays/staging/kustomization.yaml" 2>/dev/null; then
      skip_check "staging overlay references ecommerce — verify Oscar is intentionally included (deprecated, being replaced by purchase-gateway)"
    else
      pass_check "staging overlay: no Oscar ecommerce reference (deprecated service excluded)"
    fi
  fi

  echo ""

  # ── 1d. Documentation prerequisites ──────────────────────────────────────
  echo "  -- Documentation prerequisites --"

  STAGING_ACTIVATION_DOC="$REPO_ROOT/docs/operations/STAGING_ACTIVATION.md"
  if [[ -f "$STAGING_ACTIVATION_DOC" ]]; then
    pass_check "staging activation runbook exists: docs/operations/STAGING_ACTIVATION.md"
  else
    fail_check "staging activation runbook missing: docs/operations/STAGING_ACTIVATION.md"
  fi

  RELEASE_CHECKLIST="$REPO_ROOT/docs/operations/RELEASE_CHECKLIST.md"
  if [[ -f "$RELEASE_CHECKLIST" ]]; then
    pass_check "release checklist exists: docs/operations/RELEASE_CHECKLIST.md"
  else
    skip_check "release checklist missing: docs/operations/RELEASE_CHECKLIST.md"
  fi

  TROUBLESHOOTING_DOC="$REPO_ROOT/docs/operations/TROUBLESHOOTING.md"
  if [[ -f "$TROUBLESHOOTING_DOC" ]]; then
    pass_check "troubleshooting runbook exists: docs/operations/TROUBLESHOOTING.md"
  else
    fail_check "troubleshooting runbook missing: docs/operations/TROUBLESHOOTING.md"
  fi

  echo ""
fi

# =============================================================================
# S2: Live cluster checks (online)
# =============================================================================
if [[ "$MODE_ONLINE" == true ]]; then
  echo "S2: Live Cluster Checks (Online)"
  echo ""

  if ! command -v kubectl &>/dev/null; then
    fail_check "kubectl not found in PATH — cannot run online checks"
  elif ! KC cluster-info &>/dev/null 2>&1; then
    fail_check "Cannot reach cluster context '${KUBECONTEXT}' — skipping online checks"
    skip_check "[live] All cluster checks skipped (unreachable)"
  else
    pass_check "kubectl reachable: context=${KUBECONTEXT}"

    # ── 2a. Production ArgoCD Application health ────────────────────────────
    echo "  -- Production ArgoCD Application --"
    PROD_APP_JSON=$(KC get application mereka-lms-prod -n "$ARGOCD_NS" -o json 2>/dev/null || echo "")
    if [[ -z "$PROD_APP_JSON" ]]; then
      skip_check "[live] ArgoCD Application 'mereka-lms-prod' not found in ${ARGOCD_NS} — production may not be on this cluster"
    else
      pass_check "[live] ArgoCD Application 'mereka-lms-prod' found"

      sync_status=$(echo "$PROD_APP_JSON" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('sync',{}).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
      health_status=$(echo "$PROD_APP_JSON" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('health',{}).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

      if [[ "$sync_status" == "Synced" ]]; then
        pass_check "[live] production sync status: Synced"
      else
        fail_check "[live] production sync status: ${sync_status} (expected Synced)"
      fi

      if [[ "$health_status" == "Healthy" ]]; then
        pass_check "[live] production health status: Healthy"
      else
        fail_check "[live] production health status: ${health_status} (expected Healthy)"
      fi
    fi

    # ── 2b. Staging ArgoCD Application (not yet active — expect SKIP) ───────
    echo ""
    echo "  -- Staging ArgoCD Application --"
    STAGING_APP_JSON=$(KC get application mereka-lms-staging -n "$ARGOCD_NS" -o json 2>/dev/null || echo "")
    if [[ -z "$STAGING_APP_JSON" ]]; then
      skip_check "[live] ArgoCD Application 'mereka-lms-staging' not found — staging not yet activated (expected)"
    else
      pass_check "[live] ArgoCD Application 'mereka-lms-staging' found — staging is active"

      staging_sync=$(echo "$STAGING_APP_JSON" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('sync',{}).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
      staging_health=$(echo "$STAGING_APP_JSON" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('health',{}).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

      if [[ "$staging_sync" == "Synced" ]]; then
        pass_check "[live] staging sync status: Synced"
      else
        fail_check "[live] staging sync status: ${staging_sync}"
      fi

      if [[ "$staging_health" == "Healthy" ]]; then
        pass_check "[live] staging health status: Healthy"
      else
        fail_check "[live] staging health status: ${staging_health}"
      fi
    fi

    # ── 2c. Core workload readiness in production namespace ─────────────────
    echo ""
    echo "  -- Core workload readiness (production namespace) --"
    CORE_WORKLOADS=("lms" "cms" "caddy")
    for workload in "${CORE_WORKLOADS[@]}"; do
      READY=$(KC get deployment "$workload" -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "")
      DESIRED=$(KC get deployment "$workload" -n "$NS" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
      if [[ -z "$READY" ]]; then
        skip_check "[live] deployment ${workload} not found in namespace ${NS}"
      elif [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
        pass_check "[live] deployment ${workload}: ${READY}/${DESIRED} replicas ready"
      else
        fail_check "[live] deployment ${workload}: ${READY:-0}/${DESIRED:-?} replicas ready"
      fi
    done

    # ── 2d. Check for CrashLoopBackOff in production ────────────────────────
    echo ""
    echo "  -- CrashLoopBackOff check (production namespace) --"
    CRASH_PODS=$(KC get pods -n "$NS" \
      -o jsonpath='{range .items[*]}{.metadata.name}={range .status.containerStatuses[*]}{.state.waiting.reason}{end}{"\n"}{end}' 2>/dev/null \
      | grep 'CrashLoopBackOff' || true)
    if [[ -z "$CRASH_PODS" ]]; then
      pass_check "[live] no CrashLoopBackOff pods in ${NS}"
    else
      CRASH_COUNT=$(echo "$CRASH_PODS" | grep -c . || true)
      fail_check "[live] ${CRASH_COUNT} pod(s) in CrashLoopBackOff in ${NS}:"
      echo "$CRASH_PODS" | head -5 | sed 's/^/    /'
    fi

    # ── 2e. ExternalSecrets sync status ─────────────────────────────────────
    echo ""
    echo "  -- ExternalSecrets sync status --"
    if KC get externalsecret -n "$NS" &>/dev/null 2>&1; then
      NOT_READY=$(KC get externalsecret -n "$NS" \
        -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[0].status}{"\n"}{end}' 2>/dev/null \
        | grep -v '=True' || true)
      if [[ -z "$NOT_READY" ]]; then
        pass_check "[live] all ExternalSecrets in ${NS} are synced"
      else
        while IFS= read -r entry; do
          [[ -z "$entry" ]] && continue
          fail_check "[live] ExternalSecret not ready: ${entry}"
        done <<< "$NOT_READY"
      fi
    else
      skip_check "[live] ExternalSecret CRD not available or no ExternalSecrets in ${NS}"
    fi
  fi

  echo ""
fi

# =============================================================================
# S3: Promotion path prerequisite summary
# =============================================================================
if [[ "$MODE_OFFLINE" == true ]]; then
  echo "S3: Promotion Path Prerequisite Summary"
  echo ""

  PREREQS_MET=true

  # Checklist of conditions required before staging can be activated
  check_prereq() {
    local description="$1"
    local check_result="$2"  # "pass", "fail", or "skip"
    case "$check_result" in
      pass) pass_check "PREREQ OK: ${description}" ;;
      skip) skip_check "PREREQ PENDING: ${description}" ;;
      fail) fail_check "PREREQ MISSING: ${description}"; PREREQS_MET=false ;;
    esac
  }

  # These are evaluated against what we discovered above
  if [[ -d "$REPO_ROOT/deploy/k8s/overlays/staging" ]]; then
    check_prereq "mereka-lms staging overlay exists" "pass"
  else
    check_prereq "mereka-lms staging overlay exists (deploy/k8s/overlays/staging/)" "fail"
  fi

  if [[ -n "$BBI_INFRA" && -d "$BBI_INFRA/apps/mereka-lms/overlays/staging" ]]; then
    check_prereq "bbi-infrastructure staging overlay exists" "pass"
  else
    check_prereq "bbi-infrastructure staging overlay exists (apps/mereka-lms/overlays/staging/)" "skip"
  fi

  if [[ -n "$BBI_INFRA" ]] && grep -q "env: staging" "$BBI_INFRA/applicationsets/kustomize-apps.yaml" 2>/dev/null; then
    check_prereq "ApplicationSet staging entry is uncommented" "pass"
  else
    check_prereq "ApplicationSet staging entry is uncommented in kustomize-apps.yaml" "skip"
  fi

  if [[ -f "$REPO_ROOT/docs/operations/STAGING_ACTIVATION.md" ]]; then
    check_prereq "staging activation runbook exists" "pass"
  else
    check_prereq "staging activation runbook exists (docs/operations/STAGING_ACTIVATION.md)" "fail"
  fi

  echo ""
fi

# =============================================================================
# Summary
# =============================================================================
echo "========================================================"
echo "Summary: ${PASS} PASS / ${FAIL} FAIL / ${SKIP} SKIP"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation hints:"
  echo "  S1 (manifests):  Check deploy/k8s/overlays/staging/ in this repo"
  echo "  S1 (gitops):     Check bbi-infrastructure/apps/mereka-lms/overlays/staging/"
  echo "  S1 (argocd):     Uncomment staging block in bbi-infrastructure/applicationsets/kustomize-apps.yaml"
  echo "  S1 (docs):       See docs/operations/STAGING_ACTIVATION.md for activation steps"
  echo "  S2 (live):       Run with --online after fixing offline failures"
  echo ""
  echo "See docs/operations/STAGING_ACTIVATION.md for the full promotion path."
  exit 1
fi

if [[ "$SKIP" -gt 0 && "$PASS" -gt 0 ]]; then
  echo ""
  echo "Note: SKIP items indicate staging is not yet activated (expected for pre-activation state)."
  echo "Follow docs/operations/STAGING_ACTIVATION.md to complete staging setup."
fi

exit 0
