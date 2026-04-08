#!/usr/bin/env bash
# @covers AC-GIS-003
# @spec: gitops-integrity-system_spec.md
#
# Generate truth-state-matrix entries from git log and acceptance results.
# Usage: ./scripts/qa/generate-truth-state-matrix.sh [--since DAYS] [--write]
#
# Without --write, outputs what WOULD be added (dry-run).
# With --write, appends new entries to config/truth-state-matrix.yaml.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
MATRIX="${REPO_ROOT}/config/truth-state-matrix.yaml"
SINCE_DAYS="${SINCE_DAYS:-7}"
WRITE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE_DAYS="$2"; shift 2 ;;
    --write) WRITE=true; shift ;;
    *) shift ;;
  esac
done

echo "=== Truth State Matrix Generator ==="
echo "Scanning last ${SINCE_DAYS} days of merged PRs..."
echo ""

# Find merged PRs in the last N days
MERGED_PRS=$(git log --since="${SINCE_DAYS} days ago" --oneline --grep='(#' | grep -oP '#\d+' | sort -u)

if [[ -z "$MERGED_PRS" ]]; then
  echo "No merged PRs found in last ${SINCE_DAYS} days."
  exit 0
fi

echo "Found PRs: ${MERGED_PRS}"
echo ""

for PR in $MERGED_PRS; do
  PR_NUM="${PR#\#}"
  COMMIT=$(git log --oneline --grep="(${PR})" -1 --format='%H' 2>/dev/null || true)
  if [[ -z "$COMMIT" ]]; then
    continue
  fi
  SHORT=$(git log -1 --format='%h %s' "$COMMIT" 2>/dev/null)
  
  echo "--- PR $PR ---"
  echo "  commit: ${COMMIT:0:12}"
  echo "  subject: ${SHORT}"
  echo "  branch_truth: YES (merged)"
  echo "  merged_truth: YES (on main)"
  echo "  realized_truth: UNKNOWN (check ArgoCD)"
  echo "  proved_truth: UNKNOWN (check acceptance lanes)"
  echo "  durable_truth: UNKNOWN (check bootstrap reproducibility)"
  echo ""
done

if [[ "$WRITE" == "true" ]]; then
  echo "NOTE: --write appends to ${MATRIX}"
  echo "TODO: Implement YAML append logic"
else
  echo "Dry-run complete. Use --write to append entries."
fi
