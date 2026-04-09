#!/usr/bin/env bash
# verify-ops-reliability-streak.sh — B-027 ops reliability streak consumer
#
# Reads the ops-reliability-streak artifact from the most recent
# daily-infrastructure-audit run and reports whether the streak meets the
# 7-run threshold.
#
# This is INFORMATIONAL only: exits 0 regardless of streak status.
# A WARNING is printed when streak < 7 so the state is visible in CI output.
#
# Usage:
#   scripts/qa/verify-ops-reliability-streak.sh [--repo OWNER/REPO]
#
# Prerequisites:
#   gh CLI authenticated (GITHUB_TOKEN or gh auth login)
#
# Environment:
#   GH_REPO   Override the target repo (default: Biji-Biji-Initiative/mereka-lms)

set -euo pipefail

REQUIRED_STREAK=7
ARTIFACT_NAME="ops-reliability-streak"
WORKFLOW_FILE="daily-infrastructure-audit.yml"
GH_REPO="${GH_REPO:-Biji-Biji-Initiative/mereka-lms}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      GH_REPO="${2:?--repo requires OWNER/REPO}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--repo OWNER/REPO]" >&2
      exit 1
      ;;
  esac
done

echo "=== Ops Reliability Streak Check (B-027) ==="
echo "Repo:     $GH_REPO"
echo "Artifact: $ARTIFACT_NAME"
echo "Required: $REQUIRED_STREAK consecutive successful daily audit runs"
echo ""

if ! command -v gh &>/dev/null; then
  echo "WARNING: gh CLI not found — cannot fetch artifact. Skipping streak check."
  echo "Install gh: https://cli.github.com/"
  exit 0
fi

# Find the most recent successful run of the workflow that produced the artifact
RUN_ID=$(
  gh api \
    "repos/${GH_REPO}/actions/workflows/${WORKFLOW_FILE}/runs?event=schedule&per_page=10&status=completed" \
    --jq '.workflow_runs | map(select(.conclusion == "success")) | first | .id // empty' \
    2>/dev/null || true
)

if [[ -z "$RUN_ID" ]]; then
  echo "WARNING: No completed successful runs found for ${WORKFLOW_FILE}."
  echo "         Streak data unavailable — cannot assess ops reliability."
  exit 0
fi

echo "Latest successful run ID: $RUN_ID"

# Download the artifact JSON
ARTIFACT_JSON=$(
  gh api \
    "repos/${GH_REPO}/actions/runs/${RUN_ID}/artifacts" \
    --jq ".artifacts | map(select(.name == \"${ARTIFACT_NAME}\")) | first // empty" \
    2>/dev/null || true
)

if [[ -z "$ARTIFACT_JSON" ]]; then
  echo "WARNING: Artifact '${ARTIFACT_NAME}' not found in run ${RUN_ID}."
  echo "         Streak data unavailable — the daily audit may not have emitted it yet."
  exit 0
fi

ARTIFACT_ID=$(echo "$ARTIFACT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "Artifact ID: $ARTIFACT_ID"

# Download artifact zip to a temp dir
TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

gh api \
  "repos/${GH_REPO}/actions/artifacts/${ARTIFACT_ID}/zip" \
  --header "Accept: application/vnd.github+json" \
  > "${TMPDIR_WORK}/artifact.zip" 2>/dev/null

if [[ ! -s "${TMPDIR_WORK}/artifact.zip" ]]; then
  echo "WARNING: Artifact download returned empty file. Skipping streak check."
  exit 0
fi

# Extract the JSON file from the zip
if ! command -v unzip &>/dev/null; then
  echo "WARNING: unzip not found — cannot extract artifact. Skipping streak check."
  exit 0
fi

unzip -q "${TMPDIR_WORK}/artifact.zip" -d "${TMPDIR_WORK}/extracted"

STREAK_FILE="$(find "${TMPDIR_WORK}/extracted" -name "ops-reliability-streak.json" | head -1)"
if [[ -z "$STREAK_FILE" ]]; then
  echo "WARNING: ops-reliability-streak.json not found inside artifact zip."
  exit 0
fi

# Parse and report
python3 - "$STREAK_FILE" "$REQUIRED_STREAK" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
required = int(sys.argv[2])

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"WARNING: Could not parse streak JSON: {exc}")
    sys.exit(0)

streak = data.get("streak", 0)
status = data.get("status", "unknown")
required_consecutive = data.get("required_consecutive", required)
generated_at = data.get("generated_at", "unknown")
workflow = data.get("workflow", "unknown")

print(f"Generated at: {generated_at}")
print(f"Workflow:     {workflow}")
print(f"Streak:       {streak}/{required_consecutive}")
print(f"Status:       {status}")
print()

if streak >= required:
    print(f"PASS: Ops reliability proven — {streak} consecutive successful daily audit run(s).")
else:
    remaining = required - streak
    print(
        f"WARNING: Ops reliability streak at {streak}/{required_consecutive}. "
        f"Need {remaining} more consecutive successful run(s) to reach threshold."
    )
    print("         This is informational — release is not blocked.")

sys.exit(0)
PY
