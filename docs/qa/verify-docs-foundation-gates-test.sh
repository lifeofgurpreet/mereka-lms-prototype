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
if "policy_range" not in payload:
    raise SystemExit("expected policy_range in summary")
if "policy_root_allowlist_violations" not in payload:
    raise SystemExit("expected policy_root_allowlist_violations in summary")
PY

DOCS_POLICY_RANGE="refs/heads/does-not-exist...HEAD" \
  docs/qa/verify-docs-foundation-gates.sh \
    --policy-range "HEAD...HEAD" \
    --summary-json "$SUMMARY_JSON" >/tmp/docs_foundation_gates_policy_range_test.out 2>&1

python3 - "$SUMMARY_JSON" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit("expected status=pass with --policy-range override")
if payload.get("policy_status") != "pass":
    raise SystemExit("expected policy_status=pass with --policy-range override")
if payload.get("policy_range") != "HEAD...HEAD":
    raise SystemExit("expected policy_range=HEAD...HEAD with --policy-range override")
if payload.get("policy_content_consistent") is not True:
    raise SystemExit("expected policy_content_consistent=true with clean policy summary")
PY

echo "verify-docs-foundation-gates self-test: OK"
