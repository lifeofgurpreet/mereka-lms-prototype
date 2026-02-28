#!/usr/bin/env bash
# @covers AC-SLOT-022
# @spec: mfe-plugin-slots_spec.md
# Verify expected plugin slot IDs exist in source plugin config and rendered env config.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
RENDERED_ENV="${RENDERED_ENV:-$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx}"
EXPECTED_SLOT_IDS="${EXPECTED_SLOT_IDS:-org.openedx.frontend.layout.footer.v1}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $1"; }

echo "=== MFE Plugin Slots Verification ==="

if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "Plugin file missing: ${PLUGIN_FILE#$REPO_ROOT/}"
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  exit 1
fi

if rg -q "from tutormfe\\.hooks import PLUGIN_SLOTS" "$PLUGIN_FILE"; then
  pass "PLUGIN_SLOTS import present in plugin"
else
  fail "PLUGIN_SLOTS import missing from plugin"
fi

source_slot_count="$(python3 - "$PLUGIN_FILE" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
slots = set(re.findall(r"org\.openedx\.frontend\.layout\.[A-Za-z0-9_.-]+", text))
print(len(slots))
PY
)"
if [[ "$source_slot_count" -gt 0 ]]; then
  pass "Plugin declares ${source_slot_count} namespaced slot IDs"
else
  fail "No namespaced slot IDs found in plugin"
fi

IFS=',' read -r -a expected <<<"$EXPECTED_SLOT_IDS"
for slot in "${expected[@]}"; do
  slot="$(echo "$slot" | xargs)"
  [[ -z "$slot" ]] && continue
  if rg -qF "$slot" "$PLUGIN_FILE"; then
    pass "Expected slot present in plugin: $slot"
  else
    fail "Expected slot missing in plugin: $slot"
  fi
done

if [[ -f "$RENDERED_ENV" ]]; then
  pass "Rendered env config exists: ${RENDERED_ENV#$REPO_ROOT/}"
  for slot in "${expected[@]}"; do
    slot="$(echo "$slot" | xargs)"
    [[ -z "$slot" ]] && continue
    if rg -qF "$slot" "$RENDERED_ENV"; then
      pass "Expected slot present in rendered env config: $slot"
    else
      warn "Expected slot not found in rendered env config (may require tutor config/image rebuild): $slot"
    fi
  done
else
  warn "Rendered env config missing (skipping runtime slot check): ${RENDERED_ENV#$REPO_ROOT/}"
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]

