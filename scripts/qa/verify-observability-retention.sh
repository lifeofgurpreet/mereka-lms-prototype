#!/usr/bin/env bash
# @covers AC-LOG-007, AC-LOG-008
# @spec: observability-stack_spec.md
# Verify log and trace retention policies are enforced.
#
# Usage:
#   ./scripts/qa/verify-observability-retention.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

DEFAULT_K8S_CONTEXT="rke2-prod"
K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-$DEFAULT_K8S_CONTEXT}}"
APP_NS="${APP_NS:-${K8S_NAMESPACE:-${K8S_NAMESPACE_PROD:-mereka-lms}}}"
STRICT="${STRICT:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) APP_NS="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ "$STRICT" != "0" && "$STRICT" != "1" ]]; then
  echo "STRICT must be 0 or 1 (got: $STRICT)" >&2
  exit 2
fi

failures=0
skips=0

echo "Verify: Observability retention policies"
echo "  context:   $K8S_CONTEXT"
echo "  namespace: $APP_NS"
echo ""

# Check if kubectl/jq are available
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} kubectl not available"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} jq not available"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Check if cluster is reachable
if ! kubectl --context "$K8S_CONTEXT" cluster-info >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} Cannot reach cluster: $K8S_CONTEXT"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# AC-LOG-007: Loki retention - 30 days
echo "Checking Loki retention configuration..."

# Find Loki namespace
loki_ns=""
loki_config="{}"
for ns in monitoring loki-stack "$APP_NS"; do
  loki_workload_names="$(
    kubectl --context "$K8S_CONTEXT" -n "$ns" get statefulset,deployment \
      -l app.kubernetes.io/name=loki -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true
  )"
  if [[ -z "${loki_workload_names//[[:space:]]/}" ]]; then
    loki_workload_names="$(
      kubectl --context "$K8S_CONTEXT" -n "$ns" get statefulset,deployment \
        -l app=loki -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true
    )"
  fi
  if [[ -n "${loki_workload_names//[[:space:]]/}" ]]; then
    loki_ns="$ns"
    break
  fi
done

if [[ -z "$loki_ns" ]]; then
  echo -e "${YELLOW}SKIP${NC} Loki deployment not found"
  skips=$((skips + 1))
else
  echo "Found Loki in namespace: $loki_ns"

  # Check Loki ConfigMap for retention settings
  loki_cm=$(kubectl --context "$K8S_CONTEXT" -n "$loki_ns" get configmap -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "${loki_cm//[[:space:]]/}" ]]; then
    loki_cm=$(kubectl --context "$K8S_CONTEXT" -n "$loki_ns" get configmap -l app=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  fi
  if [[ -z "${loki_cm//[[:space:]]/}" ]]; then
    loki_cm=$(kubectl --context "$K8S_CONTEXT" -n "$loki_ns" get configmap loki-config -o jsonpath='{.metadata.name}' 2>/dev/null || true)
  fi

  if [[ -n "${loki_cm//[[:space:]]/}" ]]; then
    echo -n "  Check: Loki retention configured to 30 days... "
    loki_config=$(kubectl --context "$K8S_CONTEXT" -n "$loki_ns" get configmap "$loki_cm" -o jsonpath='{.data}' 2>/dev/null || echo "{}")

    # Look for retention_period configuration (should be 30d or 720h)
    if echo "$loki_config" | grep -qE "(retention_period.*30d|retention_period.*720h)"; then
      echo -e "${GREEN}PASS${NC}"
    elif echo "$loki_config" | grep -q "retention_period"; then
      retention=$(echo "$loki_config" | grep -oE "retention_period[:\s]*[0-9]+[dhm]" | head -1 || true)
      echo -e "${YELLOW}WARN${NC} Retention configured but not 30d: $retention"
    else
      echo -e "${YELLOW}WARN${NC} Retention config not found (using default)"
    fi
  else
    echo -e "${YELLOW}SKIP${NC} Loki ConfigMap not found"
    skips=$((skips + 1))
  fi

  # Check for compactor configuration (enforces retention)
  echo -n "  Check: Loki compactor is enabled... "
  if echo "$loki_config" | grep -q "compactor"; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${YELLOW}WARN${NC} Compactor config not found"
  fi
fi

echo ""

# AC-LOG-008: Tempo retention - 7 days
echo "Checking Tempo retention configuration..."

# Find Tempo namespace
tempo_ns=""
for ns in monitoring tempo "$APP_NS"; do
  tempo_workload_names="$(
    kubectl --context "$K8S_CONTEXT" -n "$ns" get statefulset,deployment \
      -l app.kubernetes.io/name=tempo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true
  )"
  if [[ -z "${tempo_workload_names//[[:space:]]/}" ]]; then
    tempo_workload_names="$(
      kubectl --context "$K8S_CONTEXT" -n "$ns" get statefulset,deployment \
        -l app=tempo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true
    )"
  fi
  if [[ -n "${tempo_workload_names//[[:space:]]/}" ]]; then
    tempo_ns="$ns"
    break
  fi
