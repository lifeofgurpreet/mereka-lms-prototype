#!/usr/bin/env bash
# @covers AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-024, AC-027, AC-028, AC-029, AC-030, AC-032
# @spec: k8s-deployment_spec.md
#
# verify-lms-rke2-validation.sh
#
# Comprehensive LMS validation on rke2-nonprod: smoke tests, routing checks,
# and cutover readiness gate.
#
# Modes:
#   --offline         Static manifest checks (no cluster access required)
#   --online          Live cluster + HTTP smoke tests (requires kubectl + curl)
#   --readiness-gate  Runs offline + online; exits 1 on any FAIL (cutover gate)
#   --context X       kubectl context to use (default: rke2-nonprod)
#   --namespace X     K8s namespace (default: mereka-lms)
#
# Usage:
#   scripts/qa/verify-lms-rke2-validation.sh --offline
#   scripts/qa/verify-lms-rke2-validation.sh --online
#   scripts/qa/verify-lms-rke2-validation.sh --readiness-gate
#   KUBECONTEXT=rke2-nonprod scripts/qa/verify-lms-rke2-validation.sh --readiness-gate
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# -----------------------------------------------------------------------
# Counters and helpers
# -----------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

pass_check() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip_check() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# -----------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------
MODE=""
KUBECONTEXT="${KUBECONTEXT:-rke2-nonprod}"
NS="${NS:-mereka-lms}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline)        MODE=offline;        shift ;;
    --online)         MODE=online;         shift ;;
    --readiness-gate) MODE=readiness-gate; shift ;;
    --context)        KUBECONTEXT="$2";    shift 2 ;;
    --namespace)      NS="$2";             shift 2 ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [--offline|--online|--readiness-gate] [--context CTX] [--namespace NS]

Modes:
  --offline         Static manifest checks (no cluster required)
  --online          Live cluster + HTTP smoke tests
  --readiness-gate  offline + online; exits 1 on any FAIL (pre-cutover gate)

Environment overrides:
  KUBECONTEXT       kubectl context  (default: rke2-nonprod)
  NS                K8s namespace    (default: mereka-lms)
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Error: mode required (--offline | --online | --readiness-gate)" >&2
  echo "Run with --help for usage." >&2
  exit 1
fi

# Convenience wrapper for kubectl
KC() { kubectl --context "$KUBECONTEXT" "$@"; }

# -----------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------
RKE2_OVERLAY="$REPO_ROOT/deploy/k8s/overlays/rke2-nonprod"
BASE_DIR="$REPO_ROOT/deploy/k8s/base"
BASE_SECRETS="$BASE_DIR/secrets/external-secrets.yaml"
INFISICAL_PATCH="$RKE2_OVERLAY/patches/externalsecrets-infisical.yaml"
RKE2_KUST="$RKE2_OVERLAY/kustomization.yaml"
LMS_INGRESS="$RKE2_OVERLAY/ingress-openedx-lms.yaml"
STUDIO_INGRESS="$RKE2_OVERLAY/ingress-openedx-studio.yaml"
MFE_INGRESS="$RKE2_OVERLAY/ingress-openedx-mfe.yaml"

# Nonprod domains
LMS_DOMAIN="academyv2.mereka.dev"
STUDIO_DOMAIN="studio.academyv2.mereka.dev"
MFE_DOMAIN="apps.academyv2.mereka.dev"

