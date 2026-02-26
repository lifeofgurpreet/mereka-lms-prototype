#!/usr/bin/env bash
# Build observability coverage matrix artifacts (repo + runtime) for ServiceMonitors and PrometheusRules.
#
# Usage:
#   ./scripts/qa/build-observability-coverage-matrix.sh --mode local|runtime|all \
#     [--out-json var/ci/observability-coverage-runtime.json] \
#     [--out-md var/ci/observability-coverage-runtime.md]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MODE="all"
OUT_JSON=""
OUT_MD=""
KUSTOMIZATION_PATH="${COVERAGE_KUSTOMIZATION_PATH:-deploy/k8s/base/monitoring/kustomization.yaml}"
MONITORING_DIR="${COVERAGE_MONITORING_DIR:-deploy/k8s/base/monitoring}"
APP_NAMESPACE="${COVERAGE_APP_NAMESPACE:-mereka-lms}"
MONITORING_NAMESPACE="${COVERAGE_MONITORING_NAMESPACE:-monitoring}"
K8S_CONTEXT="${COVERAGE_K8S_CONTEXT:-}"
ENV_LABEL="${COVERAGE_ENV_LABEL:-unknown}"
DISPATCH_PROFILE="${COVERAGE_DISPATCH_PROFILE:-custom}"
STRICT="${COVERAGE_STRICT:-0}"
TIMEOUT_SECONDS="${COVERAGE_KUBECTL_TIMEOUT:-5}"

usage() {
  cat <<'EOF_USAGE'
Usage:
  ./scripts/qa/build-observability-coverage-matrix.sh --mode local|runtime|all \
    [--out-json <path>] [--out-md <path>] [--strict]
EOF_USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-all}"
      shift 2
      ;;
    --out-json)
      OUT_JSON="${2:-}"
      shift 2
      ;;
    --out-md)
      OUT_MD="${2:-}"
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

if [[ "$MODE" != "local" && "$MODE" != "runtime" && "$MODE" != "all" ]]; then
  echo "Invalid mode: $MODE" >&2
  usage
  exit 1
fi

if [[ -z "$OUT_JSON" ]]; then
  OUT_JSON="var/ci/observability-coverage-${MODE}.json"
fi
if [[ -z "$OUT_MD" ]]; then
  OUT_MD="var/ci/observability-coverage-${MODE}.md"
fi

mkdir -p "$(dirname "$OUT_JSON")"
mkdir -p "$(dirname "$OUT_MD")"

REQUIRED_SERVICE_MONITORS=(
  "servicemonitor-lms.yaml"
  "servicemonitor-cms.yaml"
  "servicemonitor-mysql.yaml"
  "servicemonitor-redis.yaml"
  "servicemonitor-enterprise.yaml"
  "servicemonitor-xqueue.yaml"
  "servicemonitor-mux.yaml"
  "servicemonitor-caddy.yaml"
  "servicemonitor-mfe.yaml"
  "servicemonitor-forum.yaml"
  "servicemonitor-discovery.yaml"
  "servicemonitor-ecommerce.yaml"
  "servicemonitor-credentials.yaml"
  "servicemonitor-purchase-gateway.yaml"
)

REQUIRED_SERVICE_MONITOR_RUNTIME=(
  "lms-metrics"
  "cms-metrics"
  "mysql-metrics"
  "redis-metrics"
  "enterprise-catalog-metrics"
  "xqueue-metrics"
  "mux-delivery-monitor"
  "caddy-metrics"
  "mfe-metrics"
  "forum-metrics"
  "discovery-metrics"
  "ecommerce-metrics"
  "credentials-metrics"
  "purchase-gateway-metrics"
)

REQUIRED_PROMETHEUSRULES=(
  "prometheusrule-lms.yaml"
  "prometheusrule-enterprise.yaml"
  "prometheusrule-velero.yaml"
  "prometheusrule-slo.yaml"
  "prometheusrule-auth.yaml"
  "prometheusrule-caddy.yaml"
  "prometheusrule-services.yaml"
  "prometheusrule-video.yaml"
  "prometheusrule-email.yaml"
  "prometheusrule-libraries.yaml"
  "prometheusrule-ora2.yaml"
  "prometheusrule-credentials.yaml"
)