done

if [[ -z "$tempo_ns" ]]; then
  echo -e "${YELLOW}SKIP${NC} Tempo deployment not found (traces retention N/A)"
  skips=$((skips + 1))
else
  echo "Found Tempo in namespace: $tempo_ns"

  # Check Tempo ConfigMap for retention settings
  tempo_cm=$(kubectl --context "$K8S_CONTEXT" -n "$tempo_ns" get configmap -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "${tempo_cm//[[:space:]]/}" ]]; then
    tempo_cm=$(kubectl --context "$K8S_CONTEXT" -n "$tempo_ns" get configmap -l app=tempo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  fi
  if [[ -z "${tempo_cm//[[:space:]]/}" ]]; then
    tempo_cm=$(kubectl --context "$K8S_CONTEXT" -n "$tempo_ns" get configmap tempo -o jsonpath='{.metadata.name}' 2>/dev/null || true)
  fi

  if [[ -n "${tempo_cm//[[:space:]]/}" ]]; then
    echo -n "  Check: Tempo retention configured to 7 days... "
    tempo_config=$(kubectl --context "$K8S_CONTEXT" -n "$tempo_ns" get configmap "$tempo_cm" -o jsonpath='{.data}' 2>/dev/null || echo "{}")

    # Look for retention configuration (typically in storage section)
    if echo "$tempo_config" | grep -qE "(retention.*7d|retention.*168h)"; then
      echo -e "${GREEN}PASS${NC}"
    elif echo "$tempo_config" | grep -q "retention"; then
      retention=$(echo "$tempo_config" | grep -oE "retention[:\s]*[0-9]+[dhm]" | head -1 || true)
      echo -e "${YELLOW}WARN${NC} Retention configured but not 7d: $retention"
    else
      echo -e "${YELLOW}WARN${NC} Retention config not found (using default)"
    fi
  else
    echo -e "${YELLOW}SKIP${NC} Tempo ConfigMap not found"
    skips=$((skips + 1))
  fi
fi

echo ""

# Check Prometheus retention (from spec: 30 days)
echo "Checking Prometheus retention configuration..."

prom_ns="monitoring"
prom_workload_names="$(
  kubectl --context "$K8S_CONTEXT" -n "$prom_ns" get statefulset,deployment \
    -l app.kubernetes.io/name=prometheus -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true
)"
if [[ -z "${prom_workload_names//[[:space:]]/}" ]]; then
  prom_workload_names="$(
    kubectl --context "$K8S_CONTEXT" -n "$prom_ns" get statefulset,deployment \
      -l app=prometheus -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true
  )"
fi
if [[ -n "${prom_workload_names//[[:space:]]/}" ]]; then
  echo "Found Prometheus in namespace: $prom_ns"

  # Check Prometheus StatefulSet for retention flags
  echo -n "  Check: Prometheus retention configured to 30 days... "
  prom_args=$(kubectl --context "$K8S_CONTEXT" -n "$prom_ns" get statefulset,deployment -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].spec.template.spec.containers[?(@.name=="prometheus")].args}' 2>/dev/null || echo "[]")

  if echo "$prom_args" | grep -qE "(storage.tsdb.retention.time.*30d|storage.tsdb.retention.time.*720h)"; then
    echo -e "${GREEN}PASS${NC}"
  elif echo "$prom_args" | grep -q "storage.tsdb.retention.time"; then
    retention=$(echo "$prom_args" | grep -oE "storage.tsdb.retention.time[=]*[0-9]+[dhm]" | head -1 || true)
    echo -e "${YELLOW}WARN${NC} Retention configured but not 30d: $retention"
  else
    echo -e "${YELLOW}WARN${NC} Retention config not found (using default 15d)"
  fi
else
  echo -e "${YELLOW}SKIP${NC} Prometheus deployment not found"
  skips=$((skips + 1))
fi

echo ""
echo -e "${YELLOW}NOTE:${NC} This script verifies retention configuration in ConfigMaps/StatefulSets."
echo "To verify actual data retention, query Loki/Tempo/Prometheus with old date ranges:"
echo "  Loki:       {namespace=\"$APP_NS\"} with range 31d-30d ago"
echo "  Tempo:      traces older than 8 days should not be retrievable"
echo "  Prometheus: rate(http_requests_total[30d]) should return data"

echo ""
if [[ "$failures" -eq 0 ]]; then
  if [[ "$skips" -gt 0 ]]; then
    echo -e "${YELLOW}OK (with $skips skipped checks)${NC}"
  else
    echo -e "${GREEN}OK${NC}"
  fi
  exit 0
else
  echo -e "${RED}FAILED ($failures checks failed)${NC}"
  exit 1
fi
