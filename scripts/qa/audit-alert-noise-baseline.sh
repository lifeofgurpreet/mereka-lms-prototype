#!/usr/bin/env bash
# Audit alert-noise baseline thresholds (local contract + optional runtime sample).
#
# Usage:
#   ./scripts/qa/audit-alert-noise-baseline.sh --mode local
#   ALERT_NOISE_RUNTIME_SOURCE=/path/to/sample.json ./scripts/qa/audit-alert-noise-baseline.sh --mode runtime
#
# Runtime sample JSON contract:
# {
#   "generated_at": "2026-02-25T00:00:00Z",
#   "total_alerts": 100,
#   "duplicate_alerts": 8,
#   "false_positive_alerts": 6,
#   "severity_buckets": {
#     "critical": {"total": 8, "duplicate": 0, "false_positive": 0},
#     "error": {"total": 14, "duplicate": 1, "false_positive": 1},
#     "warning": {"total": 32, "duplicate": 5, "false_positive": 2}
#   }
# }

set -euo pipefail

MODE="local" # local|runtime
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"
CONFIG_PATH="${ALERT_NOISE_BASELINE_CONFIG:-infrastructure/monitoring/alert-noise-baseline.json}"
RUNTIME_SOURCE="${ALERT_NOISE_RUNTIME_SOURCE:-}"
CLASSIFICATION_FEED="${ALERT_NOISE_FP_CLASSIFICATION_FEED:-}"

usage() {
  cat <<'EOF2'
Usage: ./scripts/qa/audit-alert-noise-baseline.sh --mode local|runtime
EOF2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-local}"
      shift 2
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

if [[ "$MODE" != "local" && "$MODE" != "runtime" ]]; then
  echo "Invalid --mode: $MODE" >&2
  usage
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Baseline config missing: $CONFIG_PATH" >&2
  exit 1
fi

