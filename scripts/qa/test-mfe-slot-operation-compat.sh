#!/usr/bin/env bash
# test-mfe-slot-operation-compat.sh — Guard against unsupported Replace ops in Tutor MFE slots.
#
# Fails if active slot wiring relies on PLUGIN_OPERATIONS.Replace or if the critical
# replacement surfaces are not expressed as Hide+Insert pairs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms_mfe_slots.py"

pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1" >&2; exit 1; }

echo "=== Tutor MFE Slot Operation Compatibility ==="

if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "Plugin slot source missing: $PLUGIN_FILE"
fi

if rg -q "op:\\s*PLUGIN_OPERATIONS\\.Replace" "$PLUGIN_FILE"; then
  fail "Unsupported replace op is still present in active slot wiring"
else
  pass "No unsupported replace op in active slot wiring"
fi

python3 - "$PLUGIN_FILE" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
critical = {
    "org.openedx.frontend.layout.header_logo.v1": "mereka_header_logo",
    "org.openedx.frontend.learner_dashboard.no_courses_view.v1": "mereka_no_courses_view",
    "org.openedx.frontend.layout.header_learning_help.v1": "mereka_layout_header_learning_help_link",
}

if "_HIDE_INSERT_SLOTS" not in text:
    raise SystemExit("missing _HIDE_INSERT_SLOTS declaration")
if "def _hide_insert_js" not in text:
    raise SystemExit("missing _hide_insert_js helper")
if "PLUGIN_OPERATIONS.Hide" not in text or "widgetId: 'default_contents'" not in text:
    raise SystemExit("hide+insert helper missing default_contents hide semantics")

for slot, widget_id in critical.items():
    if slot not in text:
        raise SystemExit(f"missing critical slot {slot}")
    if widget_id not in text:
        raise SystemExit(f"missing widget id {widget_id}")

print("critical replacement surfaces use Hide+Insert")
PY

pass "Critical replacement surfaces use Hide+Insert"
