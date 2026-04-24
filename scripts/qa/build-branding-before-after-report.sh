#!/usr/bin/env bash
# Build a before/after branding visual report from screenshot captures.
#
# This script compares two screenshot runs (baseline vs candidate), writes a
# machine-readable JSON summary, and generates a markdown report for human
# review/share-out.
#
# Usage:
#   ./scripts/qa/build-branding-before-after-report.sh --env prod
#   ./scripts/qa/build-branding-before-after-report.sh --env dev --mfe-only
#   ./scripts/qa/build-branding-before-after-report.sh --env prod --threshold 0.04 --strict
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

ENVIRONMENT=""
BASELINE_DIR=""
CANDIDATE_DIR=""
THRESHOLD="${THRESHOLD:-0.06}"
STRICT=0
ALLOW_BOOTSTRAP=0
MFE_ONLY=0

usage() {
  cat <<'EOF'
Usage: build-branding-before-after-report.sh [options]

Options:
  --env <prod|dev>       Target environment.
  --baseline <dir>       Optional baseline screenshot directory.
  --candidate <dir>      Optional candidate screenshot directory.
  --threshold <float>    RMSE threshold (default: 0.06).
  --strict               Fail when baseline/candidate file sets differ.
  --allow-bootstrap      Exit 0 when fewer than two screenshot runs exist.
  --mfe-only             Limit comparison to MFE screenshots only.
  -h, --help             Show help.

Back-compat:
  build-branding-before-after-report.sh prod
  build-branding-before-after-report.sh dev
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -lt 2 ]] && { echo "ERROR: --env requires a value" >&2; exit 2; }
      ENVIRONMENT="$2"
      shift 2
      ;;
    --baseline)
      [[ $# -lt 2 ]] && { echo "ERROR: --baseline requires a value" >&2; exit 2; }
      BASELINE_DIR="$2"
      shift 2
      ;;
    --candidate)
      [[ $# -lt 2 ]] && { echo "ERROR: --candidate requires a value" >&2; exit 2; }
      CANDIDATE_DIR="$2"
      shift 2
      ;;
    --threshold)
      [[ $# -lt 2 ]] && { echo "ERROR: --threshold requires a value" >&2; exit 2; }
      THRESHOLD="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --allow-bootstrap)
      ALLOW_BOOTSTRAP=1
      shift
      ;;
    --mfe-only)
      MFE_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    prod|dev)
      if [[ -n "$ENVIRONMENT" ]]; then
        echo "ERROR: duplicate environment argument ($1)" >&2
        exit 2
      fi
      ENVIRONMENT="$1"
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "ERROR: --env must be prod or dev" >&2
  usage >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 2
fi

if [[ ! "$THRESHOLD" =~ ^[0-9]*\.?[0-9]+$ ]]; then
  echo "ERROR: invalid --threshold value: $THRESHOLD" >&2
  exit 2
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$REPO_ROOT/var/evidence/branding-before-after/${ENVIRONMENT}/${STAMP}"
mkdir -p "$OUT_DIR"

VISUAL_JSON="$OUT_DIR/visual-regression.json"
VISUAL_STDERR_LOG="$OUT_DIR/visual-regression.stderr.log"
REPORT_MD="$OUT_DIR/REPORT.md"
SUMMARY_TXT="$OUT_DIR/summary.txt"

visual_args=(
  "$REPO_ROOT/scripts/qa/visual-regression-branding.sh"
  "$ENVIRONMENT"
  --threshold "$THRESHOLD"
  --json
)

if [[ -n "$BASELINE_DIR" ]]; then
  visual_args+=(--baseline "$BASELINE_DIR")
fi
if [[ -n "$CANDIDATE_DIR" ]]; then
  visual_args+=(--candidate "$CANDIDATE_DIR")
fi
if [[ "$STRICT" == "1" ]]; then
  visual_args+=(--strict)
fi
if [[ "$ALLOW_BOOTSTRAP" == "1" ]]; then
  visual_args+=(--allow-bootstrap)
fi
if [[ "$MFE_ONLY" == "1" ]]; then
  # Keep MFE surfaces only (authn/account/learning/dashboard + optional biji MFE).
  visual_args+=(--exclude-regex '^(lms-|studio-|ecommerce-|credentials-|forum-|notes-|biji-home|biji-studio-home|skillourfuture-home)')
fi

set +e
"${visual_args[@]}" >"$VISUAL_JSON" 2>"$VISUAL_STDERR_LOG"
visual_rc=$?
set -e

if [[ ! -s "$VISUAL_JSON" ]]; then
  echo "ERROR: visual regression output JSON missing: $VISUAL_JSON" >&2
  if [[ -s "$VISUAL_STDERR_LOG" ]]; then
    echo "----- stderr -----" >&2
    cat "$VISUAL_STDERR_LOG" >&2
    echo "------------------" >&2
  fi
  exit "$visual_rc"
fi

python3 - "$VISUAL_JSON" "$REPORT_MD" "$SUMMARY_TXT" "$visual_rc" "$MFE_ONLY" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

json_path = pathlib.Path(sys.argv[1])
report_path = pathlib.Path(sys.argv[2])
summary_path = pathlib.Path(sys.argv[3])
visual_rc = int(sys.argv[4])
mfe_only = sys.argv[5] == "1"

data = json.loads(json_path.read_text())
bootstrap = bool(data.get("bootstrap", False))
env = data.get("env", "unknown")
threshold = data.get("threshold", "n/a")
baseline = data.get("baseline", "")
candidate = data.get("candidate", "")
diff_dir = data.get("diff_dir", "")
compared = int(data.get("compared", 0))
skipped = int(data.get("skipped", 0))
failed = int(data.get("failed", 0))
missing_in_candidate = data.get("missing_in_candidate", [])
missing_in_baseline = data.get("missing_in_baseline", [])
results = data.get("results", [])

status = "PASS"
if bootstrap:
  status = "BOOTSTRAP"
elif visual_rc != 0:
  status = "FAIL"

generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

summary_lines = [
    f"Status: {status}",
    f"Environment: {env}",
    f"Scope: {'mfe-only' if mfe_only else 'full'}",
    f"Compared: {compared}",
    f"Skipped: {skipped}",
    f"Failed: {failed}",
    f"Threshold: {threshold}",
    f"Baseline: {baseline or '(auto)'}",
    f"Candidate: {candidate or '(auto)'}",
    f"Diff Dir: {diff_dir or '(none)'}",
]
summary_path.write_text("\n".join(summary_lines) + "\n")

lines = [
    "# Frontend Branding Before/After Report",
    "",
    f"- Generated: `{generated_at}`",
    f"- Status: **{status}**",
    f"- Environment: `{env}`",
    f"- Scope: `{'mfe-only' if mfe_only else 'full'}`",
    f"- Threshold: `{threshold}`",
    f"- Compared images: `{compared}`",
    f"- Skipped images: `{skipped}`",
    f"- Over-threshold images: `{failed}`",
    f"- Baseline: `{baseline or '(auto)'}`",
    f"- Candidate: `{candidate or '(auto)'}`",
    f"- Diff directory: `{diff_dir or '(none)'}`",
    "",
]

if bootstrap:
  lines.extend(
      [
          "## Bootstrap",
          "",
          "Not enough screenshot history exists yet to produce a before/after comparison.",
          "Capture screenshots at least twice, then re-run this report.",
          "",
      ]
  )
else:
  lines.extend(
      [
          "## Result Matrix",
          "",
          "| Screenshot | RMSE | Threshold | Over Threshold |",
          "|---|---:|---:|:---:|",
      ]
  )
  for row in sorted(results, key=lambda item: item.get("file", "")):
    filename = row.get("file", "")
    rmse = row.get("rmse", 0)
    over = "yes" if bool(row.get("over_threshold")) else "no"
    lines.append(f"| `{filename}` | `{rmse}` | `{threshold}` | `{over}` |")
  if not results:
    lines.append("| `(none)` | `n/a` | `n/a` | `n/a` |")
  lines.append("")

  lines.extend(
      [
          "## File-Set Drift",
          "",
          f"- Missing in candidate: `{len(missing_in_candidate)}`",
      ]
  )
  for name in missing_in_candidate:
    lines.append(f"  - `{name}`")
  lines.append(f"- Missing in baseline: `{len(missing_in_baseline)}`")
  for name in missing_in_baseline:
    lines.append(f"  - `{name}`")
  lines.append("")

report_path.write_text("\n".join(lines) + "\n")
PY

echo "Before/after report generated:"
echo "  - JSON:    ${VISUAL_JSON#"$REPO_ROOT"/}"
echo "  - Report:  ${REPORT_MD#"$REPO_ROOT"/}"
echo "  - Summary: ${SUMMARY_TXT#"$REPO_ROOT"/}"
echo "  - STDERR:  ${VISUAL_STDERR_LOG#"$REPO_ROOT"/}"

# Preserve semantic exit for callers (non-zero on threshold/file-set failures unless bootstrap-allowed).
exit "$visual_rc"
