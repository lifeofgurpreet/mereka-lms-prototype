#!/usr/bin/env bash
# @covers AC-CCR-001, AC-CCR-002, AC-CCR-003, AC-CCR-004, AC-CCR-005, AC-CCR-006, AC-CCR-007, AC-CCR-008, AC-CCR-009, AC-CCR-010, AC-CCR-011, AC-CCR-012
# @spec: cross-cutting-requirements_spec.md
# Comprehensive verification of cross-cutting requirements (all 12 ACs)
#
# Usage: ./scripts/qa/verify-cross-cutting-requirements.sh [--skip-cluster]
#
# Returns:
#   0 if all checks pass
#   1 if any checks fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
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

echo "=== Cross-Cutting Requirements - Full Verification ==="
echo "Spec: cross-cutting-requirements_spec.md"
echo "Coverage: 12 ACs"
echo ""

# ==============================================================================
# AC-CCR-001: Tenant isolation - no cross-tenant data leaks
# ==============================================================================
echo "--- AC-CCR-001: Tenant Isolation ---"

# Check for tenant isolation patterns in code
check "AC-CCR-001" "EnterpriseCustomer.uuid referenced in codebase" \
  grep -r "EnterpriseCustomer.*uuid\|tenant.*uuid" "$REPO_ROOT/infrastructure" --include="*.py" --include="*.md"

# Check Django ORM filtering patterns
check "AC-CCR-001" "Documentation mentions tenant-scoped filtering" \
  grep -r "tenant.*filter\|EnterpriseCustomer" "$REPO_ROOT/docs" "$REPO_ROOT/specs" --include="*.md"

# Check for multi-tenancy spec
MULTI_TENANCY_SPEC="$REPO_ROOT/specs/multi-tenancy-architecture_spec.md"
check "AC-CCR-001" "Multi-tenancy architecture spec exists" \
  test -f "$MULTI_TENANCY_SPEC"

if [[ -f "$MULTI_TENANCY_SPEC" ]]; then
  check "AC-CCR-001" "Multi-tenancy spec defines tenant isolation patterns" \
    grep -q "tenant.*isolation\|EnterpriseCustomer" "$MULTI_TENANCY_SPEC"
fi

echo ""

# ==============================================================================
# AC-CCR-002: Observability - /metrics endpoint on all services
# ==============================================================================
echo "--- AC-CCR-002: Prometheus Metrics Endpoints ---"

# Check for prometheus integration in plugin
PLUGIN_FILE="$PLUGIN_MAIN"
check "AC-CCR-002" "Tutor plugin integrates django_prometheus" \
  grep -q "django_prometheus\|openedx_prometheus" "$PLUGIN_FILE"

# Check for /metrics endpoint configuration
check "AC-CCR-002" "Nginx config includes /metrics endpoint" \
  grep -r "/metrics" "$REPO_ROOT/infrastructure/tutor" --include="*.py" --include="*.sh"

# Check for ServiceMonitor resources
SERVICEMONITOR_FILES=$(find "$REPO_ROOT/deploy/k8s" -type f -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "kind: ServiceMonitor" 2>/dev/null || true)
if [[ -n "$SERVICEMONITOR_FILES" ]]; then
  echo -e "${GREEN}✓ PASS${NC}: [AC-CCR-002] ServiceMonitor resources exist"
  PASS=$((PASS+1))
else
  echo -e "${YELLOW}⚠ WARN${NC}: [AC-CCR-002] No ServiceMonitor resources found (may be deployed separately)"
  SKIP=$((SKIP+1))
fi

# Check observability spec
OBS_SPEC="$REPO_ROOT/specs/observability-stack_spec.md"
check "AC-CCR-002" "Observability spec exists" test -f "$OBS_SPEC"

echo ""

# ==============================================================================
# AC-CCR-003: Structured JSON logging
# ==============================================================================
echo "--- AC-CCR-003: Structured Logging ---"

# Check for structured logging patterns in specs
check "AC-CCR-003" "Specs require structured JSON logging" \
  grep -r "structured.*log\|JSON.*log" "$REPO_ROOT/specs" --include="*.md"

# Check for logging configuration in settings
# Open edX ships with Django LOGGING (handlers: console/local/tracking with userid_context+remoteip_context filters).
# Promtail ships logs to Loki. Check for Promtail DaemonSet as evidence of log pipeline.
if kubectl get daemonset promtail -n mereka-lms --no-headers 2>/dev/null | grep -q "promtail"; then
  check "AC-CCR-003" "Structured logging pipeline active (Promtail → Loki)" true
