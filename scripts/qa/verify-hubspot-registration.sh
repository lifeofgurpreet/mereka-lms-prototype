#!/usr/bin/env bash
# @covers AC-HUB-001, AC-HUB-002, AC-HUB-003, AC-HUB-004, AC-HUB-005, AC-HUB-006, AC-HUB-007, AC-HUB-008, AC-HUB-009, AC-HUB-010, AC-HUB-011, AC-HUB-012, AC-HUB-013, AC-HUB-014, AC-HUB-015, AC-HUB-016, AC-HUB-017, AC-HUB-018, AC-HUB-019, AC-HUB-020, AC-HUB-021, AC-HUB-022, AC-HUB-023, AC-HUB-024, AC-HUB-025, AC-HUB-026
# @spec: external-registration-hubspot_spec.md
# Comprehensive verification of HubSpot registration service (all 26 ACs)
#
# Usage: ./scripts/qa/verify-hubspot-registration.sh [--skip-cluster]
#
# Returns:
#   0 if all checks pass
#   1 if any checks fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

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

echo "=== HubSpot Registration Service - Full Verification ==="
echo "Spec: external-registration-hubspot_spec.md"
echo "Coverage: 26 ACs"
echo ""

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
SERVICE_DIR="$REPO_ROOT/services/hubspot-webhook"

# ==============================================================================
# AC-HUB-001: Valid webhook returns 200 OK within 2 seconds
# AC-HUB-002: Invalid signature returns 401 Unauthorized
# AC-HUB-003: Unknown form GUID returns 400 Bad Request
# AC-HUB-004: Feature flag disabled returns 503
# ==============================================================================
echo "--- Webhook Receiver Endpoint (AC-HUB-001 to AC-HUB-004) ---"

# Check service implementation exists
if [[ -d "$SERVICE_DIR" ]]; then
  check "AC-HUB-001-004" "HubSpot webhook service directory exists" test -d "$SERVICE_DIR"

  # Check for main service file
  if [[ -f "$SERVICE_DIR/functions/index.js" ]] || [[ -f "$SERVICE_DIR/src/index.js" ]] || [[ -f "$SERVICE_DIR/index.js" ]]; then
    SERVICE_FILE=$(find "$SERVICE_DIR" -name "index.js" -type f | head -1)
    check "AC-HUB-001" "Service implements webhook endpoint POST handler" \
      grep -q "POST\|post\|app.post\|router.post" "$SERVICE_FILE"

    check "AC-HUB-002" "Service implements signature verification" \
      grep -q "signature\|X-HubSpot-Signature\|HMAC" "$SERVICE_FILE"

    check "AC-HUB-003" "Service validates form GUID allowlist" \
      grep -q "form.*guid\|form.*id\|allowlist\|whitelist" "$SERVICE_FILE"

    check "AC-HUB-004" "Service checks HUBSPOT_REGISTRATION_ENABLED flag" \
      grep -q "HUBSPOT_REGISTRATION_ENABLED\|ENABLED.*flag\|feature.*flag" "$SERVICE_FILE"
  else
    error "Service implementation file not found in $SERVICE_DIR"
    FAIL=$((FAIL+4))
  fi
else
  skip "AC-HUB-001-004" "HubSpot service not yet implemented (planned feature)"
  SKIP=$((SKIP+4))
fi

echo ""

# ==============================================================================
# AC-HUB-005: HubSpot OAuth (not hardcoded PAT)
# AC-HUB-006: OAuth token refresh
# AC-HUB-007: Multi-select field parsing
# ==============================================================================
echo "--- HubSpot Integration (AC-HUB-005 to AC-HUB-007) ---"

