---
title: MFE Plugin-Slot Phase 1-3 Gap Audit
type: evidence-bundle
status: active
observed_at: 2026-04-19T09:50Z
owner: platform-release
bead: mereka-lms-m0u5
spec_ref: specs/mfe-plugin-slots_spec.md
---

<!-- Last verified: 2026-04-19 -->

# MFE Plugin-Slot Phase 1-3 Gap Audit

**Date**: 2026-04-19
**Bead**: mereka-lms-m0u5 (MFE issue map → executable backlog)
**Source audited**: `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` (74 registered slots across 503 lines)
**Spec**: `specs/mfe-plugin-slots_spec.md` (AC-SLOT-001 through AC-SLOT-029; 29 criteria total)
**Do not duplicate**: Separate audit bundle at `docs/ops/evidence/gke-auth-workflow-classification-2026-04-19.md`

---

## 1. Summary

| Category | Count |
|----------|-------|
| Total unique slots registered | **74** |
| Slots with Phase 1 acceptance criteria (AC-SLOT-001–007) | **7** covering 7 slots |
| Slots with Phase 2 acceptance criteria (AC-SLOT-008–011) | **4** covering ~9 slots |
| Slots with Phase 3 acceptance criteria (AC-SLOT-012–015) | **4** covering 3 slots |
| Cross-cutting AC-covered slots (AC-SLOT-016–029) | all 74 (pattern rules) |
| **OVERSPEC** (registered, no phase-specific AC) | **49** |
| Inventory doc "ACTIVE" figure (stale) | 12 → corrected to **74** |

**How to read this audit**: OVERSPEC is a spec-maintenance debt
signal, not a code defect. The spec fell behind the code because the
code evolved to meet real requirements that were not specced up
front. The remediation is (a) write acceptance criteria for slots
with clear product value (§4a) and (b) investigate the rest
case-by-case (§4b, §4c) before any removal is considered. See §4
framing paragraph for why placeholder/Hint/HOF-wrapped registrations
are generally load-bearing even when they appear to inject nothing.

---

## 2. Complete Slot Registry

Operation codes used below:

| Code | Meaning |
|------|---------|
| `I` | Insert (DIRECT_PLUGIN) |
| `HI` | Hide default_contents + Insert |
| `M` | Modify default_contents via HOF |
| `MM` | Modify with inline menu items |

### 2.1 Layout — Header

| Slot ID | Op | Phase | MFE Target | Has Spec AC? |
|---------|-----|-------|-----------|-------------|
| `org.openedx.frontend.layout.header_logo.v1` | HI | **1** | all | **Y** — AC-SLOT-001, AC-SLOT-003, AC-SLOT-004, AC-SLOT-007 (spec lines 109–115) |
| `org.openedx.frontend.layout.header_desktop.v1` | M | **1** | all | Partial — AC-SLOT-007 covers build gate; no explicit desktop-shell AC |
| `org.openedx.frontend.layout.header_mobile.v1` | M | **1** | all | Partial — AC-SLOT-002, AC-SLOT-006, AC-SLOT-007 cover mobile viewport expectations |
| `org.openedx.frontend.layout.header_desktop_main_menu.v1` | MM | **1** | all | **Y** — AC-SLOT-005, AC-SLOT-007 (spec lines 113–115) |
| `org.openedx.frontend.layout.header_mobile_main_menu.v1` | MM | **1** | all | **Y** — AC-SLOT-006, AC-SLOT-007 (spec lines 114–115) |
| `org.openedx.frontend.layout.header_desktop_logged_out_items.v1` | MM | **1** | all | Partial — AC-SLOT-007 (build gate); no explicit logged-out nav AC |
| `org.openedx.frontend.layout.header_mobile_logged_out_items.v1` | MM | **1** | all | Partial — same |
| `org.openedx.frontend.layout.header_desktop_secondary_menu.v1` | MM | **1** | all | N — no AC; empties the secondary menu (hide Indigo dark-mode toggle) |
| `org.openedx.frontend.layout.header_desktop_user_menu.v1` | M | OVERSPEC | all | N |
| `org.openedx.frontend.layout.header_desktop_user_menu_toggle.v1` | M | OVERSPEC | all | N |
| `org.openedx.frontend.layout.header_mobile_user_menu.v1` | M | OVERSPEC | all | N |
| `org.openedx.frontend.layout.header_mobile_user_menu_trigger.v1` | M | OVERSPEC | all | N |

