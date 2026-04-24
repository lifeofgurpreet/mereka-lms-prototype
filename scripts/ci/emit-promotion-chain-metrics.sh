#!/usr/bin/env bash
# emit-promotion-chain-metrics.sh — Emit per-stage timing metrics for the
# Mereka LMS promotion conveyor (app-repo merge → bbi-infra PR opened →
# bbi-infra merge → Argo sync start → Argo sync finish → cluster pod image
# realized).
#
# The conveyor currently has no single metric capturing end-to-end latency.
# This helper writes a line per observed stage to a local JSON artifact and
# (when $GITHUB_STEP_SUMMARY is set) appends a markdown table for operators.
#
# Usage:
#   emit-promotion-chain-metrics.sh --stage <name> --release-unit-id <sha>
#   emit-promotion-chain-metrics.sh --stage app_merge --release-unit-id abc123
#   emit-promotion-chain-metrics.sh --stage bbi_pr_opened --release-unit-id abc123 --bbi-pr 3244
#   emit-promotion-chain-metrics.sh --stage argo_sync_finished --release-unit-id abc123
#
# Known stages (in chronological order of the conveyor):
#   app_merge           — app-repo commit merged to main
#   bbi_pr_opened       — bbi-infrastructure promotion PR opened
#   bbi_pr_merged       — bbi-infrastructure promotion PR merged to main
#   argo_sync_started   — ArgoCD began reconciling the new revision
#   argo_sync_finished  — ArgoCD sync operation completed
#   pod_image_realized  — live pods verified on expected digest
#                          (companion to scripts/qa/verify-pods-on-digest.sh)
#
# Output:
#   - Appends a line to promotion-chain-<release-unit-id>.jsonl (one object per call)
#   - If $GITHUB_STEP_SUMMARY is set, appends a markdown row
#
# Intended downstream consumer:
#   ci-metrics.mereka.dev receiver (separate wire-in PR against workflows)
#
# Bead: mereka-lms-lb4c.1 (S6.1 — instrument promotion chain timing)
# See also: scripts/ci/emit-build-metrics.sh (sibling pattern for build layer)

set -euo pipefail

STAGE=""
RELEASE_UNIT_ID=""
BBI_PR_NUMBER=""
OUT_DIR="${PROMOTION_METRICS_OUT_DIR:-.}"
WORKFLOW_RUN_ID="${GITHUB_RUN_ID:-}"

VALID_STAGES=(
  app_merge
  bbi_pr_opened
  bbi_pr_merged
  argo_sync_started
  argo_sync_finished
  pod_image_realized
)

die() { echo "error: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)            STAGE="${2:-}"; shift 2 ;;
    --release-unit-id)  RELEASE_UNIT_ID="${2:-}"; shift 2 ;;
    --bbi-pr)           BBI_PR_NUMBER="${2:-}"; shift 2 ;;
    --out-dir)          OUT_DIR="${2:-}"; shift 2 ;;
    --workflow-run-id)  WORKFLOW_RUN_ID="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '1,35p' "$0"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$STAGE" ]]           || die "--stage is required"
[[ -n "$RELEASE_UNIT_ID" ]] || die "--release-unit-id is required"

# Validate stage
valid=0
for s in "${VALID_STAGES[@]}"; do
  if [[ "$s" == "$STAGE" ]]; then valid=1; break; fi
done
[[ "$valid" -eq 1 ]] || die "invalid stage '$STAGE' (valid: ${VALID_STAGES[*]})"

mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/promotion-chain-${RELEASE_UNIT_ID}.jsonl"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
EPOCH_MS="$(($(date +%s%N)/1000000))"

# Build JSON object (keep fields in a stable, deterministic order)
json_line=$(python3 -c "
import json
obj = {
    'schema_version': 'promotion-chain/v1',
    'stage': '${STAGE}',
    'release_unit_id': '${RELEASE_UNIT_ID}',
    'timestamp_utc': '${TIMESTAMP}',
    'epoch_ms': ${EPOCH_MS},
    'workflow_run_id': '${WORKFLOW_RUN_ID}' if '${WORKFLOW_RUN_ID}' else None,
    'bbi_pr_number': '${BBI_PR_NUMBER}' if '${BBI_PR_NUMBER}' else None,
}
# Strip None values for cleaner output
obj = {k: v for k, v in obj.items() if v is not None}
print(json.dumps(obj, sort_keys=False, separators=(',', ':')))
")

echo "${json_line}" >> "${OUT_FILE}"
echo "[emit-promotion-chain-metrics] stage=${STAGE} timestamp=${TIMESTAMP} release=${RELEASE_UNIT_ID}" >&2

# Markdown summary for $GITHUB_STEP_SUMMARY
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  if ! grep -qF "| Promotion Chain Metric |" "${GITHUB_STEP_SUMMARY}" 2>/dev/null; then
    {
      echo ""
      echo "## Promotion Chain Metric"
      echo ""
      echo "| Stage | Release Unit | Timestamp (UTC) | Workflow Run |"
      echo "|-------|--------------|-----------------|--------------|"
    } >> "${GITHUB_STEP_SUMMARY}"
  fi
  echo "| ${STAGE} | ${RELEASE_UNIT_ID} | ${TIMESTAMP} | ${WORKFLOW_RUN_ID:--} |" >> "${GITHUB_STEP_SUMMARY}"
fi

# Emit the final file path so callers can upload it as an artifact
echo "${OUT_FILE}"
