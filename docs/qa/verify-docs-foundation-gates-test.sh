#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=${1:-$(mktemp -d)}
KEEP_ROOT=0

if [ "${1-}" != "" ]; then
  KEEP_ROOT=1
fi

if [ ! -d "$ROOT_DIR" ]; then
  mkdir -p "$ROOT_DIR"
fi

cleanup() {
  if [ "$KEEP_ROOT" -eq 0 ]; then
    rm -rf "$ROOT_DIR"
  fi
}
trap cleanup EXIT

SUMMARY_JSON="$ROOT_DIR/foundation-summary.json"

docs/qa/verify-docs-foundation-gates.sh --summary-json "$SUMMARY_JSON" >/tmp/docs_foundation_gates_test.out 2>&1

python3 - "$SUMMARY_JSON" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit("expected status=pass")
if payload.get("policy_status") != "pass":
    raise SystemExit("expected policy_status=pass")
if payload.get("repo_structure_status") != "pass":
    raise SystemExit("expected repo_structure_status=pass")
PY

echo "verify-docs-foundation-gates self-test: OK"
