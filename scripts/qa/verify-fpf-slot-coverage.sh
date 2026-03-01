#!/usr/bin/env bash
# Verify FPF slot coverage truth against plugin wiring and architecture registry notes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
REGISTRY_DOC="$REPO_ROOT/docs/architecture/FPF_PLUGIN_SLOT_REGISTRY.md"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $*"; }

if [[ ! -f "$PLUGIN_FILE" ]]; then
  echo "ERROR: plugin file not found: $PLUGIN_FILE" >&2
  exit 2
fi

if [[ ! -f "$REGISTRY_DOC" ]]; then
  echo "ERROR: registry doc not found: $REGISTRY_DOC" >&2
  exit 2
fi

mapfile -t slot_ids < <(
  rg -o '"org\.openedx\.frontend\.[^"]+\.v[0-9]+"' "$PLUGIN_FILE" \
    | tr -d '"' \
    | sort -u
)

slot_count="${#slot_ids[@]}"
if [[ "$slot_count" -gt 0 ]]; then
  pass "Discovered $slot_count unique slot IDs in mereka_lms.py"
else
  fail "No FPF slot IDs found in mereka_lms.py"
fi

declared_count="$(python3 - "$REGISTRY_DOC" <<'PY'
import re
import sys
text = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r'Current wiring state.*?:\s*(\d+)\s+slots active', text, re.I)
print(m.group(1) if m else "")
PY
)"

if [[ -n "$declared_count" ]]; then
  if [[ "$slot_count" -eq "$declared_count" ]]; then
    pass "Registry doc slot count matches plugin wiring ($slot_count)"
  else
    fail "Registry doc says $declared_count active slots, plugin currently wires $slot_count"
  fi
else
  warn "Could not parse declared slot count from FPF_PLUGIN_SLOT_REGISTRY.md"
fi

legacy_retired_ids=(
  "org.openedx.frontend.learning.course_header.v1"
  "org.openedx.frontend.learning.course_tabs.v1"
  "org.openedx.frontend.account.account_settings_tab.v1"
  "org.openedx.frontend.account.account_settings_field.v1"
  "org.openedx.frontend.authoring.course_outline_header.v1"
  "org.openedx.frontend.catalog.catalog_header.v1"
  "org.openedx.frontend.catalog.catalog_card.v1"
  "org.openedx.frontend.catalog.catalog_filters.v1"
  "org.openedx.frontend.catalog.catalog_search.v1"
  "org.openedx.frontend.catalog.catalog_sort.v1"
  "org.openedx.frontend.catalog.catalog_pagination.v1"
)

for legacy_id in "${legacy_retired_ids[@]}"; do
  if printf '%s\n' "${slot_ids[@]}" | grep -qx "$legacy_id"; then
    fail "Retired legacy slot is still wired: $legacy_id"
  else
    pass "Retired legacy slot not wired: $legacy_id"
  fi
done

required_core_slots=(
  "org.openedx.frontend.layout.header_logo.v1"
  "org.openedx.frontend.layout.footer.v1"
  "org.openedx.frontend.layout.header_desktop_main_menu.v1"
  "org.openedx.frontend.layout.header_mobile_main_menu.v1"
  "org.openedx.frontend.layout.header_desktop_logged_out_items.v1"
  "org.openedx.frontend.layout.header_mobile_logged_out_items.v1"
  "org.openedx.frontend.layout.header_desktop.v1"
  "org.openedx.frontend.layout.header_mobile.v1"
  "org.openedx.frontend.layout.header_learning_course_info.v1"
  "org.openedx.frontend.layout.header_learning_help.v1"
  "org.openedx.frontend.layout.header_learning_logged_out_items.v1"
  "org.openedx.frontend.layout.header_desktop_user_menu.v1"
  "org.openedx.frontend.layout.header_mobile_user_menu.v1"
  "org.openedx.frontend.layout.header_learning_user_menu.v1"
  "org.openedx.frontend.layout.header_desktop_user_menu_toggle.v1"
  "org.openedx.frontend.layout.header_mobile_user_menu_trigger.v1"
  "org.openedx.frontend.layout.header_learning_user_menu_toggle.v1"
  "org.openedx.frontend.layout.studio_header_search_button_slot.v1"
  "org.openedx.frontend.authn.login_component.v1"
  "org.openedx.frontend.learner_dashboard.course_list.v1"
  "org.openedx.frontend.learner_dashboard.course_card_banner.v1"
  "org.openedx.frontend.learning.course_tab_links.v1"
)

for slot_id in "${required_core_slots[@]}"; do
  if printf '%s\n' "${slot_ids[@]}" | grep -qx "$slot_id"; then
    pass "Core slot wired: $slot_id"
  else
    fail "Core slot missing: $slot_id"
  fi
done

echo ""
echo "Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
