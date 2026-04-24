#!/usr/bin/env bash
# verify-credentials-readiness.sh — Credentials + Learner Record MFE production readiness audit
#
# Checks infrastructure configuration for the Credentials service and learner-record MFE.
# Covers static (repo) checks and optional live-cluster checks.
#
# Usage:
#   ./scripts/qa/verify-credentials-readiness.sh [--cluster] [--help]
#
#   --cluster    Also run live kubectl checks (requires cluster access)
#   --help       Show this help
#
# Exit code: 0 if FAIL=0, 1 otherwise.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

# ── Argument parsing ─────────────────────────────────────────────────────────
CLUSTER=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --cluster)
      CLUSTER=true
      shift
      ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Credentials + Learner Record MFE production readiness audit.

OPTIONS:
    --cluster    Run live kubectl checks (requires cluster access)
    --help       Show this help message

EXIT CODE:
    0 if FAIL=0 (all checks pass or skip)
    1 if any check fails
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ── Counters + helpers ────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass_() { PASS=$((PASS + 1)); printf "PASS: %s\n" "$1"; }
fail_() { FAIL=$((FAIL + 1)); printf "FAIL: %s\n" "$1"; }
skip_() { SKIP=$((SKIP + 1)); printf "SKIP: %s\n" "$1"; }
warn_() { printf "WARN: %s\n" "$1"; }

# ── Key file paths ────────────────────────────────────────────────────────────
CRED_SETTINGS="$REPO_ROOT/deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py"
CRED_SETTINGS_DEV="$REPO_ROOT/deploy/k8s/base/plugins/credentials/apps/credentials/settings/development.py"
MFE_CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
MAIN_CADDYFILE="$REPO_ROOT/deploy/k8s/base/apps/caddy/Caddyfile"
DEPLOYMENTS="$REPO_ROOT/deploy/k8s/base/deployments.yml"
SERVICES="$REPO_ROOT/deploy/k8s/base/services.yml"
PROD_INGRESS="$REPO_ROOT/deploy/k8s/overlays/production/ingress-openedx-lms.yaml"
EXTERNAL_SECRETS="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
MFE_DOCKERFILE="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"
MEREKA_PLUGIN="$PLUGIN_MAIN"
VC_ISSUER_VIEWS="$REPO_ROOT/infrastructure/tutor/custom-apps/credentials_vc_issuer/views.py"
VC_ISSUER_URLS="$REPO_ROOT/infrastructure/tutor/custom-apps/credentials_vc_issuer/urls.py"
PROMETHEUS_RULE="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-credentials.yaml"
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
KUSTOMIZATION="$REPO_ROOT/deploy/k8s/base/kustomization.yaml"

echo "========================================================================"
echo "  Credentials + Learner Record MFE — Production Readiness Audit"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================================"
echo ""

# ============================================================================
echo "── Section 1: Credentials Service Deployment ──────────────────────────"
# ============================================================================

# 1.1 Deployment manifest exists
if [[ -f "$DEPLOYMENTS" ]]; then
  if grep -q 'name: credentials' "$DEPLOYMENTS"; then
    pass_ "Credentials Deployment present in deployments.yml"
  else
    fail_ "Credentials Deployment NOT found in deployments.yml"
  fi
else
  fail_ "deployments.yml not found: $DEPLOYMENTS"
fi

# 1.2 Credentials image is pinned (not :latest)
if grep -A5 'name: credentials$' "$DEPLOYMENTS" 2>/dev/null | grep -q 'openedx-credentials:'; then
  IMAGE_TAG=$(grep -A5 'name: credentials$' "$DEPLOYMENTS" | grep 'openedx-credentials:' | head -1 | awk -F: '{print $NF}' | tr -d ' "')
  if [[ "$IMAGE_TAG" == "latest" ]]; then
    fail_ "Credentials image tag is :latest (must be pinned)"
  else
    pass_ "Credentials image tag is pinned: $IMAGE_TAG"
  fi
else
  skip_ "Could not parse credentials image tag from deployments.yml"
fi

# 1.3 Service defined
if [[ -f "$SERVICES" ]]; then
  if grep -q 'name: credentials' "$SERVICES"; then
    pass_ "Credentials Service present in services.yml"
  else
    fail_ "Credentials Service NOT found in services.yml"
  fi
else
  fail_ "services.yml not found: $SERVICES"
fi