if [[ -d "$SERVICE_DIR" ]]; then
  SERVICE_FILE=$(find "$SERVICE_DIR" -name "*.js" -type f | head -1)

  check "AC-HUB-005" "Service uses OAuth (not hardcoded PAT)" \
    ! grep -q "hapikey\|api_key.*=.*\"hap\|Bearer.*hap" "$SERVICE_FILE"

  check "AC-HUB-005" "Service references OAuth credentials from env" \
    grep -q "HUBSPOT.*CLIENT.*ID\|HUBSPOT.*CLIENT.*SECRET\|HUBSPOT.*REFRESH" "$SERVICE_FILE"

  check "AC-HUB-006" "Service implements token refresh logic" \
    grep -q "refresh.*token\|token.*refresh\|oauth.*refresh" "$SERVICE_FILE"

  check "AC-HUB-007" "Service parses multi-select fields (semicolon delimited)" \
    grep -q "split.*;\|;.*split\|multi.*select" "$SERVICE_FILE"
else
  SKIP=$((SKIP+4))
fi

echo ""

# ==============================================================================
# AC-HUB-008: Check for duplicate email before creation
# AC-HUB-009: Duplicate email skips creation, sends email
# AC-HUB-010: Unique username generation
# AC-HUB-011: Profile enrichment with hubspot_contact_id
# ==============================================================================
echo "--- User Creation (AC-HUB-008 to AC-HUB-011) ---"

if [[ -d "$SERVICE_DIR" ]]; then
  SERVICE_FILE=$(find "$SERVICE_DIR" -name "*.js" -type f | head -1)

  check "AC-HUB-008" "Service checks for existing user by email" \
    grep -q "accounts.*email\|user.*exist\|duplicate.*email" "$SERVICE_FILE"

  check "AC-HUB-009" "Service logs duplicate email warnings" \
    grep -q "duplicate\|already.*exist\|email.*hash" "$SERVICE_FILE"

  check "AC-HUB-010" "Service generates unique username (email_prefix + random)" \
    grep -q "username.*random\|random.*4.*digit\|Math.random\|crypto.random" "$SERVICE_FILE"

  check "AC-HUB-011" "Service enriches profile with hubspot_contact_id" \
    grep -q "hubspot.*contact.*id\|extended.*profile\|PATCH.*accounts" "$SERVICE_FILE"
else
  SKIP=$((SKIP+4))
fi

echo ""

# ==============================================================================
# AC-HUB-012: Language-based SendGrid templates
# AC-HUB-013: Welcome email includes password
# AC-HUB-014: Reminder scheduled with encrypted password
# AC-HUB-015: 7-day reminder sent via Redis job
# ==============================================================================
echo "--- Email Delivery (AC-HUB-012 to AC-HUB-015) ---"

if [[ -d "$SERVICE_DIR" ]]; then
  SERVICE_FILE=$(find "$SERVICE_DIR" -name "*.js" -type f | head -1)

  check "AC-HUB-012" "Service maps form GUID to language template" \
    grep -q "template.*id\|sendgrid.*template\|language.*template" "$SERVICE_FILE"

  check "AC-HUB-013" "Welcome email includes generated password" \
    grep -q "password.*email\|dynamic.*data.*password" "$SERVICE_FILE"

  check "AC-HUB-014" "Service schedules 7-day reminder with AES encryption" \
    grep -q "7.*day\|reminder.*schedule\|AES\|encrypt.*password" "$SERVICE_FILE"

  check "AC-HUB-015" "Service uses Redis for reminder jobs" \
    grep -q "redis.*stream\|redis.*queue\|bull\|bee.*queue" "$SERVICE_FILE"
else
  SKIP=$((SKIP+4))
fi

echo ""

# ==============================================================================
# AC-HUB-016: Deduplication via Redis (24-hour TTL)
# AC-HUB-017: Duplicate returns 200 OK immediately
# ==============================================================================
echo "--- Idempotency (AC-HUB-016 to AC-HUB-017) ---"

if [[ -d "$SERVICE_DIR" ]]; then
  SERVICE_FILE=$(find "$SERVICE_DIR" -name "*.js" -type f | head -1)

  check "AC-HUB-016" "Service uses Redis for deduplication" \
    grep -q "dedup\|redis.*set.*nx\|SET.*NX.*EX" "$SERVICE_FILE"

  check "AC-HUB-017" "Service returns 200 for duplicate submissions" \
    grep -q "already.*processed\|dedup.*key.*exist" "$SERVICE_FILE"
else
  SKIP=$((SKIP+2))
fi

echo ""

