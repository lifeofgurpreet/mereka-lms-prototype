#!/usr/bin/env bash
# Build a deterministic alert-noise runtime sample from live Prometheus alerts.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

OUT_FILE="${ALERT_NOISE_SAMPLE_OUT:-var/ci/alert-noise-runtime-sample.json}"
K8S_CONTEXT="${ALERT_NOISE_K8S_CONTEXT:-${K8S_CONTEXT:-}}"
MONITORING_NAMESPACE="${ALERT_NOISE_MONITORING_NAMESPACE:-monitoring}"
PROMETHEUS_POD_LABEL="${ALERT_NOISE_PROMETHEUS_POD_LABEL:-app.kubernetes.io/name=prometheus}"
PROMETHEUS_CONTAINER="${ALERT_NOISE_PROMETHEUS_CONTAINER:-prometheus}"
PROMETHEUS_URL_PATH="${ALERT_NOISE_PROMETHEUS_URL_PATH:-/api/v1/alerts}"
PROMETHEUS_PORT="${ALERT_NOISE_PROMETHEUS_PORT:-9090}"
PROMETHEUS_TIMEOUT="${ALERT_NOISE_PROMETHEUS_TIMEOUT:-15}"
BASELINE_CONFIG="${ALERT_NOISE_BASELINE_CONFIG:-infrastructure/monitoring/alert-noise-baseline.json}"
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"

FP_LABEL_KEY="${ALERT_NOISE_FP_LABEL_KEY:-alert_noise_classification}"
FP_LABEL_VAL="${ALERT_NOISE_FP_LABEL_VALUE:-false_positive}"
FP_ANNOTATION_KEY="${ALERT_NOISE_FP_ANNOTATION_KEY:-alert_noise_classification}"
FP_ANNOTATION_VAL="${ALERT_NOISE_FP_ANNOTATION_VALUE:-false_positive}"
FP_CLASSIFICATION_FEED="${ALERT_NOISE_FP_CLASSIFICATION_FEED:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/build-alert-noise-runtime-sample.sh \
  [--out path] [--k8s-context context] [--monitoring-namespace ns] [--strict]

Environment:
  ALERT_NOISE_SAMPLE_OUT              Output JSON file (default: var/ci/alert-noise-runtime-sample.json)
  ALERT_NOISE_K8S_CONTEXT             Optional kubectl context
  ALERT_NOISE_MONITORING_NAMESPACE    Monitoring namespace (default: monitoring)
  ALERT_NOISE_PROMETHEUS_POD_LABEL     kubectl pod label selector for Prometheus
  ALERT_NOISE_PROMETHEUS_CONTAINER     Prometheus container name (default: prometheus)
  ALERT_NOISE_PROMETHEUS_URL_PATH      Prometheus endpoint path (default: /api/v1/alerts)
  ALERT_NOISE_PROMETHEUS_PORT          Prometheus container port (default: 9090)
  ALERT_NOISE_BASELINE_CONFIG          Baseline config path (default: infrastructure/monitoring/alert-noise-baseline.json)
  ALERT_NOISE_DUP_WINDOW_MINUTES       Fingerprint duplicate window in minutes
  ALERT_NOISE_MIN_DUP_GROUP_SIZE       Minimum duplicate group size for fingerprint windows
  ALERT_NOISE_FP_LABEL_KEY             Label key marking false-positive alerts
  ALERT_NOISE_FP_LABEL_VALUE           Label value marking false-positive alerts
  ALERT_NOISE_FP_ANNOTATION_KEY        Annotation key marking false-positive alerts
  ALERT_NOISE_FP_ANNOTATION_VALUE      Annotation value marking false-positive alerts
  ALERT_NOISE_FP_CLASSIFICATION_FEED    Optional JSON feed of manual/operator false-positive classifications
  STRICT_RUNTIME=1                     Fail hard when sample cannot be built
EOF
}

