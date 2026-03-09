#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="tools/docs/verify/verify-legacy-testmaps-frozen.py"

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "missing script: $SCRIPT_PATH"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" /tmp/legacy-testmaps-ok.$$' EXIT

SUMMARY_OK="$TMP_DIR/ok.json"
python3 "$SCRIPT_PATH" --range HEAD~0...HEAD --summary-file "$SUMMARY_OK" >/tmp/legacy-testmaps-ok.$$ 2>&1 || {
  cat /tmp/legacy-testmaps-ok.$$
  exit 1
}
grep -q 'LEGACY_TESTMAP_FREEZE_OK' /tmp/legacy-testmaps-ok.$$
grep -q '"status": "pass"' "$SUMMARY_OK"

echo "verify-legacy-testmaps-frozen self-test: OK"