REQUIRED_PROMETHEUSRULE_RUNTIME=(
  "lms-alerts"
  "enterprise-alerts"
  "velero-alerts"
  "slo-recording-rules"
  "auth-alerts"
  "caddy-alerts"
  "services-alerts"
  "video-alerts"
  "email-alerts"
  "library-alerts"
  "ora2-operations"
  "credentials-alerts"
)

RESULTS_FILE="$(mktemp -t obs-coverage-matrix.XXXXXX)"
trap 'rm -f "$RESULTS_FILE"' EXIT

record() {
  local status="$1"
  local category="$2"
  local check_id="$3"
  local detail="$4"
  printf '%s\t%s\t%s\t%s\n' "$status" "$category" "$check_id" "$detail" >> "$RESULTS_FILE"
}

kubectl_cmd() {
  if [[ -n "$K8S_CONTEXT" ]]; then
    kubectl --context "$K8S_CONTEXT" "$@"
  else
    kubectl "$@"
  fi
}

has_runtime_access=0
if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  if command -v kubectl >/dev/null 2>&1; then
    set +e
    # Keep the probe resilient in minimal shells where `timeout` may be absent.
    # `kubectl --request-timeout` is available in all supported clients and avoids
    # shell-level command lookup pitfalls.
    kubectl_cmd --request-timeout "${TIMEOUT_SECONDS}s" get namespace "$APP_NAMESPACE" >/dev/null 2>&1
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      has_runtime_access=1
    else
      if [[ "$STRICT" == "1" ]]; then
        record fail "runtime_prereq" "cluster" "kubernetes cluster not reachable for selected namespace"
      else
        record skip "runtime_prereq" "cluster" "kubernetes cluster not reachable for selected namespace"
      fi
    fi
  else
    if [[ "$STRICT" == "1" ]]; then
      record fail "runtime_prereq" "cluster" "kubectl missing"
    else
      record skip "runtime_prereq" "cluster" "kubectl missing"
    fi
  fi
fi

runtime_namespaces() {
  local ns
  if [[ -n "${APP_NAMESPACE}" ]]; then
    printf '%s\n' "$APP_NAMESPACE"
  fi
  if [[ -n "${MONITORING_NAMESPACE}" && "${MONITORING_NAMESPACE}" != "${APP_NAMESPACE}" ]]; then
    printf '%s\n' "$MONITORING_NAMESPACE"
  fi
}

resource_exists() {
  local resource_kind="$1"
  local resource_name="$2"

  local ns
  for ns in $(runtime_namespaces); do
    if kubectl_cmd get "$resource_kind" "$resource_name" -n "$ns" >/dev/null 2>&1; then
      echo "$ns"
      return 0
    fi
  done

  return 1
}

resource_exists_with_alias() {
  local resource_kind="$1"
  local resource_name="$2"

  local namespace
  local -a candidates

  candidates=("$resource_name")

  if [[ "$resource_kind" == "servicemonitor" ]]; then
    case "$resource_name" in
      caddy-metrics)
        candidates+=("caddy")
        ;;
      caddy)
        candidates+=("caddy-metrics")
        ;;
    esac
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    namespace="$(resource_exists "$resource_kind" "$candidate" || true)"
    if [[ -n "$namespace" ]]; then
      echo "${namespace}|${candidate}"
      return 0
    fi
  done

  return 1
}

declare -A sm_file_set
for sm in "${REQUIRED_SERVICE_MONITORS[@]}"; do
  sm_file_set[$sm]=1
done

declare -A pr_file_set
for pr in "${REQUIRED_PROMETHEUSRULES[@]}"; do
  pr_file_set[$pr]=1
done

# Repo-only checks
for sm in "${REQUIRED_SERVICE_MONITORS[@]}"; do
  sm_path="$MONITORING_DIR/$sm"
  if [[ -f "$sm_path" ]]; then
    record pass "repo" "service-monitor-file" "$sm" "present at $sm_path"
  else
    record fail "repo" "service-monitor-file" "$sm" "missing from monitoring dir"
  fi

  if [[ -f "$KUSTOMIZATION_PATH" && -n "$(grep -F "$sm" "$KUSTOMIZATION_PATH" 2>/dev/null)" ]]; then
    record pass "repo" "service-monitor-in-kustomization" "$sm" "listed in kustomization"
  else
    record fail "repo" "service-monitor-in-kustomization" "$sm" "missing in kustomization"
  fi
done

