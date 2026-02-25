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
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"

FP_LABEL_KEY="${ALERT_NOISE_FP_LABEL_KEY:-alert_noise_classification}"
FP_LABEL_VAL="${ALERT_NOISE_FP_LABEL_VALUE:-false_positive}"
FP_ANNOTATION_KEY="${ALERT_NOISE_FP_ANNOTATION_KEY:-alert_noise_classification}"
FP_ANNOTATION_VAL="${ALERT_NOISE_FP_ANNOTATION_VALUE:-false_positive}"

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
  ALERT_NOISE_FP_LABEL_KEY             Label key marking false-positive alerts
  ALERT_NOISE_FP_LABEL_VALUE           Label value marking false-positive alerts
  ALERT_NOISE_FP_ANNOTATION_KEY        Annotation key marking false-positive alerts
  ALERT_NOISE_FP_ANNOTATION_VALUE      Annotation value marking false-positive alerts
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
  "source": {
    "type": "fallback",
    "note": "Unable to build live sample in current runtime context"
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

python3 - "$OUT_FILE" "$FP_LABEL_KEY" "$FP_LABEL_VAL" "$FP_ANNOTATION_KEY" "$FP_ANNOTATION_VAL" <<'PY'
import json
import sys
from collections import defaultdict
from datetime import datetime

out_file = sys.argv[1]
fp_label_key = sys.argv[2]
fp_label_val = sys.argv[3]
fp_annot_key = sys.argv[4]
fp_annot_val = sys.argv[5]

payload = json.load(sys.stdin)
alerts = payload.get("data", []) or []

severity_buckets = {
    "critical": {"total": 0, "duplicate": 0, "false_positive": 0},
    "error": {"total": 0, "duplicate": 0, "false_positive": 0},
    "warning": {"total": 0, "duplicate": 0, "false_positive": 0},
}

fingerprint_seen = defaultdict(int)
total_alerts = 0
duplicate_alerts = 0
false_positive_alerts = 0

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

    if fingerprint_seen[fingerprint] > 0:
        duplicate_alerts += 1
        severity_buckets[severity]["duplicate"] += 1
    fingerprint_seen[fingerprint] += 1

    is_fp = (
        str(labels.get(fp_label_key, "")).strip().lower() == fp_label_val.strip().lower()
        or str(annotations.get(fp_annot_key, "")).strip().lower() == fp_annot_val.strip().lower()
    )
    if is_fp:
        false_positive_alerts += 1
        severity_buckets[severity]["false_positive"] += 1

output = {
    "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "generated_by": "build-alert-noise-runtime-sample.sh",
    "total_alerts": total_alerts,
    "duplicate_alerts": duplicate_alerts,
    "false_positive_alerts": false_positive_alerts,
    "severity_buckets": severity_buckets,
    "source": {
        "type": "prometheus_api",
        "alert_count": len(alerts),
        "lookback_days": 0,
    },
}

with open(out_file, "w", encoding="utf-8") as fp:
    fp.write(json.dumps(output, indent=2) + "\n")
PY

echo "OK   wrote alert-noise runtime sample -> $OUT_FILE"
echo "  generated: $(cat "$OUT_FILE")"