jq -e '
  .schema_version and
  (.lookback_days | numbers and . > 0) and
  (.minimum_sample_size | numbers and . > 0) and
  (.required_severities | type == "array" and length >= 1) and
  ((.required_severities | unique | length) == (.required_severities | length)) and
  (all(.required_severities[]; . == "critical" or . == "error" or . == "warning")) and
  (.thresholds.duplicate_alert_ratio_max | numbers and . >= 0 and . <= 1) and
  (.thresholds.false_positive_ratio_max | numbers and . >= 0 and . <= 1) and
  ((.thresholds.severity // {}) | type == "object") and
  (all((.required_severities // [])[] as $severity; .thresholds.severity[$severity] )) and
  (all((.thresholds.severity | to_entries | .[]); .value.duplicate_alert_ratio_max | numbers and . >= 0 and . <= 1 and .value.false_positive_ratio_max | numbers and . >= 0 and . <= 1)) and
  (all((.required_severities // [])[] as $severity; .thresholds.severity[$severity] != null and .thresholds.severity[$severity].duplicate_alert_ratio_max >= 0 and .thresholds.severity[$severity].false_positive_ratio_max >= 0)) and
  (((.required_severities | sort) | unique) == ((.thresholds.severity | keys | sort) | unique))
' "$CONFIG_PATH" >/dev/null

echo "OK   local: alert-noise baseline schema valid ($CONFIG_PATH)"

if [[ "$MODE" == "local" ]]; then
  exit 0
fi

if [[ -z "$RUNTIME_SOURCE" || ! -f "$RUNTIME_SOURCE" ]]; then
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    echo "Runtime source missing. Set ALERT_NOISE_RUNTIME_SOURCE=/path/to/sample.json" >&2
    exit 1
  fi
  echo "SKIP runtime: ALERT_NOISE_RUNTIME_SOURCE not provided."
  exit 0
fi

if [[ -n "$CLASSIFICATION_FEED" ]]; then
  if [[ ! -f "$CLASSIFICATION_FEED" ]]; then
    echo "WARN: ALERT_NOISE_FP_CLASSIFICATION_FEED points to missing file: $CLASSIFICATION_FEED" >&2
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      exit 1
    fi
  else
    if ! jq -e '
      type == "object" and
      (.entries | type == "array") and
      (all(.entries[]?; (.fingerprint | type == "string") and (.fingerprint | length > 0) and (.classification | type == "string") and (.classification == "false_positive" or .classification == "suppress")))
    ' "$CLASSIFICATION_FEED" >/dev/null; then
      echo "WARN: malformed ALERT_NOISE_FP_CLASSIFICATION_FEED: $CLASSIFICATION_FEED" >&2
      if [[ "$STRICT_RUNTIME" == "1" ]]; then
        exit 1
      fi
    fi
  fi
fi

jq -e '
  (.total_alerts | numbers and . >= 0) and
  (.duplicate_alerts | numbers and . >= 0) and
  (.false_positive_alerts | numbers and . >= 0) and
  (((.false_positive_summary // {}) | type == "object") and
    (((.false_positive_summary.label_matches // 0) | numbers and . >= 0)) and
    (((.false_positive_summary.feed_matches // 0) | numbers and . >= 0))) and
  (.duplicate_detection.window_minutes | numbers and . > 0) and
  (.duplicate_detection.min_dup_group_size | numbers and . >= 2) and
  (((.classification_feed // {}) | type == "object")) and
  (((.classification_feed.entries_total // 0) | numbers and . >= 0)) and
  (((.classification_feed.entries_accepted // 0) | numbers and . >= 0)) and
  (((.classification_feed.entries_rejected // 0) | numbers and . >= 0)) and
  (.duplicate_windows | type == "array")
' "$RUNTIME_SOURCE" >/dev/null

required_severities=(
  $(jq -r '.required_severities[]' "$CONFIG_PATH")
)

if [[ "${#required_severities[@]}" -eq 0 ]]; then
  echo "FAIL runtime: required_severities must contain at least one severity" >&2
  exit 1
fi

sample_total="$(jq -r '.total_alerts' "$RUNTIME_SOURCE")"
sample_dup="$(jq -r '.duplicate_alerts' "$RUNTIME_SOURCE")"
sample_fp="$(jq -r '.false_positive_alerts' "$RUNTIME_SOURCE")"
sample_window="$(jq -r '.duplicate_detection.window_minutes // 0' "$RUNTIME_SOURCE")"
sample_min_dup_group="$(jq -r '.duplicate_detection.min_dup_group_size // 0' "$RUNTIME_SOURCE")"
sample_feed="$(jq -r '.classification_feed.path // ""' "$RUNTIME_SOURCE")"

min_n="$(jq -r '.minimum_sample_size' "$CONFIG_PATH")"
dup_max="$(jq -r '.thresholds.duplicate_alert_ratio_max' "$CONFIG_PATH")"
fp_max="$(jq -r '.thresholds.false_positive_ratio_max' "$CONFIG_PATH")"
cfg_window="$(jq -r '.thresholds.duplicate_detection.fingerprint_window_minutes // 5' "$CONFIG_PATH")"
cfg_min_dup_group="$(jq -r '.thresholds.duplicate_detection.min_dup_group_size // 2' "$CONFIG_PATH")"

if [[ "$sample_window" != "$cfg_window" ]] || [[ "$sample_min_dup_group" != "$cfg_min_dup_group" ]]; then
  echo "WARN runtime sample duplicate detection config mismatch: sample window=${sample_window},group=${sample_min_dup_group}; config window=${cfg_window},group=${cfg_min_dup_group}"
fi

if [[ -n "$CLASSIFICATION_FEED" && -n "$sample_feed" && "$sample_feed" != "$CLASSIFICATION_FEED" ]]; then
  echo "WARN runtime sample consumed different false-positive feed than requested: expected=${CLASSIFICATION_FEED}, sample=${sample_feed}"
fi

if [[ "$sample_total" -lt "$min_n" ]]; then
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    echo "Runtime sample size too small: total_alerts=$sample_total < minimum_sample_size=$min_n" >&2
    exit 1
  fi
  echo "SKIP runtime: sample size too small ($sample_total < $min_n)."
  exit 0
fi

overall_dup_ratio="$(awk -v d="$sample_dup" -v t="$sample_total" 'BEGIN{printf "%.6f", (t==0?0:d/t)}')"
overall_fp_ratio="$(awk -v f="$sample_fp" -v t="$sample_total" 'BEGIN{printf "%.6f", (t==0?0:f/t)}')"

overall_dup_ok="$(awk -v x="$overall_dup_ratio" -v m="$dup_max" 'BEGIN{print (x<=m ? 1 : 0)}')"
overall_fp_ok="$(awk -v x="$overall_fp_ratio" -v m="$fp_max" 'BEGIN{print (x<=m ? 1 : 0)}')"

if [[ "$overall_dup_ok" -eq 1 ]]; then
  echo "OK   runtime: duplicate_alert_ratio=$overall_dup_ratio <= max=$dup_max"
else
  echo "FAIL runtime: duplicate_alert_ratio=$overall_dup_ratio > max=$dup_max" >&2
  exit 1
fi

if [[ "$overall_fp_ok" -eq 1 ]]; then
  echo "OK   runtime: false_positive_ratio=$overall_fp_ratio <= max=$fp_max"
else
  echo "FAIL runtime: false_positive_ratio=$overall_fp_ratio > max=$fp_max" >&2
  exit 1
fi

severity_thresholds_present="$(jq -r '(.thresholds.severity // {} | to_entries | length)' "$CONFIG_PATH")"
if [[ "$severity_thresholds_present" -gt 0 ]]; then
  for severity in "${required_severities[@]}"; do
    severity_total="$(jq -r --arg s "$severity" '.severity_buckets[$s].total // empty' "$RUNTIME_SOURCE")"
    severity_dup="$(jq -r --arg s "$severity" '.severity_buckets[$s].duplicate // empty' "$RUNTIME_SOURCE")"
    severity_fp="$(jq -r --arg s "$severity" '.severity_buckets[$s].false_positive // empty' "$RUNTIME_SOURCE")"

    if [[ -z "$severity_total" || -z "$severity_dup" || -z "$severity_fp" ]]; then
      if [[ "$STRICT_RUNTIME" == "1" ]]; then
        echo "FAIL runtime: required severity '${severity}' missing from severity_buckets in runtime sample" >&2
        exit 1
      fi
      echo "SKIP runtime: required severity '${severity}' missing from sample"
      continue
    fi

    severity_dup_ratio="$(awk -v d="$severity_dup" -v t="$severity_total" 'BEGIN{printf "%.6f", (t==0?0:d/t)}')"
    severity_fp_ratio="$(awk -v f="$severity_fp" -v t="$severity_total" 'BEGIN{printf "%.6f", (t==0?0:f/t)}')"

    severity_dup_max="$(jq -r --arg s "$severity" '.thresholds.severity[$s].duplicate_alert_ratio_max' "$CONFIG_PATH")"
    severity_fp_max="$(jq -r --arg s "$severity" '.thresholds.severity[$s].false_positive_ratio_max' "$CONFIG_PATH")"

    severity_dup_ok="$(awk -v x="$severity_dup_ratio" -v m="$severity_dup_max" 'BEGIN{print (x<=m ? 1 : 0)}')"
    severity_fp_ok="$(awk -v x="$severity_fp_ratio" -v m="$severity_fp_max" 'BEGIN{print (x<=m ? 1 : 0)}')"

    if [[ "$severity_dup_ok" -eq 1 ]]; then
      echo "OK   runtime: severity=${severity} duplicate_alert_ratio=$severity_dup_ratio <= max=$severity_dup_max"
    else
      echo "FAIL runtime: severity=${severity} duplicate_alert_ratio=$severity_dup_ratio > max=$severity_dup_max" >&2
      exit 1
    fi

    if [[ "$severity_fp_ok" -eq 1 ]]; then
      echo "OK   runtime: severity=${severity} false_positive_ratio=$severity_fp_ratio <= max=$severity_fp_max"
    else
      echo "FAIL runtime: severity=${severity} false_positive_ratio=$severity_fp_ratio > max=$severity_fp_max" >&2
      exit 1
    fi
  done
fi
