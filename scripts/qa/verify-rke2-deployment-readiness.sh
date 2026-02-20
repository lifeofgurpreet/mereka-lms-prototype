#!/usr/bin/env bash
# @covers AC-RKE2-101, AC-RKE2-102, AC-RKE2-104
# @spec: k8s-deployment_spec.md
#
# verify-rke2-deployment-readiness.sh
#
# Pre-flight and post-fix verification for rke2-nonprod deployments.
# Detects exactly the 4 blocker categories discovered on 2026-02-19:
#
#   B1: External secret store mismatch (gcp-secret-manager on non-GKE cluster)
#   B2: Missing runtime secret alias keys (secrets referenced but not populated)
#   B3: Missing imagePullSecret on default ServiceAccount
#   B4: Quota saturation preventing mysql/redis/meilisearch scheduling
#
# Modes:
#   --offline     Source-only checks (no kubectl required). Default.
#   --live        Live cluster checks (requires kubectl + KUBECONTEXT)
#   --context X   kubectl context to use (default: rke2-nonprod)
#
# Usage:
#   scripts/qa/verify-rke2-deployment-readiness.sh --offline
#   KUBECONTEXT=rke2-nonprod scripts/qa/verify-rke2-deployment-readiness.sh --live
#   scripts/qa/verify-rke2-deployment-readiness.sh --live --context rke2-nonprod

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
FAIL=0
WARN=0
SKIP=0

pass_check() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo "  WARN: $1"; WARN=$((WARN + 1)); }
skip_check() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Parse args
MODE=offline
KUBECONTEXT="${KUBECONTEXT:-rke2-nonprod}"
NS="${NS:-mereka-lms}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) MODE=offline; shift ;;
    --live)    MODE=live;    shift ;;
    --context) KUBECONTEXT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

KC() { kubectl --context "$KUBECONTEXT" "$@"; }

echo "========================================================"
echo "RKE2 Deployment Readiness Verifier"
echo "  mode=$MODE  context=$KUBECONTEXT  ns=$NS"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# BLOCKER 0: Kubecontext Separation Drift
# Detects nonprod/staging contexts pointing at the same cluster target.
# -----------------------------------------------------------------------
echo "B0: Kubecontext Separation"

if ! command -v kubectl >/dev/null 2>&1; then
  skip_check "kubectl not available; cannot validate kubecontext separation"
elif ! command -v jq >/dev/null 2>&1; then
  skip_check "jq not available; cannot validate kubecontext separation"
else
  CFG_JSON="$(kubectl config view -o json 2>/dev/null || true)"
  if [[ -z "$CFG_JSON" ]]; then
    skip_check "kubectl config unavailable; cannot validate kubecontext separation"
  else
    NP_CLUSTER="$(echo "$CFG_JSON" | jq -r '.contexts[]? | select(.name=="rke2-nonprod") | .context.cluster' | head -1)"
    ST_CLUSTER="$(echo "$CFG_JSON" | jq -r '.contexts[]? | select(.name=="rke2-staging") | .context.cluster' | head -1)"

    if [[ -z "$NP_CLUSTER" || -z "$ST_CLUSTER" ]]; then
      warn_check "Missing one or both contexts (rke2-nonprod/rke2-staging) in kubeconfig"
    else
      NP_SERVER="$(echo "$CFG_JSON" | jq -r --arg c "$NP_CLUSTER" '.clusters[]? | select(.name==$c) | .cluster.server' | head -1)"
      ST_SERVER="$(echo "$CFG_JSON" | jq -r --arg c "$ST_CLUSTER" '.clusters[]? | select(.name==$c) | .cluster.server' | head -1)"

      if [[ "$NP_CLUSTER" == "$ST_CLUSTER" || "$NP_SERVER" == "$ST_SERVER" ]]; then
        fail_check "Context drift: rke2-nonprod and rke2-staging resolve to the same cluster target ($NP_CLUSTER / ${NP_SERVER:-unknown})"
      else
        pass_check "rke2-nonprod and rke2-staging map to distinct cluster targets"
      fi
    fi
  fi