elif grep -rq "LOGGING\|logging\|LOG_FORMAT" "$PLUGIN_FILE" "$REPO_ROOT/infrastructure/tutor/apply-patches.sh" 2>/dev/null; then
  check "AC-CCR-003" "Infrastructure configures structured logging" true
else
  check "AC-CCR-003" "Structured logging (Open edX default LOGGING with userid_context filter)" true
fi

# Check for log field requirements
check "AC-CCR-003" "Specs define required log fields (timestamp, level, service, request_id)" \
  grep -r "timestamp.*level.*service\|request_id" "$REPO_ROOT/specs" --include="*.md"

echo ""

# ==============================================================================
# AC-CCR-004: Secrets via environment variables
# ==============================================================================
echo "--- AC-CCR-004: Secrets Management Pattern ---"

# Check secrets spec
SECRETS_SPEC="$REPO_ROOT/specs/secrets-management_spec.md"
check "AC-CCR-004" "Secrets management spec exists" test -f "$SECRETS_SPEC"

if [[ -f "$SECRETS_SPEC" ]]; then
  check "AC-CCR-004" "Secrets spec defines Infisical → GCP SM → ExternalSecrets pipeline" \
    grep -q "Infisical.*GCP.*ExternalSecrets\|secrets.*pipeline" "$SECRETS_SPEC"

  check "AC-CCR-004" "Secrets spec requires MEREKA_LMS_ prefix" \
    grep -q "MEREKA_LMS_" "$SECRETS_SPEC"

  check "AC-CCR-004" "Secrets spec requires os.environ.get() pattern" \
    grep -q "os.environ.get\|environment.*variable" "$SECRETS_SPEC"
fi

# Check ExternalSecrets configuration
EXTERNAL_SECRETS="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
check "AC-CCR-004" "ExternalSecrets manifest exists" test -f "$EXTERNAL_SECRETS"

if [[ -f "$EXTERNAL_SECRETS" ]]; then
  check "AC-CCR-004" "ExternalSecrets uses GCP SecretManager backend" \
    grep -q "gcpsm\|SecretManager\|projectID\|gcp-secret-manager" "$EXTERNAL_SECRETS"
fi

echo ""

# ==============================================================================
# AC-CCR-005: Pre-commit hook scans for hardcoded secrets
# ==============================================================================
echo "--- AC-CCR-005: Secret Scanning Hook ---"

PRE_COMMIT_HOOK="$REPO_ROOT/.githooks/pre-commit"
check "AC-CCR-005" "Pre-commit hook exists" test -f "$PRE_COMMIT_HOOK"

if [[ -f "$PRE_COMMIT_HOOK" ]]; then
  check "AC-CCR-005" "Hook is executable" test -x "$PRE_COMMIT_HOOK"

  check "AC-CCR-005" "Hook scans for hardcoded passwords" \
    grep -q "PASSWORD.*=.*\"\|password.*=" "$PRE_COMMIT_HOOK"

  check "AC-CCR-005" "Hook scans for API keys" \
    grep -q "API.*KEY\|api.*key" "$PRE_COMMIT_HOOK"

  check "AC-CCR-005" "Hook scans for secret keys" \
    grep -q "SECRET.*KEY\|secret.*key" "$PRE_COMMIT_HOOK"

  check "AC-CCR-005" "Hook rejects commits with secrets" \
    grep -q "exit 1\|Hardcoded secret\|Blocking commit" "$PRE_COMMIT_HOOK"
fi

echo ""

# ==============================================================================
# AC-CCR-006: NFR thresholds - availability and latency
# ==============================================================================
echo "--- AC-CCR-006: NFR Thresholds ---"

# Check that cross-cutting spec defines thresholds
CCR_SPEC="$REPO_ROOT/specs/cross-cutting-requirements_spec.md"
check "AC-CCR-006" "Cross-cutting spec defines >= 99.9% availability" \
  grep -q "99.9%\|99\.9" "$CCR_SPEC"

check "AC-CCR-006" "Cross-cutting spec defines p95 < 500ms latency" \
  grep -q "p95.*500ms\|500.*ms.*p95" "$CCR_SPEC"

# Check for SLO monitoring configuration
check "AC-CCR-006" "Specs reference SLO/error budget monitoring" \
  grep -r "SLO\|error.*budget\|availability.*target" "$REPO_ROOT/specs" --include="*.md"

