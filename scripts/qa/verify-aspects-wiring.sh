#!/usr/bin/env bash
# verify-aspects-wiring.sh — Aspects analytics wiring prerequisites check
# @spec: analytics-pipeline_spec.md
#
# Verifies that the prerequisites for wiring Aspects into the kustomization graph
# are met (or tracks the correct NOT-YET-WIRED state). Checks:
#
# Section 1: Manifests are self-contained and well-formed
# Section 2: ExternalSecret for aspects-secrets is wired (or not yet wired)
# Section 3: Overlay patches exist (or correctly absent)
# Section 4: Cluster state — secrets synced, pods running (SKIP if kubectl unavailable)
# Section 5: Ingress and DNS prerequisites (SKIP if cluster unavailable)
# Section 6: Wiring checklist documentation exists
#
# PASS/FAIL/SKIP exit codes:
#   0 = all checks PASS or SKIP (no failures)
#   1 = one or more FAIL
#
# Usage: ./scripts/qa/verify-aspects-wiring.sh
#   Set CLUSTER=rke2-nonprod or CLUSTER=production to restrict cluster checks
#   Set SKIP_CLUSTER=1 to skip all kubectl-dependent checks (offline/CI mode)
#   Set ASPECTS_WIRED=1 if Aspects has been wired (changes expected state in Section 3)
#
# Example (offline):
#   SKIP_CLUSTER=1 ./scripts/qa/verify-aspects-wiring.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_skip() { SKIP=$((SKIP + 1)); echo -e "${YELLOW}[SKIP]${NC} $1"; }

ASPECTS_DIR="${REPO_ROOT}/deploy/k8s/base/plugins/aspects"
BASE_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/base/kustomization.yaml"
NONPROD_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/overlays/rke2-nonprod/kustomization.yaml"
PROD_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml"
NONPROD_PATCHES_DIR="${REPO_ROOT}/deploy/k8s/overlays/rke2-nonprod/patches"
EXTERNAL_SECRETS_FILE="${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml"
WIRING_CHECKLIST="${REPO_ROOT}/docs/operations/ASPECTS_WIRING_CHECKLIST.md"
SETUP_DOC="${REPO_ROOT}/docs/operations/ASPECTS_ANALYTICS_SETUP.md"

# Runtime flags
SKIP_CLUSTER="${SKIP_CLUSTER:-0}"
# Auto-detect wired state from rke2-nonprod overlay (can be overridden via env)
if [[ -z "${ASPECTS_WIRED:-}" ]]; then
  if [[ -f "${NONPROD_KUSTOMIZATION}" ]] && grep -q "plugins/aspects" "${NONPROD_KUSTOMIZATION}"; then
    ASPECTS_WIRED=1
  else
    ASPECTS_WIRED=0
  fi
fi

# Detect kubectl availability
KUBECTL_AVAILABLE=0
if command -v kubectl >/dev/null 2>&1 && [[ "${SKIP_CLUSTER}" != "1" ]]; then
  if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
    KUBECTL_AVAILABLE=1
  fi
fi

echo -e "${BLUE}=== Aspects Analytics Wiring Prerequisites ===${NC}"
echo "  Repo root: ${REPO_ROOT}"
echo "  Aspects manifests: deploy/k8s/base/plugins/aspects/"
echo "  Kubectl available: ${KUBECTL_AVAILABLE}"
echo "  Aspects wired flag: ${ASPECTS_WIRED}"
echo ""

# ── Section 1: Manifests are self-contained and well-formed ───────────

echo -e "${BLUE}-- Section 1: Manifest files and structure --${NC}"

EXPECTED_MANIFESTS=(
  "kustomization.yaml"
  "configmaps.yml"
  "volumes.yml"
  "services.yml"
  "deployments.yml"
  "jobs.yml"
  "ingress.yml"
  "prometheusrule.yml"
)

if [[ ! -d "${ASPECTS_DIR}" ]]; then
  do_fail "Aspects manifests directory not found: deploy/k8s/base/plugins/aspects/"
else
  do_pass "Aspects manifests directory exists"
  for f in "${EXPECTED_MANIFESTS[@]}"; do
    if [[ -f "${ASPECTS_DIR}/${f}" ]]; then
      do_pass "  manifest exists: ${f}"
    else
      do_fail "  manifest missing: ${f}"
    fi
  done
fi