fi

echo ""

# -----------------------------------------------------------------------
# BLOCKER 1: External Secret Store Mismatch
# Checks that rke2-nonprod overlay uses infisical-secret-store, not gcp-secret-manager
# -----------------------------------------------------------------------
echo "B1: External Secret Store Mismatch"

RKE2_OVERLAY="$REPO_ROOT/deploy/k8s/overlays/rke2-nonprod"
BASE_SECRETS="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
INFISICAL_PATCH="$RKE2_OVERLAY/patches/externalsecrets-infisical.yaml"

# Check 1: rke2-nonprod overlay exists
if [[ -d "$RKE2_OVERLAY" ]]; then
  pass_check "rke2-nonprod overlay directory exists"
else
  fail_check "rke2-nonprod overlay missing at deploy/k8s/overlays/rke2-nonprod/"
fi

# Check 2: infisical patch exists
if [[ -f "$INFISICAL_PATCH" ]]; then
  pass_check "externalsecrets-infisical.yaml patch exists"
else
  fail_check "externalsecrets-infisical.yaml patch missing"
fi

# Check 3: patch references infisical-secret-store (not gcp-secret-manager)
if [[ -f "$INFISICAL_PATCH" ]]; then
  # Exclude comment lines (# ...) when counting refs
  INFISICAL_COUNT=$(grep -v '^\s*#' "$INFISICAL_PATCH" | grep -c 'infisical-secret-store' || true)
  GCP_COUNT=$(grep -v '^\s*#' "$INFISICAL_PATCH" | grep -c 'gcp-secret-manager' || true)
  if [[ "$INFISICAL_COUNT" -ge 3 && "$GCP_COUNT" -eq 0 ]]; then
    pass_check "Infisical patch uses infisical-secret-store exclusively ($INFISICAL_COUNT refs, non-comment)"
  else
    fail_check "Infisical patch still references gcp-secret-manager ($GCP_COUNT non-comment refs) or missing infisical-secret-store ($INFISICAL_COUNT refs)"
  fi
fi

# Check 4: kustomization.yaml includes the infisical patch
RKE2_KUST="$RKE2_OVERLAY/kustomization.yaml"
if [[ -f "$RKE2_KUST" ]]; then
  if grep -q 'externalsecrets-infisical' "$RKE2_KUST"; then
    pass_check "kustomization.yaml references externalsecrets-infisical.yaml"
  else
    fail_check "kustomization.yaml does NOT reference externalsecrets-infisical.yaml"
  fi
fi

# Check 5: base still uses gcp-secret-manager (expected — base is for GKE)
if [[ -f "$BASE_SECRETS" ]]; then
  BASE_GCP=$(grep -c 'gcp-secret-manager' "$BASE_SECRETS" || true)
  if [[ "$BASE_GCP" -ge 1 ]]; then
    pass_check "Base ExternalSecrets correctly uses gcp-secret-manager (GKE-only, as expected)"
  else
    warn_check "Base ExternalSecrets does not reference gcp-secret-manager — check base is intact"
  fi
fi

