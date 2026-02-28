#!/usr/bin/env bash
set -euo pipefail

WORKFLOW="build-tutor-images.yml"
BRANCH=""
MAX_STALE_MINUTES="${MAX_STALE_MINUTES:-20}"
BUILD_MFE="${BUILD_MFE:-false}"
BUILD_OPENEDX="${BUILD_OPENEDX:-true}"
TARGET_ENV="${TARGET_ENV:-production}"
CANCEL_ALL_IN_PROGRESS=0

usage() {
  cat <<'EOF'
Usage: recover-stale-build-tutor-images.sh --branch <branch>

Cancels stale in-progress workflow_dispatch runs for build-tutor-images on the
given branch, then dispatches a fresh run on that same branch.

Environment overrides:
  MAX_STALE_MINUTES (default: 20)
  BUILD_OPENEDX (default: true)
  BUILD_MFE (default: false)
  TARGET_ENV (default: production)

Options:
  --cancel-all-in-progress   Cancel all in-progress workflow_dispatch runs on branch.

Example:
  ./scripts/infra/recover-stale-build-tutor-images.sh --branch build/tenantfix-20260228-r5
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      BRANCH="${2:-}"
      shift 2
      ;;
    --cancel-all-in-progress)
      CANCEL_ALL_IN_PROGRESS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  echo "--branch is required" >&2
  usage
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

now_epoch="$(date -u +%s)"
echo "Scanning in-progress $WORKFLOW runs on branch: $BRANCH"

if [[ "$CANCEL_ALL_IN_PROGRESS" -eq 1 ]]; then
  mapfile -t stale_ids < <(
    gh run list --workflow "$WORKFLOW" --branch "$BRANCH" --limit 20 \
      --json databaseId,status,event \
    | jq -r '.[] | select(.status == "in_progress" and .event == "workflow_dispatch") | .databaseId'
  )
else
  mapfile -t stale_ids < <(
    gh run list --workflow "$WORKFLOW" --branch "$BRANCH" --limit 20 \
      --json databaseId,status,event,createdAt \
    | jq -r --argjson now "$now_epoch" --argjson maxm "$MAX_STALE_MINUTES" '
        .[]
        | select(.status == "in_progress" and .event == "workflow_dispatch")
        | . as $run
        | ((($now - (.createdAt | sub("\\..*Z$"; "Z") | fromdateiso8601)) / 60) | floor) as $age_min
        | select($age_min >= $maxm)
        | .databaseId
      '
  )
fi

if [[ "${#stale_ids[@]}" -gt 0 ]]; then
  if [[ "$CANCEL_ALL_IN_PROGRESS" -eq 1 ]]; then
    echo "Cancelling all in-progress runs: ${stale_ids[*]}"
  else
    echo "Cancelling stale runs (>= ${MAX_STALE_MINUTES}m): ${stale_ids[*]}"
  fi
  for id in "${stale_ids[@]}"; do
    gh run cancel "$id" || true
  done
  sleep 3
else
  echo "No stale in-progress runs found."
fi

echo "Dispatching fresh workflow run on $BRANCH"
gh workflow run "$WORKFLOW" --ref "$BRANCH" \
  -f build_openedx="$BUILD_OPENEDX" \
  -f build_mfe="$BUILD_MFE" \
  -f update_gitops=false \
  -f deploy_to_staging=false \
  -f target_environment="$TARGET_ENV"

sleep 3
echo "Latest runs on $BRANCH:"
gh run list --workflow "$WORKFLOW" --branch "$BRANCH" --limit 5 \
  --json databaseId,status,conclusion,createdAt,headSha,event \
| jq -r '.[] | [.databaseId, .status, (.conclusion // ""), .event, .headSha, .createdAt] | @tsv'
