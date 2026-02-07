#!/usr/bin/env bash
# Audit Velero alert pipeline end-to-end:
# - repo templates (log metrics + alert policies)
# - runtime GCP objects (optional if gcloud auth present)
# - runtime Velero cronjob freshness in cluster
#
# Usage:
#   ./scripts/qa/audit-velero-alert-pipeline.sh
#   ./scripts/qa/audit-velero-alert-pipeline.sh --json
#   STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PROJECT="${GCP_PROJECT:-mereka-lms}"
K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
VELERO_NS="${VELERO_NS:-velero}"
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"
HOURLY_SCHEDULE_NAME="${HOURLY_SCHEDULE_NAME:-velero-local-hourly-critical-databases}"
HOURLY_MAX_AGE_HOURS="${HOURLY_MAX_AGE_HOURS:-2.5}"
JSON_OUT=0

REQUIRED_LOG_METRICS=(
  "velero-backup-verification-failures"
  "velero-backup-verification-success"
  "velero-restore-test-failures"
  "velero-restore-test-success"
)

REQUIRED_ALERT_DISPLAY_NAMES=(
  "Velero backup verification failures (logs)"
  "Velero restore-test failures (logs)"
)

OPTIONAL_ALERT_DISPLAY_NAMES=(
  "Velero backup verification stale (no success in 30h)"
  "Velero restore-test stale (no success in 45d)"
)

usage() {
  cat <<EOF
Usage: ./scripts/qa/audit-velero-alert-pipeline.sh [--json]
Env:
  STRICT_RUNTIME=1  fail when runtime checks are unreachable/missing
  HOURLY_SCHEDULE_NAME=velero-local-hourly-critical-databases
  HOURLY_MAX_AGE_HOURS=2.5
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

CHECK_NAMES=()
CHECK_OK=()
CHECK_MSG=()
failures=0
warnings=0

record_check() {
  local name="$1"
  local ok="$2"
  local msg="${3:-}"
  CHECK_NAMES+=("$name")
  CHECK_OK+=("$ok")
  CHECK_MSG+=("$msg")
  if [[ "$ok" -eq 0 ]]; then
    failures=$((failures + 1))
  fi
}

record_warning() {
  warnings=$((warnings + 1))
  if [[ "$JSON_OUT" -eq 0 ]]; then
    echo "WARN: $1"
  fi
  return 0
}

run_check() {
  local name="$1"; shift
  local tmp rc out
  tmp="$(mktemp -t audit-velero-alert.XXXXXX)"
  set +e
  "$@" >"$tmp" 2>&1
  rc=$?
  set -e
  out="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ "$rc" -eq 0 ]]; then
    record_check "$name" 1 ""
    if [[ "$JSON_OUT" -eq 0 ]]; then
      echo "OK   $name"
    fi
  else
    record_check "$name" 0 "$out"
    if [[ "$JSON_OUT" -eq 0 ]]; then
      echo "FAIL $name"
      if [[ -n "$out" ]]; then
        echo "$out" | sed 's/^/  /'
      fi
    fi
  fi
  return 0
}

check_repo_templates() {
  command -v jq >/dev/null

  local metric
  for metric in "${REQUIRED_LOG_METRICS[@]}"; do
    local metric_file="infrastructure/monitoring/logging-metrics/${metric}.json"
    [[ -f "$metric_file" ]] || { echo "Missing file: $metric_file"; return 1; }
    jq -e --arg n "$metric" '.name == $n' "$metric_file" >/dev/null || {
      echo "Metric name mismatch in $metric_file"
      return 1
    }
  done

  local expected
  for expected in "${REQUIRED_ALERT_DISPLAY_NAMES[@]}"; do
    jq -r '.displayName' infrastructure/monitoring/alerts/velero-*.json \
      infrastructure/monitoring/alerts/log-velero-*.json \
      | rg -Fx -- "$expected" >/dev/null || {
        echo "Missing alert displayName: $expected"
        return 1
      }
  done
}

check_runtime_velero_cronjobs() {
  command -v kubectl >/dev/null
  command -v python3 >/dev/null

  local cronjobs_json
  cronjobs_json="$(kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get cronjob backup-verification restore-test -o json)"

  python3 - "$STRICT_RUNTIME" "$cronjobs_json" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone

strict = sys.argv[1] == "1"
obj = json.loads(sys.argv[2])
items = {it["metadata"]["name"]: it for it in obj.get("items", [])}

for name in ("backup-verification", "restore-test"):
    if name not in items:
        print(f"Missing CronJob: {name}")
        sys.exit(1)

def parse_ts(ts):
    if not ts:
        return None
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))

backup_ts = parse_ts(items["backup-verification"].get("status", {}).get("lastSuccessfulTime"))
restore_ts = parse_ts(items["restore-test"].get("status", {}).get("lastSuccessfulTime"))
now = datetime.now(timezone.utc)

if not backup_ts:
    print("backup-verification has no lastSuccessfulTime")
    sys.exit(1 if strict else 0)
if now - backup_ts > timedelta(hours=30):
    print(f"backup-verification stale: {backup_ts.isoformat()}")
    sys.exit(1 if strict else 0)

if not restore_ts:
    print("restore-test has no lastSuccessfulTime")
    sys.exit(1 if strict else 0)
if now - restore_ts > timedelta(days=45):
    print(f"restore-test stale: {restore_ts.isoformat()}")
    sys.exit(1 if strict else 0)
PY
}

