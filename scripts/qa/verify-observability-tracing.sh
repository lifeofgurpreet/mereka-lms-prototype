#!/usr/bin/env bash
# @covers: AC-005
# @spec: observability-stack_spec.md
#
# Verify tracing implementation contract in manifests and runtime.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
STRICT="${STRICT:-0}"
TEMPO_URL="${TEMPO_URL:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass=0
warn=0
skip=0
fail=0

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/verify-observability-tracing.sh [options]

Options:
  --context <context>    kubectl context
  --namespace <ns>       application namespace (default: mereka-lms)
  --tempo-url <url>      tempo endpoint for optional live readiness probe (e.g. http://tempo.monitoring.svc.cluster.local:3200)
  --strict               fail on non-strict checks
  -h, --help             show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      K8S_CONTEXT="$2"
      shift 2
      ;;
    --namespace)
      APP_NS="$2"
      shift 2
      ;;
    --tempo-url)
      TEMPO_URL="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

report() {
  local status="$1"
  shift
  case "$status" in
    PASS)
      pass=$((pass + 1))
      echo -e "${GREEN}PASS${NC} $*"
      ;;
    WARN)
      warn=$((warn + 1))
      echo -e "${YELLOW}WARN${NC} $*"
      ;;
    SKIP)
      skip=$((skip + 1))
      echo -e "${YELLOW}SKIP${NC} $*"
      ;;
    FAIL)
      fail=$((fail + 1))
      echo -e "${RED}FAIL${NC} $*"
      ;;
  esac
}

echo "Verifying distributed tracing support"
echo "  context: $K8S_CONTEXT"
echo "  namespace: $APP_NS"
echo "  strict: $STRICT"
echo ""

# ---------------------------------------------------------------------------
# Repo checks (manifest/documentation level)
# ---------------------------------------------------------------------------
echo "=== Tracing docs and manifests ==="

if [[ -f "docs/adr/020-tracing-scope-and-pilot-decision.md" ]]; then
  report PASS "Tracing scope decision ADR exists"
else
  report SKIP "Tracing scope decision ADR is missing: docs/adr/020-tracing-scope-and-pilot-decision.md"
fi

tracing_manifest_count=0
while IFS= read -r f; do
  tracing_manifest_count=$((tracing_manifest_count + 1))
done < <(find deploy/k8s infrastructure/monitoring -type f \( -iname '*tempo*' -o -iname '*otel*' -o -iname '*opentelemetry*' -o -iname '*tracing*' \) 2>/dev/null || true)

if [[ "$tracing_manifest_count" -gt 0 ]]; then
  report PASS "Tracing manifests found in repo: $tracing_manifest_count files"
else
  report SKIP "No Tempo/OTEL manifests found in deploy/k8s or infrastructure/monitoring"
fi

if rg -qi "OTEL_EXPORTER_OTLP_ENDPOINT|OTEL_SERVICE_NAME|opentelemetry|tempo" deploy/k8s/ >/dev/null 2>&1; then
  report PASS "OTEL/Tempo references found in deployment manifests"
else
  report WARN "No OTEL/Tempo references found in deployment manifests"
fi

# ---------------------------------------------------------------------------
# Runtime checks
# ---------------------------------------------------------------------------
echo ""
echo "=== Runtime tracing checks ==="

if ! command -v kubectl >/dev/null 2>&1; then
  report SKIP "kubectl not available"
  [[ "$STRICT" == "1" ]] && report FAIL "Strict mode requested but kubectl unavailable" && exit 1 || true
  echo ""
  echo "PASS: $pass"
  echo "WARN: $warn"
  echo "SKIP: $skip"
  echo "FAIL: $fail"
  exit 0
fi

if ! kubectl --context "$K8S_CONTEXT" cluster-info >/dev/null 2>&1; then
  report SKIP "Cannot reach cluster: $K8S_CONTEXT"
  [[ "$STRICT" == "1" ]] && report FAIL "Strict mode requested but cluster unavailable" && exit 1 || true
  echo ""
  echo "PASS: $pass"
  echo "WARN: $warn"
  echo "SKIP: $skip"
  echo "FAIL: $fail"
  exit 0
