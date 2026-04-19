#!/usr/bin/env bash
# Self-test for verify-mfe-plugin-slots.sh
# Fixtures: 1) happy path  2) missing Phase-1 slot  3) duplicate slot ID
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER="$REPO_ROOT/scripts/qa/verify-mfe-plugin-slots.sh"

tmpdir="$(mktemp -d -t test-verify-mfe-plugin-slots.XXXXXX)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*" >&2; exit 1; }

echo "=== test-verify-mfe-plugin-slots.sh ==="

# ── Fixture 1: Happy path ──────────────────────────────────────────────────────
# Use the actual in-repo plugin file; it should have exactly 74 slots.
fixture_happy="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms_mfe_slots.py"
if [[ ! -f "$fixture_happy" ]]; then
  fail "Fixture 1: plugin source missing at $fixture_happy"
fi

if PLUGIN_OVERRIDE="$fixture_happy" EXPECTED_SLOT_COUNT=74 \
    bash "$VERIFIER" >/dev/null 2>&1; then
  pass "Fixture 1: happy path — verifier passes on in-repo plugin (74 slots)"
else
  fail "Fixture 1: happy path — verifier unexpectedly failed on current plugin"
fi

# ── Fixture 2: Missing Phase-1 slot ───────────────────────────────────────────
# Remove header_logo.v1 from the fixture; Gate 3 should catch it.
fixture_missing="$tmpdir/missing_slot.py"
sed '/org\.openedx\.frontend\.layout\.header_logo\.v1/d' \
  "$fixture_happy" > "$fixture_missing"

if PLUGIN_OVERRIDE="$fixture_missing" EXPECTED_SLOT_COUNT=73 \
    bash "$VERIFIER" >/dev/null 2>&1; then
  fail "Fixture 2: missing Phase-1 slot — verifier should have failed but passed"
else
  pass "Fixture 2: missing Phase-1 slot (header_logo.v1) — verifier correctly failed"
fi

# ── Fixture 3: Duplicate slot ID ──────────────────────────────────────────────
# Duplicate the first entry in _INSERT_SLOTS to seed a duplicate.
fixture_dup="$tmpdir/dup_slot.py"
# Find the first namespaced slot ID and add it again inside _INSERT_SLOTS
first_slot="$(python3 - "$fixture_happy" <<'PY'
import re
text = open(__import__("sys").argv[1]).read()
m = re.search(
    r"_INSERT_SLOTS\s*:\s*[^\[]*\[(.*?)\n\]",
    text, re.DOTALL
)
if not m:
    # Try plain assignment
    m = re.search(r"_INSERT_SLOTS[^=]*=\s*\[(.*?)\n\]", text, re.DOTALL)
ids = re.findall(
    r"org\.openedx\.frontend\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+\.v[0-9]+",
    m.group(1) if m else text,
)
print(ids[0] if ids else "")
PY
)"

if [[ -z "$first_slot" ]]; then
  fail "Fixture 3: could not extract first slot ID from plugin for dup injection"
fi

# Inject the duplicate tuple at the end of _INSERT_SLOTS
python3 - "$fixture_happy" "$fixture_dup" "$first_slot" <<'PY'
import sys, re
src = open(sys.argv[1], encoding="utf-8").read()
dest = sys.argv[2]
dup_slot = sys.argv[3]

# Inject a duplicate entry just before the closing ] of _INSERT_SLOTS
injection = f'''    (
        "{dup_slot}",
        "mereka_dup_widget_id",
        "MerekaDupWidget",
    ),
'''
# Find end of _INSERT_SLOTS list and insert before ]
patched = re.sub(
    r"(# ── Authentication)",
    injection + r"\1",
    src,
    count=1,
)
open(dest, "w", encoding="utf-8").write(patched)
PY

if PLUGIN_OVERRIDE="$fixture_dup" EXPECTED_SLOT_COUNT=74 \
    bash "$VERIFIER" >/dev/null 2>&1; then
  fail "Fixture 3: duplicate slot — verifier should have failed but passed"
else
  pass "Fixture 3: duplicate slot ID in _INSERT_SLOTS — verifier correctly failed"
fi

echo ""
echo "All 3 fixtures passed."
