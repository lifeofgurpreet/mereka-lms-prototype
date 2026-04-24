#!/usr/bin/env bash
# @covers AC-001
# @spec: observability-stack_spec.md
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
#   ./scripts/qa/audit-observability.sh --project mereka-lms --context rke2-prod
#   # Canonical runtime/all evidence gate:
#   OBSERVABILITY_ENV_LABEL=prod OBSERVABILITY_DISPATCH_PROFILE=prod \
#     ./scripts/qa/run-observability-first-class.sh --mode runtime --strict
#
# Environment controls (optional):
# - OBSERVABILITY_INCLUDE_GRAFANA_DASHBOARDS=1 => include Grafana-only dashboard files in dashboard parity checks
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PROJECT="${GCP_PROJECT:-mereka-lms}"
COMPUTE_QUOTA_PROJECT="${COMPUTE_QUOTA_PROJECT:-$PROJECT}"
K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-rke2-prod}}"
APP_NS="${APP_NS:-mereka-lms}"
VELERO_NS="${VELERO_NS:-velero}"
INCLUDE_LEGACY="${INCLUDE_LEGACY_MONITORING:-0}"
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"
SNAPSHOT_QUOTA_WARN_PCT="${SNAPSHOT_QUOTA_WARN_PCT:-90}"
SNAPSHOT_QUOTA_FAIL_PCT="${SNAPSHOT_QUOTA_FAIL_PCT:-95}"
VELERO_SIGNBLOB_WINDOW="${VELERO_SIGNBLOB_WINDOW:-5m}"
GCLOUD_TIMEOUT="${AUDIT_OBS_GCLOUD_TIMEOUT:-30}"
DEBUG_MODE="${AUDIT_OBS_DEBUG:-0}"
INCLUDE_GRAFANA_DASHBOARDS="${OBSERVABILITY_INCLUDE_GRAFANA_DASHBOARDS:-0}"
MODE="local" # local | runtime | all
JSON_OUT=0
usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/audit-observability.sh [--project PROJECT] [--compute-quota-project PROJECT] [--context CONTEXT] [--app-namespace NS] [--velero-namespace NS] [--mode local|runtime|all] [--include-legacy] [--strict-runtime] [--json]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --compute-quota-project) COMPUTE_QUOTA_PROJECT="${2:-}"; shift 2 ;;
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