### 2.2 Layout — Learning Header

| Slot ID | Op | Phase | MFE Target | Has Spec AC? |
|---------|-----|-------|-----------|-------------|
| `org.openedx.frontend.layout.header_learning.v1` | I | **2** | all | Partial — AC-SLOT-008 references sidebar branding; no explicit learning-header AC |
| `org.openedx.frontend.layout.header_learning_course_info.v1` | M | OVERSPEC | all | N |
| `org.openedx.frontend.layout.header_learning_help.v1` | HI | OVERSPEC | all | N |
| `org.openedx.frontend.layout.header_learning_logged_out_items.v1` | M | OVERSPEC | all | N |
| `org.openedx.frontend.layout.header_learning_user_menu.v1` | M | OVERSPEC | all | N |
| `org.openedx.frontend.layout.header_learning_user_menu_toggle.v1` | M | OVERSPEC | all | N |

### 2.3 Layout — Footer

| Slot ID | Op | Phase | MFE Target | Has Spec AC? |
|---------|-----|-------|-----------|-------------|
| `org.openedx.frontend.layout.footer.v1` | HI | Pre-Phase 1 | all | N — footer is in-scope for branding-system_spec, not this spec (see spec §Out of Scope) |
| `org.openedx.frontend.layout.studio_footer.v1` | I | Pre-Phase 1 | all | N — same; studio footer is branding-system_spec scope |
| `org.openedx.frontend.layout.studio_header_search_button_slot.v1` | M | OVERSPEC | all | N |

### 2.4 Authn

| Slot ID | Op | Phase | MFE Target | Has Spec AC? |
|---------|-----|-------|-----------|-------------|
| `org.openedx.frontend.authn.login_component.v1` | I | Pre-Phase 1 | authn | N — login branding predates the spec; treated as baseline |

### 2.5 Learner Dashboard

| Slot ID | Op | Phase | MFE Target | Has Spec AC? |
|---------|-----|-------|-----------|-------------|
| `org.openedx.frontend.learner_dashboard.widget_sidebar.v1` | I | Pre-Phase 1 | learner-dashboard | N — implemented before spec; no AC assigned |
| `org.openedx.frontend.learner_dashboard.no_courses_view.v1` | HI | Pre-Phase 1 | learner-dashboard | N |
| `org.openedx.frontend.learner_dashboard.course_list.v1` | I | OVERSPEC | learner-dashboard | N |
| `org.openedx.frontend.learner_dashboard.course_card_banner.v1` | I | OVERSPEC | learner-dashboard | N |
| `org.openedx.frontend.learner_dashboard.course_card_action.v1` | I | OVERSPEC | learner-dashboard | N |
| `org.openedx.frontend.learner_dashboard.dashboard_modal.v1` | I | OVERSPEC | learner-dashboard | N |

### 2.6 Learning (Courseware)

| Slot ID | Op | Phase | MFE Target | Has Spec AC? |
|---------|-----|-------|-----------|-------------|
| `org.openedx.frontend.learning.course_outline_sidebar.v1` | I | **2** | learning | **Y** — AC-SLOT-008, AC-SLOT-011 (spec lines 119–122) |
| `org.openedx.frontend.learning.progress_certificate_status.v1` | I | **2** | learning | **Y** — AC-SLOT-011 (build gate); primary is AC-SLOT-008 area |
| `org.openedx.frontend.learning.sequence_navigation.v1` | I | **2** | learning | **Y** — AC-SLOT-009, AC-SLOT-011 (spec lines 120–122) |
| `org.openedx.frontend.learning.course_tab_links.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.course_breadcrumbs.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.learner_tools.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.progress_tab_course_grade.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.progress_tab_related_links.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.progress_tab_certificate_status_main_body.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.progress_tab_certificate_status_side_panel.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.progress_tab_grade_breakdown.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.unit_title.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.course_outline_sidebar_trigger.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.course_home_section_outline.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.course_recommendations.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.content_iframe_loader.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.content_iframe_error.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.sequence_container.v1` | I | OVERSPEC | learning | N — explicitly flagged NOT recommended in inventory doc |
| `org.openedx.frontend.learning.gated_unit_content_message.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.next_unit_top_nav_trigger.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.course_outline_tab_notifications.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.notification_widget.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.notification_tray.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.notifications_discussions_sidebar.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.course_exit_view_courses.v1` | I | OVERSPEC | learning | N |
| `org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1` | I | OVERSPEC | learning | N |