# Kustomization references all manifest files
if [[ -f "${ASPECTS_DIR}/kustomization.yaml" ]]; then
  kustom_files=("configmaps.yml" "volumes.yml" "services.yml" "deployments.yml" "jobs.yml" "ingress.yml" "prometheusrule.yml")
  for f in "${kustom_files[@]}"; do
    if grep -q "${f}" "${ASPECTS_DIR}/kustomization.yaml"; then
      do_pass "  kustomization.yaml references: ${f}"
    else
      do_fail "  kustomization.yaml does NOT reference: ${f}"
    fi
  done

  # Namespace is set
  if grep -q "namespace: mereka-lms" "${ASPECTS_DIR}/kustomization.yaml"; then
    do_pass "  kustomization.yaml sets namespace: mereka-lms"
  else
    do_fail "  kustomization.yaml missing namespace: mereka-lms"
  fi
fi

# Ingress base uses prod domain (by design — overlays override for dev)
if [[ -f "${ASPECTS_DIR}/ingress.yml" ]]; then
  if grep -q "analytics.academyv2.mereka.io" "${ASPECTS_DIR}/ingress.yml"; then
    do_pass "  ingress.yml base host: analytics.academyv2.mereka.io (prod domain, overridden by overlay)"
  else
    do_fail "  ingress.yml base host is not analytics.academyv2.mereka.io (unexpected)"
  fi
fi

# PVC uses GKE storage class (overlay patch needed for rke2)
if [[ -f "${ASPECTS_DIR}/volumes.yml" ]]; then
  if grep -q "storageClassName: standard-rwo" "${ASPECTS_DIR}/volumes.yml"; then
    do_pass "  volumes.yml uses standard-rwo (GKE storage class; overlay patch required for rke2)"
  else
    do_fail "  volumes.yml storageClassName not standard-rwo — verify this is intentional"
  fi
fi

# secrets.yml should NOT be in kustomization (ExternalSecrets manage the secret)
if [[ -f "${ASPECTS_DIR}/kustomization.yaml" ]]; then
  if grep -q "secrets.yml" "${ASPECTS_DIR}/kustomization.yaml"; then
    do_fail "  kustomization.yaml still references secrets.yml — ExternalSecrets should manage aspects-secrets"
  else
    do_pass "  secrets.yml not in kustomization (correct — ExternalSecrets manage the secret)"
  fi
fi

echo ""

# ── Section 2: ExternalSecret wired for aspects-secrets ──────────────

echo -e "${BLUE}-- Section 2: ExternalSecret for aspects-secrets --${NC}"

if [[ -f "${EXTERNAL_SECRETS_FILE}" ]]; then
  if grep -q "aspects-secrets" "${EXTERNAL_SECRETS_FILE}"; then
    do_pass "aspects-secrets ExternalSecret found in deploy/k8s/base/secrets/external-secrets.yaml"

    # Check all three required keys are mapped
    for key in "clickhouse-password" "superset-secret-key" "superset-db-password"; do
      if grep -A 20 "name: aspects-secrets" "${EXTERNAL_SECRETS_FILE}" | grep -q "${key}"; then
        do_pass "  ExternalSecret maps key: ${key}"
      else
        do_fail "  ExternalSecret missing key mapping: ${key} — update external-secrets.yaml"
      fi
    done

    # Check it references the correct GCP SM secret names
    for secret in "MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD" "MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY" "MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD"; do
      if grep -q "${secret}" "${EXTERNAL_SECRETS_FILE}"; then
        do_pass "  ExternalSecret references GCP SM key: ${secret}"
      else
        do_fail "  ExternalSecret missing GCP SM reference: ${secret}"
      fi
    done
  else
    do_fail "aspects-secrets ExternalSecret NOT in deploy/k8s/base/secrets/external-secrets.yaml"
    echo "         ACTION: Add ExternalSecret block per ASPECTS_WIRING_CHECKLIST.md Step 1.3"
  fi
else
  do_fail "external-secrets.yaml not found: deploy/k8s/base/secrets/external-secrets.yaml"
fi

echo ""

# ── Section 3: Overlay patches and wiring state ───────────────────────

echo -e "${BLUE}-- Section 3: Overlay patches and kustomization wiring --${NC}"

# Base kustomization should NOT include aspects (aspects is added only in overlays)
if [[ -f "${BASE_KUSTOMIZATION}" ]]; then
  if grep -q "plugins/aspects" "${BASE_KUSTOMIZATION}"; then
    do_fail "plugins/aspects is in deploy/k8s/base/kustomization.yaml (should only be in overlays)"
    echo "         ACTION: Remove from base kustomization — add to overlay(s) instead"
  else
    do_pass "plugins/aspects is NOT in base kustomization (correct — added per-overlay)"
  fi