emit_fallback_sample() {
  local out="$1"
  local generated
  generated="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p "$(dirname "$out")"
  cat <<EOF_JSON > "$out"
{
  "generated_at": "${generated}",
  "generated_by": "build-alert-noise-runtime-sample.sh (fallback)",
  "total_alerts": 0,
  "duplicate_alerts": 0,
  "false_positive_alerts": 0,
  "false_positive_summary": {
    "label_matches": 0,
    "feed_matches": 0
  },
  "severity_buckets": {
    "critical": {
      "total": 0,
      "duplicate": 0,
      "false_positive": 0
    },
    "error": {
      "total": 0,
      "duplicate": 0,
      "false_positive": 0
    },
    "warning": {
      "total": 0,
      "duplicate": 0,
      "false_positive": 0
    }
  },
  "duplicate_windows": [],
  "duplicate_detection": {
    "window_minutes": ${DUPLICATE_WINDOW_MINUTES},
    "min_dup_group_size": ${MIN_DUP_GROUP_SIZE}
  },
  "source": {
    "type": "fallback",
    "baseline_config": "${BASELINE_CONFIG}",
    "note": "Unable to build live sample in current runtime context"
  },
  "classification_feed": {
    "source": "${FP_CLASSIFICATION_FEED}",
    "entries_used": 0,
    "entries_accepted": 0,
    "entries_rejected": 0
  }
}
EOF_JSON
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      OUT_FILE="${2:?}"
      shift 2
      ;;
    --k8s-context)
      K8S_CONTEXT="${2:?}"
      shift 2
      ;;
    --monitoring-namespace)
      MONITORING_NAMESPACE="${2:?}"
      shift 2
      ;;
    --strict)
      STRICT_RUNTIME=1
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

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for alert noise sample build." >&2
  exit 1
fi

if ! [[ -f "$BASELINE_CONFIG" ]]; then
  echo "Baseline config missing: $BASELINE_CONFIG" >&2
  exit 1
fi

if [[ -n "$FP_CLASSIFICATION_FEED" ]] && ! [[ -f "$FP_CLASSIFICATION_FEED" ]]; then
  echo "WARN: false-positive classification feed missing: $FP_CLASSIFICATION_FEED" >&2
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    exit 1
  fi
  FP_CLASSIFICATION_FEED=""
fi

DEFAULT_DUP_WINDOW_MINUTES="$(jq -r '.thresholds.duplicate_detection.fingerprint_window_minutes // 5' "$BASELINE_CONFIG")"
DEFAULT_MIN_DUP_GROUP_SIZE="$(jq -r '.thresholds.duplicate_detection.min_dup_group_size // 2' "$BASELINE_CONFIG")"

if [[ -z "$DEFAULT_DUP_WINDOW_MINUTES" || "$DEFAULT_DUP_WINDOW_MINUTES" == "null" ]]; then
  DEFAULT_DUP_WINDOW_MINUTES="5"
fi
if [[ -z "$DEFAULT_MIN_DUP_GROUP_SIZE" || "$DEFAULT_MIN_DUP_GROUP_SIZE" == "null" ]]; then
  DEFAULT_MIN_DUP_GROUP_SIZE="2"
fi

DUPLICATE_WINDOW_MINUTES="${ALERT_NOISE_DUP_WINDOW_MINUTES:-$DEFAULT_DUP_WINDOW_MINUTES}"
MIN_DUP_GROUP_SIZE="${ALERT_NOISE_MIN_DUP_GROUP_SIZE:-$DEFAULT_MIN_DUP_GROUP_SIZE}"

if ! [[ "$DUPLICATE_WINDOW_MINUTES" =~ ^[0-9]+$ ]] || [[ "$DUPLICATE_WINDOW_MINUTES" -le 0 ]]; then
  echo "Invalid ALERT_NOISE_DUP_WINDOW_MINUTES: $DUPLICATE_WINDOW_MINUTES" >&2
  exit 1
fi

if ! [[ "$MIN_DUP_GROUP_SIZE" =~ ^[0-9]+$ ]] || [[ "$MIN_DUP_GROUP_SIZE" -lt 2 ]]; then
  echo "Invalid ALERT_NOISE_MIN_DUP_GROUP_SIZE: $MIN_DUP_GROUP_SIZE" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required for alert noise sample build." >&2
  exit 1
fi

KUBECTL=(kubectl)
if [[ -n "$K8S_CONTEXT" ]]; then
  KUBECTL+=(--context "$K8S_CONTEXT")
fi

PROM_POD="$($KUBECTL get pods -n "$MONITORING_NAMESPACE" -l "$PROMETHEUS_POD_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

if [[ -z "$PROM_POD" ]]; then
  echo "WARN: no Prometheus pod found for label '$PROMETHEUS_POD_LABEL' in namespace '$MONITORING_NAMESPACE'." >&2
  emit_fallback_sample "$OUT_FILE"
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    exit 1
  fi
  exit 0
fi

