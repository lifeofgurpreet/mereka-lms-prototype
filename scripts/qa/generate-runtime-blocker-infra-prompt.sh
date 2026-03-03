#!/usr/bin/env bash
# generate-runtime-blocker-infra-prompt.sh — Build infra-ready action prompt from blocker sweep JSON.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_GLOB="$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-*.summary.json"
PREFERRED_DEFAULTS=(
  "$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-latest-both.summary.json"
  "$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-latest-dev.summary.json"
  "$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-latest-prod.summary.json"
)
INPUT_JSON=""
OUTPUT_FILE=""
FORMAT="text"

usage() {
  cat <<'USAGE'
Usage: generate-runtime-blocker-infra-prompt.sh [--input <summary.json>] [--output <path>] [--format text|markdown]

Options:
  --input <path>   Explicit blocker sweep summary JSON. If omitted, latest matching file is used.
  --output <path>  Also write rendered prompt to this file path.
  --format <mode>  Output format: text (default) or markdown.
  -h, --help       Show help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      [[ $# -lt 2 ]] && { echo "ERROR: --input requires a value" >&2; exit 2; }
      INPUT_JSON="$2"
      shift 2
      ;;
    --output)
      [[ $# -lt 2 ]] && { echo "ERROR: --output requires a value" >&2; exit 2; }
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --format)
      [[ $# -lt 2 ]] && { echo "ERROR: --format requires a value" >&2; exit 2; }
      FORMAT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$INPUT_JSON" ]]; then
  for candidate in "${PREFERRED_DEFAULTS[@]}"; do
    if [[ -f "$candidate" ]]; then
      INPUT_JSON="$candidate"
      break
    fi
  done
fi

if [[ -z "$INPUT_JSON" ]]; then
  INPUT_JSON="$(ls -1t $DEFAULT_GLOB 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$INPUT_JSON" ]]; then
  echo "ERROR: no blocker sweep summary json found under var/qa" >&2
  exit 1
fi

if [[ ! -f "$INPUT_JSON" ]]; then
  echo "ERROR: input file not found: $INPUT_JSON" >&2
  exit 1
fi

if [[ "$FORMAT" != "text" && "$FORMAT" != "markdown" ]]; then
  echo "ERROR: --format must be text or markdown (got: $FORMAT)" >&2
  exit 2
fi

python3 - "$INPUT_JSON" "$OUTPUT_FILE" "$FORMAT" <<'PY'
import json
import io
import sys
from pathlib import Path
from datetime import datetime, timezone

p = Path(sys.argv[1])
output_file = sys.argv[2].strip() if len(sys.argv) > 2 else ""
fmt = sys.argv[3].strip() if len(sys.argv) > 3 else "text"
data = json.loads(p.read_text())
summary = data.get("summary", {})
diags = data.get("artifacts", {}).get("diagnostics", [])
latest_artifacts = data.get("artifacts", {}).get("latest", {})
diagnostics_tsv = latest_artifacts.get("diagnostics_tsv") or data.get("artifacts", {}).get("diagnostics_tsv")

fails = [d for d in diags if d.get("status") == "fail"]
now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

buf = io.StringIO()
def line(s=""):
    print(s, file=buf)

if fmt == "markdown":
    line("## Infra Action Prompt")
    line(f"- generated: `{now}`")
    line(f"- source summary: `{p}`")
    line("")
    line("Execute runtime remediation for the dev credentials blocker based on this canonical sweep output.")
    line("")
    line("### Current Status")
    line(f"- summary: `pass={summary.get('pass', 'na')} fail={summary.get('fail', 'na')} skip={summary.get('skip', 'na')}`")
    if diagnostics_tsv:
        line(f"- diagnostics_tsv: `{diagnostics_tsv}`")
else:
    line("Infra Action Prompt")
    line(f"Generated: {now}")
    line(f"Source summary: {p}")
    line("")
    line("Please execute runtime remediation for dev credentials blocker based on this canonical sweep output.")
    line("")
    line("Current status")
    line(f"- pass={summary.get('pass', 'na')} fail={summary.get('fail', 'na')} skip={summary.get('skip', 'na')}")
    if diagnostics_tsv:
        line(f"- diagnostics_tsv={diagnostics_tsv}")

if not fails:
    if fmt == "markdown":
        line("- no failing diagnostics found in summary JSON.")
    else:
        line("- No failing diagnostics found in summary JSON.")
    rendered = buf.getvalue()
    print(rendered, end="")
    if output_file:
        op = Path(output_file)
        op.parent.mkdir(parents=True, exist_ok=True)
        op.write_text(rendered)
    sys.exit(0)

line("")
if fmt == "markdown":
    line("### Required Actions (in order)")
else:
    line("Required actions (in order)")
seen = set()
for d in fails:
  diagnosis = d.get("diagnosis", "unknown")
  owner = d.get("owner", "unknown")
  next_action = d.get("next_action", "inspect_logs")
  log = d.get("log") or "(no log path)"
  key = (diagnosis, owner, next_action)
  if key in seen:
    continue
  seen.add(key)
  if fmt == "markdown":
      line(f"- diagnosis: `{diagnosis}`")
      line(f"  owner: `{owner}`")
      line(f"  next_action: `{next_action}`")
      line(f"  evidence_log: `{log}`")
  else:
      line(f"- diagnosis={diagnosis}")
      line(f"  owner={owner}")
      line(f"  next_action={next_action}")
      line(f"  evidence_log={log}")

line("")
if fmt == "markdown":
    line("### Execution Contract (infra lane)")
else:
    line("Execution contract (infra lane)")
line("- Build and roll out the credentials-serving runtime that includes python tzdata + UTC zoneinfo in dev.")
line("- Do not mutate app code in this step; apply runtime/GitOps rollout only.")
line("- After rollout, run these exact verifiers from this repo:")
line("  1. `./scripts/qa/verify-auth-surfaces.sh dev`")
line("  2. `./scripts/qa/verify-credentials-readiness.sh --cluster`")
line("  3. `make qa-frontend-runtime-blocker-sweep QA_ENV=both`")
line("- Capture artifacts from the rerun and attach them in the issue handoff.")
line("")
if fmt == "markdown":
    line("### Rollback Contract")
else:
    line("Rollback contract")
line("- If credentials login still returns 500 after rollout, revert to last known-good image tag and rerun the three verifiers above.")
line("- Keep rollback evidence as logs plus blocker sweep summary JSON.")
line("")
if fmt == "markdown":
    line("### Acceptance Criteria")
else:
    line("Acceptance criteria")
line("- credentials dev /login and /login/edx-oauth2 return 302 in auth-surfaces dev check")
line("- credentials readiness cluster check passes ZoneInfo('UTC') and tzdata checks")
line("- rerun: make qa-frontend-runtime-blocker-sweep QA_ENV=both")
line("- expected summary: fail=0")

rendered = buf.getvalue()
print(rendered, end="")
if output_file:
    op = Path(output_file)
    op.parent.mkdir(parents=True, exist_ok=True)
    op.write_text(rendered)
PY