else
  do_fail "Base kustomization not found: deploy/k8s/base/kustomization.yaml"
fi

# rke2-nonprod overlay
if [[ -f "${NONPROD_KUSTOMIZATION}" ]]; then
  if [[ "${ASPECTS_WIRED}" == "1" ]]; then
    # Operator has indicated wiring is done — check it IS present
    if grep -q "plugins/aspects" "${NONPROD_KUSTOMIZATION}"; then
      do_pass "rke2-nonprod overlay includes plugins/aspects (ASPECTS_WIRED=1)"
    else
      do_fail "rke2-nonprod overlay does NOT include plugins/aspects — complete Step 1.7 of wiring checklist"
    fi
  else
    # Pre-wiring state — check it is absent (expected)
    if grep -q "plugins/aspects" "${NONPROD_KUSTOMIZATION}"; then
      do_pass "rke2-nonprod overlay already includes plugins/aspects"
    else
      do_pass "rke2-nonprod overlay does NOT include plugins/aspects (pre-wiring state — expected)"
      echo "         To wire: follow ASPECTS_WIRING_CHECKLIST.md Step 1.7"
    fi
  fi
else
  do_fail "rke2-nonprod kustomization not found: deploy/k8s/overlays/rke2-nonprod/kustomization.yaml"
fi

# rke2-nonprod: Infisical ESO override patch should cover aspects-secrets when wired
if [[ -f "${NONPROD_PATCHES_DIR}/externalsecrets-infisical.yaml" ]]; then
  if grep -q "aspects-secrets" "${NONPROD_PATCHES_DIR}/externalsecrets-infisical.yaml"; then
    do_pass "rke2-nonprod externalsecrets-infisical.yaml includes aspects-secrets override"
  else
    do_fail "rke2-nonprod externalsecrets-infisical.yaml missing aspects-secrets override"
    echo "         ACTION: Add aspects-secrets Infisical override per ASPECTS_WIRING_CHECKLIST.md Step 1.3"
  fi
else
  do_fail "rke2-nonprod Infisical ESO patch not found: ${NONPROD_PATCHES_DIR}/externalsecrets-infisical.yaml"
fi

# rke2-nonprod: storage class patch
ASPECTS_SC_PATCH="${NONPROD_PATCHES_DIR}/aspects-storage-class.yaml"
if [[ -f "${ASPECTS_SC_PATCH}" ]]; then
  do_pass "rke2-nonprod storage class patch exists: patches/aspects-storage-class.yaml"
  # Confirm storageClassName is NOT standard-rwo (which is GKE-specific)
  # Use grep on non-comment lines only to avoid false positives from comments
  if grep -v '^\s*#' "${ASPECTS_SC_PATCH}" | grep -q "standard-rwo"; then
    do_fail "  aspects-storage-class.yaml uses standard-rwo as storageClassName — update to rke2 storage class"
  else
    do_pass "  storage class patch does not use standard-rwo (GKE-specific)"
  fi
else
  do_fail "rke2-nonprod storage class patch missing: patches/aspects-storage-class.yaml"
  echo "         ACTION: Create patch per ASPECTS_WIRING_CHECKLIST.md Step 1.4"
fi

# rke2-nonprod: dev ingress patch (overrides base ingress host from mereka.io to mereka.dev)
NONPROD_INGRESS_PATCH="${NONPROD_PATCHES_DIR}/aspects-ingress-dev.yaml"
if [[ -f "${NONPROD_INGRESS_PATCH}" ]]; then
  do_pass "rke2-nonprod dev ingress patch exists: patches/aspects-ingress-dev.yaml"
  if grep -q "analytics.academyv2.mereka.dev" "${NONPROD_INGRESS_PATCH}"; then
    do_pass "  dev ingress patch uses correct host: analytics.academyv2.mereka.dev"
  else
    do_fail "  dev ingress patch does not use analytics.academyv2.mereka.dev"
  fi
  if grep -q "analytics.academyv2.mereka.io" "${NONPROD_INGRESS_PATCH}"; then
    do_fail "  dev ingress patch references prod domain mereka.io — must use mereka.dev for rke2-nonprod"
  else
    do_pass "  dev ingress patch does not reference prod domain"
  fi
else
  do_fail "rke2-nonprod dev ingress patch missing: patches/aspects-ingress-dev.yaml"
  echo "         ACTION: Create patch per ASPECTS_WIRING_CHECKLIST.md Step 1.6"
fi

echo ""

