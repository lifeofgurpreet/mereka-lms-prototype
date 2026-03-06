#!/usr/bin/env bash
set -euo pipefail

CURRENT_SUMMARY=""
BASE_REF="origin/main"
BASE_SUMMARY=""
MAX_STALE_DAYS=45
REGRESSION_THRESHOLD=10
WORKDIR=""
OUT_PATH=""
BASE_SUMMARY_PATH=""

usage() {
  cat <<'EOF'
Usage:
  compare-docs-scorecard-to-base.sh --current-summary <current-summary.json> [options]

Options:
  --current-summary <path>   (required) current catalog health summary file
  --base-ref <ref>           git ref for baseline branch (default: origin/main)
  --base-summary <path>      precomputed baseline summary file to avoid git worktree
  --max-stale-days <n>       stale threshold used for baseline refresh (default: 45)
  --regression-threshold <n> max allowed score drop (default: 10)
  --out <path>               write JSON comparison artifact
  --help                     show usage
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --current-summary)
      CURRENT_SUMMARY="${2:-}"
      shift 2
      ;;
    --base-ref)
      BASE_REF="${2:-origin/main}"
      shift 2
      ;;
    --base-summary)
      BASE_SUMMARY="${2:-}"
      shift 2
      ;;
    --max-stale-days)
      MAX_STALE_DAYS="${2:-45}"
      shift 2
      ;;
    --regression-threshold)
      REGRESSION_THRESHOLD="${2:-10}"
      shift 2
      ;;
    --out)
      OUT_PATH="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [ -z "$CURRENT_SUMMARY" ]; then
  usage
  exit 1
fi

if [ -z "$BASE_SUMMARY" ]; then
  WORKDIR="$(mktemp -d)"
  BASE_REPO="${WORKDIR}/base-repo"
  BASE_SUMMARY_PATH="${WORKDIR}/base-catalog-health-summary.json"
  BASE_SCORE="${WORKDIR}/base-scorecard.json"
  CURRENT_SCORE="${WORKDIR}/current-scorecard.json"
  cleanup() {
    if [ -n "${BASE_REPO}" ] && [ -d "${BASE_REPO}" ]; then
      git worktree remove --force "${BASE_REPO}" >/dev/null 2>&1 || true
    fi
    if [ -n "${WORKDIR}" ] && [ -d "${WORKDIR}" ]; then
      rm -rf "${WORKDIR}"
    fi
  }
  trap cleanup EXIT

  git worktree add --detach "${BASE_REPO}" "${BASE_REF}"
  python3 docs/qa/verify-doc-catalog-health.py \
    --max-stale-days "${MAX_STALE_DAYS}" \
    --root "${BASE_REPO}" \
    --summary-file "${BASE_SUMMARY_PATH}"
else
  BASE_SUMMARY_PATH="$BASE_SUMMARY"
  WORKDIR="$(mktemp -d)"
  BASE_SCORE="${WORKDIR}/base-scorecard.json"
  CURRENT_SCORE="${WORKDIR}/current-scorecard.json"
  cleanup() {
    if [ -n "${WORKDIR}" ] && [ -d "${WORKDIR}" ]; then
      rm -rf "${WORKDIR}"
    fi
  }
  trap cleanup EXIT
fi

python3 docs/qa/build-docs-scorecard.py \
  --summary-file "$BASE_SUMMARY_PATH" \
  --out "$BASE_SCORE" \
  --min-score 0
python3 docs/qa/build-docs-scorecard.py \
  --summary-file "$CURRENT_SUMMARY" \
  --out "$CURRENT_SCORE" \
  --min-score 0

python3 - "$BASE_SCORE" "$CURRENT_SCORE" "$REGRESSION_THRESHOLD" "${BASE_REF}" "${OUT_PATH}" <<'PY'
import json
import sys
from pathlib import Path

base = json.load(open(sys.argv[1], encoding="utf-8"))
current = json.load(open(sys.argv[2], encoding="utf-8"))
threshold = int(sys.argv[3])
base_ref = sys.argv[4]
out_path = sys.argv[5]

base_score = int(base.get("score", 0))
current_score = int(current.get("score", 0))
drop = base_score - current_score
status = "pass" if drop <= threshold else "fail"

result = {
    "base_ref": base_ref,
    "base_score": base_score,
    "current_score": current_score,
    "score_drop": drop,
    "max_allowed_drop": threshold,
    "status": status,
}

if out_path:
    Path(out_path).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(f"DOCS_SCORECARD_TREND status={status} base={base_score} current={current_score} drop={drop} threshold={threshold}")
if status == "fail":
    raise SystemExit(1)
PY