ALERTS_JSON="$($KUBECTL exec -n "$MONITORING_NAMESPACE" "$PROM_POD" -c "$PROMETHEUS_CONTAINER" -- \
  wget -qO- --timeout="$PROMETHEUS_TIMEOUT" "http://localhost:${PROMETHEUS_PORT}${PROMETHEUS_URL_PATH}" || true)"

if [[ -z "$ALERTS_JSON" ]]; then
  echo "WARN: unable to query Prometheus alerts from pod '${PROM_POD}'." >&2
  emit_fallback_sample "$OUT_FILE"
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    exit 1
  fi
  exit 0
fi

if ! jq -e '.status == "success" and (.data|type == "array")' <<<"$ALERTS_JSON" >/dev/null 2>&1; then
  echo "WARN: unexpected Prometheus /api/v1/alerts payload." >&2
  jq -e . <<<"$ALERTS_JSON" >/dev/null 2>&1 || true
  emit_fallback_sample "$OUT_FILE"
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    exit 1
  fi
  exit 0
fi

mkdir -p "$(dirname "$OUT_FILE")"

export ALERT_NOISE_DUP_WINDOW_MINUTES="$DUPLICATE_WINDOW_MINUTES"
export ALERT_NOISE_MIN_DUP_GROUP_SIZE="$MIN_DUP_GROUP_SIZE"
export ALERT_NOISE_BASELINE_CONFIG="$BASELINE_CONFIG"
export STRICT_RUNTIME="$STRICT_RUNTIME"
export ALERT_NOISE_FP_CLASSIFICATION_FEED="$FP_CLASSIFICATION_FEED"

python3 - "$OUT_FILE" "$FP_LABEL_KEY" "$FP_LABEL_VAL" "$FP_ANNOTATION_KEY" "$FP_ANNOTATION_VAL" <<PY
import json
import os
import sys
from collections import defaultdict, deque
from datetime import datetime, timezone

out_file = sys.argv[1]
fp_label_key = sys.argv[2]
fp_label_val = sys.argv[3]
fp_annot_key = sys.argv[4]
fp_annot_val = sys.argv[5]
strict_runtime = (os.environ.get("STRICT_RUNTIME", "0") == "1")
fp_feed_path = os.environ.get("ALERT_NOISE_FP_CLASSIFICATION_FEED", "")

payload = json.load(sys.stdin)
alerts = payload.get("data", []) or []

severity_buckets = {
    "critical": {"total": 0, "duplicate": 0, "false_positive": 0},
    "error": {"total": 0, "duplicate": 0, "false_positive": 0},
    "warning": {"total": 0, "duplicate": 0, "false_positive": 0},
}

window_minutes = int(os.environ.get("ALERT_NOISE_DUP_WINDOW_MINUTES", "5"))
min_group_size = max(2, int(os.environ.get("ALERT_NOISE_MIN_DUP_GROUP_SIZE", "2")))
window_seconds = window_minutes * 60

fingerprint_windows = defaultdict(list)
total_alerts = 0
duplicate_alerts = 0
false_positive_alerts = 0
false_positive_by_label = 0
false_positive_by_feed = 0

feed_entries_total = 0
feed_entries_accepted = 0
feed_entries_rejected = 0
feed_by_fingerprint = {}


def load_classification_feed(path, strict):
    if not path:
        return 0, 0, 0, {}

    try:
        with open(path, "r", encoding="utf-8") as fp:
            feed = json.load(fp)
    except Exception as exc:
        print(f"WARN: failed to parse classification feed '{path}': {exc}", file=sys.stderr)
        if strict:
            raise
        return 0, 0, 0, {}

    entries = feed.get("entries")
    if not isinstance(entries, list):
        print(f"WARN: classification feed '{path}' missing required entries array", file=sys.stderr)
        if strict:
            raise SystemExit(1)
        return 0, 0, 0, {}

    map_by_fp = {}
    entries_total = 0
    entries_accepted = 0
    entries_rejected = 0
    for entry in entries:
        if not isinstance(entry, dict):
            entries_rejected += 1
            continue
        fingerprint = str(entry.get("fingerprint", "")).strip()
        classification = str(entry.get("classification", "")).strip().lower()
        entries_total += 1
        if not fingerprint:
            entries_rejected += 1
            continue
        if classification not in {"false_positive", "suppress"}:
            entries_rejected += 1
            continue
        map_by_fp[fingerprint] = {
            "classification": classification,
            "reason": str(entry.get("reason", "")).strip(),
            "owner": str(entry.get("owner", "")).strip(),
            "expires_at": str(entry.get("expires_at", "")).strip(),
            "source": str(entry.get("source", "manual")).strip() or "manual",
        }
        entries_accepted += 1

    if strict and entries_rejected > 0:
        raise SystemExit(1)

    return entries_total, entries_accepted, entries_rejected, map_by_fp