# ── Section 4: Cluster state (SKIP if kubectl unavailable) ────────────

echo -e "${BLUE}-- Section 4: Cluster state --${NC}"

if [[ "${KUBECTL_AVAILABLE}" != "1" ]]; then
  do_skip "kubectl not available or SKIP_CLUSTER=1 — skipping all cluster checks"
  do_skip "  aspects-secrets ExternalSecret Ready state (no kubectl)"
  do_skip "  clickhouse pod status (no kubectl)"
  do_skip "  superset pod status (no kubectl)"
  do_skip "  superset-worker pod status (no kubectl)"
  do_skip "  MySQL superset database existence (no kubectl)"
else
  # ExternalSecret sync state
  es_status=$(kubectl get externalsecret aspects-secrets -n mereka-lms \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NOT_FOUND")
  if [[ "${es_status}" == "True" ]]; then
    do_pass "ExternalSecret aspects-secrets is Ready/Synced"
  elif [[ "${es_status}" == "NOT_FOUND" ]]; then
    do_fail "ExternalSecret aspects-secrets not found in cluster — complete Step 1.3 and push to git"
  else
    do_fail "ExternalSecret aspects-secrets is not Ready (status: ${es_status}) — check ESO logs"
  fi

  # ClickHouse pod
  ch_ready=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=clickhouse \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "NOT_FOUND")
  if [[ "${ch_ready}" == "true" ]]; then
    do_pass "clickhouse pod is Ready"
  elif [[ "${ch_ready}" == "NOT_FOUND" ]]; then
    do_skip "clickhouse pod not found (Aspects not yet deployed to this cluster)"
  else
    do_fail "clickhouse pod is not Ready (ready: ${ch_ready}) — check pod logs"
  fi

  # Superset pod
  ss_ready=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=superset \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "NOT_FOUND")
  if [[ "${ss_ready}" == "true" ]]; then
    do_pass "superset pod is Ready"
  elif [[ "${ss_ready}" == "NOT_FOUND" ]]; then
    do_skip "superset pod not found (Aspects not yet deployed to this cluster)"
  else
    do_fail "superset pod is not Ready (ready: ${ss_ready}) — check pod logs and MySQL DB setup"
  fi

  # Superset worker pod
  ssw_ready=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=superset-worker \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "NOT_FOUND")
  if [[ "${ssw_ready}" == "true" ]]; then
    do_pass "superset-worker pod is Ready"
  elif [[ "${ssw_ready}" == "NOT_FOUND" ]]; then
    do_skip "superset-worker pod not found (Aspects not yet deployed to this cluster)"
  else
    do_fail "superset-worker pod is not Ready (ready: ${ssw_ready})"
  fi

  # Check init jobs completed (if they ran)
  ch_init_status=$(kubectl get job clickhouse-init -n mereka-lms \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "NOT_FOUND")
  if [[ "${ch_init_status}" == "True" ]]; then
    do_pass "clickhouse-init Job completed successfully"
  elif [[ "${ch_init_status}" == "NOT_FOUND" ]]; then
    do_skip "clickhouse-init Job not found (not yet run — run after pods are Ready)"
  else
    do_fail "clickhouse-init Job has not completed — run: kubectl apply -n mereka-lms -f deploy/k8s/base/plugins/aspects/jobs.yml"
  fi

  ss_init_status=$(kubectl get job superset-init -n mereka-lms \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "NOT_FOUND")
  if [[ "${ss_init_status}" == "True" ]]; then
    do_pass "superset-init Job completed successfully"
  elif [[ "${ss_init_status}" == "NOT_FOUND" ]]; then
    do_skip "superset-init Job not found (not yet run — run after pods are Ready)"
  else
    do_fail "superset-init Job has not completed — check MySQL DB setup (Step 1.8)"
  fi
fi

echo ""

# ── Section 5: Ingress and DNS ─────────────────────────────────────────

echo -e "${BLUE}-- Section 5: Ingress and DNS --${NC}"

if [[ "${KUBECTL_AVAILABLE}" != "1" ]]; then
  do_skip "kubectl not available — skipping ingress checks"
  do_skip "  Superset Ingress state (no kubectl)"
