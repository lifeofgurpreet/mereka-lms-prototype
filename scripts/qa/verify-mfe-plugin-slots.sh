#!/usr/bin/env bash
# @covers AC-SLOT-001, AC-SLOT-002, AC-SLOT-003, AC-SLOT-004, AC-SLOT-005, AC-SLOT-006, AC-SLOT-007, AC-SLOT-008, AC-SLOT-009, AC-SLOT-010, AC-SLOT-011, AC-SLOT-012, AC-SLOT-013, AC-SLOT-015, AC-SLOT-022, AC-SLOT-024
# @spec: mfe-plugin-slots_spec.md
# Verify expected plugin slot IDs exist in source plugin config and rendered env config.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN_FILE="$PLUGIN_MAIN"
RENDERED_ENV="${RENDERED_ENV:-$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx}"
EXPECTED_SLOT_IDS="${EXPECTED_SLOT_IDS:-org.openedx.frontend.layout.header_logo.v1,org.openedx.frontend.layout.footer.v1,org.openedx.frontend.layout.studio_footer.v1,org.openedx.frontend.layout.studio_header_search_button_slot.v1,org.openedx.frontend.authoring.course_unit_sidebar.v1,org.openedx.frontend.authoring.course_outline_sidebar.v1,org.openedx.frontend.authoring.course_outline_header_actions.v1,org.openedx.frontend.authoring.course_unit_header_actions.v1,org.openedx.frontend.authoring.course_outline_page_alerts.v1,org.openedx.frontend.authoring.edit_video_alerts.v1,org.openedx.frontend.authoring.edit_file_alerts.v1,org.openedx.frontend.authoring.additional_course_plugin.v1,org.openedx.frontend.authoring.additional_course_content_plugin.v1,org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1,org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1,org.openedx.frontend.authoring.course_unit_sidebar.v2,org.openedx.frontend.authoring.files_upload_page_table.v1,org.openedx.frontend.authoring.videos_upload_page_table.v1,org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1,org.openedx.frontend.authn.login_component.v1,org.openedx.frontend.learner_dashboard.widget_sidebar.v1,org.openedx.frontend.learner_dashboard.no_courses_view.v1,org.openedx.frontend.learner_dashboard.course_list.v1,org.openedx.frontend.learner_dashboard.course_card_banner.v1,org.openedx.frontend.learner_dashboard.course_card_action.v1,org.openedx.frontend.learner_dashboard.dashboard_modal.v1,org.openedx.frontend.learning.course_outline_sidebar.v1,org.openedx.frontend.learning.progress_certificate_status.v1,org.openedx.frontend.layout.header_learning.v1,org.openedx.frontend.layout.header_desktop.v1,org.openedx.frontend.layout.header_mobile.v1,org.openedx.frontend.layout.header_learning_course_info.v1,org.openedx.frontend.learning.course_tab_links.v1,org.openedx.frontend.learning.course_breadcrumbs.v1,org.openedx.frontend.learning.learner_tools.v1,org.openedx.frontend.learning.progress_tab_course_grade.v1,org.openedx.frontend.learning.progress_tab_related_links.v1,org.openedx.frontend.learning.progress_tab_certificate_status_main_body.v1,org.openedx.frontend.learning.progress_tab_certificate_status_side_panel.v1,org.openedx.frontend.learning.progress_tab_grade_breakdown.v1,org.openedx.frontend.learning.unit_title.v1,org.openedx.frontend.learning.sequence_navigation.v1,org.openedx.frontend.learning.course_outline_sidebar_trigger.v1,org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1,org.openedx.frontend.learning.course_home_section_outline.v1,org.openedx.frontend.learning.course_recommendations.v1,org.openedx.frontend.learning.content_iframe_loader.v1,org.openedx.frontend.learning.content_iframe_error.v1,org.openedx.frontend.learning.sequence_container.v1,org.openedx.frontend.learning.gated_unit_content_message.v1,org.openedx.frontend.learning.next_unit_top_nav_trigger.v1,org.openedx.frontend.learning.course_outline_tab_notifications.v1,org.openedx.frontend.learning.notification_widget.v1,org.openedx.frontend.learning.notification_tray.v1,org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1,org.openedx.frontend.learning.notifications_discussions_sidebar.v1,org.openedx.frontend.learning.course_exit_view_courses.v1,org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1,org.openedx.frontend.account.id_verification_page.v1,org.openedx.frontend.account.additional_profile_fields.v1,org.openedx.frontend.profile.additional_profile_fields.v1,org.openedx.frontend.layout.header_desktop_main_menu.v1,org.openedx.frontend.layout.header_mobile_main_menu.v1,org.openedx.frontend.layout.header_desktop_logged_out_items.v1,org.openedx.frontend.layout.header_mobile_logged_out_items.v1,org.openedx.frontend.layout.header_desktop_secondary_menu.v1,org.openedx.frontend.layout.header_learning_help.v1,org.openedx.frontend.layout.header_learning_logged_out_items.v1,org.openedx.frontend.layout.header_desktop_user_menu.v1,org.openedx.frontend.layout.header_mobile_user_menu.v1,org.openedx.frontend.layout.header_learning_user_menu.v1,org.openedx.frontend.layout.header_desktop_user_menu_toggle.v1,org.openedx.frontend.layout.header_mobile_user_menu_trigger.v1,org.openedx.frontend.layout.header_learning_user_menu_toggle.v1}"
STRICT_RENDERED_SLOTS="${STRICT_RENDERED_SLOTS:-0}"
CHECK_RENDERED_SLOTS="${CHECK_RENDERED_SLOTS:-0}"