check_runtime_hourly_backup_recency() {
  command -v kubectl >/dev/null
  command -v python3 >/dev/null

  if ! kubectl --context "$K8S_CONTEXT" get namespace "$VELERO_NS" >/dev/null 2>&1; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Cannot reach velero namespace: context=$K8S_CONTEXT namespace=$VELERO_NS"
      return 1
    fi
    record_warning "Skipping hourly backup recency check (cannot reach $K8S_CONTEXT / $VELERO_NS)."
    return 0
  fi

  local backups_tmp
  backups_tmp="$(mktemp -t velero-backups.XXXXXX)"
  kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get backup -o json >"$backups_tmp"

  set +e
  python3 - "$HOURLY_SCHEDULE_NAME" "$HOURLY_MAX_AGE_HOURS" "$backups_tmp" <<'PY'
import json
import sys
from datetime import datetime, timezone

schedule_name = sys.argv[1]
max_age_hours = float(sys.argv[2])
backups_path = sys.argv[3]
with open(backups_path, "r", encoding="utf-8") as f:
    obj = json.load(f)

def parse_ts(ts):
    if not ts:
        return None
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))

candidates = []
for it in obj.get("items", []):
    labels = (it.get("metadata") or {}).get("labels") or {}
    if labels.get("velero.io/schedule-name") != schedule_name:
        continue
    phase = ((it.get("status") or {}).get("phase") or "").strip()
    if phase != "Completed":
        continue
    ts = parse_ts((it.get("status") or {}).get("completionTimestamp") or (it.get("metadata") or {}).get("creationTimestamp"))
    if ts:
        candidates.append((ts, (it.get("metadata") or {}).get("name", "")))

if not candidates:
    print(f"No completed backups found for schedule={schedule_name}")
    sys.exit(1)

latest_ts, latest_name = sorted(candidates, key=lambda t: t[0])[-1]
age_hours = (datetime.now(timezone.utc) - latest_ts).total_seconds() / 3600.0
if age_hours > max_age_hours:
    print(
        f"Hourly critical backup stale for schedule={schedule_name}: "
        f"latest={latest_name} at {latest_ts.isoformat()} ({age_hours:.2f}h old > {max_age_hours:.2f}h)"
    )
    sys.exit(1)
PY
  local rc=$?
  set -e
  rm -f "$backups_tmp"
  return "$rc"
}

check_runtime_gcp_objects() {
  command -v gcloud >/dev/null
  command -v jq >/dev/null

  local account
  account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
  if [[ -z "$account" ]]; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "No active gcloud account. Run: gcloud auth login && gcloud config set account <account>"
      return 1
    fi
    record_warning "Skipping GCP runtime object check (no active gcloud account)."
    return 0
  fi

  local metric
  local runtime_metrics
  runtime_metrics="$(gcloud logging metrics list --project="$PROJECT" --format=json | jq -r '.[].name')"
  for metric in "${REQUIRED_LOG_METRICS[@]}"; do
    echo "$runtime_metrics" | rg -Fx -- "$metric" >/dev/null || {
      echo "Missing runtime log metric: $metric"
      return 1
    }
  done

  local runtime_alerts
  runtime_alerts="$(gcloud monitoring policies list --project="$PROJECT" --format=json | jq -r '.[].displayName')"
  local expected
  for expected in "${REQUIRED_ALERT_DISPLAY_NAMES[@]}"; do
    echo "$runtime_alerts" | rg -Fx -- "$expected" >/dev/null || {
      echo "Missing runtime alert policy: $expected"
      return 1
    }
  done

  local optional
  for optional in "${OPTIONAL_ALERT_DISPLAY_NAMES[@]}"; do
    if ! echo "$runtime_alerts" | rg -Fx -- "$optional" >/dev/null; then
      record_warning "Optional runtime alert policy not found: $optional (staleness is enforced by runtime cronjob freshness checks)."
    fi
  done
}

if [[ "$JSON_OUT" -eq 0 ]]; then
  echo "Audit: Velero alert pipeline"
  echo "  project:       $PROJECT"
  echo "  context:       $K8S_CONTEXT"
  echo "  velero ns:     $VELERO_NS"
  echo "  strict:        $STRICT_RUNTIME"
  echo "  hourly backup: schedule=$HOURLY_SCHEDULE_NAME max_age=${HOURLY_MAX_AGE_HOURS}h"
  echo ""
fi

run_check "repo: velero metric/alert templates exist" check_repo_templates
run_check "runtime: velero cronjobs freshness is within SLO" check_runtime_velero_cronjobs
run_check "runtime: hourly critical backup recency is within SLO" check_runtime_hourly_backup_recency
run_check "runtime: gcp velero metrics/policies exist" check_runtime_gcp_objects

if [[ "$JSON_OUT" -eq 1 ]]; then
  strict_json="false"
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    strict_json="true"
  fi
  printf "{"
  printf "\"project\":\"%s\"," "$(json_escape "$PROJECT")"
  printf "\"context\":\"%s\"," "$(json_escape "$K8S_CONTEXT")"
  printf "\"velero_namespace\":\"%s\"," "$(json_escape "$VELERO_NS")"
  printf "\"strict_runtime\":%s," "$strict_json"
  printf "\"checks\":["
  for i in "${!CHECK_NAMES[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "{"
    printf "\"name\":\"%s\",\"ok\":%s" "$(json_escape "${CHECK_NAMES[$i]}")" "${CHECK_OK[$i]}"
    if [[ -n "${CHECK_MSG[$i]}" ]]; then
      printf ",\"message\":\"%s\"" "$(json_escape "${CHECK_MSG[$i]}")"
    fi
    printf "}"
  done
  printf "],"
  printf "\"warnings\":%s," "$warnings"
  printf "\"failures\":%s" "$failures"
  printf "}\n"
else
  echo ""
  if [[ "$failures" -eq 0 ]]; then
    echo "OK"
  else
    echo "FAILED ($failures checks failed)"
  fi
fi

[[ "$failures" -eq 0 ]]