### 2.7 Account & Profile

| Slot ID | Op | Phase | MFE Target | Has Spec AC? |
|---------|-----|-------|-----------|-------------|
| `org.openedx.frontend.account.additional_profile_fields.v1` | I | **3** | account | **Y** — AC-SLOT-012, AC-SLOT-014, AC-SLOT-015 (spec lines 126–129) |
| `org.openedx.frontend.account.id_verification_page.v1` | I | OVERSPEC | account | N |
| `org.openedx.frontend.profile.additional_profile_fields.v1` | I | **3** | profile | **Y** — AC-SLOT-013, AC-SLOT-015 (spec lines 127–129) |

### 2.8 Authoring (Studio)

| Slot ID | Op | Phase | MFE Target | Has Spec AC? |
|---------|-----|-------|-----------|-------------|
| `org.openedx.frontend.authoring.course_unit_sidebar.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.course_outline_sidebar.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.course_outline_header_actions.v1` | I | OVERSPEC | authoring | N — listed in inventory "Priority 3" but no AC written |
| `org.openedx.frontend.authoring.course_unit_header_actions.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.course_outline_page_alerts.v1` | I | OVERSPEC | authoring | N — listed in inventory "Priority 3" but no AC written |
| `org.openedx.frontend.authoring.edit_video_alerts.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.edit_file_alerts.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.additional_course_plugin.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.additional_course_content_plugin.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.course_unit_sidebar.v2` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.files_upload_page_table.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.videos_upload_page_table.v1` | I | OVERSPEC | authoring | N |
| `org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1` | I | OVERSPEC | authoring | N — explicitly listed "Not Recommended" in inventory |

---

## 3. Phase / AC Coverage Summary

| Phase | Spec AC IDs | Slots Directly Covered | Registered Count |
|-------|-------------|----------------------|-----------------|
| Phase 1 — Header Branding | AC-SLOT-001–007 | header_logo, header_desktop, header_mobile, header_desktop_main_menu, header_mobile_main_menu | 5 primary + 2 supporting (logged_out menus) = **7** |
| Phase 2 — Learning MFE | AC-SLOT-008–011 | course_outline_sidebar, progress_certificate_status, sequence_navigation + header_learning | **4** |
| Phase 3 — Account & Profile | AC-SLOT-012–015 | account.additional_profile_fields, profile.additional_profile_fields | **2** (+ id_verification OVERSPEC) |
| Cross-cutting patterns | AC-SLOT-016–020 | All 74 (pattern constraints, not slot-specific) | 74 |
| Testing / CI | AC-SLOT-021–024 | No slot-specific coverage (scripts not yet written) | 0 scripts live |
| NFRs | AC-SLOT-025–029 | No automated enforcement | 0 |
| **Pre-Phase baseline** | (footer, studio_footer, authn_login, learner sidebar) | footer, studio_footer, authn.login_component, learner_dashboard.widget_sidebar, learner_dashboard.no_courses_view | **5** (all landed before spec was written) |
| **OVERSPEC** | None | 49 slots with no spec AC | **49** |

---

## 4. OVERSPEC: 49 slots — a spec gap, not a code defect

**Framing correction**: OVERSPEC means the spec lacks acceptance
criteria for a slot that was added while the codebase evolved. It does
NOT mean the slot is wrong or unwanted. In edX MFE plugin-slot
architecture, "Hint" / placeholder / HOF-wrapper registrations are
often intentional forward-compat extension points — they hold the slot
API surface stable so Mereka-side customization can be wired later
without another round of upstream coordination.

**Do not delete OVERSPEC slots without an explicit investigation per
slot.** The correct remediation path for almost every OVERSPEC entry
is to write acceptance criteria (spec extension), not to delete the
registration.

### 4a. Candidates for immediate spec extension

These slots have clear product value already and should be formally
specified in a follow-up PR to `specs/mfe-plugin-slots_spec.md`.
Writing ACs graduates them from OVERSPEC without touching the plugin
code:

| Slot | Rationale |
|------|-----------|
| `layout.header_learning.v1` | Complements Phase 2 — learning header branding is a natural extension of AC-SLOT-008 |
| `layout.header_desktop_secondary_menu.v1` | Actively suppresses Indigo dark-mode toggle; operational intent is real |
| `layout.header_desktop_logged_out_items.v1` | Logged-out nav is part of Phase 1 header story (AC-SLOT-005 gap) |
| `layout.header_mobile_logged_out_items.v1` | Same as above for mobile (AC-SLOT-006 gap) |
| `learning.sequence_navigation.v1` | AC-SLOT-009 references this slot by name — AC already written, slot just lacks explicit line citation |
| `learning.progress_tab_*` (5 slots) | Natural extension of Phase 2 progress/certificate story; extend AC-SLOT-008 area |
| `learning.course_exit_*` (2 slots) | Post-course branding touchpoints; low-risk |
| `authoring.course_outline_header_actions.v1` | Inventory "Priority 3" already noted this; write AC and promote |
| `authoring.course_outline_page_alerts.v1` | Same — inventory already surfaced |
| `account.id_verification_page.v1` | Natural Phase 3 extension for enterprise users |
| `learner_dashboard.course_card_banner.v1` | Branded course card accent is visible learner experience |

### 4b. Slots requiring case-by-case investigation before any action

These slots are registered as placeholder `*Hint` widgets or HOF
wrappers that do not inject visible output today. **This is not the
same as "dead code."** In the edX plugin-slot pattern, a registered
Hint or wrapped HOF may be:

- a deliberate API surface held stable for planned future work,
- an upstream template hook that Mereka intentionally holds open,
- a cross-MFE interface that upstream tools introspect (e.g. visual
  regression tools walk the slot registry), or
- a forward-compat placeholder for a tenant-specific injection that
  has not yet been scheduled.

None of those conditions can be inferred from a grep-level audit. The
correct remediation is to investigate each slot:

1. Confirm whether the original commit that added the registration
   cites a ticket / spec / bead.
2. Check whether any runtime reference in `_mereka_lms/mfe_runtime/`
   or upstream MFE source depends on the slot name being registered.
3. If the slot is genuinely a leftover with no referenced intent and
   no upstream consumer, propose AC or deletion via a bead + reviewer
   decision — NOT in a silent cleanup PR.

The following slots are the INVESTIGATION SET — each needs its own
bead before any removal is considered:

| Slot | Initial observation (needs verification) |
|------|------------------------------------------|
| `layout.header_desktop_user_menu.v1` | HOF wrapper; confirm whether the wrap customizes user-menu rendering |
| `layout.header_desktop_user_menu_toggle.v1` | May guard mobile toggle behavior; check with a live probe |
| `layout.header_mobile_user_menu.v1` | Same pattern; investigate before touching |
| `layout.header_mobile_user_menu_trigger.v1` | Same |
| `layout.header_learning_course_info.v1` | Modify HOF — determine what it modifies before assuming no-op |
| `layout.header_learning_logged_out_items.v1` | Logged-out learning header; edge case but not obviously obsolete |
| `layout.header_learning_user_menu.v1` | Same pattern as desktop user menu |
| `layout.header_learning_user_menu_toggle.v1` | Same |
| `layout.header_learning_help.v1` | HI that removes help link — **do not touch** until help-link removal is confirmed intentional |
| `learning.sequence_container.v1` | Inventory notes "high risk of regressions" — signals this IS load-bearing, not retire-able |
| `learning.content_iframe_loader.v1` | Possible future loading UX surface |
| `learning.content_iframe_error.v1` | Possible future error UX surface |
| `learning.course_outline_tab_notifications.v1` | Notification surface — likely planned product feature |
| `learning.notification_widget.v1` | Same |
| `learning.notification_tray.v1` | Same |
| `learning.notifications_discussions_sidebar.v1` | Discussions sidebar — Forum v2 integration may consume this in future |
| `learning.notifications_discussions_sidebar_trigger.v1` | Same |
| `learning.gated_unit_content_message.v1` | Enterprise content gating — likely intentional |
| `learning.next_unit_top_nav_trigger.v1` | Learning nav — investigate |
| `authoring.course_unit_sidebar.v1` + `.v2` | Check which is live; `.v1` may be upstream default fallback |
| `authoring.edit_video_alerts.v1` | Studio alerting surface — likely intentional |
| `authoring.edit_file_alerts.v1` | Same |
| `authoring.files_upload_page_table.v1` | Studio upload surface — investigate |
| `authoring.videos_upload_page_table.v1` | Same |
| `authoring.video_transcript_additional_translations_component.v1` | Flagged "Not Recommended" in inventory — inventory note is guidance, not a retire order |
| `authoring.course_outline_subsection_card_extra_actions.v1` | Planned Studio extension point |
| `authoring.course_outline_unit_card_extra_actions.v1` | Same |
| `authoring.additional_course_plugin.v1` | Course-level plugin surface |
| `authoring.additional_course_content_plugin.v1` | Same |
| `learner_dashboard.dashboard_modal.v1` | Modal injection point — likely intentional UX hook |
| `learner_dashboard.course_card_action.v1` | Course card CTA hook — product surface |
| `learner_dashboard.course_list.v1` | Interacts with `no_courses_view` — investigate interaction before touching |
| `layout.studio_header_search_button_slot.v1` | Studio header search — possible tenant customization |

### 4c. Also in the investigation set

| Slot | Open question |
|------|----------------|
| `learning.learner_tools.v1` | Learner tools panel — is this the Mereka-specific tools home? Needs product answer. |
| `learning.course_breadcrumbs.v1` | Breadcrumb branding — cosmetic value but not in spec |
| `learning.course_recommendations.v1` | Post-course recommendations — potential product feature |
| `learning.course_home_section_outline.v1` | Mobile outline; may duplicate course_outline_sidebar work |
| `learning.course_tab_links.v1` | Tab link customization — potential for tenant-specific tabs |
| `learning.unit_title.v1` | Unit title styling — low risk, but intentional vs. leftover? |
| `authoring.course_outline_sidebar.v1` | Authoring sidebar — different from learning sidebar |
| `authoring.course_unit_header_actions.v1` | Studio unit header — is there a planned action? |

---

## 5. Stale Inventory Figure Correction

`docs/reference/architecture/MFE_PLUGIN_SLOT_INVENTORY.md` line 27 states `ACTIVE | 12`.

This was accurate at the time the inventory was last verified (2026-02-28). As of 2026-04-19 the plugin file `mereka_lms_mfe_slots.py` registers **74 unique slots** across `_INSERT_SLOTS` (53), `_HIDE_INSERT_SLOTS` (3), `_MODIFY_SLOTS` (11), footer (1), menu-modify (4), and secondary-menu-modify (1) groups (with `layout.studio_footer.v1` added separately in the INSERT list as slot 50).

The inventory doc "ACTIVE" table covers only the 12 slots that existed before the MFE-slots refactor was landed. It does not reflect the 62 additional registrations added during the m0u5 sprint. The inventory doc has been updated (see §6 below).

---

## 6. Next Steps

1. **Spec extension PR** — Add ACs for the 11 "immediate spec
   extension" candidates listed in §4a. This is the one clearly
   actionable follow-up and the only way to graduate those slots
   from OVERSPEC. Zero code-behavior change.
2. **Per-slot investigation beads** — For the ~33 slots in §4b and
   §4c, open a separate bead per slot (or per related group). Each
   investigation must answer:
   - Is there an original commit citing a ticket / spec / bead?
   - Does any runtime (`_mereka_lms/mfe_runtime/*`) or upstream MFE
     source reference the slot by name?
   - Is the slot serving as a planned-future extension point?
   Only after these answers come back can a reviewer make a keep /
   spec-extend / remove decision — and that decision should ship in
   its own small PR, NOT as a bulk cleanup.
3. **Verification script** — AC-SLOT-022 requires
   `scripts/qa/verify-mfe-plugin-slots.sh`. No script exists today.
   This is the highest-priority CI gap and can be written against the
   current 74-slot reality without waiting on spec extension. The
   verifier should assert every registered slot actually exists in
   the plugin file and that critical Phase 1-3 ACs still pass —
   nothing more.
4. **Visual regression baseline** — AC-SLOT-021 requires screenshot
   baselines for all Phase 1-3 slots. None exist. Required before any
   Phase 1 slot can be marked DONE.

**Explicit non-goal for this audit**: bulk deletion of OVERSPEC slots.
The OVERSPEC count is a **spec-maintenance debt signal** — the spec
has fallen behind the code because the code evolved to meet
requirements that weren't specced up front. That is a normal,
expected state for a live product. The remediation is to let the
spec catch up (or capture a deliberate decision to retire a slot
with its own review), not to delete code that might be load-bearing.