# 1.4 Production ingress includes credentials host
if [[ -f "$PROD_INGRESS" ]]; then
  if grep -q 'credentials.academyv2.mereka.io' "$PROD_INGRESS"; then
    pass_ "credentials.academyv2.mereka.io present in production ingress"
  else
    fail_ "credentials.academyv2.mereka.io MISSING from production ingress"
  fi
else
  skip_ "Production ingress not found: $PROD_INGRESS"
fi

# 1.5 TLS entry for credentials host
if [[ -f "$PROD_INGRESS" ]]; then
  if grep -A40 '^  tls:' "$PROD_INGRESS" | grep -q 'credentials.academyv2.mereka.io'; then
    pass_ "TLS entry present for credentials.academyv2.mereka.io"
  else
    fail_ "TLS entry MISSING for credentials.academyv2.mereka.io"
  fi
fi

# ============================================================================
echo ""
echo "── Section 2: Caddy Proxy Configuration ───────────────────────────────"
# ============================================================================

# 2.1 Main Caddyfile has credentials proxy block
if [[ -f "$MAIN_CADDYFILE" ]]; then
  if grep -q 'credentials.academyv2.mereka.io' "$MAIN_CADDYFILE"; then
    pass_ "Credentials Caddy proxy block present in main Caddyfile"
  else
    fail_ "Credentials Caddy proxy block MISSING from main Caddyfile"
  fi
else
  fail_ "Main Caddyfile not found: $MAIN_CADDYFILE"
fi

# 2.2 Caddy block proxies to credentials:8000
if [[ -f "$MAIN_CADDYFILE" ]]; then
  if grep -q '"credentials:8000"' "$MAIN_CADDYFILE" || grep -q 'proxy "credentials:8000"' "$MAIN_CADDYFILE"; then
    pass_ "Caddy credentials block proxies to credentials:8000"
  else
    fail_ "Caddy credentials block does NOT proxy to credentials:8000"
  fi
fi

# 2.3 CRITICAL: learner-record route MISSING from MFE Caddyfile
if [[ -f "$MFE_CADDYFILE" ]]; then
  if grep -q 'learner-record' "$MFE_CADDYFILE"; then
    pass_ "learner-record route present in MFE Caddyfile"
  else
    fail_ "learner-record route MISSING from MFE Caddyfile (T108 gap — learners cannot access /learner-record/)"
  fi
else
  fail_ "MFE Caddyfile not found: $MFE_CADDYFILE"
fi

# 2.4 learner-record dist path referenced correctly if route exists
if [[ -f "$MFE_CADDYFILE" ]] && grep -q 'learner-record' "$MFE_CADDYFILE"; then
  if grep -A4 'mfe_learner-record' "$MFE_CADDYFILE" 2>/dev/null | grep -q '/openedx/dist/learner-record'; then
    pass_ "learner-record Caddy route points to correct dist path"
  else
    fail_ "learner-record Caddy route does not reference /openedx/dist/learner-record"
  fi
fi

# ============================================================================
echo ""
echo "── Section 3: Credentials Settings (production.py) ────────────────────"
# ============================================================================

# 3.1 Settings file exists
if [[ -f "$CRED_SETTINGS" ]]; then
  pass_ "Credentials production settings file exists"
else
  fail_ "Credentials production settings file NOT found: $CRED_SETTINGS"
fi

# 3.2 USE_LEARNER_RECORD_MFE = True
if [[ -f "$CRED_SETTINGS" ]]; then
  if grep -q 'USE_LEARNER_RECORD_MFE = True' "$CRED_SETTINGS"; then
    pass_ "USE_LEARNER_RECORD_MFE = True in production settings"
  else
    fail_ "USE_LEARNER_RECORD_MFE is not True in production settings"
  fi
fi

# 3.3 ENABLE_VERIFIABLE_CREDENTIALS = True
if [[ -f "$CRED_SETTINGS" ]]; then
  if grep -q 'ENABLE_VERIFIABLE_CREDENTIALS = True' "$CRED_SETTINGS"; then
    pass_ "ENABLE_VERIFIABLE_CREDENTIALS = True in production settings"
  else
    fail_ "ENABLE_VERIFIABLE_CREDENTIALS is not True in production settings"
  fi
fi