is_unsupported_alert_artifact() {
  local base
  base="$(basename "$1")"
  case "$base" in
    velero-restore-test-stale.json)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_grafana_only_dashboard_artifact() {
  local base
  base="$(basename "$1")"
  case "$base" in
    video-cost.json|video-operations.json)
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
        if [[ "$INCLUDE_GRAFANA_DASHBOARDS" != "1" ]] && is_grafana_only_dashboard_artifact "$file"; then
          continue
        fi
        if [[ "$INCLUDE_LEGACY" != "1" ]] && is_legacy_artifact "$file"; then
          continue
        fi
        jq -r '.displayName // ""' "$file" >>"$out"
      done
      ;;
    alerts)
      for file in infrastructure/monitoring/alerts/*.json; do
        if [[ "$INCLUDE_LEGACY" != "1" ]] && is_legacy_artifact "$file"; then
          continue
        fi
        if is_unsupported_alert_artifact "$file"; then
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

  sed -i '/^$/d;/^[Nn][Uu][Ll][Ll]$/d' "$out"

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

  local missing_count expected_count actual_count
  missing_count=$(wc -l <"$missing")
  expected_count=$(wc -l <"$expected")
  actual_count=$(wc -l <"$actual")

  if [[ "$missing_count" -gt 0 ]]; then
    echo "Missing $label: (expected=$expected_count runtime=$actual_count)"
    sed 's/^/  - /' "$missing"
    return 1
  fi
}

fetch_runtime_names() {
  local kind="$1"
  local out="$2"

  if ! command -v timeout >/dev/null 2>&1; then
    echo "timeout command is required for bounded gcloud queries" >&2
    return 1
  fi

  case "$kind" in
    uptime)
      timeout "$GCLOUD_TIMEOUT" gcloud monitoring uptime list-configs --project="$PROJECT" --format=json \
        | jq -r '.[] | .displayName // ""' \
        | sed '/^$/d;/^[Nn][Uu][Ll][Ll]$/d' | sort -u >"$out" || {
          echo "Failed to fetch GCP uptime configs for project=$PROJECT"
          return 1
        }
      ;;
    dashboards)
      timeout "$GCLOUD_TIMEOUT" gcloud monitoring dashboards list --project="$PROJECT" --format=json \
        | jq -r '.[] | .displayName // ""' \
        | sed '/^$/d;/^[Nn][Uu][Ll][Ll]$/d' | sort -u >"$out" || {
          echo "Failed to fetch GCP dashboards for project=$PROJECT"
          return 1
        }
      ;;
    alerts)
      timeout "$GCLOUD_TIMEOUT" gcloud monitoring policies list --project="$PROJECT" --format=json \
        | jq -r '.[] | .displayName // ""' \
        | sed '/^$/d;/^[Nn][Uu][Ll][Ll]$/d' | sort -u >"$out" || {
          echo "Failed to fetch GCP alerting policies for project=$PROJECT"
          return 1
        }
      ;;
    log_metrics)
      timeout "$GCLOUD_TIMEOUT" gcloud logging metrics list --project="$PROJECT" --format=json \
        | jq -r '.[] | .name // ""' \
        | sed '/^$/d;/^[Nn][Uu][Ll][Ll]$/d' | sort -u >"$out" || {
          echo "Failed to fetch GCP logging metrics for project=$PROJECT"
          return 1
        }
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

  [[ "$DEBUG_MODE" == "1" ]] && echo "DEBUG runtime_gcp_check: start" >&2

  local active_account
  active_account="$(timeout "$GCLOUD_TIMEOUT" gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
  if [[ -z "$active_account" ]]; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "No active gcloud account. Run: gcloud auth login && gcloud config set account <account>"
      return 1
    fi
    echo "SKIP: no active gcloud account"
    return 0
  fi

  [[ "$DEBUG_MODE" == "1" ]] && echo "DEBUG runtime_gcp_check: active account=$active_account" >&2

  local kinds=(uptime dashboards alerts log_metrics)
  local kind
  for kind in "${kinds[@]}"; do
    [[ "$DEBUG_MODE" == "1" ]] && echo "DEBUG runtime_gcp_check: kind=$kind" >&2
    local expected="$tmpdir/expected-$kind.txt"
    local actual="$tmpdir/actual-$kind.txt"

    if ! expected_from_repo "$kind" "$expected"; then
      echo "Runtime GCP parity failed for kind=$kind while reading repository manifests"
      return 1
    fi

    if ! fetch_runtime_names "$kind" "$actual"; then
      echo "Runtime GCP parity failed for kind=$kind while querying GCP"
      return 1
    fi

    [[ "$DEBUG_MODE" == "1" ]] && echo "DEBUG runtime_gcp_check: kind=$kind fetch done" >&2

    if ! assert_expected_in_actual "$expected" "$actual" "$kind"; then
      echo "Runtime GCP parity failed for kind=$kind"
      return 1
    fi

    [[ "$DEBUG_MODE" == "1" ]] && echo "DEBUG runtime_gcp_check: kind=$kind compare done" >&2
  done

  return 0
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

  local cronjobs_file backups_file
  cronjobs_file="$(mktemp -t velero-cronjobs.XXXXXX.json)"
  backups_file="$(mktemp -t velero-backups.XXXXXX.json)"
  kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get cronjob backup-verification restore-test -o json >"$cronjobs_file"
  kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get backup.velero.io -o json >"$backups_file" 2>/dev/null || echo '{"items":[]}' >"$backups_file"

  STRICT_RUNTIME="$STRICT_RUNTIME" python3 - "$cronjobs_file" "$backups_file" <<'PY'
import json
import os
import sys
from datetime import datetime, timedelta, timezone

with open(sys.argv[1], "r", encoding="utf-8") as f:
    cronjobs = json.load(f)
with open(sys.argv[2], "r", encoding="utf-8") as f:
    backups = json.load(f)
obj = cronjobs
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

# Add actionable backup phase context when backup-verification is stale/missing.
if any("backup-verification" in w for w in warnings):
    cutoff = datetime.now(timezone.utc) - timedelta(hours=30)
    phase_counts = {}
    failed_names = []
    for item in backups.get("items", []):
      meta = item.get("metadata", {})
      status = item.get("status", {})
      created = parse_ts(meta.get("creationTimestamp"))
      if created and created < cutoff:
        continue
      phase = status.get("phase") or "Unknown"
      phase_counts[phase] = phase_counts.get(phase, 0) + 1
      if phase in {"Failed", "PartiallyFailed"}:
        failed_names.append(meta.get("name", "<unknown>"))
    if phase_counts:
      summary = ", ".join(f"{k}={v}" for k, v in sorted(phase_counts.items()))
      warnings.append(f"recent backups (30h) phase summary: {summary}")
    if failed_names:
      warnings.append(f"recent failed backups sample: {', '.join(failed_names[-3:])}")

if warnings:
    if strict:
        print("; ".join(warnings))
        sys.exit(1)
    print("WARN: " + "; ".join(warnings))
    sys.exit(0)
PY
  local py_status=$?
  rm -f "$cronjobs_file" "$backups_file"
  return "$py_status"
}

runtime_snapshot_quota_headroom_check() {
  command -v gcloud >/dev/null
  command -v python3 >/dev/null

  local quota_json
  quota_json="$(timeout "$GCLOUD_TIMEOUT" gcloud compute project-info describe --project="$COMPUTE_QUOTA_PROJECT" --format=json)" || {
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Failed to fetch compute quota for project=$COMPUTE_QUOTA_PROJECT"
      return 1
    fi
    echo "SKIP: failed to fetch compute quota for project=$COMPUTE_QUOTA_PROJECT"
    return 0
  }

  python3 - "$quota_json" "$SNAPSHOT_QUOTA_WARN_PCT" "$SNAPSHOT_QUOTA_FAIL_PCT" "$STRICT_RUNTIME" <<'PY'
import json
import sys

obj = json.loads(sys.argv[1])
warn_pct = float(sys.argv[2])
fail_pct = float(sys.argv[3])
strict = sys.argv[4] == "1"

snap = next((q for q in obj.get("quotas", []) if q.get("metric") == "SNAPSHOTS"), None)
if not snap:
    msg = "SNAPSHOTS quota metric not found"
    if strict:
        print(msg)
        sys.exit(1)
    print(f"WARN: {msg}")
    sys.exit(0)

limit = float(snap.get("limit") or 0)
usage = float(snap.get("usage") or 0)
if limit <= 0:
    msg = f"invalid SNAPSHOTS quota limit: {limit}"
    if strict:
        print(msg)
        sys.exit(1)
    print(f"WARN: {msg}")
    sys.exit(0)

pct = (usage / limit) * 100.0
summary = f"SNAPSHOTS usage={int(usage)}/{int(limit)} ({pct:.1f}%)"
if pct >= fail_pct:
    print(f"{summary} exceeds fail threshold {fail_pct:.1f}%")
    sys.exit(1)
if pct >= warn_pct:
    print(f"WARN: {summary} exceeds warn threshold {warn_pct:.1f}%")
sys.exit(0)
PY
}

runtime_velero_signblob_check() {
  command -v kubectl >/dev/null

  if ! kubectl --context "$K8S_CONTEXT" get namespace "$VELERO_NS" >/dev/null 2>&1; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Cannot reach velero namespace: context=$K8S_CONTEXT namespace=$VELERO_NS"
      return 1
    fi
    echo "SKIP: cannot reach velero namespace ($K8S_CONTEXT / $VELERO_NS)"
    return 0
  fi

  local logs
  logs="$(kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" logs deploy/velero-local --since="$VELERO_SIGNBLOB_WINDOW" 2>/dev/null || true)"
  if [[ -z "$logs" ]]; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Unable to read velero-local logs in namespace $VELERO_NS"
      return 1
    fi
    echo "SKIP: unable to read velero-local logs in namespace $VELERO_NS"
    return 0
  fi

  if rg -q 'iam\.serviceAccounts\.signBlob|IAM_PERMISSION_DENIED' <<<"$logs"; then
    echo "Detected recent Velero signBlob IAM errors in velero-local logs (window=$VELERO_SIGNBLOB_WINDOW)"
    return 1
  fi
}

if [[ "$JSON_OUT" -eq 0 ]]; then
  echo "Audit: observability posture"
  echo "  project:        $PROJECT"
  echo "  compute quota:  $COMPUTE_QUOTA_PROJECT"
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
  run_check "runtime: compute snapshot quota has headroom" runtime_snapshot_quota_headroom_check
  run_check "runtime: velero signBlob IAM errors absent (recent window)" runtime_velero_signblob_check
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
  if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
    echo
    echo "Canonical runtime evidence gate:"
    echo "  OBSERVABILITY_ENV_LABEL=prod OBSERVABILITY_DISPATCH_PROFILE=prod \\"
    echo "    ./scripts/qa/run-observability-first-class.sh --mode ${MODE} --strict"
  fi
fi

[[ "$failures" -eq 0 ]]
