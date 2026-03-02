#!/usr/bin/env bash
# print-runtime-blocker-status.sh — Canonical human-readable status from blocker summary JSON.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_INPUT="$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-latest-both.summary.json"
INPUT_JSON="$DEFAULT_INPUT"
OUTPUT_FILE=""
STRICT=0

usage() {
  cat <<'USAGE'
Usage: print-runtime-blocker-status.sh [--input <summary.json>] [--output <path>] [--strict]

Options:
  --input <path>   Blocker sweep summary JSON path (default: latest-both pointer).
  --output <path>  Also write rendered status output to this path.
  --strict         Exit non-zero when summary.fail > 0.
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
    --strict)
      STRICT=1
      shift
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

if [[ ! -f "$INPUT_JSON" ]]; then
  echo "ERROR: summary json not found: $INPUT_JSON" >&2
  exit 1
fi

python3 - "$INPUT_JSON" "$OUTPUT_FILE" "$STRICT" <<'PY'
import io
import json
import sys
from pathlib import Path

p = Path(sys.argv[1])
output_file = sys.argv[2].strip()
strict = sys.argv[3].strip() == "1"

data = json.loads(p.read_text())
env = data.get("environment", "unknown")
ts = data.get("timestamp", "unknown")
summary = data.get("summary", {})
artifacts = data.get("artifacts", {})
latest = artifacts.get("latest", {})
diagnostics = artifacts.get("diagnostics", [])

pass_count = int(summary.get("pass", 0) or 0)
fail_count = int(summary.get("fail", 0) or 0)
skip_count = int(summary.get("skip", 0) or 0)

buf = io.StringIO()
def line(s=""):
    print(s, file=buf)

line("Runtime Blocker Status")
line(f"source={p}")
line(f"environment={env} timestamp={ts}")
line(f"summary=PASS:{pass_count} FAIL:{fail_count} SKIP:{skip_count}")
if latest:
    line("latest_artifacts:")
    for k in sorted(latest.keys()):
        line(f"  - {k}={latest[k]}")

failing = [d for d in diagnostics if d.get("status") == "fail"]
if failing:
    line("failing_diagnostics:")
    seen = set()
    for d in failing:
        diagnosis = d.get("diagnosis", "unknown")
        owner = d.get("owner", "unknown")
        action = d.get("next_action", "inspect_logs")
        log = d.get("log", "")
        key = (diagnosis, owner, action, log)
        if key in seen:
            continue
        seen.add(key)
        line(f"  - diagnosis={diagnosis}")
        line(f"    owner={owner}")
        line(f"    next_action={action}")
        line(f"    log={log}")
else:
    line("failing_diagnostics: none")

rendered = buf.getvalue()
print(rendered, end="")
if output_file:
    op = Path(output_file)
    op.parent.mkdir(parents=True, exist_ok=True)
    op.write_text(rendered)

if strict and fail_count > 0:
    raise SystemExit(1)
PY