# 3.4 LEARNER_RECORD_MFE_RECORDS_PAGE_URL set
if [[ -f "$CRED_SETTINGS" ]]; then
  if grep -q 'LEARNER_RECORD_MFE_RECORDS_PAGE_URL' "$CRED_SETTINGS"; then
    pass_ "LEARNER_RECORD_MFE_RECORDS_PAGE_URL set in production settings"
  else
    fail_ "LEARNER_RECORD_MFE_RECORDS_PAGE_URL MISSING from production settings"
  fi
fi

# 3.5 VERIFIABLE_CREDENTIALS dict has required keys
if [[ -f "$CRED_SETTINGS" ]]; then
  MISSING_VC_KEYS=()
  for key in ISSUER_DID ISSUER_NAME SIGNATURE_SUITE SIGNING_KEY_ID; do
    if ! grep -q "\"$key\"" "$CRED_SETTINGS"; then
      MISSING_VC_KEYS+=("$key")
    fi
  done
  if [[ ${#MISSING_VC_KEYS[@]} -eq 0 ]]; then
    pass_ "VERIFIABLE_CREDENTIALS dict has all required keys"
  else
    fail_ "VERIFIABLE_CREDENTIALS dict missing keys: ${MISSING_VC_KEYS[*]}"
  fi
fi

# 3.6 SIGNATURE_SUITE is Ed25519
if [[ -f "$CRED_SETTINGS" ]]; then
  if grep -q 'Ed25519Signature2020' "$CRED_SETTINGS"; then
    pass_ "SIGNATURE_SUITE is Ed25519Signature2020"
  else
    fail_ "SIGNATURE_SUITE is not Ed25519Signature2020"
  fi
fi

# 3.7 MerekaPlatformAdminMiddleware wired
if [[ -f "$CRED_SETTINGS" ]]; then
  if grep -q 'MerekaPlatformAdminMiddleware' "$CRED_SETTINGS"; then
    pass_ "MerekaPlatformAdminMiddleware wired in credentials settings"
  else
    fail_ "MerekaPlatformAdminMiddleware NOT wired in credentials settings"
  fi
fi

# 3.8 Dev settings have ENABLE_VERIFIABLE_CREDENTIALS = False (safety check)
if [[ -f "$CRED_SETTINGS_DEV" ]]; then
  if grep -q 'ENABLE_VERIFIABLE_CREDENTIALS = False' "$CRED_SETTINGS_DEV"; then
    pass_ "Dev settings: ENABLE_VERIFIABLE_CREDENTIALS = False (correct)"
  else
    fail_ "Dev settings: ENABLE_VERIFIABLE_CREDENTIALS is not False (risk of VC issuance in dev)"
  fi
fi

# ============================================================================
echo ""
echo "── Section 4: ExternalSecrets (credentials secrets) ───────────────────"
# ============================================================================

if [[ ! -f "$EXTERNAL_SECRETS" ]]; then
  fail_ "external-secrets.yaml not found: $EXTERNAL_SECRETS"
else
  REQUIRED_SECRETS=(
    "CREDENTIALS_SECRET_KEY"
    "CREDENTIALS_BACKEND_OAUTH2_SECRET"
    "CREDENTIALS_SSO_OAUTH2_SECRET"
    "JWT_SECRET_KEY_CREDENTIALS"
    "VC_SIGNING_PRIVATE_KEY"
    "MYSQL_CREDENTIALS_PASSWORD"
  )

  for secret_key in "${REQUIRED_SECRETS[@]}"; do
    if grep -q "secretKey: $secret_key" "$EXTERNAL_SECRETS"; then
      pass_ "ExternalSecret mapped: $secret_key"
    else
      fail_ "ExternalSecret MISSING: $secret_key"
    fi
  done

  # Verify VC key maps from bbi-k8 project
  if grep -A3 'VC_SIGNING_PRIVATE_KEY' "$EXTERNAL_SECRETS" | grep -q 'MEREKA_LMS_VC_SIGNING_PRIVATE_KEY'; then
    pass_ "VC_SIGNING_PRIVATE_KEY maps from MEREKA_LMS_VC_SIGNING_PRIVATE_KEY (bbi-k8)"
  else
    fail_ "VC_SIGNING_PRIVATE_KEY GCP SM key name is wrong (expected MEREKA_LMS_VC_SIGNING_PRIVATE_KEY)"
  fi
fi

# ============================================================================
echo ""
echo "── Section 5: VC Issuer Custom App ────────────────────────────────────"
# ============================================================================

# 5.1 VC issuer app files present
VC_ISSUER_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps/credentials_vc_issuer"
for f in __init__.py apps.py views.py urls.py setup.py; do
  if [[ -f "$VC_ISSUER_DIR/$f" ]]; then
    pass_ "VC issuer file present: credentials_vc_issuer/$f"
  else
    fail_ "VC issuer file MISSING: credentials_vc_issuer/$f"
  fi
done

# 5.2 DID document endpoint in urls.py
if [[ -f "$VC_ISSUER_URLS" ]]; then
  if grep -q '\.well-known/did\.json' "$VC_ISSUER_URLS"; then
    pass_ "DID document endpoint (.well-known/did.json) wired in vc_issuer urls.py"
  else
    fail_ "DID document endpoint MISSING from vc_issuer urls.py"
  fi
fi

# 5.3 Tutor plugin installs vc_issuer into credentials Dockerfile
if [[ -f "$MEREKA_PLUGIN" ]]; then
  if grep -q 'credentials-dockerfile-post-python-requirements' "$MEREKA_PLUGIN"; then
    pass_ "Tutor plugin hook: credentials-dockerfile-post-python-requirements present"
  else
    fail_ "Tutor plugin hook: credentials-dockerfile-post-python-requirements MISSING"
  fi
fi

# 5.4 Tutor plugin wires vc_issuer into credentials URL patterns
if [[ -f "$MEREKA_PLUGIN" ]]; then
  if grep -q 'credentials-urlpatterns' "$MEREKA_PLUGIN"; then
    pass_ "Tutor plugin hook: credentials-urlpatterns present"
  else
    fail_ "Tutor plugin hook: credentials-urlpatterns MISSING"
  fi
fi

# 5.5 Settings guard: credentials_vc_issuer installed via importlib.util
if [[ -f "$CRED_SETTINGS" ]]; then
  if grep -q 'credentials_vc_issuer' "$CRED_SETTINGS" && grep -q 'find_spec' "$CRED_SETTINGS"; then
    pass_ "Credentials settings: credentials_vc_issuer loaded with fallback guard"
  else
    fail_ "Credentials settings: credentials_vc_issuer loading guard NOT present"
  fi
fi

# 5.6 cryptography library installed for Ed25519 key operations
if [[ -f "$MEREKA_PLUGIN" ]]; then
  if grep -q 'cryptography>=41' "$MEREKA_PLUGIN"; then
    pass_ "Tutor plugin installs cryptography>=41.0.0 for Ed25519 key ops"
  else
    fail_ "cryptography>=41.0.0 NOT installed by Tutor plugin (Ed25519 key derivation will fail)"
  fi
fi

# 5.7 tzdata package installed so ZoneInfo("UTC") works in minimal images
if [[ -f "$MEREKA_PLUGIN" ]]; then
  if grep -q 'tzdata>=2024.1' "$MEREKA_PLUGIN"; then
    pass_ "Tutor plugin installs tzdata>=2024.1 for credentials timezone stability"
  else
    fail_ "tzdata>=2024.1 NOT installed by Tutor plugin (credentials ZoneInfo lookups may fail)"
  fi
fi

# ============================================================================
echo ""
echo "── Section 6: LMS → Credentials Wiring ───────────────────────────────"
# ============================================================================

if [[ -f "$LMS_SETTINGS" ]]; then
  # 6.1 CREDENTIALS_INTERNAL_SERVICE_URL
  if grep -q 'CREDENTIALS_INTERNAL_SERVICE_URL' "$LMS_SETTINGS"; then
    pass_ "LMS settings: CREDENTIALS_INTERNAL_SERVICE_URL defined"
  else
    fail_ "LMS settings: CREDENTIALS_INTERNAL_SERVICE_URL MISSING"
  fi

  # 6.2 CREDENTIALS_PUBLIC_SERVICE_URL
  if grep -q 'CREDENTIALS_PUBLIC_SERVICE_URL' "$LMS_SETTINGS"; then
    pass_ "LMS settings: CREDENTIALS_PUBLIC_SERVICE_URL defined"
  else
    fail_ "LMS settings: CREDENTIALS_PUBLIC_SERVICE_URL MISSING"
  fi

  # 6.3 CREDENTIALS_SERVICE_USERNAME
  if grep -q 'CREDENTIALS_SERVICE_USERNAME' "$LMS_SETTINGS"; then
    pass_ "LMS settings: CREDENTIALS_SERVICE_USERNAME defined"
  else
    fail_ "LMS settings: CREDENTIALS_SERVICE_USERNAME MISSING"
  fi

  # 6.4 Default URL points to credentials subdomain (not localhost or 127.0.0.1)
  if grep -A3 'CREDENTIALS_INTERNAL_SERVICE_URL' "$LMS_SETTINGS" | grep -q 'MEREKA_CREDENTIALS_BASE_URL'; then
    pass_ "LMS CREDENTIALS_INTERNAL_SERVICE_URL defaults to MEREKA_CREDENTIALS_BASE_URL"
  else
    fail_ "LMS CREDENTIALS_INTERNAL_SERVICE_URL default may be wrong (not using MEREKA_CREDENTIALS_BASE_URL)"
  fi
else
  skip_ "LMS production.py not found — cannot verify LMS → Credentials wiring"
fi

# ============================================================================
echo ""
echo "── Section 7: Learner Record MFE Build ────────────────────────────────"
# ============================================================================

if [[ -f "$MFE_DOCKERFILE" ]]; then
  # 7.1 learner-record build stage present
  if grep -q 'learner-record-git' "$MFE_DOCKERFILE"; then
    pass_ "MFE Dockerfile: learner-record build stage present"
  else
    fail_ "MFE Dockerfile: learner-record build stage MISSING"
  fi

  # 7.2 learner-record source pinned to release/ulmo.1
  if grep -q 'frontend-app-learner-record.git#release/ulmo.1' "$MFE_DOCKERFILE"; then
    pass_ "MFE Dockerfile: learner-record pinned to release/ulmo.1"
  else
    fail_ "MFE Dockerfile: learner-record NOT pinned to release/ulmo.1"
  fi

  # 7.3 learner-record dist copied in final image stage
  if grep -q 'COPY --from=learner-record-prod /openedx/app/dist /openedx/dist/learner-record' "$MFE_DOCKERFILE"; then
    pass_ "MFE Dockerfile: learner-record dist copied to /openedx/dist/learner-record"
  else
    fail_ "MFE Dockerfile: learner-record dist NOT copied in final stage"
  fi

  # 7.4 PUBLIC_PATH is /learner-record/
  if grep -A5 '#### learner-record (common)' "$MFE_DOCKERFILE" 2>/dev/null | grep -q "PUBLIC_PATH='/learner-record/'" || \
     grep -q "PUBLIC_PATH='/learner-record/'" "$MFE_DOCKERFILE"; then
    pass_ "MFE Dockerfile: learner-record PUBLIC_PATH=/learner-record/"
  else
    fail_ "MFE Dockerfile: learner-record PUBLIC_PATH not set to /learner-record/"
  fi
else
  skip_ "MFE Dockerfile not found: $MFE_DOCKERFILE"
fi

# ============================================================================
echo ""
echo "── Section 8: Monitoring ──────────────────────────────────────────────"
# ============================================================================

if [[ -f "$PROMETHEUS_RULE" ]]; then
  # 8.1 PrometheusRule file exists
  pass_ "credentials-alerts PrometheusRule file exists"

  # 8.2 Required alert rules present
  REQUIRED_ALERTS=(
    "VCIssuanceLatencyHigh"
    "VCIssuanceFailureSpike"
    "VCDIDDocumentUnavailable"
  )
  for alert in "${REQUIRED_ALERTS[@]}"; do
    if grep -q "alert: $alert" "$PROMETHEUS_RULE"; then
      pass_ "PrometheusRule: $alert alert defined"
    else
      fail_ "PrometheusRule: $alert alert MISSING"
    fi
  done
else
  fail_ "credentials-alerts PrometheusRule NOT found: $PROMETHEUS_RULE"
fi

# ============================================================================
echo ""
echo "── Section 9: Kustomization ───────────────────────────────────────────"
# ============================================================================

if [[ -f "$KUSTOMIZATION" ]]; then
  # 9.1 credentials-settings ConfigMap defined
  if grep -q 'credentials-settings' "$KUSTOMIZATION"; then
    pass_ "Kustomization: credentials-settings ConfigMap defined"
  else
    fail_ "Kustomization: credentials-settings ConfigMap NOT defined"
  fi
else
  skip_ "Kustomization file not found: $KUSTOMIZATION"
fi

# ============================================================================
echo ""
echo "── Section 10: Live Cluster Checks (kubectl) ──────────────────────────"
# ============================================================================

if [[ "$CLUSTER" != "true" ]]; then
  skip_ "Cluster checks skipped (pass --cluster to enable)"
  skip_ "credentials pod running"
  skip_ "credentials pod Ready"
  skip_ "credentials endpoints populated"
  skip_ "learner-record route reachable (HTTP 200)"
  skip_ "credentials health endpoint reachable"
  skip_ "DID document endpoint reachable"
  skip_ "credentials runtime ZoneInfo('UTC') check"
  skip_ "credentials runtime python tzdata package check"
else
  NAMESPACE="mereka-lms"

  # 10.1 kubectl available
  if ! command -v kubectl &>/dev/null; then
    skip_ "kubectl not available — skipping all cluster checks"
  else
    # 10.2 Credentials pod running
    CRED_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=credentials \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "$CRED_POD" ]]; then
      pass_ "Credentials pod found: $CRED_POD"
    else
      fail_ "No credentials pod found in namespace $NAMESPACE"
      CRED_POD=""
    fi

    # 10.3 Credentials pod Ready
    if [[ -n "$CRED_POD" ]]; then
      CRED_READY=$(kubectl get pod "$CRED_POD" -n "$NAMESPACE" \
        -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
      if [[ "$CRED_READY" == "true" ]]; then
        pass_ "Credentials pod is Ready"
      else
        fail_ "Credentials pod is NOT Ready"
      fi
    fi

    # 10.4 Credentials endpoints populated
    CRED_ENDPOINTS=$(kubectl get endpoints credentials -n "$NAMESPACE" \
      -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)
    if [[ -n "$CRED_ENDPOINTS" ]]; then
      pass_ "Credentials Service endpoints populated (pod IP: $CRED_ENDPOINTS)"
    else
      fail_ "Credentials Service endpoints are empty — Service cannot route traffic"
    fi

    CRED_INTERNAL_HOST="${CREDENTIALS_INTERNAL_HOST_HEADER:-credentials.academyv2.mereka.io}"

    # 10.5 Credentials health endpoint reachable
    if [[ -n "$CRED_POD" ]]; then
      HEALTH_STATUS="$(kubectl exec -i "$CRED_POD" -n "$NAMESPACE" -- \
        python - "$CRED_INTERNAL_HOST" <<'PY' || echo "FAILED"
import sys
import urllib.request

host = sys.argv[1]
req = urllib.request.Request(
    "http://127.0.0.1:8000/health/",
    headers={"Host": host},
)
with urllib.request.urlopen(req, timeout=10) as resp:
    print(resp.read().decode("utf-8", errors="replace")[:500])
PY
)"
      if echo "$HEALTH_STATUS" | grep -qi '"overall_status"[[:space:]]*:[[:space:]]*"OK"\|ok\|healthy'; then
        pass_ "Credentials health endpoint responds OK (Host: ${CRED_INTERNAL_HOST})"
      else
        fail_ "Credentials health endpoint did not return healthy response (Host: ${CRED_INTERNAL_HOST})"
      fi
    else
      skip_ "Credentials health check skipped (credentials pod not found)"
    fi

    ZONEINFO_OK=0
    # 10.6 Credentials runtime can resolve ZoneInfo('UTC')
    if [[ -n "$CRED_POD" ]]; then
      ZONEINFO_RESULT="$(kubectl exec "$CRED_POD" -n "$NAMESPACE" -- \
        python -c "from zoneinfo import ZoneInfo; ZoneInfo('UTC'); print('OK')" 2>&1 || true)"
      if echo "$ZONEINFO_RESULT" | grep -qx 'OK'; then
        ZONEINFO_OK=1
        pass_ "Credentials runtime resolves ZoneInfo('UTC')"
      else
        fail_ "Credentials runtime cannot resolve ZoneInfo('UTC') (output: ${ZONEINFO_RESULT})"
      fi
    else
      skip_ "ZoneInfo check skipped (credentials pod not found)"
    fi

    # 10.7 DID document endpoint returns valid JSON
    if [[ -n "$CRED_POD" ]]; then
      DID_RESPONSE="$(kubectl exec -i "$CRED_POD" -n "$NAMESPACE" -- \
        python - "$CRED_INTERNAL_HOST" <<'PY' || echo "ERROR|0|FAILED"
import sys
import urllib.error
import urllib.request

host = sys.argv[1]
req = urllib.request.Request(
    "http://127.0.0.1:8000/.well-known/did.json",
    headers={"Host": host},
)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        body = resp.read().decode("utf-8", errors="replace")[:1000]
        print(f"OK|{resp.status}|{body}")
except urllib.error.HTTPError as exc:
    body = exc.read().decode("utf-8", errors="replace")[:1000]
    print(f"HTTPERR|{exc.code}|{body}")
except Exception as exc:
    print(f"ERROR|0|{exc}")
PY
)"
      DID_MODE="$(printf "%s" "$DID_RESPONSE" | cut -d'|' -f1)"
      DID_STATUS="$(printf "%s" "$DID_RESPONSE" | cut -d'|' -f2)"
      DID_BODY="$(printf "%s" "$DID_RESPONSE" | cut -d'|' -f3-)"
      DID_BODY_PREVIEW="$(printf "%s" "$DID_BODY" | tr '\r\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-220)"
      if [[ "$DID_MODE" == "OK" ]] && echo "$DID_BODY" | grep -q '"id".*did:web:'; then
        pass_ "DID document endpoint returns valid DID document (Host: ${CRED_INTERNAL_HOST})"
      elif [[ "$ZONEINFO_OK" -eq 0 ]]; then
        warn_ "DID endpoint failure appears cascaded from timezone runtime failure (Host: ${CRED_INTERNAL_HOST}; mode=${DID_MODE}; status=${DID_STATUS}; body='${DID_BODY_PREVIEW}')"
      else
        fail_ "DID document endpoint invalid (Host: ${CRED_INTERNAL_HOST}; mode=${DID_MODE}; status=${DID_STATUS}; body='${DID_BODY_PREVIEW}')"
      fi
    else
      skip_ "DID document check skipped (credentials pod not found)"
    fi

    # 10.8 MFE pod running
    MFE_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=mfe \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "$MFE_POD" ]]; then
      pass_ "MFE pod found: $MFE_POD"
    else
      fail_ "No MFE pod found in namespace $NAMESPACE"
    fi

    # 10.9 learner-record dist directory present in MFE pod
    if [[ -n "$MFE_POD" ]]; then
      LR_DIST=$(kubectl exec "$MFE_POD" -n "$NAMESPACE" -- \
        ls /openedx/dist/learner-record/index.html 2>/dev/null || echo "MISSING")
      if [[ "$LR_DIST" == "MISSING" ]]; then
        fail_ "learner-record MFE dist NOT present in MFE pod (/openedx/dist/learner-record/index.html)"
      else
        pass_ "learner-record MFE dist present in MFE pod"
      fi
    fi

    # 10.10 Credentials runtime exposes python tzdata package (or equivalent source).
    if [[ -n "$CRED_POD" ]]; then
      TZDATA_RESULT="$(kubectl exec "$CRED_POD" -n "$NAMESPACE" -- \
        python -c "import importlib.util; print('yes' if importlib.util.find_spec('tzdata') else 'no')" 2>/dev/null || echo "no")"
      if [[ "$TZDATA_RESULT" == "yes" ]]; then
        pass_ "Credentials runtime has python tzdata package"
      else
        warn_ "Credentials runtime python tzdata package not found (acceptable if system zoneinfo is present and ZoneInfo check passed)"
      fi
    else
      skip_ "tzdata package check skipped (credentials pod not found)"
    fi
  fi
fi

# ============================================================================
echo ""
echo "========================================================================"
printf "  RESULTS: PASS=%d  FAIL=%d  SKIP=%d\n" "$PASS" "$FAIL" "$SKIP"
echo "========================================================================"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "FAIL: $FAIL check(s) failed. Review output above and consult:"
  echo "  docs/status/readiness/CREDENTIALS_READINESS.md"
  echo ""
  # Emit targeted guidance for the known gap
  if ! grep -q 'learner-record' "$MFE_CADDYFILE" 2>/dev/null; then
    echo "ACTION REQUIRED (BLOCKER): Add learner-record route to MFE Caddyfile."
    echo "  File: deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
    echo "  Add after the @mfe_learner-dashboard block:"
    echo ""
    echo "  @mfe_learner-record {"
    echo "      path /learner-record /learner-record/*"
    echo "  }"
    echo "  handle @mfe_learner-record {"
    echo "      uri strip_prefix /learner-record"
    echo "      root * /openedx/dist/learner-record"
    echo "      try_files /{path} /index.html"
    echo "      file_server"
    echo "  }"
    echo ""
  fi
  exit 1
fi

echo "All checks passed or skipped."
exit 0