else
  # Check if Superset Ingress exists in cluster
  ingress_host=$(kubectl get ingress superset -n mereka-lms \
    -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "NOT_FOUND")
  if [[ "${ingress_host}" == "NOT_FOUND" ]]; then
    do_skip "Superset Ingress not found in cluster (not yet deployed)"
  elif echo "${ingress_host}" | grep -q "mereka.dev"; then
    do_pass "Superset Ingress host is dev domain: ${ingress_host}"
  elif echo "${ingress_host}" | grep -q "mereka.io"; then
    do_pass "Superset Ingress host is prod domain: ${ingress_host}"
  else
    do_fail "Superset Ingress host is unexpected: ${ingress_host}"
  fi

  # Check TLS certificate if ingress exists
  if [[ "${ingress_host}" != "NOT_FOUND" ]]; then
    tls_secret=$(kubectl get ingress superset -n mereka-lms \
      -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || echo "")
    if [[ -n "${tls_secret}" ]]; then
      cert_ready=$(kubectl get certificate "${tls_secret}" -n mereka-lms \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NOT_FOUND")
      if [[ "${cert_ready}" == "True" ]]; then
        do_pass "TLS certificate ${tls_secret} is Ready"
      elif [[ "${cert_ready}" == "NOT_FOUND" ]]; then
        do_skip "TLS certificate ${tls_secret} not found yet (may still be provisioning)"
      else
        do_fail "TLS certificate ${tls_secret} is not Ready — check cert-manager"
      fi
    fi
  fi
fi

# DNS check (offline-compatible — uses nslookup/dig if available)
DEV_DOMAIN="analytics.academyv2.mereka.dev"
if command -v dig >/dev/null 2>&1; then
  dev_ip=$(dig "${DEV_DOMAIN}" +short 2>/dev/null | head -1 || echo "")
  if [[ -n "${dev_ip}" ]]; then
    do_pass "DNS resolves: ${DEV_DOMAIN} → ${dev_ip}"
  else
    do_fail "DNS does not resolve: ${DEV_DOMAIN} — create Cloudflare DNS record (Step 1.5)"
  fi
elif command -v nslookup >/dev/null 2>&1; then
  if nslookup "${DEV_DOMAIN}" >/dev/null 2>&1; then
    do_pass "DNS resolves: ${DEV_DOMAIN}"
  else
    do_fail "DNS does not resolve: ${DEV_DOMAIN} — create Cloudflare DNS record (Step 1.5)"
  fi
else
  do_skip "DNS check skipped (dig/nslookup not available)"
fi

echo ""

# ── Section 6: Documentation ──────────────────────────────────────────

echo -e "${BLUE}-- Section 6: Documentation --${NC}"

if [[ -f "${WIRING_CHECKLIST}" ]]; then
  do_pass "Wiring checklist exists: docs/operations/ASPECTS_WIRING_CHECKLIST.md"

  # Verify key sections are present
  for section in "Phase 1" "Phase 2" "Pre-flight" "Step 1.1" "Step 1.3" "Step 1.7" "Step 1.8" "Ralph" "Rollback"; do
    if grep -q "${section}" "${WIRING_CHECKLIST}"; then
      do_pass "  checklist contains section: ${section}"
    else
      do_fail "  checklist missing section: ${section}"
    fi
  done
else
  do_fail "Wiring checklist missing: docs/operations/ASPECTS_WIRING_CHECKLIST.md"
fi

if [[ -f "${SETUP_DOC}" ]]; then
  do_pass "Aspects setup doc exists: docs/operations/ASPECTS_ANALYTICS_SETUP.md"
else
  do_fail "Aspects setup doc missing: docs/operations/ASPECTS_ANALYTICS_SETUP.md"
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────

echo -e "${BLUE}=== Summary ===${NC}"
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo "  SKIP: ${SKIP}"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL — ${FAIL} check(s) failed${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review FAIL items above"
  echo "  2. Follow docs/operations/ASPECTS_WIRING_CHECKLIST.md step by step"
  echo "  3. Re-run this script after each step to verify progress"
  echo "  4. Section 4/5 checks SKIP when cluster is unavailable (offline/CI) — run on-cluster to verify"
  exit 1
else
  echo -e "${GREEN}RESULT: PASS — all checks passed (${SKIP} skipped)${NC}"
  echo ""
  if [[ "${SKIP}" -gt 0 ]]; then
    echo "Note: ${SKIP} check(s) were skipped due to missing kubectl/DNS tools."
    echo "  Run on a machine with kubectl configured to verify cluster state."
  fi
  if [[ "${ASPECTS_WIRED}" != "1" ]]; then
    echo ""
    echo "Aspects is NOT yet wired. Prerequisites checked above are not yet complete."
    echo "Follow docs/operations/ASPECTS_WIRING_CHECKLIST.md to wire Aspects into dev."
  fi
  exit 0
fi
