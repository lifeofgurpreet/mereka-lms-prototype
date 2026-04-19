#!/usr/bin/env bash
# @covers AC-DEP-001, AC-DEP-002, AC-DEP-003, AC-DEP-004
# @spec: k8s-deployment_spec.md
#
# verify-staging-activation.sh — Verify the live dev/staging lane contract.
#
# Staging is an active runtime lane on the shared RKE2 nonprod cluster.
# Production remains on GKE, but that lane is intentionally parked and is
# verified separately via scripts/qa/verify-prod-parked-state.sh.
#
# Modes:
#   --offline  Check source manifests only (no cluster access). Default.
#   --online   Live cluster checks via kubectl (requires cluster access and --context).
#   --context  kubectl context to use for online checks (default: rke2-nonprod)
#
# Usage:
#   ./scripts/qa/verify-staging-activation.sh --offline
#   ./scripts/qa/verify-staging-activation.sh --online --context rke2-nonprod
#   ./scripts/qa/verify-staging-activation.sh --offline --online --context rke2-nonprod

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"
POLICY_FILE="${REPO_ROOT}/config/runtime-proof-policy.env"

if [[ -f "$POLICY_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$POLICY_FILE"
fi

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
KUBECONTEXT="${KUBECONTEXT:-${K8S_CONTEXT_STAGING:-${K8S_CONTEXT_NONPROD:-rke2-nonprod}}}"
NS="${NS:-stg-mereka-lms}"
DEV_NS="${DEV_NS:-mereka-lms-dev}"
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
echo "Staging Lane Truth Verifier"
echo "  offline=${MODE_OFFLINE}  online=${MODE_ONLINE}  context=${KUBECONTEXT}  staging-ns=${NS}  dev-ns=${DEV_NS}"
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
  # NOTE (Wave 9 prep, bead mereka-lms-2xwo item 4): the app-repo staging and
  # production overlays are DEPRECATED shadow artifacts per ADR-025, pending
  # deletion. Authoritative overlays live in
  # bbi-infrastructure/apps/mereka-lms/overlays/{staging,prod}/.
  # Assertions below are absence-tolerant: they skip (not fail) if the
  # directory has been deleted, so this verifier stays green after Wave 9
  # ships. While the overlay still exists, we assert the DEPRECATED marker
  # is present to prevent drift.
  STAGING_OVERLAY="$REPO_ROOT/deploy/k8s/overlays/staging"
  if [[ -d "$STAGING_OVERLAY" ]]; then
    pass_check "staging overlay directory exists: deploy/k8s/overlays/staging/ (pending Wave 9 deletion)"

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

      # The app-repo staging overlay is a historical producer-side artifact.
      # Live staging is realized from bbi-infrastructure/apps/mereka-lms/overlays/staging.
      if grep -q 'DEPRECATED' "$STAGING_OVERLAY/kustomization.yaml" 2>/dev/null; then
        pass_check "staging/kustomization.yaml is explicitly marked as a non-authoritative historical overlay"
      else
        fail_check "staging/kustomization.yaml should stay marked DEPRECATED to prevent app-repo overlay drift"
      fi
    else
      fail_check "staging kustomization.yaml missing (directory exists but kustomization.yaml is gone)"
    fi
  else
    # Wave 9 has shipped — overlay correctly deleted. Authoritative source is bbi-infra.
    skip_check "staging overlay directory absent (Wave 9 deletion complete): deploy/k8s/overlays/staging/ — bbi-infra is authoritative"
  fi

  # Check production overlay (historical release-tooling target until Wave 9
  # retargeting lands; absence-tolerant post-deletion).
  PROD_OVERLAY="$REPO_ROOT/deploy/k8s/overlays/production"
  if [[ -d "$PROD_OVERLAY" ]]; then
    pass_check "production overlay directory exists: deploy/k8s/overlays/production/ (pending Wave 9 deletion)"

    if [[ -f "$PROD_OVERLAY/kustomization.yaml" ]]; then
      pass_check "production kustomization.yaml present"

      # Verify no latest tags in production overlay
      if grep -q "newTag: latest" "$PROD_OVERLAY/kustomization.yaml" 2>/dev/null; then
        fail_check "production kustomization.yaml contains 'latest' tag — use pinned SHA tags only"
      else
        pass_check "production kustomization.yaml: no 'latest' image tags"
      fi
    else
      fail_check "production kustomization.yaml missing (directory exists but kustomization.yaml is gone)"
    fi
  else
    # Wave 9 has shipped — overlay correctly deleted.
    skip_check "production overlay directory absent (Wave 9 deletion complete): deploy/k8s/overlays/production/ — bbi-infra is authoritative"
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

    # Dedicated live Argo resources in bbi-infrastructure
    DEV_APPSET_MANIFEST="$BBI_INFRA/argocd/applicationsets/mereka-lms-dev.yaml"
    STAGING_APP_MANIFEST="$BBI_INFRA/argocd/applications/mereka-lms-staging.yaml"
    PROD_APP_MANIFEST="$BBI_INFRA/argocd/applications/mereka-lms-prod.yaml"
    STAGING_BOOTSTRAP_OVERLAY="$BBI_INFRA/bootstrap/applicationsets/overlays/staging/kustomization.yaml"

    if [[ -f "$DEV_APPSET_MANIFEST" ]]; then
      pass_check "ArgoCD ApplicationSet manifest exists: argocd/applicationsets/mereka-lms-dev.yaml"
      if grep -q "apps/mereka-lms/overlays/profiles/dev" "$DEV_APPSET_MANIFEST" 2>/dev/null; then
        pass_check "dev ArgoCD appset source path: apps/mereka-lms/overlays/profiles/dev"
      else
        fail_check "dev ArgoCD appset source path does not reference overlays/profiles/dev"
      fi
      if grep -q "namespace: mereka-lms-dev" "$DEV_APPSET_MANIFEST" 2>/dev/null; then
        pass_check "dev ArgoCD appset destination namespace: mereka-lms-dev"
      else
        fail_check "dev ArgoCD appset destination namespace is not mereka-lms-dev"
      fi
    else
      fail_check "dev ArgoCD ApplicationSet manifest missing: ${DEV_APPSET_MANIFEST}"
    fi

    if [[ -f "$STAGING_APP_MANIFEST" ]]; then
      pass_check "ArgoCD Application manifest exists: argocd/applications/mereka-lms-staging.yaml"
      if grep -q "apps/mereka-lms/overlays/staging" "$STAGING_APP_MANIFEST" 2>/dev/null; then
        pass_check "staging ArgoCD app source path: apps/mereka-lms/overlays/staging"
      else
        fail_check "staging ArgoCD app source path does not reference overlays/staging"
      fi
      if grep -q "namespace: stg-mereka-lms" "$STAGING_APP_MANIFEST" 2>/dev/null; then
        pass_check "staging ArgoCD app destination namespace: stg-mereka-lms"
      else
        fail_check "staging ArgoCD app destination namespace is not stg-mereka-lms"
      fi
    else
      fail_check "staging ArgoCD Application manifest missing: ${STAGING_APP_MANIFEST}"
    fi

    if [[ -f "$STAGING_BOOTSTRAP_OVERLAY" ]]; then
      pass_check "staging bootstrap overlay exists: bootstrap/applicationsets/overlays/staging/kustomization.yaml"
      if grep -q "argocd/applications/mereka-lms-staging.yaml" "$STAGING_BOOTSTRAP_OVERLAY" 2>/dev/null; then
        pass_check "staging bootstrap overlay includes mereka-lms-staging application"
      else
        fail_check "staging bootstrap overlay does not include argocd/applications/mereka-lms-staging.yaml"
      fi
    else
      fail_check "staging bootstrap overlay missing: ${STAGING_BOOTSTRAP_OVERLAY}"
    fi

    # Production ArgoCD Application definition (parked lane on GKE)
    if [[ -f "$PROD_APP_MANIFEST" ]]; then
      pass_check "ArgoCD Application manifest exists: argocd/applications/mereka-lms-prod.yaml"

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

  STAGING_ACTIVATION_DOC="$REPO_ROOT/docs/ops/runbooks/STAGING_ACTIVATION.md"
  if [[ -f "$STAGING_ACTIVATION_DOC" ]]; then
    pass_check "staging activation runbook exists: docs/ops/runbooks/STAGING_ACTIVATION.md"
  else
    fail_check "staging activation runbook missing: docs/ops/runbooks/STAGING_ACTIVATION.md"
  fi

  RELEASE_CHECKLIST="$REPO_ROOT/docs/ops/runbooks/RELEASE_CHECKLIST.md"
  if [[ -f "$RELEASE_CHECKLIST" ]]; then
    pass_check "release checklist exists: docs/ops/runbooks/RELEASE_CHECKLIST.md"
  else
    skip_check "release checklist missing: docs/ops/runbooks/RELEASE_CHECKLIST.md"
  fi

  TROUBLESHOOTING_DOC="$REPO_ROOT/docs/ops/runbooks/TROUBLESHOOTING.md"
  if [[ -f "$TROUBLESHOOTING_DOC" ]]; then
    pass_check "troubleshooting runbook exists: docs/ops/runbooks/TROUBLESHOOTING.md"
  else
    fail_check "troubleshooting runbook missing: docs/ops/runbooks/TROUBLESHOOTING.md"
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

    check_live_app() {
      local app_name="$1"
      local label="$2"
      local expected_ns="$3"
      local app_json

      app_json=$(KC get application "$app_name" -n "$ARGOCD_NS" -o json 2>/dev/null || echo "")
      if [[ -z "$app_json" ]]; then
        fail_check "[live] ArgoCD Application '${app_name}' not found in ${ARGOCD_NS}"
        return
      fi

      pass_check "[live] ArgoCD Application '${app_name}' found"

      local sync_status health_status live_ns
      sync_status=$(echo "$app_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('sync',{}).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
      health_status=$(echo "$app_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('health',{}).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
      live_ns=$(echo "$app_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('spec',{}).get('destination',{}).get('namespace','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

      if [[ "$sync_status" == "Synced" ]]; then
        pass_check "[live] ${label} sync status: Synced"
      else
        fail_check "[live] ${label} sync status: ${sync_status}"
      fi

      if [[ "$health_status" == "Healthy" ]]; then
        pass_check "[live] ${label} health status: Healthy"
      else
        fail_check "[live] ${label} health status: ${health_status}"
      fi

      if [[ "$live_ns" == "$expected_ns" ]]; then
        pass_check "[live] ${label} destination namespace: ${expected_ns}"
      else
        fail_check "[live] ${label} destination namespace ${live_ns} != ${expected_ns}"
      fi
    }

    # ── 2a. Dev ArgoCD Application ──────────────────────────────────────────
    echo "  -- Dev ArgoCD Application --"
    check_live_app "mereka-lms-dev" "dev" "$DEV_NS"

    # ── 2b. Staging ArgoCD Application ──────────────────────────────────────
    echo ""
    echo "  -- Staging ArgoCD Application --"
    check_live_app "mereka-lms-staging" "staging" "$NS"

    # ── 2c. Core workload readiness in staging namespace ────────────────────
    echo ""
    echo "  -- Core workload readiness (staging namespace) --"
    CORE_WORKLOADS=("lms" "cms" "caddy")
    for workload in "${CORE_WORKLOADS[@]}"; do
      READY=$(KC get deployment "$workload" -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "")
      DESIRED=$(KC get deployment "$workload" -n "$NS" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
      if [[ -z "$READY" ]]; then
        fail_check "[live] deployment ${workload} not found in namespace ${NS}"
      elif [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
        pass_check "[live] deployment ${workload}: ${READY}/${DESIRED} replicas ready"
      else
        fail_check "[live] deployment ${workload}: ${READY:-0}/${DESIRED:-?} replicas ready"
      fi
    done

    # ── 2d. Check for CrashLoopBackOff in staging ───────────────────────────
    echo ""
    echo "  -- CrashLoopBackOff check (staging namespace) --"
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

    # ── 2f. Production lane contract note ───────────────────────────────────
    echo ""
    echo "  -- Production lane contract --"
    skip_check "[live] Production runtime is intentionally parked on GKE; verify it separately with ${PROD_PARKED_VERIFIER:-scripts/qa/verify-prod-parked-state.sh}"
  fi

  echo ""
fi

# =============================================================================
# S3: Lane integrity summary
# =============================================================================
if [[ "$MODE_OFFLINE" == true ]]; then
  echo "S3: Lane Integrity Summary"
  echo ""

  check_prereq() {
    local description="$1"
    local check_result="$2"  # "pass", "fail", or "skip"
    case "$check_result" in
      pass) pass_check "LANE OK: ${description}" ;;
      skip) skip_check "LANE NOTE: ${description}" ;;
      fail) fail_check "LANE MISSING: ${description}" ;;
    esac
  }

  if [[ -d "$REPO_ROOT/deploy/k8s/overlays/staging" ]]; then
    check_prereq "app-repo historical staging overlay remains present and non-authoritative" "pass"
  else
    check_prereq "mereka-lms staging overlay exists (deploy/k8s/overlays/staging/)" "fail"
  fi

  if [[ -n "$BBI_INFRA" && -d "$BBI_INFRA/apps/mereka-lms/overlays/staging" ]]; then
    check_prereq "bbi-infrastructure staging overlay exists" "pass"
  else
    check_prereq "bbi-infrastructure staging overlay exists (apps/mereka-lms/overlays/staging/)" "fail"
  fi

  if [[ -n "$BBI_INFRA" && -f "$BBI_INFRA/argocd/applicationsets/mereka-lms-dev.yaml" ]]; then
    check_prereq "dev lane is realized by argocd/applicationsets/mereka-lms-dev.yaml" "pass"
  else
    check_prereq "dev lane ApplicationSet manifest exists" "fail"
  fi

  if [[ -n "$BBI_INFRA" && -f "$BBI_INFRA/argocd/applications/mereka-lms-staging.yaml" ]]; then
    check_prereq "staging lane is realized by argocd/applications/mereka-lms-staging.yaml" "pass"
  else
    check_prereq "staging lane Application manifest exists" "fail"
  fi

  if [[ -f "$REPO_ROOT/docs/ops/runbooks/STAGING_ACTIVATION.md" ]]; then
    check_prereq "staging lane runbook exists" "pass"
  else
    check_prereq "staging lane runbook exists (docs/ops/runbooks/STAGING_ACTIVATION.md)" "fail"
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
  echo "  S1 (app repo):   Check deploy/k8s/overlays/staging/ stays explicitly non-authoritative"
  echo "  S1 (gitops):     Check bbi-infrastructure argocd/applications{,ets}/mereka-lms-{dev,staging,prod}.yaml"
  echo "  S1 (bootstrap):  Check bootstrap/applicationsets/overlays/staging/kustomization.yaml"
  echo "  S1 (docs):       See docs/ops/runbooks/STAGING_ACTIVATION.md for the live lane contract"
  echo "  S2 (live):       Run with --online against rke2-nonprod after fixing offline failures"
  echo ""
  echo "See docs/ops/runbooks/STAGING_ACTIVATION.md for the live dev/staging lane contract."
  exit 1
fi

if [[ "$SKIP" -gt 0 && "$PASS" -gt 0 ]]; then
  echo ""
  echo "Note: SKIP items document adjacent lanes that are intentionally verified elsewhere."
  echo "Use docs/ops/runbooks/STAGING_ACTIVATION.md for the live dev/staging lane contract."
fi

exit 0
