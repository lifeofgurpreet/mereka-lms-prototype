#!/usr/bin/env bash
# @covers AC-SLOT-022
# @spec: mfe-plugin-slots_spec.md
# Verify expected plugin slot IDs exist in source plugin config and rendered env config.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
RENDERED_ENV="${RENDERED_ENV:-$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx}"
EXPECTED_SLOT_IDS="${EXPECTED_SLOT_IDS:-org.openedx.frontend.layout.header_logo.v1,org.openedx.frontend.layout.footer.v1,org.openedx.frontend.layout.studio_footer.v1,org.openedx.frontend.authoring.course_unit_sidebar.v1,org.openedx.frontend.authoring.course_outline_sidebar.v1,org.openedx.frontend.authoring.course_outline_header_actions.v1,org.openedx.frontend.authoring.course_unit_header_actions.v1,org.openedx.frontend.authn.login_component.v1,org.openedx.frontend.learner_dashboard.widget_sidebar.v1,org.openedx.frontend.learner_dashboard.no_courses_view.v1,org.openedx.frontend.learner_dashboard.course_list.v1,org.openedx.frontend.learner_dashboard.course_card_banner.v1,org.openedx.frontend.learner_dashboard.course_card_action.v1,org.openedx.frontend.learner_dashboard.dashboard_modal.v1,org.openedx.frontend.learning.course_outline_sidebar.v1,org.openedx.frontend.learning.progress_certificate_status.v1,org.openedx.frontend.layout.header_learning.v1,org.openedx.frontend.learning.course_tab_links.v1,org.openedx.frontend.learning.course_breadcrumbs.v1,org.openedx.frontend.learning.learner_tools.v1,org.openedx.frontend.learning.progress_tab_course_grade.v1,org.openedx.frontend.learning.progress_tab_related_links.v1,org.openedx.frontend.learning.progress_tab_certificate_status_main_body.v1,org.openedx.frontend.learning.progress_tab_certificate_status_side_panel.v1,org.openedx.frontend.learning.progress_tab_grade_breakdown.v1,org.openedx.frontend.learning.unit_title.v1,org.openedx.frontend.learning.sequence_navigation.v1,org.openedx.frontend.learning.course_outline_sidebar_trigger.v1,org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1,org.openedx.frontend.learning.course_home_section_outline.v1,org.openedx.frontend.learning.course_recommendations.v1,org.openedx.frontend.learning.content_iframe_loader.v1,org.openedx.frontend.learning.content_iframe_error.v1,org.openedx.frontend.learning.sequence_container.v1,org.openedx.frontend.learning.gated_unit_content_message.v1,org.openedx.frontend.learning.next_unit_top_nav_trigger.v1,org.openedx.frontend.learning.course_outline_tab_notifications.v1,org.openedx.frontend.learning.notification_widget.v1,org.openedx.frontend.learning.notification_tray.v1,org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1,org.openedx.frontend.learning.notifications_discussions_sidebar.v1,org.openedx.frontend.learning.course_exit_view_courses.v1,org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1,org.openedx.frontend.account.id_verification_page.v1,org.openedx.frontend.account.additional_profile_fields.v1,org.openedx.frontend.profile.additional_profile_fields.v1,org.openedx.frontend.layout.header_desktop_main_menu.v1,org.openedx.frontend.layout.header_mobile_main_menu.v1}"
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
  ["org.openedx.frontend.authoring.course_unit_sidebar.v1"]="mereka_authoring_course_unit_sidebar_hint"
  ["org.openedx.frontend.authoring.course_outline_sidebar.v1"]="mereka_authoring_course_outline_sidebar_hint"
  ["org.openedx.frontend.authoring.course_outline_header_actions.v1"]="mereka_authoring_course_outline_header_actions_hint"
  ["org.openedx.frontend.authoring.course_unit_header_actions.v1"]="mereka_authoring_course_unit_header_actions_hint"
  ["org.openedx.frontend.authn.login_component.v1"]="mereka_authn_login_component"
  ["org.openedx.frontend.learner_dashboard.widget_sidebar.v1"]="mereka_learner_sidebar_widget"
  ["org.openedx.frontend.learner_dashboard.no_courses_view.v1"]="mereka_no_courses_view"
  ["org.openedx.frontend.learner_dashboard.course_list.v1"]="mereka_dashboard_course_list_context"
  ["org.openedx.frontend.learner_dashboard.course_card_banner.v1"]="mereka_dashboard_course_card_banner_accent"
  ["org.openedx.frontend.learner_dashboard.course_card_action.v1"]="mereka_dashboard_course_card_action_hint"
  ["org.openedx.frontend.learner_dashboard.dashboard_modal.v1"]="mereka_dashboard_modal_hint"
  ["org.openedx.frontend.learning.course_outline_sidebar.v1"]="mereka_course_outline_sidebar"
  ["org.openedx.frontend.learning.progress_certificate_status.v1"]="mereka_progress_certificate_status"
  ["org.openedx.frontend.layout.header_learning.v1"]="mereka_layout_header_learning_context"
  ["org.openedx.frontend.learning.course_tab_links.v1"]="mereka_learning_course_tab_links_hint"
  ["org.openedx.frontend.learning.course_breadcrumbs.v1"]="mereka_learning_course_breadcrumbs_hint"
  ["org.openedx.frontend.learning.learner_tools.v1"]="mereka_learning_learner_tools_hint"
  ["org.openedx.frontend.learning.progress_tab_course_grade.v1"]="mereka_learning_progress_course_grade_hint"
  ["org.openedx.frontend.learning.progress_tab_related_links.v1"]="mereka_learning_progress_related_links_hint"
  ["org.openedx.frontend.learning.progress_tab_certificate_status_main_body.v1"]="mereka_learning_progress_certificate_status_main_body"
  ["org.openedx.frontend.learning.progress_tab_certificate_status_side_panel.v1"]="mereka_learning_progress_certificate_status_side_panel"
  ["org.openedx.frontend.learning.progress_tab_grade_breakdown.v1"]="mereka_learning_progress_grade_breakdown_hint"
  ["org.openedx.frontend.learning.unit_title.v1"]="mereka_learning_unit_title_hint"
  ["org.openedx.frontend.learning.sequence_navigation.v1"]="mereka_learning_sequence_navigation_hint"
  ["org.openedx.frontend.learning.course_outline_sidebar_trigger.v1"]="mereka_learning_outline_sidebar_trigger_hint"
  ["org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1"]="mereka_learning_outline_mobile_sidebar_trigger_hint"
  ["org.openedx.frontend.learning.course_home_section_outline.v1"]="mereka_learning_course_home_section_outline_hint"
  ["org.openedx.frontend.learning.course_recommendations.v1"]="mereka_learning_course_recommendations_hint"
  ["org.openedx.frontend.learning.content_iframe_loader.v1"]="mereka_learning_content_iframe_loader_hint"
  ["org.openedx.frontend.learning.content_iframe_error.v1"]="mereka_learning_content_iframe_error_hint"
  ["org.openedx.frontend.learning.sequence_container.v1"]="mereka_learning_sequence_container_hint"
  ["org.openedx.frontend.learning.gated_unit_content_message.v1"]="mereka_learning_gated_unit_content_message_hint"
  ["org.openedx.frontend.learning.next_unit_top_nav_trigger.v1"]="mereka_learning_next_unit_top_nav_trigger_hint"
  ["org.openedx.frontend.learning.course_outline_tab_notifications.v1"]="mereka_learning_course_outline_tab_notifications_hint"
  ["org.openedx.frontend.learning.notification_widget.v1"]="mereka_learning_notification_widget_hint"
  ["org.openedx.frontend.learning.notification_tray.v1"]="mereka_learning_notification_tray_hint"
  ["org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1"]="mereka_learning_notifications_discussions_sidebar_trigger_hint"
  ["org.openedx.frontend.learning.notifications_discussions_sidebar.v1"]="mereka_learning_notifications_discussions_sidebar_hint"
  ["org.openedx.frontend.learning.course_exit_view_courses.v1"]="mereka_learning_course_exit_view_courses_hint"
  ["org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1"]="mereka_learning_course_exit_dashboard_footnote_link_hint"
  ["org.openedx.frontend.account.id_verification_page.v1"]="mereka_account_id_verification_hint"
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