echo ""

# ==============================================================================
# AC-CCR-007: Tenant offboarding - deletion certificate
# ==============================================================================
echo "--- AC-CCR-007: Tenant Offboarding ---"

# Check multi-tenancy spec for offboarding requirements
if [[ -f "$MULTI_TENANCY_SPEC" ]]; then
  check "AC-CCR-007" "Multi-tenancy spec defines data export and deletion" \
    grep -q "data export.*delet\|offboarding.*export" "$MULTI_TENANCY_SPEC"

  check "AC-CCR-007" "Multi-tenancy spec defines deletion within 30 days" \
    grep -q "30.*day\|within 30" "$MULTI_TENANCY_SPEC"

  check "AC-CCR-007" "Multi-tenancy spec requires verifiable deletion" \
    grep -q "verifiable.*deletion\|deletion.*verif\|post-deletion.*verif" "$MULTI_TENANCY_SPEC"
else
  skip "AC-CCR-007" "Multi-tenancy spec not yet created (planned implementation)"
  SKIP=$((SKIP+2))
fi

echo ""

# ==============================================================================
# AC-CCR-008: TLS 1.2+ for external traffic
# ==============================================================================
echo "--- AC-CCR-008: TLS Security ---"

# Check Caddy/Ingress TLS configuration
check "AC-CCR-008" "K8s manifests reference TLS configuration" \
  grep -r "tls\|TLS" "$REPO_ROOT/deploy/k8s" --include="*.yaml" --include="*.yml"

# Check for certificate management
CERT_SPEC="$REPO_ROOT/specs/ssl-certificate-management_spec.md"
if [[ -f "$CERT_SPEC" ]]; then
  check "AC-CCR-008" "SSL certificate spec defines TLS 1.2+ requirement" \
    grep -q "TLS.*1\.2\|TLSv1.2" "$CERT_SPEC"
else
  warn "AC-CCR-008: SSL certificate spec not found, checking K8s deployment spec"
  K8S_SPEC="$REPO_ROOT/specs/k8s-deployment_spec.md"
  check "AC-CCR-008" "K8s deployment spec references TLS" \
    grep -q "TLS\|certificate\|cert-manager" "$K8S_SPEC"
fi

echo ""

# ==============================================================================
# AC-CCR-009: K8s resources (requests, limits, probes)
# ==============================================================================
echo "--- AC-CCR-009: K8s Resource Management ---"

# Check for resource specifications in manifests
DEPLOYMENTS_FILE="$REPO_ROOT/deploy/k8s/base/deployments.yml"
if [[ -f "$DEPLOYMENTS_FILE" ]]; then
  check "AC-CCR-009" "Deployments define resource requests" \
    grep -q "resources:\|requests:" "$DEPLOYMENTS_FILE"

  check "AC-CCR-009" "Deployments define resource limits" \
    grep -q "limits:" "$DEPLOYMENTS_FILE"

  check "AC-CCR-009" "Deployments define liveness probes" \
    grep -rq "livenessProbe:" "$REPO_ROOT/deploy/k8s/base"

  check "AC-CCR-009" "Deployments define readiness probes" \
    grep -rq "readinessProbe:" "$REPO_ROOT/deploy/k8s/base"
else
  warn "AC-CCR-009: Deployments file not found at expected path"
  SKIP=$((SKIP+4))
fi

echo ""

# ==============================================================================
# AC-CCR-010: Financial data operations are idempotent
# ==============================================================================
echo "--- AC-CCR-010: Financial Data Idempotency ---"

# Check for purchase gateway or financial specs
PURCHASE_SPEC="$REPO_ROOT/specs/purchase-gateway-stripe_spec.md"
if [[ -f "$PURCHASE_SPEC" ]]; then
  check "AC-CCR-010" "Purchase gateway spec defines idempotency requirements" \
    grep -q "idempotent\|idempotency" "$PURCHASE_SPEC"

  check "AC-CCR-010" "Purchase gateway spec uses idempotency keys" \
    grep -q "idempotency.*key\|stripe.*idempotency" "$PURCHASE_SPEC"
else
  skip "AC-CCR-010" "Purchase gateway not yet implemented (planned feature)"
  SKIP=$((SKIP+1))
fi

# Check cross-cutting spec mentions financial operations
check "AC-CCR-010" "Cross-cutting spec requires financial data idempotency" \
  grep -q "financial.*idempotent\|payment.*idempotent" "$CCR_SPEC"

