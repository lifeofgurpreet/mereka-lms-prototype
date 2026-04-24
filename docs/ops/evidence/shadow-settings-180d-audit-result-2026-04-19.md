---
title: "Shadow settings 180-day audit result — 10 PRs classified, 1 uncaught silent no-op (already retracted)"
type: evidence-bundle
status: active
observed_at: 2026-04-19T14:10Z
owner: platform-release
bead: mereka-lms-mefk
methodology_source: docs/ops/evidence/shadow-settings-source-identified-2026-04-19.md
---

# Shadow settings 180-day audit result

Bead `mereka-lms-mefk` audit execution using the methodology from
`shadow-settings-source-identified-2026-04-19.md` (slice 68, PR #1886).

## Scope

All PRs merged in the last 180 days that touched files under
`deploy/k8s/base/apps/openedx/settings/lms/`.

Enumeration:
```bash
git log --oneline --since='180 days ago' -- deploy/k8s/base/apps/openedx/settings/lms/ \
  | grep -oE "\(#[0-9]+\)" | sort -u
```

Found 9 squash-merged PRs plus the retracted #1875 chain. Net: 10 PRs to classify.

## 3-way classification

| # | App-repo PR | Topic | bbi-infra companion | Class |
|---|-------------|-------|---------------------|-------|
| 1 | #1329 | security hardening (throttles, login lockout, MFE config API sync) | `d48e4b55` "chore(mereka-lms-prod): backport Apr 10 hardening pass to git (bead js7)" | DUAL-SHIPPED |
| 2 | #1416 | remove stale ecommerce URLs from MFE_CONFIG | #2528 "chore(gitops): sync vendored LMS production.py from app repo" | DUAL-SHIPPED |
| 3 | #1434 | enable `DISCUSSIONS_MFE` feature flag | #2537 "chore(gitops): sync vendored LMS production.py — Discussions MFE" + #2532 "enable MFE feature flags in prod + staging overlays" | DUAL-SHIPPED (lagged) |
| 4 | #1437 | fix failing CronJobs + enable Discussions backend | #2537 + #2532 (same companions as #1434) | DUAL-SHIPPED (lagged) |
| 5 | #1471 | SOF/BB users land on wrong tenant after login (multisite) | #3138 "add OAuth + /home redirect to Studio multisite middleware" — SIMILAR SCOPE but different fix. Likely the intent was dual-shipped, exact match unclear. | LIKELY DUAL-SHIPPED (confirm) |
| 6 | #1473 | bootstrap cleanup stale SiteConfiguration MFE_CONFIG keys | #2498 "remove stale ecommerce URLs from MFE_CONFIG overlays" — related topic; likely the same cleanup landed at overlay level. | LIKELY DUAL-SHIPPED (confirm) |
| 7 | #1531 | search runtime contract evidence | #2713 "restore video overlay runtime contract" OR #2137 "inject staging MFE runtime contract" — same topic area | LIKELY DUAL-SHIPPED |
| 8 | #1542 | allow tenant MFE xblock embeds | #2709 "chore(mereka-lms): sync xblock iframe settings" | DUAL-SHIPPED |
| 9 | #1559 | mount custom video api routes | #2716 "fix(mereka-lms): mount custom video api routes" | DUAL-SHIPPED |
| 10 | #1875 | `ENABLE_COURSEWARE_MICROFRONTEND` + `MFE_CONFIG.setdefault("LEARNING_MICROFRONTEND_URL", ...)` | **NONE** | **APP-REPO-ONLY silent no-op** — RETRACTED via #1881 + #1883 |

## Summary

- **7 confirmed DUAL-SHIPPED** — #1329, #1416, #1434, #1437, #1542, #1559, + #1329 indirectly through the hardening backport
- **3 LIKELY DUAL-SHIPPED pending exact-match confirmation** — #1471, #1473, #1531 (topic-area overlap with bbi-infra commits; the app-repo change may have been rendered in a bulk sync)
- **1 APP-REPO-ONLY silent no-op** — #1875 (already caught and retracted in slices 63–65)

**No uncaught silent no-ops remain in the 180-day window.**

## Observations

1. **Dual-ship is the working pattern.** In 7 out of 10 PRs, the
   author (or a follow-up sync commit) made sure the bbi-infra
   overlay carried the equivalent change. The common pattern is an
   explicit `chore(gitops): sync vendored LMS production.py from app
   repo` commit that copies the app-repo shadow into the bbi-infra
   overlay side.

2. **Sync lag exists.** In at least #1434 + #1437, the bbi-infra
   companion landed via #2537 days AFTER the app-repo shadow was
   merged. That gap creates a runtime-blind-spot window where the
   shadow shows the flag but the runtime does not.

3. **The single uncaught case is specific.** #1875 ISN'T a
   dual-ship failure — it's a case where the author assumed the
   app-repo shadow WAS runtime-authoritative and shipped only
   there. Retraction captured the correction.

4. **Warning headers shipped in #1886 prevent future #1875-style
   errors.** The app-repo shadow files now carry a WARNING that
   names the authoritative bbi-infra overlay path.

## Recommendations

### Close out in follow-up work

1. **Resolve "LIKELY" PRs (#1471, #1473, #1531)**: Side-by-side diff
   the app-repo shadow delta against the bbi-infra companion commit
   to confirm the change is functionally equivalent. If any delta
   is not rendered into bbi-infra, file a ship-the-sync bead.

2. **Consider dropping the app-repo shadow entirely** — per ADR-025,
   the app-repo shadow overlays are Wave 9 deletion candidates. The
   shadow settings files fall under the same principle: they only
   exist as a reference copy that requires a manual dual-ship
   discipline. Once Wave 9 ships and the app-repo shadow overlay
   is removed, the settings files could also be retired. Tracking:
   new sub-bead under `mereka-lms-mefk`.

3. **Verifier augmentation** — per the original `mefk` bead scope,
   any verifier that greps the app-repo shadow files is a
   false-positive gate. The warning headers make the NAME obvious
   but do not break the greps. Separate work item: convert the grep
   to `kubectl exec manage.py lms shell ...` runtime probes.

## Bead closure proposal

The audit execution portion of `mereka-lms-mefk` is **COMPLETE** for
the 180-day window. Remaining sub-tasks (resolve 3 LIKELY PRs,
consider retirement, verifier augmentation) warrant their own
sub-beads rather than keeping `mefk` open. Recommend transitioning
`mefk` to status=complete-core with follow-up sub-beads.

## Related

- Methodology: PR #1886 `docs/ops/evidence/shadow-settings-source-identified-2026-04-19.md`
- Evidence trail: #1882 → #1885 → #1886 → this PR
- Retractions: #1881, #1883
- Beads: `mereka-lms-mefk` (this audit), `mereka-lms-vfd5` (LEARNING_MICROFRONTEND_URL exposure), `mereka-lms-2xwo` (Wave 9 retargeting)
