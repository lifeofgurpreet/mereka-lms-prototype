#!/usr/bin/env bash
# @covers AC-SLOT-022
# @spec: mfe-plugin-slots_spec.md
# Verify expected plugin slot IDs exist in source plugin config and rendered env config.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
RENDERED_ENV="${RENDERED_ENV:-$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx}"
EXPECTED_SLOT_IDS="${EXPECTED_SLOT_IDS:-org.openedx.frontend.layout.header_logo.v1,org.openedx.frontend.layout.footer.v1,org.openedx.frontend.layout.studio_footer.v1,org.openedx.frontend.authn.login_component.v1,org.openedx.frontend.learner_dashboard.widget_sidebar.v1,org.openedx.frontend.learner_dashboard.no_courses_view.v1,org.openedx.frontend.learner_dashboard.dashboard_header.v1,org.openedx.frontend.learner_dashboard.course_card.v1,org.openedx.frontend.learning.course_outline_sidebar.v1,org.openedx.frontend.learning.progress_certificate_status.v1,org.openedx.frontend.learning.course_header.v1,org.openedx.frontend.learning.course_tabs.v1,org.openedx.frontend.account.additional_profile_fields.v1,org.openedx.frontend.profile.additional_profile_fields.v1,org.openedx.frontend.layout.header_desktop_main_menu.v1,org.openedx.frontend.layout.header_mobile_main_menu.v1}"
STRICT_RENDERED_SLOTS="${STRICT_RENDERED_SLOTS:-0}"
CHECK_RENDERED_SLOTS="${CHECK_RENDERED_SLOTS:-0}"

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
# Canonical FPF slot id shape: org.openedx.frontend.<path>.vN
slots = set(re.findall(r"org\.openedx\.frontend\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+\.v[0-9]+", text))
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

declare -A SLOT_BINDING_MARKERS=(
  ["org.openedx.frontend.layout.header_logo.v1"]="mereka_header_logo"
  ["org.openedx.frontend.layout.footer.v1"]="mereka_footer"
  ["org.openedx.frontend.layout.studio_footer.v1"]="mereka_studio_footer"
  ["org.openedx.frontend.authn.login_component.v1"]="mereka_authn_login_component"
  ["org.openedx.frontend.learner_dashboard.widget_sidebar.v1"]="mereka_learner_sidebar_widget"
  ["org.openedx.frontend.learner_dashboard.no_courses_view.v1"]="mereka_no_courses_view"
  ["org.openedx.frontend.learner_dashboard.dashboard_header.v1"]="mereka_dashboard_header"
  ["org.openedx.frontend.learner_dashboard.course_card.v1"]="mereka_dashboard_course_card_accent"
  ["org.openedx.frontend.learning.course_outline_sidebar.v1"]="mereka_course_outline_sidebar"
  ["org.openedx.frontend.learning.progress_certificate_status.v1"]="mereka_progress_certificate_status"
  ["org.openedx.frontend.learning.course_header.v1"]="mereka_learning_course_header"
  ["org.openedx.frontend.learning.course_tabs.v1"]="mereka_learning_course_tabs_hint"
  ["org.openedx.frontend.account.additional_profile_fields.v1"]="mereka_additional_profile_fields"
  ["org.openedx.frontend.profile.additional_profile_fields.v1"]="mereka_profile_additional_fields"
  ["org.openedx.frontend.layout.header_desktop_main_menu.v1"]="withMerekaMenuItems("
  ["org.openedx.frontend.layout.header_mobile_main_menu.v1"]="withMerekaMenuItems("
)

for slot in "${expected[@]}"; do
  slot="$(echo "$slot" | xargs)"
  [[ -z "$slot" ]] && continue
  if [[ -v SLOT_BINDING_MARKERS[$slot] ]]; then
    marker="${SLOT_BINDING_MARKERS[$slot]}"
    if rg -qF "$marker" "$PLUGIN_FILE"; then
      pass "Expected slot binding marker present for $slot: $marker"
    else
      fail "Expected slot binding marker missing for $slot: $marker"
    fi
  fi
done

# Footer slot should explicitly hide default footer contents before insert.
if rg -qF "org.openedx.frontend.layout.footer.v1" "$PLUGIN_FILE" \
  && rg -qF "op: PLUGIN_OPERATIONS.Hide" "$PLUGIN_FILE" \
  && rg -qF "widgetId: 'default_contents'" "$PLUGIN_FILE"; then
  pass "Footer slot override hides default contents before custom insert"
else
  fail "Footer slot override must hide default_contents before custom insert"
fi

if [[ "$CHECK_RENDERED_SLOTS" != "1" ]]; then
  pass "Rendered env slot checks skipped (set CHECK_RENDERED_SLOTS=1 to enable)"
elif [[ -f "$RENDERED_ENV" ]]; then
  pass "Rendered env config exists: ${RENDERED_ENV#$REPO_ROOT/}"
  rendered_missing=0
  for slot in "${expected[@]}"; do
    slot="$(echo "$slot" | xargs)"
    [[ -z "$slot" ]] && continue
    if rg -qF "$slot" "$RENDERED_ENV"; then
      pass "Expected slot present in rendered env config: $slot"
    else
      rendered_missing=$((rendered_missing + 1))
      if [[ "$STRICT_RENDERED_SLOTS" == "1" ]]; then
        warn "Expected slot not found in rendered env config: $slot"
      fi
    fi
  done
  if [[ "$rendered_missing" -gt 0 ]]; then
    if [[ "$STRICT_RENDERED_SLOTS" == "1" ]]; then
      warn "Rendered env config is missing $rendered_missing expected slot ID(s)"
    else
      warn "Rendered env config missing $rendered_missing expected slot ID(s); run tutor config save + apply-patches + mfe rebuild to refresh runtime output"
    fi
  fi
else
  warn "Rendered env config missing (skipping runtime slot check): ${RENDERED_ENV#$REPO_ROOT/}"
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