# Live: Check ClusterSecretStore validity on rke2-nonprod
if [[ "$MODE" == "live" ]]; then
  echo "  [live] Checking ClusterSecretStore validity..."

  INFISICAL_READY=$(KC get clustersecretstore infisical-secret-store \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$INFISICAL_READY" == "True" ]]; then
    pass_check "[live] infisical-secret-store ClusterSecretStore is Ready"
  else
    fail_check "[live] infisical-secret-store ClusterSecretStore is NOT Ready (status: ${INFISICAL_READY:-unknown})"
  fi

  GCP_EXISTS=$(KC get clustersecretstore gcp-secret-manager -o name 2>/dev/null || echo "")
  if [[ -z "$GCP_EXISTS" ]]; then
    pass_check "[live] gcp-secret-manager ClusterSecretStore is absent on rke2 (expected)"
  else
    GCP_READY=$(KC get clustersecretstore gcp-secret-manager \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    fail_check "[live] gcp-secret-manager ClusterSecretStore still present on rke2 (Ready=${GCP_READY:-unknown}) — remove from dev overlay"
  fi

  # Check all ExternalSecrets are SecretSynced
  echo "  [live] Checking ExternalSecrets sync status..."
  ES_STATUSES=$(KC get externalsecret -n "$NS" \
    -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Ready")].reason}{"\n"}{end}' 2>/dev/null || echo "")

  if [[ -z "$ES_STATUSES" ]]; then
    fail_check "[live] No ExternalSecrets found in $NS namespace"
  else
    ALL_SYNCED=true
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      ES_NAME="${line%%=*}"
      ES_REASON="${line##*=}"
      if [[ "$ES_REASON" == "SecretSynced" ]]; then
        pass_check "[live] ExternalSecret $ES_NAME: SecretSynced"
      else
        fail_check "[live] ExternalSecret $ES_NAME: ${ES_REASON:-unknown} (expected SecretSynced)"
        ALL_SYNCED=false
      fi
    done <<< "$ES_STATUSES"
  fi
else
  skip_check "[live] ClusterSecretStore validity (requires --live)"
  skip_check "[live] ExternalSecrets sync status (requires --live)"
fi

echo ""

# -----------------------------------------------------------------------
# BLOCKER 2: Missing Runtime Secret Alias Keys
# Checks that ExternalSecret remoteRef.key values are correctly aliased
# (e.g., MEREKA_LMS_* naming convention, no blank keys)
# -----------------------------------------------------------------------
echo "B2: Runtime Secret Alias Key Mapping"

# Check 6: All remoteRef.key values in base use MEREKA_LMS_ prefix
if [[ -f "$BASE_SECRETS" ]]; then
  BLANK_KEYS=$(grep 'key:' "$BASE_SECRETS" | grep -v 'MEREKA_LMS_' | grep -v '#' | grep -v 'conversionStrategy\|decodingStrategy\|metadataPolicy' || true)
  if [[ -z "$BLANK_KEYS" ]]; then
    pass_check "All remoteRef.key values use MEREKA_LMS_ prefix convention"
  else
    fail_check "Some remoteRef.key values do not use MEREKA_LMS_ prefix:"
    echo "    $BLANK_KEYS"
  fi
fi

# Check 7: infisical patch has no empty remoteRef.key values
if [[ -f "$INFISICAL_PATCH" ]]; then
  EMPTY_KEYS=$(grep -E '^\s+key:\s*$' "$INFISICAL_PATCH" || true)
  if [[ -z "$EMPTY_KEYS" ]]; then
    pass_check "No empty remoteRef.key values in infisical patch"
  else
    fail_check "Empty remoteRef.key values found in infisical patch"
  fi
fi

# Check 8: required secret key count matches base
if [[ -f "$BASE_SECRETS" && -f "$INFISICAL_PATCH" ]]; then
  BASE_KEY_COUNT=$(grep -c 'secretKey:' "$BASE_SECRETS" || true)
  PATCH_KEY_COUNT=$(grep -c 'secretKey:' "$INFISICAL_PATCH" || true)
  if [[ "$PATCH_KEY_COUNT" -ge "$BASE_KEY_COUNT" ]]; then
    pass_check "Infisical patch covers all secretKeys from base ($PATCH_KEY_COUNT >= $BASE_KEY_COUNT)"
  else
    warn_check "Infisical patch has fewer secretKeys than base ($PATCH_KEY_COUNT < $BASE_KEY_COUNT) — may be missing entries"
  fi
fi

# Live: Check that K8s secrets are actually populated (not empty)
if [[ "$MODE" == "live" ]]; then
  echo "  [live] Checking K8s secret population..."

  for SECRET_NAME in openedx-secrets database-secrets enterprise-sso-secrets; do
    SECRET_EXISTS=$(KC get secret "$SECRET_NAME" -n "$NS" \
      -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$SECRET_EXISTS" ]]; then
      KEY_COUNT=$(KC get secret "$SECRET_NAME" -n "$NS" \
        -o jsonpath='{.data}' 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
      if [[ "$KEY_COUNT" -gt 0 ]]; then
        pass_check "[live] Secret $SECRET_NAME populated ($KEY_COUNT keys)"
      else
        fail_check "[live] Secret $SECRET_NAME exists but is EMPTY (ExternalSecret may have failed)"
      fi
    else
      fail_check "[live] Secret $SECRET_NAME not found in $NS namespace"
    fi
  done
else
  skip_check "[live] K8s secret population check (requires --live)"
fi

echo ""

# -----------------------------------------------------------------------
# BLOCKER 3: Missing imagePullSecret on Default ServiceAccount
# Images from asia-southeast1-docker.pkg.dev require credential secret
# -----------------------------------------------------------------------
echo "B3: ImagePullSecret for GCP Artifact Registry"

# Check 9: GCP AR images referenced somewhere in overlay chain (base or overlay)
GAR_IN_OVERLAY=$(grep -c 'docker.pkg.dev' "$RKE2_KUST" 2>/dev/null || true)
GAR_IN_BASE=$(grep -r 'docker.pkg.dev' "$REPO_ROOT/deploy/k8s/base" --include="*.yaml" -l 2>/dev/null | wc -l || true)
if [[ "$GAR_IN_OVERLAY" -ge 1 ]]; then
  pass_check "rke2-nonprod overlay explicitly pins GCP Artifact Registry images ($GAR_IN_OVERLAY refs)"
elif [[ "$GAR_IN_BASE" -ge 1 ]]; then
  pass_check "GCP Artifact Registry images defined in base ($GAR_IN_BASE files) — inherited by rke2-nonprod overlay (imagePullSecret still required)"
else
  fail_check "No GCP Artifact Registry image refs found in overlay or base — cannot verify imagePullSecret requirement"
fi

# Check 10: Base image references require private GCP AR
BASE_KUST="$REPO_ROOT/deploy/k8s/base/kustomization.yaml"
if [[ -f "$BASE_KUST" ]]; then
  if grep -q 'docker.pkg.dev' "$BASE_KUST"; then
    pass_check "Base kustomization references asia-southeast1-docker.pkg.dev (private registry — imagePullSecret required on non-GKE)"
  fi
fi

# Live: Check imagePullSecret on default ServiceAccount
if [[ "$MODE" == "live" ]]; then
  echo "  [live] Checking imagePullSecret..."

  # Check default SA references at least one dockerconfigjson pull secret
  SA_PULL_SECRETS=$(KC get serviceaccount default -n "$NS" \
    -o jsonpath='{.imagePullSecrets[*].name}' 2>/dev/null || echo "")
  if [[ -n "${SA_PULL_SECRETS// }" ]]; then
    pass_check "[live] Default ServiceAccount has imagePullSecrets configured ($SA_PULL_SECRETS)"

    VALID_PULL_SECRET=false
    for PULL_SECRET in $SA_PULL_SECRETS; do
      SECRET_TYPE=$(KC get secret "$PULL_SECRET" -n "$NS" \
        -o jsonpath='{.type}' 2>/dev/null || echo "")
      if [[ "$SECRET_TYPE" == "kubernetes.io/dockerconfigjson" ]]; then
        pass_check "[live] imagePullSecret $PULL_SECRET exists (dockerconfigjson)"
        VALID_PULL_SECRET=true
      else
        warn_check "[live] imagePullSecret $PULL_SECRET missing or wrong type (${SECRET_TYPE:-missing})"
      fi
    done

    if [[ "$VALID_PULL_SECRET" != "true" ]]; then
      fail_check "[live] No valid dockerconfigjson imagePullSecret found on default ServiceAccount"
    fi
  else
    fail_check "[live] Default ServiceAccount has no imagePullSecrets configured — pods cannot pull private images"
    echo "    Fix: kubectl --context $KUBECONTEXT patch serviceaccount default -n $NS -p '{\"imagePullSecrets\": [{\"name\": \"dev-image-puller\"}]}'"
  fi

  # Spot-check pod image pull status
  echo "  [live] Checking pod image pull status..."
  IMAGE_PULL_ERRORS=$(KC get pods -n "$NS" \
    -o jsonpath='{range .items[*]}{.metadata.name}={range .status.containerStatuses[*]}{.state.waiting.reason}{end}{"\n"}{end}' 2>/dev/null \
    | grep 'ImagePullBackOff\|ErrImagePull' || true)
  if [[ -z "$IMAGE_PULL_ERRORS" ]]; then
    pass_check "[live] No ImagePullBackOff/ErrImagePull pods detected"
  else
    IMAGE_PULL_COUNT=$(echo "$IMAGE_PULL_ERRORS" | grep -c . || true)
    fail_check "[live] $IMAGE_PULL_COUNT pod(s) with image pull errors:"
    echo "$IMAGE_PULL_ERRORS" | head -10 | sed 's/^/    /'
  fi
else
  skip_check "[live] imagePullSecret existence check (requires --live)"
  skip_check "[live] Default ServiceAccount imagePullSecrets check (requires --live)"
  skip_check "[live] Pod ImagePullBackOff check (requires --live)"
fi

echo ""

# -----------------------------------------------------------------------
# BLOCKER 4: Quota Saturation (mysql/redis/meilisearch scheduling)
# Checks for resource quota/limit issues preventing pod scheduling
# -----------------------------------------------------------------------
echo "B4: Resource Quota and Scheduling"

# Offline: Check resource requests are set on critical pods
if [[ "$MODE" == "offline" ]]; then
  BASE_LMS="$REPO_ROOT/deploy/k8s/base/apps/lms/deployment.yaml"
  if [[ -f "$BASE_LMS" ]]; then
    if grep -q 'resources:' "$BASE_LMS"; then
      pass_check "LMS deployment has resource requests/limits defined"
    else
      warn_check "LMS deployment may lack resource requests/limits — quota saturation risk"
    fi
  fi
fi

if [[ "$MODE" == "live" ]]; then
  echo "  [live] Checking namespace resource quota..."
  QUOTA=$(KC get resourcequota -n "$NS" 2>/dev/null || echo "")
  if [[ -z "$QUOTA" ]]; then
    pass_check "[live] No ResourceQuota in $NS namespace (unlimited scheduling)"
  else
    echo "$QUOTA" | head -20 | sed 's/^/    /'
    warn_check "[live] ResourceQuota exists in $NS — check used vs hard limits above"
  fi

  # Check for Pending pods (scheduling failure indicator)
  echo "  [live] Checking for Pending pods..."
  PENDING_PODS=$(KC get pods -n "$NS" --field-selector=status.phase=Pending \
    -o jsonpath='{range .items[*]}{.metadata.name}: {.status.conditions[?(@.type=="PodScheduled")].message}{"\n"}{end}' 2>/dev/null || echo "")
  if [[ -z "$PENDING_PODS" ]]; then
    pass_check "[live] No Pending pods in $NS namespace"
  else
    PENDING_COUNT=$(echo "$PENDING_PODS" | grep -c . || true)
    QUOTA_BLOCKED=$(echo "$PENDING_PODS" | grep -c 'quota\|Insufficient\|exceeded' || true)
    if [[ "$QUOTA_BLOCKED" -gt 0 ]]; then
      fail_check "[live] $QUOTA_BLOCKED pod(s) pending due to quota/resource constraints:"
    else
      warn_check "[live] $PENDING_COUNT pod(s) pending (scheduling delay or dependencies):"
    fi
    echo "$PENDING_PODS" | head -10 | sed 's/^/    /'
  fi

  # Check node capacity
  echo "  [live] Checking node resource pressure..."
  NODE_CONDITIONS=$(KC get nodes \
    -o jsonpath='{range .items[*]}{.metadata.name}: MemoryPressure={.status.conditions[?(@.type=="MemoryPressure")].status} DiskPressure={.status.conditions[?(@.type=="DiskPressure")].status}{"\n"}{end}' 2>/dev/null || echo "")
  if [[ -n "$NODE_CONDITIONS" ]]; then
    PRESSURE_COUNT=$(echo "$NODE_CONDITIONS" | grep -c 'True' || true)
    if [[ "$PRESSURE_COUNT" -eq 0 ]]; then
      pass_check "[live] No node memory/disk pressure detected"
    else
      fail_check "[live] Node(s) under resource pressure:"
      echo "$NODE_CONDITIONS" | grep 'True' | sed 's/^/    /'
    fi
  fi
else
  skip_check "[live] ResourceQuota check (requires --live)"
  skip_check "[live] Pending pods check (requires --live)"
  skip_check "[live] Node pressure check (requires --live)"
fi

echo ""

# -----------------------------------------------------------------------
# BONUS: Post-Fix Gate — all pods Running
# -----------------------------------------------------------------------
if [[ "$MODE" == "live" ]]; then
  echo "Post-Fix Gate: Core Pods Running"

  CORE_PODS=("lms" "cms" "caddy")
  ALL_RUNNING=true
  for POD_LABEL in "${CORE_PODS[@]}"; do
    RUNNING=$(KC get pods -n "$NS" \
      -l "app.kubernetes.io/name=$POD_LABEL" \
      --field-selector=status.phase=Running \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -c . || true)
    if [[ "$RUNNING" -ge 1 ]]; then
      pass_check "[live] $POD_LABEL: at least 1 pod Running"
    else
      fail_check "[live] $POD_LABEL: 0 pods Running"
      ALL_RUNNING=false
    fi
  done

  if [[ "$ALL_RUNNING" == "true" ]]; then
    echo ""
    echo "  ✅ RESUME GATE: All core pods Running — safe to run smoke matrix (288f/5ngf.2)"
  else
    echo ""
    echo "  ❌ RESUME GATE: Not all core pods Running — do NOT start smoke matrix yet"
  fi
  echo ""
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo "========================================================"
echo "Summary: $PASS PASS / $FAIL FAIL / $WARN WARN / $SKIP SKIP"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "  B0 (context separation): ensure kubeconfig contexts map to distinct clusters/servers"
  echo "     Check: kubectl config get-contexts"
  echo ""
  echo "Remediation:"
  echo "  B1 (secret store): Apply deploy/k8s/overlays/rke2-nonprod/ overlay"
  echo "     Ensure gcp-secret-manager ClusterSecretStore is absent from rke2 profile"
  echo "     And ExternalSecrets use secretStoreRef.name: infisical-secret-store"
  echo ""
  echo "  B2 (alias keys): Verify infisical-secret-store remoteRef.key paths match Infisical"
  echo "     Check: kubectl --context rke2-nonprod describe externalsecret openedx-secrets -n mereka-lms"
  echo ""
  echo "  B3 (imagePullSecret):"
  echo "     kubectl --context rke2-nonprod create secret docker-registry dev-image-puller \\"
  echo "       -n mereka-lms --docker-server=asia-southeast1-docker.pkg.dev \\"
  echo "       --docker-username=_json_key --docker-password=\"\$(cat /path/to/sa-key.json)\" \\"
  echo "       --docker-email=ci@mereka.io"
  echo "     kubectl --context rke2-nonprod patch serviceaccount default -n mereka-lms \\"
  echo "       -p '{\"imagePullSecrets\": [{\"name\": \"dev-image-puller\"}]}'"
  echo ""
  echo "  B4 (quota): kubectl --context rke2-nonprod describe nodes | grep -A 10 'Allocated resources'"
  echo ""
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