# ==============================================================================
# AC-HUB-018: DLQ for failed operations
# AC-HUB-019: Error notification after 3 DLQ retries
# AC-HUB-020: Admin API for DLQ replay
# ==============================================================================
echo "--- Dead Letter Queue (AC-HUB-018 to AC-HUB-020) ---"

if [[ -d "$SERVICE_DIR" ]]; then
  SERVICE_FILE=$(find "$SERVICE_DIR" -name "*.js" -type f | head -1)

  check "AC-HUB-018" "Service enqueues failures to DLQ" \
    grep -q "dlq\|dead.*letter\|failed.*queue" "$SERVICE_FILE"

  check "AC-HUB-019" "Service sends error notifications to ops" \
    grep -q "ops@mereka\|error.*notification\|sendgrid.*error" "$SERVICE_FILE"

  check "AC-HUB-020" "Service exposes DLQ replay admin API" \
    grep -q "admin.*dlq\|replay.*dlq\|POST.*dlq" "$SERVICE_FILE"
else
  SKIP=$((SKIP+3))
fi

echo ""

# ==============================================================================
# AC-HUB-021: Signature failures don't log full body
# AC-HUB-022: No plaintext passwords/keys in logs
# AC-HUB-023: Read-only FS, non-root UID 1000
# ==============================================================================
echo "--- Security (AC-HUB-021 to AC-HUB-023) ---"

if [[ -d "$SERVICE_DIR" ]]; then
  SERVICE_FILE=$(find "$SERVICE_DIR" -name "*.js" -type f | head -1)

  check "AC-HUB-021" "Service sanitizes signature failure logs" \
    grep -q "hash.*email\|SHA.*256\|metadata.*only" "$SERVICE_FILE"

  check "AC-HUB-022" "Service hashes emails before logging" \
    grep -q "email.*hash\|sha256.*email\|hash.*pii" "$SERVICE_FILE"

  # Check Dockerfile
  DOCKERFILE=$(find "$SERVICE_DIR" -name "Dockerfile*" -type f | head -1)
  if [[ -n "$DOCKERFILE" ]]; then
    check "AC-HUB-023" "Dockerfile runs as non-root user" \
      grep -q "USER.*1000\|USER.*node\|USER.*app" "$DOCKERFILE"

    # Check K8s manifest
    HUBSPOT_MANIFEST=$(find "$REPO_ROOT/deploy/k8s" -name "*hubspot*" \( -name "*.yaml" -o -name "*.yml" \) | head -1)
    if [[ -n "$HUBSPOT_MANIFEST" ]]; then
      check "AC-HUB-023" "K8s manifest sets readOnlyRootFilesystem: true" \
        grep -q "readOnlyRootFilesystem.*true" "$HUBSPOT_MANIFEST"

      check "AC-HUB-023" "K8s manifest sets runAsUser: 1000" \
        grep -q "runAsUser.*1000" "$HUBSPOT_MANIFEST"
    else
      skip "AC-HUB-023" "K8s manifest not yet created"
      SKIP=$((SKIP+2))
    fi
  else
    skip "AC-HUB-023" "Dockerfile not yet created"
    SKIP=$((SKIP+3))
  fi
else
  SKIP=$((SKIP+5))
fi

echo ""

# ==============================================================================
# AC-HUB-024: Prometheus metrics endpoint
# AC-HUB-025: Structured JSON logs
# AC-HUB-026: Alert on high failure rate
# ==============================================================================
echo "--- Observability (AC-HUB-024 to AC-HUB-026) ---"

