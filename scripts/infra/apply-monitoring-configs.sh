#!/usr/bin/env bash
# @covers AC-001
# @spec: observability-stack_spec.md
# Apply uptime checks, logging metrics, and alert policies to GCP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT="${GCP_PROJECT:-mereka-lms}"
MODE="${1:-plan}"
INCLUDE_LEGACY="${INCLUDE_LEGACY_MONITORING:-0}"
OFFLINE_PLAN="${OFFLINE_PLAN:-0}"

if [[ "$MODE" != "plan" && "$MODE" != "apply" ]]; then
  echo "Usage: $0 [plan|apply]" >&2
  exit 1
fi

if [[ "$MODE" == "apply" && "$OFFLINE_PLAN" == "1" ]]; then
  echo "OFFLINE_PLAN=1 is only supported with mode=plan" >&2
  exit 1
fi

is_legacy_artifact() {
  local file="$1"
  local base
  base="$(basename "$file")"
  case "$base" in
    cloudsql.json|cloudsql-disk.json)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_unsupported_alert_template() {
  local file="$1"
  local base
  base="$(basename "$file")"
  case "$base" in
    velero-restore-test-stale.json)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

apply_cmd() {
  if [[ "$MODE" == "apply" ]]; then
    eval "$1"
  else
    echo "$1"
  fi
}

uptime_id_for() {
  local display_name=$1
  if [[ "$OFFLINE_PLAN" == "1" ]]; then
    echo ""
    return 0
  fi
  gcloud monitoring uptime list-configs --project="$PROJECT" --format=json \
    | jq -r --arg name "$display_name" '.[] | select(.displayName==$name) | .name' \
    | head -n 1
}

policy_id_for() {
  local display_name=$1
  if [[ "$OFFLINE_PLAN" == "1" ]]; then
    echo ""
    return 0
  fi
  gcloud monitoring policies list --project="$PROJECT" --format=json \
    | jq -r --arg name "$display_name" '.[] | select(.displayName==$name) | .name' \
    | head -n 1
}

dashboard_id_for() {
  local display_name=$1
  if [[ "$OFFLINE_PLAN" == "1" ]]; then
    echo ""
    return 0
  fi
  gcloud monitoring dashboards list --project="$PROJECT" --format=json \
    | jq -r --arg name "$display_name" '.[] | select(.displayName==$name) | .name' \
    | head -n 1
}

