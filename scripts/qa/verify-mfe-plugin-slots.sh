#!/usr/bin/env bash
# @covers AC-SLOT-022
# @spec: mfe-plugin-slots_spec.md
#
# Observation-only gate for MFE plugin slot registrations.
# Fails on: import errors, slot count drift, missing Phase 1-3 slots, duplicates.
# Does NOT prescribe removal of OVERSPEC slots.
# Bump EXPECTED_SLOT_COUNT in the same PR when legitimately adding a slot.
#
# Usage:
#   bash scripts/qa/verify-mfe-plugin-slots.sh
#   EXPECTED_SLOT_COUNT=75 bash scripts/qa/verify-mfe-plugin-slots.sh
#   PLUGIN_OVERRIDE=/path/to/fixture.py bash scripts/qa/verify-mfe-plugin-slots.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_FILE="${PLUGIN_OVERRIDE:-$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms_mfe_slots.py}"
EXPECTED_SLOT_COUNT="${EXPECTED_SLOT_COUNT:-74}"

FAILURES=0
pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*" >&2; FAILURES=$((FAILURES + 1)); }

echo "=== AC-SLOT-022: MFE Plugin Slots Observation Gate ==="
echo "    plugin: ${PLUGIN_FILE}"
echo ""

# ── Gate 1: Import / syntax check ─────────────────────────────────────────────
# Catches syntax errors before any string-search runs.
# Tutormfe is not installed in CI outside the Tutor venv, so we mock it then
# exec the module — this catches any Python syntax error or NameError in the
# module body while tolerating the missing Tutor dependency.
if python3 - "$PLUGIN_FILE" <<'PY'
import sys, pathlib, types, ast

plugin_path = pathlib.Path(sys.argv[1])
if not plugin_path.exists():
    print(f"MISSING: {plugin_path}", file=sys.stderr)
    sys.exit(1)

# Syntax check via ast.parse — catches SyntaxError without executing
try:
    ast.parse(plugin_path.read_text(encoding="utf-8"))
except SyntaxError as exc:
    print(f"SYNTAX ERROR: {exc}", file=sys.stderr)
    sys.exit(1)

# Mock tutormfe so exec_module succeeds even outside a Tutor venv
mock_hooks = types.SimpleNamespace(PLUGIN_SLOTS=types.SimpleNamespace(add_items=lambda x: None))
mock_tutormfe = types.ModuleType("tutormfe")
mock_tutormfe.hooks = mock_hooks
sys.modules.setdefault("tutormfe", mock_tutormfe)
sys.modules.setdefault("tutormfe.hooks", mock_hooks)

import importlib.util
spec = importlib.util.spec_from_file_location("_mereka_mfe_slots_check", plugin_path)
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as exc:
    print(f"EXEC ERROR: {exc}", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
then
  pass "Gate 1: plugin file parses and executes without error"
else
  fail "Gate 1: plugin file import/syntax error (see stderr above)"
fi

# ── Gate 2: Slot count assertion ───────────────────────────────────────────────
# Counts unique org.openedx.frontend.*.vN slot IDs across the whole file.
# Fails if count differs from EXPECTED_SLOT_COUNT.
actual_count="$(python3 - "$PLUGIN_FILE" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
slots = set(re.findall(
    r"org\.openedx\.frontend\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+\.v[0-9]+",
    text,
))
print(len(slots))
PY
)"

echo "    slot count: ${actual_count} (expected: ${EXPECTED_SLOT_COUNT})"
if [[ "$actual_count" -eq "$EXPECTED_SLOT_COUNT" ]]; then
  pass "Gate 2: slot count is ${actual_count}"
else
  fail "Gate 2: slot count is ${actual_count}, expected ${EXPECTED_SLOT_COUNT} — if intentional bump EXPECTED_SLOT_COUNT"
fi

# ── Gate 3: Phase 1-3 AC coverage ─────────────────────────────────────────────
# These are the canonical slot IDs required by Phase 1 (AC-001..007),
# Phase 2 (AC-008..011), and Phase 3 (AC-012..015) of the spec.
# Missing any of these is a hard failure.
declare -A PHASE_SLOTS=(
  # Phase 1: Header Branding (7 slots / 7 ACs)
  ["org.openedx.frontend.layout.header_logo.v1"]="Phase-1 desktop header logo"
  ["org.openedx.frontend.layout.header_desktop.v1"]="Phase-1 header desktop shell"
  ["org.openedx.frontend.layout.header_mobile.v1"]="Phase-1 header mobile shell"
  ["org.openedx.frontend.layout.header_desktop_main_menu.v1"]="Phase-1 desktop main menu"
  ["org.openedx.frontend.layout.header_mobile_main_menu.v1"]="Phase-1 mobile main menu"
  ["org.openedx.frontend.layout.header_desktop_logged_out_items.v1"]="Phase-1 desktop logged-out items"
  ["org.openedx.frontend.layout.header_mobile_logged_out_items.v1"]="Phase-1 mobile logged-out items"
  # Phase 2: Learning MFE (4 slots / 4 ACs)
  ["org.openedx.frontend.learning.course_outline_sidebar.v1"]="Phase-2 learning course outline sidebar"
  ["org.openedx.frontend.learning.sequence_navigation.v1"]="Phase-2 learning sequence navigation"
  ["org.openedx.frontend.learning.progress_certificate_status.v1"]="Phase-2 learning progress certificate"
  ["org.openedx.frontend.layout.header_learning.v1"]="Phase-2 learning header"
  # Phase 3: Account & Profile (3 slots / 3 ACs)
  ["org.openedx.frontend.account.additional_profile_fields.v1"]="Phase-3 account additional profile fields"
  ["org.openedx.frontend.profile.additional_profile_fields.v1"]="Phase-3 profile additional profile fields"
  ["org.openedx.frontend.account.id_verification_page.v1"]="Phase-3 account id verification"
)