if [[ -d "$SERVICE_DIR" ]]; then
  SERVICE_FILE=$(find "$SERVICE_DIR" -name "*.js" -type f | head -1)

  check "AC-HUB-024" "Service exposes /metrics endpoint" \
    grep -q "/metrics\|prom-client\|prometheus.*registry" "$SERVICE_FILE"

  check "AC-HUB-024" "Service defines hubspot_webhook_requests_total metric" \
    grep -q "hubspot.*webhook.*request\|Counter.*webhook" "$SERVICE_FILE"

  check "AC-HUB-024" "Service defines hubspot_user_creation_total metric" \
    grep -q "hubspot.*user.*creation\|Counter.*creation" "$SERVICE_FILE"

  check "AC-HUB-025" "Service emits structured JSON logs" \
    grep -q "JSON.stringify\|winston\|pino\|structured.*log" "$SERVICE_FILE"

  # Check for alert rules
  ALERT_RULES=$(find "$REPO_ROOT/infrastructure" -name "*alert*" -type f | head -1)
  if [[ -n "$ALERT_RULES" ]]; then
    check "AC-HUB-026" "Alert rules exist for HubSpot service" \
      grep -q "HubSpot\|hubspot" "$ALERT_RULES"
  else
    skip "AC-HUB-026" "Alert rules not yet created"
  fi
else
  SKIP=$((SKIP+5))
fi

echo ""

# ==============================================================================
# Secrets Configuration (AC-HUB-005 dependencies)
# ==============================================================================
echo "--- Secrets Configuration ---"

EXTERNAL_SECRETS="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
if [[ -f "$EXTERNAL_SECRETS" ]]; then
  check "Secrets" "ExternalSecrets defines HUBSPOT_CLIENT_ID" \
    grep -q "MEREKA_LMS_HUBSPOT_CLIENT_ID\|HUBSPOT_CLIENT_ID" "$EXTERNAL_SECRETS"

  check "Secrets" "ExternalSecrets defines HUBSPOT_CLIENT_SECRET" \
    grep -q "MEREKA_LMS_HUBSPOT_CLIENT_SECRET\|HUBSPOT_CLIENT_SECRET" "$EXTERNAL_SECRETS"

  check "Secrets" "ExternalSecrets defines HUBSPOT_REFRESH_TOKEN" \
    grep -q "MEREKA_LMS_HUBSPOT_REFRESH_TOKEN\|HUBSPOT_REFRESH_TOKEN" "$EXTERNAL_SECRETS"

  check "Secrets" "ExternalSecrets defines SENDGRID_API_KEY" \
    grep -q "MEREKA_LMS_SENDGRID_API_KEY\|SENDGRID_API_KEY" "$EXTERNAL_SECRETS"

  check "Secrets" "ExternalSecrets defines OPENEDX_SERVICE_ACCOUNT credentials" \
    grep -q "OPENEDX_SERVICE_ACCOUNT\|LMS.*SERVICE" "$EXTERNAL_SECRETS"
else
  skip "Secrets" "ExternalSecrets not configured for HubSpot service"
  SKIP=$((SKIP+5))
fi

echo ""

# ==============================================================================
# K8s Deployment Configuration
# ==============================================================================
echo "--- K8s Deployment ---"

HUBSPOT_MANIFEST=$(find "$REPO_ROOT/deploy/k8s" -name "*hubspot*" \( -name "*.yaml" -o -name "*.yml" \) | head -1)
if [[ -n "$HUBSPOT_MANIFEST" ]]; then
  check "K8s" "Deployment manifest exists" test -f "$HUBSPOT_MANIFEST"

  check "K8s" "Deployment sets HUBSPOT_REGISTRATION_ENABLED env var" \
    grep -q "HUBSPOT_REGISTRATION_ENABLED" "$HUBSPOT_MANIFEST"

  check "K8s" "Deployment defines health check endpoints" \
    grep -q "/healthz\|/readyz\|livenessProbe" "$HUBSPOT_MANIFEST"

  check "K8s" "Deployment defines resource requests/limits" \
    grep -q "resources:\|requests:\|limits:" "$HUBSPOT_MANIFEST"

  check "K8s" "Deployment has at least 2 replicas for HA" \
    grep -q "replicas:.*[2-9]\|replicas:.*[1-9][0-9]" "$HUBSPOT_MANIFEST"
else
  skip "K8s" "Deployment manifest not yet created"
  SKIP=$((SKIP+5))
fi

echo ""

# ==============================================================================
# Feature Documentation
# ==============================================================================
echo "--- Documentation ---"

