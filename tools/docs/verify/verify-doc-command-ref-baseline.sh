#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

BASELINE_FILE="tools/docs/verify/.doc-command-ref-baseline"
SUMMARY_JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline-file)
      BASELINE_FILE="${2:?missing value}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-doc-command-ref-baseline.sh [options]

Options:
  --baseline-file <path>  baseline file path (default: tools/docs/verify/.doc-command-ref-baseline)
  --summary-json <path>   optional JSON summary output path
  --help                  show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$BASELINE_FILE" ]; then
  echo "DOCS_CMDREF_BASELINE_FAIL: baseline file missing: $BASELINE_FILE" >&2
  exit 1
fi

python3 - "$ROOT_DIR" "$BASELINE_FILE" "$SUMMARY_JSON" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
baseline_file = Path(sys.argv[2])
summary_json = sys.argv[3]

entries = []
seen = {}
duplicates = []
missing = []
invalid = []

for raw in baseline_file.read_text(encoding="utf-8", errors="ignore").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    entries.append(line)
    seen[line] = seen.get(line, 0) + 1

for entry, count in seen.items():
    if count > 1:
        duplicates.append(entry)

for entry in entries:
    p = Path(entry)
    if p.suffix.lower() != ".md":
        invalid.append(entry)
        continue

    target = p if p.is_absolute() else (root / p)
    if not target.exists():
        missing.append(entry)
        continue
    if not target.is_file():
        missing.append(entry)
        continue

status = "pass"
if duplicates or missing or invalid:
    status = "fail"

payload = {
    "status": status,
    "baseline_file": str(baseline_file),
    "entries": len(entries),
    "duplicates": sorted(set(duplicates)),
    "missing": sorted(set(missing)),
    "invalid_non_markdown": sorted(set(invalid)),
}

if summary_json:
    Path(summary_json).parent.mkdir(parents=True, exist_ok=True)
    Path(summary_json).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

if status == "fail":
    print(
        "DOCS_CMDREF_BASELINE_FAIL "
        f"entries={payload['entries']} duplicates={len(payload['duplicates'])} "
        f"missing={len(payload['missing'])} invalid_non_markdown={len(payload['invalid_non_markdown'])}",
        file=sys.stderr,
    )
    for item in payload["duplicates"]:
        print(f"- duplicate: {item}", file=sys.stderr)
    for item in payload["missing"]:
        print(f"- missing: {item}", file=sys.stderr)
    for item in payload["invalid_non_markdown"]:
        print(f"- invalid_non_markdown: {item}", file=sys.stderr)
    raise SystemExit(1)

print(
    "DOCS_CMDREF_BASELINE_OK "
    f"entries={payload['entries']} duplicates=0 missing=0 invalid_non_markdown=0"
)
PY