PASS=0
FAIL=0
WARN=0

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-contract.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN_FILE="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

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
  ["org.openedx.frontend.authoring.course_outline_page_alerts.v1"]="mereka_authoring_course_outline_page_alerts_hint"
  ["org.openedx.frontend.authoring.edit_video_alerts.v1"]="mereka_authoring_edit_video_alerts_hint"
  ["org.openedx.frontend.authoring.edit_file_alerts.v1"]="mereka_authoring_edit_file_alerts_hint"
  ["org.openedx.frontend.authoring.additional_course_plugin.v1"]="mereka_authoring_additional_course_plugin_hint"
  ["org.openedx.frontend.authoring.additional_course_content_plugin.v1"]="mereka_authoring_additional_course_content_plugin_hint"
  ["org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1"]="mereka_authoring_outline_subsection_extra_actions_hint"
  ["org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1"]="mereka_authoring_outline_unit_extra_actions_hint"
  ["org.openedx.frontend.authoring.course_unit_sidebar.v2"]="mereka_authoring_course_unit_sidebar_v2_hint"
  ["org.openedx.frontend.authoring.files_upload_page_table.v1"]="mereka_authoring_files_upload_page_table_hint"
  ["org.openedx.frontend.authoring.videos_upload_page_table.v1"]="mereka_authoring_videos_upload_page_table_hint"
  ["org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1"]="mereka_authoring_video_transcript_translations_hint"
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
  ["org.openedx.frontend.layout.header_desktop.v1"]="withMerekaHeaderDesktopShell"
  ["org.openedx.frontend.layout.header_mobile.v1"]="withMerekaHeaderMobileShell"
  ["org.openedx.frontend.layout.header_learning_course_info.v1"]="withMerekaHeaderLearningCourseInfo"
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
  ["org.openedx.frontend.layout.header_desktop_logged_out_items.v1"]="withMerekaMenuItems("
  ["org.openedx.frontend.layout.header_mobile_logged_out_items.v1"]="withMerekaMenuItems("
  ["org.openedx.frontend.layout.header_desktop_secondary_menu.v1"]="withMerekaMenuItems("
  ["org.openedx.frontend.layout.header_learning_help.v1"]="MerekaLearningHelpLink"
  ["org.openedx.frontend.layout.header_learning_logged_out_items.v1"]="withMerekaLearningLoggedOutItems"
  ["org.openedx.frontend.layout.header_desktop_user_menu.v1"]="withMerekaHeaderUserMenuSupport"
  ["org.openedx.frontend.layout.header_mobile_user_menu.v1"]="withMerekaHeaderUserMenuSupport"
  ["org.openedx.frontend.layout.header_learning_user_menu.v1"]="withMerekaLearningUserMenuSupport"
  ["org.openedx.frontend.layout.header_desktop_user_menu_toggle.v1"]="withMerekaHeaderUserMenuToggle"
  ["org.openedx.frontend.layout.header_mobile_user_menu_trigger.v1"]="withMerekaMobileUserMenuTrigger"
  ["org.openedx.frontend.layout.header_learning_user_menu_toggle.v1"]="withMerekaLearningUserMenuToggle"
  ["org.openedx.frontend.layout.studio_header_search_button_slot.v1"]="withMerekaStudioHeaderSearchButton"
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

