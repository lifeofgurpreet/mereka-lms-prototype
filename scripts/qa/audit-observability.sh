#!/usr/bin/env bash
# End-to-end observability posture audit (read-only).
#
# Goals:
# - Verify monitoring-as-code coverage in this repo (dashboards/alerts/logging metrics/uptime).
# - Verify runtime objects exist in GCP Monitoring + Logging and key in-cluster CronJobs exist.
# - Provide one deterministic report to reduce tribal knowledge.
#
# Usage:
#   ./scripts/qa/audit-observability.sh
#   ./scripts/qa/audit-observability.sh --json
#   ./scripts/qa/audit-observability.sh --project mereka-lms --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PROJECT="${GCP_PROJECT:-mereka-lms}"
K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
VELERO_NS="${VELERO_NS:-velero}"
INCLUDE_LEGACY="${INCLUDE_LEGACY_MONITORING:-0}"
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"
MODE="local" # local | runtime | all
JSON_OUT=0

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/audit-observability.sh [--project PROJECT] [--context CONTEXT] [--app-namespace NS] [--velero-namespace NS] [--mode local|runtime|all] [--include-legacy] [--strict-runtime] [--json]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --context) K8S_CONTEXT="${2:-}"; shift 2 ;;
    --app-namespace) APP_NS="${2:-}"; shift 2 ;;
    --velero-namespace) VELERO_NS="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --include-legacy) INCLUDE_LEGACY=1; shift ;;
    --strict-runtime) STRICT_RUNTIME=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$MODE" != "local" && "$MODE" != "runtime" && "$MODE" != "all" ]]; then
  echo "Invalid --mode: $MODE" >&2
  usage
  exit 1
fi

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

CHECK_NAMES=()
CHECK_OK=()
CHECK_CODE=()
CHECK_MSG=()
failures=0

run_check() {
  local name="$1"; shift
  local tmp
  tmp="$(mktemp -t audit-observability.XXXXXX)"

  set +e
  "$@" >"$tmp" 2>&1
  local code=$?
  set -e

  local ok=0
  if [[ "$code" -eq 0 ]]; then ok=1; fi

  CHECK_NAMES+=("$name")
  CHECK_OK+=("$ok")
  CHECK_CODE+=("$code")

  if [[ "$ok" -eq 1 ]]; then
    CHECK_MSG+=("")
    [[ "$JSON_OUT" -eq 0 ]] && printf "OK   %s\n" "$name"
  else
    failures=$((failures + 1))
    local tail
    tail="$(tail -n 40 "$tmp" | sed 's/\r$//')"
    CHECK_MSG+=("$tail")
    if [[ "$JSON_OUT" -eq 0 ]]; then
      printf "FAIL %s (exit=%s)\n" "$name" "$code" >&2
      printf "%s\n" "$tail" | sed 's/^/  /' >&2
    fi
  fi

  rm -f "$tmp"
}

tmpdir="$(mktemp -d -t observability-audit.XXXXXX)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

is_legacy_artifact() {
  local base
  base="$(basename "$1")"
  case "$base" in
    cloudsql.json|cloudsql-disk.json)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

