#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

SUMMARY_JSON=""
POLICY_RANGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-json)
      SUMMARY_JSON="${2:?missing value}"
      shift 2
      ;;
    --policy-range)
      POLICY_RANGE="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-docs-foundation-gates.sh [options]

Options:
  --summary-json <path>  optional JSON summary output path
  --policy-range <range> explicit range passed to verify-docs-policy.sh
  --help                 show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

policy_log="$TMP_DIR/policy.log"
structure_log="$TMP_DIR/structure.log"
policy_summary_json="$TMP_DIR/policy-summary.json"

policy_status="pass"
structure_status="pass"

if [ -n "$POLICY_RANGE" ]; then
  policy_cmd=(./tools/docs/verify/verify-docs-policy.sh --range "$POLICY_RANGE" --summary-json "$policy_summary_json")
else
  policy_cmd=(./tools/docs/verify/verify-docs-policy.sh --summary-json "$policy_summary_json")
fi

if ! "${policy_cmd[@]}" >"$policy_log" 2>&1; then
  policy_status="fail"
fi

if ! ./scripts/qa/verify-repo-structure.sh >"$structure_log" 2>&1; then
  structure_status="fail"
fi

status="pass"
if [ "$policy_status" = "fail" ] || [ "$structure_status" = "fail" ]; then
  status="fail"
fi

if [ -n "$SUMMARY_JSON" ]; then
  python3 - "$SUMMARY_JSON" "$status" "$policy_status" "$structure_status" "$policy_summary_json" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
status = sys.argv[2]
policy_status = sys.argv[3]
repo_structure_status = sys.argv[4]
policy_summary_path = Path(sys.argv[5])

policy_summary = {}
if policy_summary_path.exists():
    policy_summary = json.loads(policy_summary_path.read_text(encoding="utf-8"))

payload = {
    "status": status,
    "policy_status": policy_status,
    "repo_structure_status": repo_structure_status,
    "policy_range": policy_summary.get("range", ""),
    "policy_root_allowlist_violations": policy_summary.get("root_allowlist_violations", 0),
    "policy_changed_markdown_files": policy_summary.get("changed_markdown_files", 0),
    "policy_content_status": policy_summary.get("content_status", "unknown"),
    "policy_content_consistent": not (
        policy_summary.get("content_status", "unknown") == "pass"
        and len(policy_summary.get("content_errors", [])) > 0
    ),
    "policy_content_errors": policy_summary.get("content_errors", []),
}
summary_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
PY
fi

if [ "$status" = "fail" ]; then
  echo "DOCS_FOUNDATION_GATES_FAIL: policy=${policy_status} repo_structure=${structure_status}" >&2
  if [ "$policy_status" = "fail" ]; then
    echo "---- verify-docs-policy.sh ----" >&2
    cat "$policy_log" >&2
  fi
  if [ "$structure_status" = "fail" ]; then
    echo "---- verify-repo-structure.sh ----" >&2
    cat "$structure_log" >&2
  fi
  exit 1
fi

echo "DOCS_FOUNDATION_GATES_OK policy=${policy_status} repo_structure=${structure_status}"
