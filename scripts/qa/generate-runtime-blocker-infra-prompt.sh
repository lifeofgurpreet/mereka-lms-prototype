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

usage() {
  cat <<'USAGE'
Usage: generate-runtime-blocker-infra-prompt.sh [--input <summary.json>]

Options:
  --input <path>   Explicit blocker sweep summary JSON. If omitted, latest matching file is used.
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

python3 - "$INPUT_JSON" <<'PY'
import json
import sys
from pathlib import Path
from datetime import datetime, timezone

p = Path(sys.argv[1])
data = json.loads(p.read_text())
summary = data.get("summary", {})
diags = data.get("artifacts", {}).get("diagnostics", [])

fails = [d for d in diags if d.get("status") == "fail"]
now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

print("Infra Action Prompt")
print(f"Generated: {now}")
print(f"Source summary: {p}")
print("")
print("Please execute runtime remediation for dev credentials blocker based on this canonical sweep output.")
print("")
print("Current status")
print(f"- pass={summary.get('pass', 'na')} fail={summary.get('fail', 'na')} skip={summary.get('skip', 'na')}")

if not fails:
  print("- No failing diagnostics found in summary JSON.")
  sys.exit(0)

print("")
print("Required actions (in order)")
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
  print(f"- diagnosis={diagnosis}")
  print(f"  owner={owner}")
  print(f"  next_action={next_action}")
  print(f"  evidence_log={log}")

print("")
print("Execution contract (infra lane)")
print("- Build and roll out the credentials-serving runtime that includes python tzdata + UTC zoneinfo in dev.")
print("- Do not mutate app code in this step; apply runtime/GitOps rollout only.")
print("- After rollout, run these exact verifiers from this repo:")
print("  1) ./scripts/qa/verify-auth-surfaces.sh dev")
print("  2) ./scripts/qa/verify-credentials-readiness.sh --cluster")
print("  3) make qa-frontend-runtime-blocker-sweep-both")
print("- Capture artifacts from the rerun and attach them in the issue handoff.")
print("")
print("Rollback contract")
print("- If credentials login still returns 500 after rollout, revert to last known-good image tag and rerun the three verifiers above.")
print("- Keep rollback evidence as logs plus blocker sweep summary JSON.")
print("")
print("Acceptance criteria")
print("- credentials dev /login and /login/edx-oauth2 return 302 in auth-surfaces dev check")
print("- credentials readiness cluster check passes ZoneInfo('UTC') and tzdata checks")
print("- rerun: make qa-frontend-runtime-blocker-sweep-both")
print("- expected summary: fail=0")
PY