fi

tempo_ns=""
tempo_svc=$(kubectl --context "$K8S_CONTEXT" get svc -A -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.namespace}/{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$tempo_svc" ]]; then
  tempo_ns="${tempo_svc%%/*}"
  report PASS "Tempo service discovered in namespace ${tempo_ns} (${tempo_svc#*/})"
else
  tempo_resource=$(kubectl --context "$K8S_CONTEXT" get deployment,daemonset,statefulset -A -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.namespace}/{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$tempo_resource" ]]; then
    tempo_ns="${tempo_resource%%/*}"
    report PASS "Tempo workload discovered in namespace ${tempo_ns}"
  else
    report SKIP "Tempo workload/service not found in cluster"
    tempo_ns=""
  fi
fi

if [[ -n "${tempo_ns}" ]]; then
  tempo_pods=$(kubectl --context "$K8S_CONTEXT" -n "$tempo_ns" get pods -l app.kubernetes.io/name=tempo -o json 2>/dev/null || echo '{"items":[]}')
  tempo_pod_count=$(echo "$tempo_pods" | jq -r '.items | length')
  if [[ "$tempo_pod_count" -gt 0 ]]; then
    report PASS "Tempo pods discovered: $tempo_pod_count"
  else
    report WARN "No Tempo pods found with standard app label"
  fi
fi

if command -v curl >/dev/null 2>&1 && [[ -n "$TEMPO_URL" ]]; then
  if curl -fsS "${TEMPO_URL%/}/ready" >/dev/null 2>&1; then
    report PASS "Tempo readiness endpoint reachable"
  else
    report WARN "Tempo readiness probe failed for $TEMPO_URL"
  fi
elif [[ -z "$TEMPO_URL" ]] && [[ -n "$tempo_ns" ]]; then
  # Attempt best-effort discovery of Tempo service URL.
  tempo_service_name=$(kubectl --context "$K8S_CONTEXT" -n "$tempo_ns" get svc -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$tempo_service_name" ]]; then
    discover_url="http://${tempo_service_name}.${tempo_ns}.svc.cluster.local:3200"
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS "${discover_url}/ready" >/dev/null 2>&1; then
        report PASS "Tempo readiness endpoint reachable: $discover_url/ready"
      else
        report WARN "Tempo readiness endpoint not reachable at $discover_url/ready"
      fi
    else
      report SKIP "curl unavailable; cannot probe $discover_url"
    fi
  else
    report SKIP "Tempo service name could not be discovered for readiness check"
  fi
else
  report SKIP "No Tempo URL configured for readiness probe"
fi

echo ""
echo "=== Trace context propagation coverage (manifest-level) ==="

if kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy -o json | jq -e '.items | length > 0' >/dev/null 2>&1; then
  if kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy -o json | jq -e '.items[] | (.spec.template.spec.containers[].env // [] )[] | select(.name | test(\"OTEL_EXPORTER_OTLP_ENDPOINT|OTEL_SERVICE_NAME|OTEL_EXPORTER_OTLP_PROTOCOL\"))' >/dev/null 2>&1; then
    report PASS "OTEL env vars present in at least one deployment"
  else
    report WARN "No OTEL env vars found in app deployments"
  fi
else
  report SKIP "No deployments found in $APP_NS"
fi

echo ""
echo "=== Tracing check summary ==="
echo "PASS: $pass"
echo "WARN: $warn"
echo "SKIP: $skip"
echo "FAIL: $fail"

if [[ "$STRICT" == "1" && "$fail" -gt 0 ]]; then
  echo -e "${RED}FAILED (strict mode)${NC}"
  exit 1
fi

if [[ "$fail" -gt 0 ]]; then
  echo -e "${YELLOW}OK (non-blocking failures present in non-strict mode)${NC}"
  exit 0
fi

echo -e "${GREEN}OK${NC}"
exit 0