repo_sm_files=("$MONITORING_DIR"/servicemonitor-*.yaml)
if [[ -n "${repo_sm_files[0]:-}" && -e "${repo_sm_files[0]}" ]]; then
  for sm_file in "${repo_sm_files[@]}"; do
    sm_base="$(basename "$sm_file")"
    if [[ -z "${sm_file_set[$sm_base]:-}" ]]; then
      record pass "repo" "service-monitor-extra" "$sm_base" "extra service monitor present in directory"
    fi
  done
else
  record fail "repo" "service-monitor-dir" "servicemonitor" "no service monitor files found"
fi

for pr in "${REQUIRED_PROMETHEUSRULES[@]}"; do
  pr_path="$MONITORING_DIR/$pr"
  if [[ -f "$pr_path" ]]; then
    record pass "repo" "prometheusrule-file" "$pr" "present at $pr_path"
  else
    record fail "repo" "prometheusrule-file" "$pr" "missing from monitoring dir"
  fi

  if [[ -f "$KUSTOMIZATION_PATH" && -n "$(grep -F "$pr" "$KUSTOMIZATION_PATH" 2>/dev/null)" ]]; then
    record pass "repo" "prometheusrule-in-kustomization" "$pr" "listed in kustomization"
  else
    record fail "repo" "prometheusrule-in-kustomization" "$pr" "missing in kustomization"
  fi
done

repo_pr_files=("$MONITORING_DIR"/prometheusrule-*.yaml)
if [[ -n "${repo_pr_files[0]:-}" && -e "${repo_pr_files[0]}" ]]; then
  for pr_file in "${repo_pr_files[@]}"; do
    pr_base="$(basename "$pr_file")"
    if [[ -z "${pr_file_set[$pr_base]:-}" ]]; then
      record pass "repo" "prometheusrule-extra" "$pr_base" "extra prometheusrule present in directory"
    fi
  done
else
  record fail "repo" "prometheusrule-dir" "prometheusrule" "no prometheusrule files found"
fi

# Runtime checks
if [[ "$has_runtime_access" -eq 1 ]]; then
  for sm in "${REQUIRED_SERVICE_MONITOR_RUNTIME[@]}"; do
    # Keep command substitution non-fatal in strict mode when a resource is absent.
    runtime_hit="$(resource_exists_with_alias servicemonitor "$sm" || true)"
    if [[ -n "$runtime_hit" ]]; then
      runtime_ns="${runtime_hit%|*}"
      runtime_name="${runtime_hit#*|}"
      if [[ "$runtime_name" != "$sm" ]]; then
        record pass "runtime" "service-monitor-live" "$sm" "found as alias '$runtime_name' in namespace $runtime_ns"
      else
        record pass "runtime" "service-monitor-live" "$sm" "found in namespace $runtime_ns"
      fi
    else
      if [[ "$STRICT" == "1" ]]; then
        record fail "runtime" "service-monitor-live" "$sm" "missing in cluster"
      else
        record skip "runtime" "service-monitor-live" "$sm" "missing in cluster"
      fi
    fi
  done

  for pr in "${REQUIRED_PROMETHEUSRULE_RUNTIME[@]}"; do
    # Keep command substitution non-fatal in strict mode when a resource is absent.
    runtime_ns="$(resource_exists prometheusrules.monitoring.coreos.com "$pr" || true)"
    if [[ -n "$runtime_ns" ]]; then
      record pass "runtime" "prometheusrule-live" "$pr" "found in namespace $runtime_ns"
    else
      if [[ "$STRICT" == "1" ]]; then
        record fail "runtime" "prometheusrule-live" "$pr" "missing in cluster"
      else
        record skip "runtime" "prometheusrule-live" "$pr" "missing in cluster"
      fi
    fi
  done
else
  if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
    for sm in "${REQUIRED_SERVICE_MONITOR_RUNTIME[@]}"; do
      if [[ "$STRICT" == "1" ]]; then
        record fail "runtime" "service-monitor-live" "$sm" "runtime unavailable: cannot verify"
      else
        record skip "runtime" "service-monitor-live" "$sm" "runtime unavailable: cannot verify"
      fi
    done

    for pr in "${REQUIRED_PROMETHEUSRULE_RUNTIME[@]}"; do
      if [[ "$STRICT" == "1" ]]; then
        record fail "runtime" "prometheusrule-live" "$pr" "runtime unavailable: cannot verify"
      else
        record skip "runtime" "prometheusrule-live" "$pr" "runtime unavailable: cannot verify"
      fi
    done
  fi