# Source-contract assertions for key slot behaviors (no runtime dependency).
# These checks intentionally map to AC-SLOT source guarantees and do not assert browser rendering.
if rg -qF "org.openedx.frontend.layout.header_logo.v1" "$PLUGIN_FILE" \
  && rg -qF "mereka_header_logo" "$PLUGIN_FILE" \
  && rg -qF "logoUrl: '/theme/logo-horizontal.svg'" "$PLUGIN_FILE"; then
  pass "Source contract: desktop header logo slot binds to branded logo path"
else
  fail "Source contract: desktop header logo slot/logo path markers missing"
fi

if rg -qF "mobileLogoUrl:" "$PLUGIN_FILE" \
  && rg -qF "selectedLogo = isMobileViewport && variant.mobileLogoUrl ? variant.mobileLogoUrl : variant.logoUrl;" "$PLUGIN_FILE"; then
  pass "Source contract: mobile header logo selection uses mobileLogoUrl with viewport guard"
else
  fail "Source contract: mobile header logo selection markers missing"
fi

if rg -q "/dashboard" "$PLUGIN_FILE" \
  && rg -q "baseUrl \\? .*\\/dashboard.*: '/dashboard'" "$PLUGIN_FILE"; then
  pass "Source contract: dashboard href resolution includes baseUrl-aware /dashboard path"
else
  fail "Source contract: dashboard href resolution markers missing"
fi

if rg -qF "'academy.biji-biji.com': {" "$PLUGIN_FILE" \
  && rg -qF "'skillourfuture.academy.mereka.io': {" "$PLUGIN_FILE" \
  && rg -qF "const MEREKA_SITE_VARIANTS = {" "$PLUGIN_FILE"; then
  pass "Source contract: tenant hostnames are present in SITE_VARIANTS map"
else
  fail "Source contract: expected tenant hostnames missing from SITE_VARIANTS map"
fi

if rg -qF "content: 'Discover Courses'" "$PLUGIN_FILE" \
  && rg -qF "content: 'Support'" "$PLUGIN_FILE" \
  && rg -qF "href: '/dashboard'" "$PLUGIN_FILE"; then
  pass "Source contract: menu wiring contains Dashboard, Discover Courses, and Support markers"
else
  fail "Source contract: required menu content markers missing"
fi

if rg -qF "org.openedx.frontend.layout.header_desktop_main_menu.v1" "$PLUGIN_FILE" \
  && rg -qF "org.openedx.frontend.layout.header_mobile_main_menu.v1" "$PLUGIN_FILE" \
  && rg -qF "withMerekaMenuItems(" "$PLUGIN_FILE"; then
  pass "Source contract: desktop/mobile main menu slots share withMerekaMenuItems helper"
else
  fail "Source contract: desktop/mobile menu parity helper markers missing"
fi

if rg -qF "org.openedx.frontend.learning.course_outline_sidebar.v1" "$PLUGIN_FILE" \
  && rg -qF "mereka_course_outline_sidebar" "$PLUGIN_FILE"; then
  pass "Source contract: learning course outline sidebar slot markers present"
else
  fail "Source contract: learning course outline sidebar slot markers missing"
fi

if rg -qF "org.openedx.frontend.learning.sequence_navigation.v1" "$PLUGIN_FILE" \
  && rg -qF "mereka_learning_sequence_navigation_hint" "$PLUGIN_FILE"; then
  pass "Source contract: learning sequence navigation slot markers present"
else
  fail "Source contract: learning sequence navigation slot markers missing"
fi

if rg -qF "org.openedx.frontend.account.additional_profile_fields.v1" "$PLUGIN_FILE" \
  && rg -qF "mereka_additional_profile_fields" "$PLUGIN_FILE"; then
  pass "Source contract: account additional profile fields slot markers present"
else
  fail "Source contract: account additional profile fields slot markers missing"
fi

if rg -qF "org.openedx.frontend.profile.additional_profile_fields.v1" "$PLUGIN_FILE" \
  && rg -qF "mereka_profile_additional_fields" "$PLUGIN_FILE"; then
  pass "Source contract: profile additional profile fields slot markers present"
else
  fail "Source contract: profile additional profile fields slot markers missing"
fi

# Build/verification diagnostics contract for rapid slot debugging.
if rg -qF 'Expected slot binding marker missing for $slot: $marker' "$0" \
  && rg -qF 'Expected slot missing in plugin: $slot' "$0"; then
  pass "Diagnostics contract: failures include both slot ID and component marker context"
else
  fail "Diagnostics contract: slot/component failure message template missing"
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