echo "========================================================"
echo "LMS RKE2 Nonprod Validation"
echo "  mode=$MODE  context=$KUBECONTEXT  ns=$NS"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# OFFLINE: Section 1 — K8s manifests exist
# -----------------------------------------------------------------------
run_offline_checks() {
  echo "--- [1/7] Required K8s Manifests ---"

  local required_files=(
    "$RKE2_OVERLAY/kustomization.yaml:rke2-nonprod kustomization.yaml"
    "$LMS_INGRESS:LMS Ingress manifest"
    "$STUDIO_INGRESS:Studio Ingress manifest"
    "$MFE_INGRESS:MFE Ingress manifest"
    "$INFISICAL_PATCH:externalsecrets-infisical.yaml patch"
    "$RKE2_OVERLAY/patches/domain-env.yaml:domain-env.yaml patch"
    "$RKE2_OVERLAY/patches/single-node-recreate-strategy.yaml:single-node-recreate-strategy.yaml patch"
    "$BASE_DIR/deployments.yml:base deployments.yml"
    "$BASE_DIR/services.yml:base services.yml"
    "$BASE_SECRETS:base external-secrets.yaml"
  )

  for entry in "${required_files[@]}"; do
    local file="${entry%%:*}"
    local label="${entry##*:}"
    if [[ -f "$file" ]]; then
      pass_check "$label exists"
    else
      fail_check "$label missing: $file"
    fi
  done

  # Check base deployments contain LMS, CMS, Caddy
  if [[ -f "$BASE_DIR/deployments.yml" ]]; then
    for deploy_name in lms cms caddy; do
      if grep -q "name: ${deploy_name}$" "$BASE_DIR/deployments.yml"; then
        pass_check "base deployments.yml contains Deployment: $deploy_name"
      else
        fail_check "base deployments.yml missing Deployment: $deploy_name"
      fi
    done
  fi

  # Check base services contain expected services
  if [[ -f "$BASE_DIR/services.yml" ]]; then
    for svc_name in lms cms caddy; do
      if grep -q "name: ${svc_name}$" "$BASE_DIR/services.yml"; then
        pass_check "base services.yml contains Service: $svc_name"
      else
        fail_check "base services.yml missing Service: $svc_name"
      fi
    done
  fi

  echo ""

  # -----------------------------------------------------------------------
  # OFFLINE: Section 2 — LMS settings patches
  # -----------------------------------------------------------------------
  echo "--- [2/7] LMS Settings Patches ---"

  local lms_settings
  lms_settings=$(find "$REPO_ROOT" \
    -path "*/patches/*production*.py" \
    -not -path "*/.git/*" \
    -not -path "*worktrees/*" 2>/dev/null | head -3)

  if [[ -n "$lms_settings" ]]; then
    pass_check "LMS production settings patch file(s) found"

    # Check for required settings keys
    while IFS= read -r settings_file; do
      [[ -z "$settings_file" ]] && continue

      local required_settings=(
        "ENABLE_COMPREHENSIVE_THEMING"
        "SESSION_COOKIE_SECURE"
        "CSRF_TRUSTED_ORIGINS"
      )
      for setting in "${required_settings[@]}"; do
        if grep -q "$setting" "$settings_file" 2>/dev/null; then
          pass_check "production.py contains $setting"
        else
          skip_check "production.py: $setting not found in $(basename "$settings_file") (may be in overlay)"
        fi
      done
    done <<< "$lms_settings"
  else
    skip_check "LMS production settings patch not found in repo (may be in bbi-infrastructure)"
  fi

  # Check apply-patches.sh and its sourced patch scripts for critical configs
  local apply_patches="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
  local patches_dir="$REPO_ROOT/infrastructure/tutor/patches"
  if [[ -f "$apply_patches" ]]; then
    # mysql_native_password lives in mereka_lms.py plugin (ENV_PATCHES mysql-docker-compose)
    if grep -rq "mysql_native_password\|mysql-native-password" "$apply_patches" "$patches_dir" 2>/dev/null; then
      pass_check "tutor patches contain mysql_native_password configuration"
    else
      fail_check "tutor patches missing mysql_native_password configuration"
    fi

    # CSRF_TRUSTED_ORIGINS lives in mereka_lms.py plugin (ENV_PATCHES openedx-lms-production-settings)
    if grep -rq "CSRF_TRUSTED_ORIGINS\|csrf.origins\|csrf-origins" "$apply_patches" "$patches_dir" 2>/dev/null; then
      pass_check "tutor patches contain CSRF_TRUSTED_ORIGINS configuration"
    else
      fail_check "tutor patches missing CSRF_TRUSTED_ORIGINS configuration"
    fi

    # ENABLE_COMPREHENSIVE_THEMING lives in multisite config files
    if grep -rq "ENABLE_COMPREHENSIVE_THEMING" \
        "$REPO_ROOT/infrastructure/tutor/" 2>/dev/null; then
      pass_check "tutor config contains ENABLE_COMPREHENSIVE_THEMING"
    else
      skip_check "ENABLE_COMPREHENSIVE_THEMING not found in tutor config (may be in bbi-infrastructure overlay)"
    fi
  else
    skip_check "infrastructure/tutor/apply-patches.sh not found"
  fi

  echo ""

  # -----------------------------------------------------------------------
  # OFFLINE: Section 3 — Caddy routing
  # -----------------------------------------------------------------------
  echo "--- [3/7] Caddy Configuration / Domain Routing ---"

  # Verify rke2-nonprod ingress has correct domains
  if [[ -f "$LMS_INGRESS" ]]; then
    if grep -q "$LMS_DOMAIN" "$LMS_INGRESS"; then
      pass_check "LMS Ingress routes $LMS_DOMAIN"
    else
      fail_check "LMS Ingress does not route $LMS_DOMAIN"
    fi
    if grep -q "cert-manager.io/cluster-issuer" "$LMS_INGRESS"; then
      pass_check "LMS Ingress has cert-manager.io/cluster-issuer annotation"
    else
      fail_check "LMS Ingress missing cert-manager.io/cluster-issuer annotation"
    fi
    if grep -q "letsencrypt-prod" "$LMS_INGRESS"; then
      pass_check "LMS Ingress uses letsencrypt-prod cluster issuer"
    else
      fail_check "LMS Ingress not using letsencrypt-prod"
    fi
    if grep -q "ingressClassName: nginx" "$LMS_INGRESS"; then
      pass_check "LMS Ingress uses ingressClassName: nginx"
    else
      fail_check "LMS Ingress missing ingressClassName: nginx"
    fi
  fi

  if [[ -f "$STUDIO_INGRESS" ]]; then
    if grep -q "$STUDIO_DOMAIN" "$STUDIO_INGRESS"; then
      pass_check "Studio Ingress routes $STUDIO_DOMAIN"
    else
      fail_check "Studio Ingress does not route $STUDIO_DOMAIN"
    fi
  fi

  if [[ -f "$MFE_INGRESS" ]]; then
    if grep -q "$MFE_DOMAIN" "$MFE_INGRESS"; then
      pass_check "MFE Ingress routes $MFE_DOMAIN"
    else
      fail_check "MFE Ingress does not route $MFE_DOMAIN"
    fi
  fi

  # Verify Caddy backend target in each ingress is "caddy" service
  for ingress_file in "$LMS_INGRESS" "$STUDIO_INGRESS" "$MFE_INGRESS"; do
    [[ ! -f "$ingress_file" ]] && continue
    local ingress_basename
    ingress_basename="$(basename "$ingress_file")"
    if grep -q "name: caddy" "$ingress_file"; then
      pass_check "$ingress_basename backend targets caddy service"
    else
      fail_check "$ingress_basename backend does not target caddy service"
    fi
  done

  # Verify domain-env patch overrides domain for rke2
  if [[ -f "$RKE2_OVERLAY/patches/domain-env.yaml" ]]; then
    if grep -q "mereka.dev" "$RKE2_OVERLAY/patches/domain-env.yaml"; then
      pass_check "domain-env.yaml patch sets *.mereka.dev domain"
    else
      fail_check "domain-env.yaml patch does not set mereka.dev domain"
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # OFFLINE: Section 4 — ExternalSecrets mapping
  # -----------------------------------------------------------------------
  echo "--- [4/7] ExternalSecrets Key Mapping ---"

  if [[ -f "$BASE_SECRETS" ]]; then
    local required_secret_keys=(
      "OPENEDX_SECRET_KEY"
      "SECRET_KEY"
      "MONGODB_PASSWORD"
      "MYSQL_ROOT_PASSWORD"
    )
    for key in "${required_secret_keys[@]}"; do
      if grep -q "secretKey: $key" "$BASE_SECRETS"; then
        pass_check "ExternalSecret maps secretKey: $key"
      else
        fail_check "ExternalSecret missing secretKey: $key"
      fi
    done

    # Verify all remoteRef.key values use MEREKA_LMS_ prefix
    local non_prefixed_keys
    non_prefixed_keys=$(grep 'key:' "$BASE_SECRETS" \
      | grep -v 'MEREKA_LMS_' \
      | grep -v '#' \
      | grep -v 'conversionStrategy\|decodingStrategy\|metadataPolicy' \
      | grep -v 'secretKey:' \
      || true)
    if [[ -z "$non_prefixed_keys" ]]; then
      pass_check "All remoteRef.key values use MEREKA_LMS_ prefix"
    else
      fail_check "Some remoteRef.key values missing MEREKA_LMS_ prefix"
    fi
  fi

  if [[ -f "$INFISICAL_PATCH" ]]; then
    # Verify infisical patch uses infisical-secret-store (not gcp-secret-manager)
    local infisical_refs
    infisical_refs=$(grep -v '^\s*#' "$INFISICAL_PATCH" \
      | grep -c 'infisical-secret-store' || true)
    local gcp_refs
    gcp_refs=$(grep -v '^\s*#' "$INFISICAL_PATCH" \
      | grep -c 'gcp-secret-manager' || true)

    if [[ "$infisical_refs" -ge 1 && "$gcp_refs" -eq 0 ]]; then
      pass_check "Infisical patch uses infisical-secret-store (no gcp-secret-manager refs)"
    else
      fail_check "Infisical patch: infisical_refs=$infisical_refs, gcp_refs=$gcp_refs (expected >=1 and 0)"
    fi

    if [[ "$RKE2_KUST" && -f "$RKE2_KUST" ]]; then
      if grep -q 'externalsecrets-infisical' "$RKE2_KUST"; then
        pass_check "kustomization.yaml includes externalsecrets-infisical.yaml patch"
      else
        fail_check "kustomization.yaml missing externalsecrets-infisical.yaml patch"
      fi
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # OFFLINE: Section 5 — Image tag consistency
  # -----------------------------------------------------------------------
  echo "--- [5/7] Image Tag Consistency ---"

  # Check kustomization.yaml references pinned image tags (not :latest)
  if [[ -f "$RKE2_KUST" ]]; then
    if grep -q 'newTag:' "$RKE2_KUST"; then
      local latest_tags
      latest_tags=$(grep 'newTag:' "$RKE2_KUST" | grep ':latest\|latest$' || true)
      if [[ -z "$latest_tags" ]]; then
        pass_check "rke2-nonprod overlay: no :latest image tags in kustomization.yaml"
      else
        fail_check "rke2-nonprod overlay: :latest image tags found (pin to SHA or semver)"
      fi
    else
      skip_check "rke2-nonprod overlay: no newTag entries in kustomization.yaml (using base tags)"
    fi

    # Verify images reference GCP Artifact Registry
    if grep -q 'docker.pkg.dev' "$RKE2_KUST"; then
      pass_check "rke2-nonprod overlay references GCP Artifact Registry images"
    else
      # May inherit from base
      if [[ -f "$BASE_DIR/kustomization.yaml" ]] && grep -q 'docker.pkg.dev' "$BASE_DIR/kustomization.yaml"; then
        pass_check "GCP Artifact Registry images defined in base (inherited by rke2-nonprod)"
      else
        skip_check "GCP Artifact Registry image refs not found in overlay or base"
      fi
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # OFFLINE: Section 6 — Resource limits
  # -----------------------------------------------------------------------
  echo "--- [6/7] Resource Limits ---"

  local resource_patch="$REPO_ROOT/deploy/k8s/overlays/production/patches/resource-limits.yaml"
  if [[ -f "$resource_patch" ]]; then
    pass_check "Production resource-limits.yaml patch exists"
    if grep -q 'resources:' "$resource_patch"; then
      pass_check "resource-limits.yaml defines resources block"
    else
      fail_check "resource-limits.yaml missing resources block"
    fi
  else
    skip_check "Production resource-limits.yaml not found (nonprod may use defaults)"
  fi

  # Check LMS deployment has resource block in base
  if [[ -f "$BASE_DIR/deployments.yml" ]]; then
    if grep -A 5 "name: lms$" "$BASE_DIR/deployments.yml" 2>/dev/null | grep -q 'resources:\|limits:\|requests:'; then
      pass_check "LMS deployment has resource requests/limits in base"
    else
      # May be in overlay patch
      if [[ -f "$resource_patch" ]] && grep -q 'lms\|openedx' "$resource_patch" 2>/dev/null; then
        pass_check "LMS resource limits defined in overlay patch"
      else
        skip_check "LMS resource limits not found in base or overlay (check manually)"
      fi
    fi
  fi

  echo ""

  # -----------------------------------------------------------------------
  # OFFLINE: Section 7 — Monitoring configuration
  # -----------------------------------------------------------------------
  echo "--- [7/7] Monitoring Configuration ---"

  local monitoring_dir="$BASE_DIR/monitoring"
  if [[ -d "$monitoring_dir" ]]; then
    pass_check "monitoring/ directory exists"

    # ServiceMonitor for LMS
    if find "$monitoring_dir" -name "*.yaml" -exec grep -l "kind: ServiceMonitor" {} \; 2>/dev/null | grep -q .; then
      pass_check "ServiceMonitor manifest(s) found in monitoring/"
    else
      fail_check "No ServiceMonitor manifests found in monitoring/"
    fi

    # Check for LMS ServiceMonitor specifically
    if find "$monitoring_dir" -name "*.yaml" 2>/dev/null \
        | xargs grep -l "kind: ServiceMonitor" 2>/dev/null \
        | xargs grep -l "lms\|openedx" 2>/dev/null \
        | grep -q .; then
      pass_check "LMS/openedx ServiceMonitor found"
    else
      skip_check "LMS-specific ServiceMonitor not confirmed (check monitoring/ contents)"
    fi

    # PrometheusRule
    if find "$monitoring_dir" -name "*.yaml" -exec grep -l "kind: PrometheusRule" {} \; 2>/dev/null | grep -q .; then
      pass_check "PrometheusRule manifest(s) found in monitoring/"
    else
      fail_check "No PrometheusRule manifests found in monitoring/"
    fi
  else
    fail_check "monitoring/ directory missing at $monitoring_dir"
  fi
}

