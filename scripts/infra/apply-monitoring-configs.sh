#!/usr/bin/env bash
# Apply uptime checks, logging metrics, and alert policies to GCP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT="${GCP_PROJECT:-mereka-lms}"
MODE="${1:-plan}"

if [[ "$MODE" != "plan" && "$MODE" != "apply" ]]; then
  echo "Usage: $0 [plan|apply]" >&2
  exit 1
fi

apply_cmd() {
  if [[ "$MODE" == "apply" ]]; then
    eval "$1"
  else
    echo "$1"
  fi
}

for file in "$ROOT_DIR"/infrastructure/monitoring/uptime/prod-*.json; do
  apply_cmd "gcloud monitoring uptime configs create --config-from-file='$file' --project='$PROJECT'"
done

for file in "$ROOT_DIR"/infrastructure/monitoring/logging-metrics/*.json; do
  metric_name=$(basename "$file" .json)
  apply_cmd "gcloud logging metrics create '$metric_name' --config-from-file='$file' --project='$PROJECT'"
done

for file in "$ROOT_DIR"/infrastructure/monitoring/alerts/*.json; do
  apply_cmd "gcloud monitoring policies create --policy-from-file='$file' --project='$PROJECT'"
done

if [[ "$MODE" == "plan" ]]; then
  echo "Plan complete. Re-run with 'apply' to execute commands."
fi