feed_entries_total, feed_entries_accepted, feed_entries_rejected, feed_by_fingerprint = load_classification_feed(fp_feed_path, strict_runtime)

def parse_timestamp(value):
    if not value:
        return None
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(value).astimezone(timezone.utc)
    except Exception:
        return None

for alert in alerts:
    total_alerts += 1
    labels = alert.get("labels") or {}
    annotations = alert.get("annotations") or {}

    severity = (labels.get("severity") or "warning").strip().lower()
    if severity not in severity_buckets:
        severity = "warning"

    severity_buckets[severity]["total"] += 1

    fingerprint = alert.get("fingerprint")
    if not fingerprint:
        label_items = sorted(labels.items())
        fingerprint = "|".join([f"{k}={v}" for k, v in label_items])

    started_at = parse_timestamp(alert.get("startsAt"))
    if not started_at:
        continue
    event_time = int(started_at.timestamp())
    fingerprint_windows[(fingerprint, severity)].append(event_time)

    is_fp = (
        str(labels.get(fp_label_key, "")).strip().lower() == fp_label_val.strip().lower()
        or str(annotations.get(fp_annot_key, "")).strip().lower() == fp_annot_val.strip().lower()
    )
    is_fp_from_feed = False
    feed_entry = feed_by_fingerprint.get(fingerprint)
    if feed_entry and feed_entry.get("classification") in {"false_positive", "suppress"}:
        is_fp_from_feed = True

    if is_fp:
        false_positive_by_label += 1
        if not is_fp_from_feed:
            false_positive_alerts += 1
            severity_buckets[severity]["false_positive"] += 1
    if is_fp_from_feed and not is_fp:
        false_positive_by_feed += 1
        false_positive_alerts += 1
        severity_buckets[severity]["false_positive"] += 1
    if is_fp and is_fp_from_feed:
        false_positive_by_label += 1
        false_positive_by_feed += 1

duplicate_windows = []
for key in sorted(fingerprint_windows.keys()):
    times = sorted(fingerprint_windows[key])
    severity = key[1]
    active_window = deque()
    group_duplicates = 0
    max_window_coverage = 0

    for event_ts in times:
        while active_window and event_ts - active_window[0] > window_seconds:
            active_window.popleft()
        active_window.append(event_ts)
        if len(active_window) >= min_group_size:
            dup_count = len(active_window) - 1
            duplicate_alerts += dup_count
            severity_buckets[severity]["duplicate"] += dup_count
            group_duplicates += dup_count
            max_window_coverage = max(max_window_coverage, len(active_window))

    if group_duplicates > 0:
        duplicate_windows.append({
            "fingerprint": key[0],
            "severity": severity,
            "dup_events_in_window": group_duplicates,
            "max_window_coverage": max_window_coverage,
            "window_minutes": window_minutes,
            "min_dup_group_size": min_group_size
        })

output = {
    "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "generated_by": "build-alert-noise-runtime-sample.sh",
    "total_alerts": total_alerts,
    "duplicate_alerts": duplicate_alerts,
    "false_positive_alerts": false_positive_alerts,
    "false_positive_summary": {
        "label_matches": false_positive_by_label,
        "feed_matches": false_positive_by_feed,
    },
    "severity_buckets": severity_buckets,
    "duplicate_windows": duplicate_windows,
    "duplicate_detection": {
        "window_minutes": window_minutes,
        "min_dup_group_size": min_group_size
    },
    "source": {
        "type": "prometheus_api",
        "alert_count": len(alerts),
        "lookback_days": 0,
        "baseline_config": os.environ.get("ALERT_NOISE_BASELINE_CONFIG", ""),
    },
    "classification_feed": {
        "path": fp_feed_path,
        "entries_total": feed_entries_total,
        "entries_accepted": feed_entries_accepted,
        "entries_rejected": feed_entries_rejected,
    },
}

with open(out_file, "w", encoding="utf-8") as fp:
    fp.write(json.dumps(output, indent=2) + "\\n")
PY


echo "OK   wrote alert-noise runtime sample -> $OUT_FILE"
echo "  generated: $(cat "$OUT_FILE")"