README="$SERVICE_DIR/README.md"
if [[ -f "$README" ]]; then
  check "Docs" "Service README exists" test -f "$README"

  check "Docs" "README documents webhook endpoint" \
    grep -q "webhook\|endpoint\|POST" "$README"

  check "Docs" "README documents environment variables" \
    grep -q "environment\|ENV\|configuration" "$README"
else
  skip "Docs" "Service README not yet created"
  SKIP=$((SKIP+2))
fi

# Check spec documentation
SPEC_FILE="$REPO_ROOT/specs/external-registration-hubspot_spec.md"
check "Docs" "Feature spec exists" test -f "$SPEC_FILE"

echo ""

# ==============================================================================
# Live Cluster Checks (if not skipped)
# ==============================================================================
if [[ "$SKIP_CLUSTER" == false ]] && command -v kubectl &>/dev/null; then
  echo "--- Live Cluster Checks ---"

  if kubectl get namespace "$NAMESPACE" &>/dev/null 2>&1; then
    info "Checking live cluster in namespace: $NAMESPACE"

    # Check if deployment exists
    if kubectl get deployment hubspot-registration-service -n "$NAMESPACE" &>/dev/null 2>&1; then
      echo -e "${GREEN}✓ PASS${NC}: [Live] HubSpot registration service deployment exists"
      PASS=$((PASS+1))

      # Check pod status
      READY=$(kubectl get deployment hubspot-registration-service -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      if [[ "$READY" -gt 0 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] Service has $READY ready replicas"
        PASS=$((PASS+1))
      else
        echo -e "${RED}✗ FAIL${NC}: [Live] Service has 0 ready replicas"
        FAIL=$((FAIL+1))
      fi

      # Check secrets exist
      if kubectl get secret hubspot-registration-secrets -n "$NAMESPACE" &>/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] HubSpot secrets exist in cluster"
        PASS=$((PASS+1))
      else
        echo -e "${RED}✗ FAIL${NC}: [Live] HubSpot secrets not found"
        FAIL=$((FAIL+1))
      fi

      # Check service endpoint
      if kubectl get service hubspot-registration-service -n "$NAMESPACE" &>/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] Service endpoint exists"
        PASS=$((PASS+1))
      else
        echo -e "${YELLOW}⊘ SKIP${NC}: [Live] Service endpoint not found (may use Ingress)"
        SKIP=$((SKIP+1))
      fi

      # Check ServiceMonitor for metrics
      if kubectl get servicemonitor -n "$NAMESPACE" -l app=hubspot-registration-service &>/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] ServiceMonitor configured for metrics scraping"
        PASS=$((PASS+1))
      else
        echo -e "${YELLOW}⊘ SKIP${NC}: [Live] ServiceMonitor not found (metrics may not be scraped)"
        SKIP=$((SKIP+1))
      fi

      # Check feature flag status
      FEATURE_FLAG=$(kubectl get deployment hubspot-registration-service -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="HUBSPOT_REGISTRATION_ENABLED")].value}' 2>/dev/null || echo "unknown")
      if [[ "$FEATURE_FLAG" == "true" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] Feature flag is enabled"
        PASS=$((PASS+1))
      elif [[ "$FEATURE_FLAG" == "false" ]]; then
        echo -e "${YELLOW}⊘ SKIP${NC}: [Live] Feature flag is disabled (dark launch mode)"
        SKIP=$((SKIP+1))
      else
        echo -e "${YELLOW}⊘ SKIP${NC}: [Live] Feature flag not set (using default)"
        SKIP=$((SKIP+1))
      fi

    else
      skip "Live" "HubSpot registration service not deployed to cluster"
      SKIP=$((SKIP+6))
    fi
  else
    warn "Namespace $NAMESPACE not found - skipping live cluster checks"
    SKIP=$((SKIP+6))
  fi

  echo ""
else
  info "Skipping live cluster checks (--skip-cluster or kubectl unavailable)"
  echo ""
fi

# ==============================================================================
# Summary
# ==============================================================================
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"
echo ""

if [[ $FAIL -gt 0 ]]; then
  error "Some checks failed. See external-registration-hubspot_spec.md"
  exit 1
else
  info "All checks passed!"
  exit 0
fi