expected_from_repo() {
  local kind="$1"
  local out="$2"
  : >"$out"

  case "$kind" in
    uptime)
      for file in infrastructure/monitoring/uptime/prod-*.json; do
        jq -r '.displayName' "$file" >>"$out"
      done
      ;;
    dashboards)
      for file in infrastructure/monitoring/dashboards/*.json; do
        if [[ "$INCLUDE_LEGACY" != "1" ]] && is_legacy_artifact "$file"; then
          continue
        fi
        jq -r '.displayName' "$file" >>"$out"
      done
      ;;
    alerts)
      for file in infrastructure/monitoring/alerts/*.json; do
        if [[ "$INCLUDE_LEGACY" != "1" ]] && is_legacy_artifact "$file"; then
          continue
        fi
        jq -r '.displayName' "$file" >>"$out"
      done
      ;;
    log_metrics)
      for file in infrastructure/monitoring/logging-metrics/*.json; do
        jq -r '.name' "$file" >>"$out"
      done
      ;;
    *)
      echo "Unknown kind: $kind" >&2
      return 1
      ;;
  esac

  sort -u "$out" -o "$out"
}

assert_files_valid_json() {
  local files=("$@")
  local f
  for f in "${files[@]}"; do
    jq -e . "$f" >/dev/null
  done
}

assert_expected_in_actual() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  local missing="$tmpdir/missing-$label.txt"
  comm -23 "$expected" "$actual" >"$missing" || true
  if [[ -s "$missing" ]]; then
    echo "Missing $label:"
    sed 's/^/  - /' "$missing"
    return 1
  fi
}

fetch_runtime_names() {
  local kind="$1"
  local out="$2"
  CLOUDSDK_CONFIG=/tmp/gcloud-observability-audit
  export CLOUDSDK_CONFIG
  mkdir -p "$CLOUDSDK_CONFIG"

  case "$kind" in
    uptime)
      gcloud monitoring uptime list-configs --project="$PROJECT" --format=json \
        | jq -r '.[].displayName' | sort -u >"$out"
      ;;
    dashboards)
      gcloud monitoring dashboards list --project="$PROJECT" --format=json \
        | jq -r '.[].displayName' | sort -u >"$out"
      ;;
    alerts)
      gcloud monitoring policies list --project="$PROJECT" --format=json \
        | jq -r '.[].displayName' | sort -u >"$out"
      ;;
    log_metrics)
      gcloud logging metrics list --project="$PROJECT" --format=json \
        | jq -r '.[].name' | sort -u >"$out"
      ;;
    *)
      echo "Unknown runtime kind: $kind" >&2
      return 1
      ;;
  esac
}

repo_json_check() {
  local all_files
  mapfile -t all_files < <(find infrastructure/monitoring -type f -name '*.json' | sort)
  assert_files_valid_json "${all_files[@]}"
}

runtime_gcp_check() {
  command -v gcloud >/dev/null
  command -v jq >/dev/null

  local active_account
  active_account="$(CLOUDSDK_CONFIG=/tmp/gcloud-observability-audit gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
  if [[ -z "$active_account" ]]; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "No active gcloud account. Run: gcloud auth login && gcloud config set account <account>"
      return 1
    fi
    echo "SKIP: no active gcloud account"
    return 0
  fi

  local kinds=(uptime dashboards alerts log_metrics)
  local kind
  for kind in "${kinds[@]}"; do
    local expected="$tmpdir/expected-$kind.txt"
    local actual="$tmpdir/actual-$kind.txt"
    expected_from_repo "$kind" "$expected"
    fetch_runtime_names "$kind" "$actual"
    assert_expected_in_actual "$expected" "$actual" "$kind"
  done
}

runtime_k8s_check() {
  command -v kubectl >/dev/null

  if ! kubectl --context "$K8S_CONTEXT" get namespace "$APP_NS" >/dev/null 2>&1; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Cannot reach cluster/context or namespace missing: context=$K8S_CONTEXT namespace=$APP_NS"
      return 1
    fi
    echo "SKIP: cannot reach cluster/context or namespace missing ($K8S_CONTEXT / $APP_NS)"
    return 0
  fi

  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get cronjob auth-verify-prod >/dev/null
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get cronjob cert-verify-prod >/dev/null
  kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get cronjob backup-verification >/dev/null
  kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get cronjob restore-test >/dev/null

  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get prometheusrule lms-alerts -o json \
    | jq -e '
      [ .spec.groups[].rules[].alert ] as $alerts
      | (
          $alerts | index("OpenEdxCriticalDeploymentUnavailable")
        ) != null
      and (
          $alerts | index("OpenEdxPodsPendingTooLong")
        ) != null
      and (
          $alerts | index("OpenEdxCrashLoopingContainers")
        ) != null
      and (
          $alerts | index("OpenEdxSyntheticOrBackupJobFailures")
        ) != null
    ' >/dev/null

  local prom_pod rules_json
  prom_pod="$(
    kubectl --context "$K8S_CONTEXT" -n monitoring get pods \
      -l app.kubernetes.io/name=prometheus \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
  )"
  if [[ -z "$prom_pod" ]]; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Prometheus pod not found in monitoring namespace"
      return 1
    fi
    echo "SKIP: Prometheus pod not found in monitoring namespace"
    return 0
  fi

  rules_json="$(
    kubectl --context "$K8S_CONTEXT" -n monitoring exec "$prom_pod" -- \
      wget -qO- --timeout=5 'http://localhost:9090/api/v1/rules' 2>/dev/null || true
  )"
  if [[ -z "$rules_json" ]]; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Unable to query Prometheus /api/v1/rules from pod $prom_pod"
      return 1
    fi
    echo "SKIP: unable to query Prometheus /api/v1/rules from pod $prom_pod"
    return 0
  fi

  jq -e '
    [ .data.groups[].rules[]? | select(.type=="alerting") | .name ] as $alerts
    | (
        $alerts | index("OpenEdxCriticalDeploymentUnavailable")
      ) != null
    and (
        $alerts | index("OpenEdxPodsPendingTooLong")
      ) != null
    and (
        $alerts | index("OpenEdxCrashLoopingContainers")
      ) != null
    and (
        $alerts | index("OpenEdxSyntheticOrBackupJobFailures")
      ) != null
  ' <<<"$rules_json" >/dev/null
}

runtime_velero_freshness_check() {
  command -v kubectl >/dev/null
  command -v python3 >/dev/null

  if ! kubectl --context "$K8S_CONTEXT" get namespace "$VELERO_NS" >/dev/null 2>&1; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Cannot reach velero namespace: context=$K8S_CONTEXT namespace=$VELERO_NS"
      return 1
    fi
    echo "SKIP: cannot reach velero namespace ($K8S_CONTEXT / $VELERO_NS)"
    return 0
  fi

  local cronjobs_json
  cronjobs_json="$(kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get cronjob backup-verification restore-test -o json)"

  STRICT_RUNTIME="$STRICT_RUNTIME" python3 - "$cronjobs_json" <<'PY'
import json
import os
import sys
from datetime import datetime, timedelta, timezone

raw = sys.argv[1]
obj = json.loads(raw)
items = {it.get("metadata", {}).get("name"): it for it in obj.get("items", [])}
strict = os.getenv("STRICT_RUNTIME", "0") == "1"
warnings = []

def parse_ts(ts: str):
    if not ts:
        return None
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))

def age_hours(ts):
    return (datetime.now(timezone.utc) - ts).total_seconds() / 3600.0

backup = items.get("backup-verification")
restore = items.get("restore-test")
if not backup or not restore:
    msg = "Missing cronjobs backup-verification or restore-test"
    if strict:
        print(msg)
        sys.exit(1)
    print(f"WARN: {msg}")
    sys.exit(0)

backup_ts = parse_ts(backup.get("status", {}).get("lastSuccessfulTime"))
if not backup_ts:
    warnings.append("backup-verification has no lastSuccessfulTime")
elif age_hours(backup_ts) > 30:
    warnings.append(f"backup-verification lastSuccessfulTime stale: {backup_ts.isoformat()}")

restore_ts = parse_ts(restore.get("status", {}).get("lastSuccessfulTime"))
if not restore_ts:
    warnings.append("restore-test has no lastSuccessfulTime")
elif datetime.now(timezone.utc) - restore_ts > timedelta(days=45):
    warnings.append(f"restore-test lastSuccessfulTime stale: {restore_ts.isoformat()}")

if warnings:
    if strict:
        print("; ".join(warnings))
        sys.exit(1)
    print("WARN: " + "; ".join(warnings))
    sys.exit(0)
PY
}

if [[ "$JSON_OUT" -eq 0 ]]; then
  echo "Audit: observability posture"
  echo "  project:        $PROJECT"
  echo "  context:        $K8S_CONTEXT"
  echo "  app namespace:  $APP_NS"
  echo "  velero ns:      $VELERO_NS"
  echo "  include legacy: $INCLUDE_LEGACY"
  echo "  mode:           $MODE"
  echo "  strict runtime: $STRICT_RUNTIME"
  echo
fi

run_check "repo: monitoring json files are valid" repo_json_check

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  run_check "runtime: gcp monitoring/logging objects exist" runtime_gcp_check
  run_check "runtime: key in-cluster cronjobs exist" runtime_k8s_check
  run_check "runtime: velero cronjob freshness is within SLO" runtime_velero_freshness_check
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  printf "{"
  printf "\"project\":\"%s\"," "$(json_escape "$PROJECT")"
  printf "\"context\":\"%s\"," "$(json_escape "$K8S_CONTEXT")"
  printf "\"app_namespace\":\"%s\"," "$(json_escape "$APP_NS")"
  printf "\"velero_namespace\":\"%s\"," "$(json_escape "$VELERO_NS")"
  printf "\"include_legacy\":%s," "$INCLUDE_LEGACY"
  printf "\"checks\":["
  for i in "${!CHECK_NAMES[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "{"
    printf "\"name\":\"%s\"," "$(json_escape "${CHECK_NAMES[$i]}")"
    printf "\"ok\":%s," "${CHECK_OK[$i]}"
    printf "\"exit_code\":%s" "${CHECK_CODE[$i]}"
    if [[ -n "${CHECK_MSG[$i]}" ]]; then
      printf ",\"message\":\"%s\"" "$(json_escape "${CHECK_MSG[$i]}")"
    fi
    printf "}"
  done
  printf "],"
  printf "\"failures\":%s" "$failures"
  printf "}\n"
else
  echo
  if [[ "$failures" -gt 0 ]]; then
    echo "FAILED ($failures checks failed)" >&2
  else
    echo "OK"
  fi
fi

[[ "$failures" -eq 0 ]]