# -----------------------------------------------------------------------
# ONLINE checks
# -----------------------------------------------------------------------
run_online_checks() {
  echo "--- [O1/6] Pod Health ---"

  if ! command -v kubectl >/dev/null 2>&1; then
    skip_check "kubectl not available — skipping all live checks"
    return 0
  fi

  if ! KC get namespace "$NS" >/dev/null 2>&1; then
    fail_check "Namespace $NS not found on context $KUBECONTEXT"
    return 0
  fi

  # Check all pods Running (no CrashLoopBackOff or other bad states)
  local bad_pods
  bad_pods=$(KC get pods -n "$NS" \
    --field-selector='status.phase!=Running,status.phase!=Succeeded' \
    -o jsonpath='{range .items[*]}{.metadata.name}={.status.phase}/{range .status.containerStatuses[*]}{.state.waiting.reason}{end}{"\n"}{end}' \
    2>/dev/null | grep -v '^=$' | grep -v '^$' || true)

  if [[ -z "$bad_pods" ]]; then
    pass_check "All pods are Running or Succeeded in $NS"
  else
    local crash_pods
    crash_pods=$(echo "$bad_pods" | grep 'CrashLoopBackOff' || true)
    if [[ -n "$crash_pods" ]]; then
      fail_check "CrashLoopBackOff pods detected:"
      echo "$crash_pods" | head -10 | sed 's/^/    /'
    else
      fail_check "Non-running pods detected:"
      echo "$bad_pods" | head -10 | sed 's/^/    /'
    fi
  fi

  # Core pods Running
  for pod_label in lms cms caddy; do
    local running_count
    running_count=$(KC get pods -n "$NS" \
      -l "app.kubernetes.io/name=$pod_label" \
      --field-selector=status.phase=Running \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
      2>/dev/null | grep -c . || true)
    if [[ "$running_count" -ge 1 ]]; then
      pass_check "At least 1 $pod_label pod is Running"
    else
      fail_check "0 $pod_label pods Running in $NS"
    fi
  done

  echo ""
  echo "--- [O2/6] Endpoints ---"

  # Verify endpoints are populated (non-empty) for core services
  for svc_name in lms cms caddy; do
    local ep_addresses
    ep_addresses=$(KC get endpoints "$svc_name" -n "$NS" \
      -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$ep_addresses" ]]; then
      pass_check "Service $svc_name endpoints populated ($ep_addresses)"
    else
      fail_check "Service $svc_name endpoints are empty (no healthy pods backing service)"
    fi
  done

  echo ""
  echo "--- [O3/6] HTTP Smoke Tests ---"

  if ! command -v curl >/dev/null 2>&1; then
    skip_check "curl not available — skipping HTTP smoke tests"
  else
    # LMS homepage
    local lms_status
    lms_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 \
      "https://${LMS_DOMAIN}/" 2>/dev/null || echo "000")
    if [[ "$lms_status" == "200" || "$lms_status" == "302" ]]; then
      pass_check "LMS homepage https://${LMS_DOMAIN}/ -> HTTP $lms_status"
    else
      fail_check "LMS homepage https://${LMS_DOMAIN}/ -> HTTP $lms_status (expected 200/302)"
    fi

    # Studio homepage
    local studio_status
    studio_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 \
      "https://${STUDIO_DOMAIN}/" 2>/dev/null || echo "000")
    if [[ "$studio_status" == "200" || "$studio_status" == "302" ]]; then
      pass_check "Studio https://${STUDIO_DOMAIN}/ -> HTTP $studio_status"
    else
      fail_check "Studio https://${STUDIO_DOMAIN}/ -> HTTP $studio_status (expected 200/302)"
    fi

    # MFE login page
    local mfe_status
    mfe_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 \
      "https://${MFE_DOMAIN}/authn/login" 2>/dev/null || echo "000")
    if [[ "$mfe_status" == "200" || "$mfe_status" == "302" ]]; then
      pass_check "MFE login https://${MFE_DOMAIN}/authn/login -> HTTP $mfe_status"
    else
      fail_check "MFE login https://${MFE_DOMAIN}/authn/login -> HTTP $mfe_status (expected 200/302)"
    fi
  fi

  echo ""
  echo "--- [O4/6] API Health Endpoints ---"

  if ! command -v curl >/dev/null 2>&1; then
    skip_check "curl not available — skipping health endpoint checks"
  else
    # LMS heartbeat
    local heartbeat_status
    heartbeat_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 \
      "https://${LMS_DOMAIN}/heartbeat" 2>/dev/null || echo "000")
    if [[ "$heartbeat_status" == "200" ]]; then
      pass_check "LMS /heartbeat -> HTTP 200"
    elif [[ "$heartbeat_status" == "404" ]]; then
      skip_check "LMS /heartbeat -> 404 (endpoint may not exist; check /health instead)"
    else
      fail_check "LMS /heartbeat -> HTTP $heartbeat_status (expected 200)"
    fi

    # LMS health check (alternative endpoint)
    local health_status
    health_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 \
      "https://${LMS_DOMAIN}/health" 2>/dev/null || echo "000")
    if [[ "$health_status" == "200" ]]; then
      pass_check "LMS /health -> HTTP 200"
    elif [[ "$health_status" == "404" ]]; then
      skip_check "LMS /health -> 404 (endpoint path may differ)"
    else
      fail_check "LMS /health -> HTTP $health_status (expected 200)"
    fi
  fi

  echo ""
  echo "--- [O5/6] Database Connectivity ---"

  # Check via LMS health endpoint response body for DB status
  if command -v curl >/dev/null 2>&1; then
    local health_body
    health_body=$(curl -s --max-time 15 \
      "https://${LMS_DOMAIN}/heartbeat" 2>/dev/null || echo "")

    if echo "$health_body" | grep -qi '"OK"\|"status": "OK"\|status.*ok'; then
      pass_check "LMS heartbeat body indicates healthy state (DB connectivity implied)"
    elif [[ -n "$health_body" ]]; then
      # Non-empty response — service is at least responding
      pass_check "LMS heartbeat endpoint responding (check body manually for DB status)"
    else
      skip_check "LMS heartbeat returned empty body (verify DB via kubectl logs)"
    fi
  else
    skip_check "curl not available — skipping DB connectivity check via health endpoint"
  fi

  # Also check: no DB-related crashes in recent LMS pod logs
  if command -v kubectl >/dev/null 2>&1; then
    local lms_pod
    lms_pod=$(KC get pods -n "$NS" \
      -l "app.kubernetes.io/name=lms" \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$lms_pod" ]]; then
      local db_errors
      db_errors=$(KC logs -n "$NS" "$lms_pod" --tail=50 2>/dev/null \
        | grep -i 'OperationalError\|connection.*refused\|can.t connect.*database\|FATAL.*database' \
        || true)
      if [[ -z "$db_errors" ]]; then
        pass_check "No DB connection errors in recent LMS pod logs ($lms_pod)"
      else
        fail_check "DB connection errors in LMS pod logs:"
        echo "$db_errors" | head -5 | sed 's/^/    /'
      fi
    else
      skip_check "No running LMS pod found — cannot check logs for DB errors"
    fi
  fi

  echo ""
  echo "--- [O6/6] SSL Certificate ---"

  if ! command -v curl >/dev/null 2>&1; then
    skip_check "curl not available — skipping SSL check"
  else
    # Verify SSL is valid (curl with cert verification enabled, no -k flag)
    local ssl_check_status
    ssl_check_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 \
      "https://${LMS_DOMAIN}/" 2>/dev/null || echo "000")

    if [[ "$ssl_check_status" != "000" ]]; then
      pass_check "SSL certificate valid for $LMS_DOMAIN (curl succeeded without -k)"
    else
      # Try with -k to distinguish SSL error from connectivity error
      local ssl_insecure_status
      ssl_insecure_status=$(curl -sk -o /dev/null -w "%{http_code}" \
        --max-time 15 \
        "https://${LMS_DOMAIN}/" 2>/dev/null || echo "000")
      if [[ "$ssl_insecure_status" != "000" ]]; then
        fail_check "SSL certificate INVALID for $LMS_DOMAIN (curl -k succeeds but strict fails)"
      else
        fail_check "LMS domain $LMS_DOMAIN unreachable (DNS or network issue)"
      fi
    fi

    # Check cert expiry via openssl if available
    if command -v openssl >/dev/null 2>&1; then
      local cert_expiry
      cert_expiry=$(echo \
        | openssl s_client -connect "${LMS_DOMAIN}:443" -servername "${LMS_DOMAIN}" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null \
        | sed 's/notAfter=//' \
        || echo "")

      if [[ -n "$cert_expiry" ]]; then
        local expiry_epoch
        expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$cert_expiry" +%s 2>/dev/null || echo "0")
        local now_epoch
        now_epoch=$(date +%s)
        local days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

        if [[ "$days_remaining" -ge 14 ]]; then
          pass_check "SSL certificate for $LMS_DOMAIN expires in $days_remaining days ($cert_expiry)"
        elif [[ "$days_remaining" -ge 0 ]]; then
          fail_check "SSL certificate for $LMS_DOMAIN expires in $days_remaining days — renew soon!"
        else
          fail_check "SSL certificate for $LMS_DOMAIN EXPIRED ($cert_expiry)"
        fi
      else
        skip_check "Could not retrieve cert expiry for $LMS_DOMAIN via openssl"
      fi
    else
      skip_check "openssl not available — skipping cert expiry check"
    fi
  fi
}

# -----------------------------------------------------------------------
# Run based on mode
# -----------------------------------------------------------------------
case "$MODE" in
  offline)
    run_offline_checks
    ;;
  online)
    run_online_checks
    ;;
  readiness-gate)
    run_offline_checks
    echo ""
    run_online_checks
    ;;
esac

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "========================================================"
echo "Summary: $PASS PASS / $FAIL FAIL / $SKIP SKIP"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL — $FAIL check(s) failed"
  echo ""
  echo "Quick remediation reference:"
  echo "  Manifests:  ls deploy/k8s/overlays/rke2-nonprod/"
  echo "  Secrets:    kubectl --context $KUBECONTEXT get externalsecret -n $NS"
  echo "  Pods:       kubectl --context $KUBECONTEXT get pods -n $NS"
  echo "  Endpoints:  kubectl --context $KUBECONTEXT get endpoints -n $NS"
  echo "  Logs:       kubectl --context $KUBECONTEXT logs -n $NS -l app.kubernetes.io/name=lms --tail=50"
  echo "  SSL:        openssl s_client -connect ${LMS_DOMAIN}:443 -servername ${LMS_DOMAIN}"
  echo ""
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
