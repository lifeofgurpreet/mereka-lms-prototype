#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

SUMMARY_JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-json)
      SUMMARY_JSON="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-docs-foundation-gates.sh [options]

Options:
  --summary-json <path>  optional JSON summary output path
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

policy_status="pass"
structure_status="pass"

if ! ./docs/qa/verify-docs-policy.sh >"$policy_log" 2>&1; then
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
  {
    echo "{"
    echo "  \"status\": \"${status}\","
    echo "  \"policy_status\": \"${policy_status}\","
    echo "  \"repo_structure_status\": \"${structure_status}\""
    echo "}"
  } > "$SUMMARY_JSON"
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