missing_phase=()
for slot_id in "${!PHASE_SLOTS[@]}"; do
  label="${PHASE_SLOTS[$slot_id]}"
  if grep -qF "$slot_id" "$PLUGIN_FILE"; then
    pass "Gate 3: ${label} (${slot_id})"
  else
    fail "Gate 3: MISSING ${label} — ${slot_id}"
    missing_phase+=("$slot_id")
  fi
done

if [[ "${#missing_phase[@]}" -gt 0 ]]; then
  echo "" >&2
  echo "  Phase 1-3 slots missing from plugin:" >&2
  for s in "${missing_phase[@]}"; do echo "    - $s" >&2; done
fi

# ── Gate 4: Duplicate detection ────────────────────────────────────────────────
# Scans each list (_INSERT_SLOTS, _HIDE_INSERT_SLOTS, _MODIFY_SLOTS) for
# duplicate slot IDs. Duplicates produce undefined ordering in FPF.
dup_output="$(python3 - "$PLUGIN_FILE" <<'PY'
import re, sys
from collections import Counter

text = open(sys.argv[1], encoding="utf-8").read()

def extract_ids_in_block(block_name):
    m = re.search(
        rf"{re.escape(block_name)}\s*[=:][^\[]*\[(.*?)\n\]",
        text,
        re.DOTALL,
    )
    if not m:
        return []
    return re.findall(
        r"org\.openedx\.frontend\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+\.v[0-9]+",
        m.group(1),
    )

all_ids = []
for block in ("_INSERT_SLOTS", "_HIDE_INSERT_SLOTS", "_MODIFY_SLOTS"):
    all_ids.extend(extract_ids_in_block(block))

counts = Counter(all_ids)
dups = [sid for sid, n in counts.items() if n > 1]
if dups:
    print("DUPLICATES: " + ", ".join(dups))
    sys.exit(1)
sys.exit(0)
PY
)" && gate4_ok=0 || gate4_ok=$?

if [[ "$gate4_ok" -eq 0 ]]; then
  pass "Gate 4: no duplicate slot IDs within declaration lists"
else
  fail "Gate 4: duplicate slot IDs detected — ${dup_output}"
fi

# ── Gate 5: Structural check ────────────────────────────────────────────────────
# Ensures the three canonical globals exist and are list/tuple literals.
struct_out="$(python3 - "$PLUGIN_FILE" <<'PY'
import ast, sys

tree = ast.parse(open(sys.argv[1], encoding="utf-8").read())
found = {}
# Top-level Assign nodes only (module body)
for node in tree.body:
    if isinstance(node, ast.Assign):
        for t in node.targets:
            if isinstance(t, ast.Name) and t.id in (
                "_INSERT_SLOTS", "_HIDE_INSERT_SLOTS", "_MODIFY_SLOTS"
            ):
                found[t.id] = isinstance(node.value, (ast.List, ast.Tuple))
    # Also check annotated assignments: _INSERT_SLOTS: list[...] = [...]
    elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
        if node.target.id in ("_INSERT_SLOTS", "_HIDE_INSERT_SLOTS", "_MODIFY_SLOTS"):
            found[node.target.id] = node.value is not None and isinstance(
                node.value, (ast.List, ast.Tuple)
            )

required = {"_INSERT_SLOTS", "_HIDE_INSERT_SLOTS", "_MODIFY_SLOTS"}
missing = required - found.keys()
wrong_type = {k for k, ok in found.items() if not ok}

errors = []
if missing:
    errors.append("missing globals: " + ", ".join(sorted(missing)))
if wrong_type:
    errors.append("wrong type (need list/tuple): " + ", ".join(sorted(wrong_type)))
if errors:
    print("; ".join(errors), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
)" && gate5_ok=0 || gate5_ok=$?

if [[ "$gate5_ok" -eq 0 ]]; then
  pass "Gate 5: _INSERT_SLOTS, _HIDE_INSERT_SLOTS, _MODIFY_SLOTS are list/tuple globals"
else
  fail "Gate 5: structural globals check failed — ${struct_out}"
fi

echo ""
echo "=== Summary: FAILURES=${FAILURES} ==="
[[ "$FAILURES" -eq 0 ]]