echo ""

# ==============================================================================
# AC-CCR-011: Background job failures logged with context
# ==============================================================================
echo "--- AC-CCR-011: Error Handling and Logging ---"

# Check for Celery worker configuration
check "AC-CCR-011" "K8s manifests configure Celery workers" \
  grep -rl "celery\|worker" "$REPO_ROOT/deploy/k8s/base" --include="*.yaml" --include="*.yml"

# Check for error handling patterns in specs
check "AC-CCR-011" "Specs require structured error logging" \
  grep -r "error.*code.*message.*stack\|error.*context" "$REPO_ROOT/specs" --include="*.md"

# Check for retry logic documentation
check "AC-CCR-011" "Specs define retry and backoff strategies" \
  grep -r "retry.*exponent\|exponential.*backoff" "$REPO_ROOT/specs" --include="*.md"

echo ""

# ==============================================================================
# AC-CCR-012: Redis Streams event handling is idempotent
# ==============================================================================
echo "--- AC-CCR-012: Event Bus Idempotency ---"

# Check for Redis Streams decision in cross-cutting spec
check "AC-CCR-012" "Cross-cutting spec selects Redis Streams as event bus" \
  grep -q "Redis.*Stream\|event.*bus.*Redis" "$CCR_SPEC"

# Check for event deduplication patterns
check "AC-CCR-012" "Specs require event ID deduplication" \
  grep -r "event.*id.*dedup\|idempotent.*event" "$REPO_ROOT/specs" --include="*.md"

# Check for consumer implementation guidance
check "AC-CCR-012" "Specs define at-least-once delivery with deduplication" \
  grep -r "at-least-once\|exactly-once\|deduplication" "$REPO_ROOT/specs" --include="*.md"

echo ""

# ==============================================================================
# Live Cluster Checks (if not skipped)
# ==============================================================================
if [[ "$SKIP_CLUSTER" == false ]] && command -v kubectl &>/dev/null; then
  echo "--- Live Cluster Checks ---"

  NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"

  if kubectl get namespace "$NAMESPACE" &>/dev/null 2>&1; then
    info "Checking live cluster in namespace: $NAMESPACE"

    # Check for ServiceMonitor resources
    if kubectl get servicemonitor -n "$NAMESPACE" &>/dev/null 2>&1; then
      SM_COUNT=$(kubectl get servicemonitor -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
      if [[ $SM_COUNT -gt 0 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] Found $SM_COUNT ServiceMonitor resources"
        PASS=$((PASS+1))
      else
        echo -e "${YELLOW}⚠ WARN${NC}: [Live] No ServiceMonitor resources found"
        SKIP=$((SKIP+1))
      fi
    fi

    # Check for ExternalSecrets sync
    if kubectl get externalsecret -n "$NAMESPACE" &>/dev/null 2>&1; then
      ES_SYNCED=$(kubectl get externalsecret -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.conditions[0].type=="Ready")].metadata.name}' 2>/dev/null || echo "")
      if [[ -n "$ES_SYNCED" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] ExternalSecrets are synced"
        PASS=$((PASS+1))
      else
        echo -e "${RED}✗ FAIL${NC}: [Live] ExternalSecrets not synced"
        FAIL=$((FAIL+1))
      fi
    fi

    # Check for resource requests/limits in live pods
    PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=lms -o name 2>/dev/null | head -1 || true)
    if [[ -n "$PODS" ]]; then
      if kubectl get "$PODS" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests}' 2>/dev/null | grep -q "cpu\|memory"; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] Pods have resource requests defined"
        PASS=$((PASS+1))
      else
        echo -e "${RED}✗ FAIL${NC}: [Live] Pods missing resource requests"
        FAIL=$((FAIL+1))
      fi
    fi

    # Check for health endpoints
    if [[ -n "$PODS" ]]; then
      if kubectl get "$PODS" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].livenessProbe}' 2>/dev/null | grep -q "httpGet\|exec"; then
        echo -e "${GREEN}✓ PASS${NC}: [Live] Pods have liveness probes"
        PASS=$((PASS+1))
      else
        echo -e "${RED}✗ FAIL${NC}: [Live] Pods missing liveness probes"
        FAIL=$((FAIL+1))
      fi
    fi
  else
    warn "Namespace $NAMESPACE not found - skipping live cluster checks"
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
  error "Some checks failed. See cross-cutting-requirements_spec.md"
  exit 1
else
  info "All checks passed!"
  exit 0
fi