fi

cat >"$OUT_JSON" <<JSON
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mode": "$MODE",
  "strict": $([[ "$STRICT" == "1" ]] && echo true || echo false),
  "identity": {
    "env": "$ENV_LABEL",
    "profile": "$DISPATCH_PROFILE",
    "context": "${K8S_CONTEXT}",
    "app_namespace": "$APP_NAMESPACE",
    "monitoring_namespace": "$MONITORING_NAMESPACE"
  },
  "summary": {
    "pass": 0,
    "fail": 0,
    "skip": 0,
    "total": 0
  },
  "coverage": []
}
JSON

python3 - "$OUT_JSON" "$RESULTS_FILE" <<'PY'
import json
import sys

from collections import defaultdict

out_path, results_path = sys.argv[1], sys.argv[2]
items = []
counts = defaultdict(int)

with open(results_path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t", 3)
        if len(parts) < 4:
            continue
        status, category, check_id, detail = parts
        counts[status] += 1
        items.append({
            "status": status,
            "category": category,
            "id": check_id,
            "detail": detail,
        })

payload = json.loads(open(out_path, "r", encoding="utf-8").read())
payload["summary"]["pass"] = counts.get("pass", 0)
payload["summary"]["fail"] = counts.get("fail", 0)
payload["summary"]["skip"] = counts.get("skip", 0)
payload["summary"]["total"] = counts.get("pass", 0) + counts.get("fail", 0) + counts.get("skip", 0)
payload["coverage"] = items

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
    f.write("\n")
PY

{
  echo "# Observability Coverage Matrix"
  echo ""
  echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- mode: $MODE"
  echo "- strict: $([ "$STRICT" -eq 1 ] && echo true || echo false)"
  echo "- identity: env=${ENV_LABEL};profile=${DISPATCH_PROFILE};context=${K8S_CONTEXT:-default};app_ns=${APP_NAMESPACE};monitoring_ns=${MONITORING_NAMESPACE}"
  echo "- mode_required_runtime: $( [[ "$MODE" == "runtime" || "$MODE" == "all" ]] && echo true || echo false )"
  echo ""
  echo "## Summary"
  echo ""
  echo "|Status|Count|"
  echo "|---|---:|"
  echo "|pass|$(awk -F $'\t' '$1=="pass"{c++} END{print c+0}' "$RESULTS_FILE")|"
  echo "|fail|$(awk -F $'\t' '$1=="fail"{c++} END{print c+0}' "$RESULTS_FILE")|"
  echo "|skip|$(awk -F $'\t' '$1=="skip"{c++} END{print c+0}' "$RESULTS_FILE")|"
  echo "|total|$(awk 'END{print NR}' "$RESULTS_FILE")|"
  echo ""

  for cat in repo runtime; do
    echo "## $cat Checks"
    echo ""
    echo "### Pass"
    echo ""
    awk -F $'\t' -v c="$cat" '$1=="pass" && $2==c {print "- " $3 ": " $4}' "$RESULTS_FILE" || true
    echo ""
    echo "### Fail"
    echo ""
    awk -F $'\t' -v c="$cat" '$1=="fail" && $2==c {print "- " $3 ": " $4}' "$RESULTS_FILE" || true
    echo ""
    echo "### Skip"
    echo ""
    awk -F $'\t' -v c="$cat" '$1=="skip" && $2==c {print "- " $3 ": " $4}' "$RESULTS_FILE" || true
    echo ""
  done

  echo "## Overall Failures"
  echo ""
  awk -F $'\t' '$1=="fail" {print "- " $2 "/" $3 ": " $4}' "$RESULTS_FILE" || true
  echo ""
} >"$OUT_MD"

if [[ "$(awk -F $'\t' '$1=="fail"{count++} END{print count+0}' "$RESULTS_FILE")" -gt 0 && "$STRICT" -eq 1 ]]; then
  echo "ERROR: coverage matrix has failures in strict mode" >&2
  echo "Report: $OUT_JSON" >&2
  exit 1
fi

echo "OK: wrote coverage matrix" >&2
echo "json: $OUT_JSON" >&2
echo "md: $OUT_MD" >&2