for file in "$ROOT_DIR"/infrastructure/monitoring/uptime/prod-*.json; do
  display_name=$(jq -r '.displayName' "$file")
  host=$(jq -r '.monitoredResource.labels.host' "$file")
  resource_project=$(jq -r '.monitoredResource.labels.project_id' "$file")
  path=$(jq -r '.httpCheck.path' "$file")
  port=$(jq -r '.httpCheck.port' "$file")
  validate_ssl=$(jq -r '.httpCheck.validateSsl' "$file")
  use_ssl=$(jq -r '.httpCheck.useSsl' "$file")
  timeout=$(jq -r '.timeout' "$file")
  period=$(jq -r '.period' "$file")
  timeout="${timeout%s}"
  period="${period%s}"
  if [[ "$period" =~ ^[0-9]+$ ]]; then
    period=$((period / 60))
  fi
  regions=$(jq -r '.selectedRegions | map(ascii_downcase | sub("^region_";"") | gsub("_";"-")) | join(",")' "$file")
  if [[ -n "$regions" ]]; then
    IFS=',' read -ra region_list <<< "$regions"
    if [[ ${#region_list[@]} -lt 3 ]]; then
      regions="asia-pacific,usa-oregon,europe"
    fi
  fi
  user_labels=$(jq -r '.userLabels | to_entries | map("\(.key)=\(.value)") | join(",")' "$file")
  protocol="http"
  if [[ "$use_ssl" == "true" ]]; then
    protocol="https"
  fi

  args=(
    "--resource-type=uptime-url"
    "--resource-labels=host=${host},project_id=${resource_project}"
    "--protocol=${protocol}"
    "--path=${path}"
    "--port=${port}"
    "--validate-ssl=${validate_ssl}"
    "--timeout=${timeout}"
    "--period=${period}"
    "--regions=${regions}"
    "--project=${PROJECT}"
  )
  if [[ -n "$user_labels" ]]; then
    args+=("--user-labels=${user_labels}")
  fi

  existing_id=$(uptime_id_for "$display_name")
  if [[ -n "$existing_id" ]]; then
    apply_cmd "gcloud monitoring uptime delete '$existing_id' --quiet --project='$PROJECT'"
  fi
  apply_cmd "gcloud monitoring uptime create '$display_name' ${args[*]}"
done

for file in "$ROOT_DIR"/infrastructure/monitoring/logging-metrics/*.json; do
  metric_name=$(basename "$file" .json)
  if [[ "$OFFLINE_PLAN" == "1" ]]; then
    echo "gcloud logging metrics create '$metric_name' --config-from-file='$file' --project='$PROJECT'"
  elif gcloud logging metrics describe "$metric_name" --project="$PROJECT" >/dev/null 2>&1; then
    apply_cmd "gcloud logging metrics update '$metric_name' --config-from-file='$file' --project='$PROJECT'"
  else
    apply_cmd "gcloud logging metrics create '$metric_name' --config-from-file='$file' --project='$PROJECT'"
  fi
done

for file in "$ROOT_DIR"/infrastructure/monitoring/alerts/*.json; do
  if [[ "$INCLUDE_LEGACY" != "1" ]] && is_legacy_artifact "$file"; then
    echo "Skipping legacy alert template: $(basename "$file") (set INCLUDE_LEGACY_MONITORING=1 to include)"
    continue
  fi
  if is_unsupported_alert_template "$file"; then
    echo "Skipping unsupported alert template: $(basename "$file") (Cloud Monitoring alert windows are limited to 24h for this condition type)"
    continue
  fi
  display_name=$(jq -r '.displayName' "$file")
  existing_id=$(policy_id_for "$display_name")
  if [[ "$MODE" == "apply" ]]; then
    if [[ -n "$existing_id" ]]; then
      if ! gcloud monitoring policies update "$existing_id" --policy-from-file="$file" --project="$PROJECT"; then
        echo "WARN: Failed to update policy $display_name. Retry after metrics propagate." >&2
      fi
    else
      if ! gcloud monitoring policies create --policy-from-file="$file" --project="$PROJECT"; then
        echo "WARN: Failed to create policy $display_name. Retry after metrics propagate." >&2
      fi
    fi
  else
    if [[ -n "$existing_id" ]]; then
      echo "gcloud monitoring policies update '$existing_id' --policy-from-file='$file' --project='$PROJECT'"
    else
      echo "gcloud monitoring policies create --policy-from-file='$file' --project='$PROJECT'"
    fi
  fi
done

for file in "$ROOT_DIR"/infrastructure/monitoring/dashboards/*.json; do
  if [[ "$INCLUDE_LEGACY" != "1" ]] && is_legacy_artifact "$file"; then
    echo "Skipping legacy dashboard template: $(basename "$file") (set INCLUDE_LEGACY_MONITORING=1 to include)"
    continue
  fi
  display_name=$(jq -r '.displayName' "$file")
  existing_id=$(dashboard_id_for "$display_name")
  if [[ "$MODE" == "apply" ]]; then
    if [[ -n "$existing_id" ]]; then
      if ! gcloud monitoring dashboards delete "$existing_id" --quiet --project="$PROJECT"; then
        echo "WARN: Failed to delete dashboard $display_name ($existing_id)." >&2
      fi
    fi
    if ! gcloud monitoring dashboards create --config-from-file="$file" --project="$PROJECT"; then
      echo "WARN: Failed to create dashboard $display_name from $(basename "$file")." >&2
    fi
  else
    if [[ -n "$existing_id" ]]; then
      echo "gcloud monitoring dashboards delete '$existing_id' --quiet --project='$PROJECT'"
    fi
    echo "gcloud monitoring dashboards create --config-from-file='$file' --project='$PROJECT'"
  fi
done

if [[ "$MODE" == "plan" ]]; then
  if [[ "$OFFLINE_PLAN" == "1" ]]; then
    echo "Offline plan complete (no cloud discovery calls were made)."
  else
    echo "Plan complete. Re-run with 'apply' to execute commands."
  fi
fi
