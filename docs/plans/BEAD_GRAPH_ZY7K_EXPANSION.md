# Bead Graph Review: zy7k Expansion — jdsx, 9ib2, mx78, e09t

**Date:** 2026-04-22
**Reviewed by:** beads-orchestration agent (read-only)
**Do not execute the `br` commands below — they are proposals for human review.**

---

## 1. Verdict

**jdsx** — Keep as sibling. The config key it targets (`LOGIN_ISSUE_SUPPORT_LINK`) is **already present** in `lms_settings.py` line 99. The real work is the SESSION_COOKIE_DOMAIN verification follow-up on PR #1928, which is a regression-check task, not brand/footer work. Absorbing it into zy7k would misrepresent zy7k's scope.

**9ib2** — Keep as sibling. Its only blocking work is wiring a K8s env var through bbi-infra overlays (strategic-merge patch). This is infrastructure plumbing orthogonal to footer SCSS and brand npm — absorbing it dilutes zy7k's "plugin-first footer + brand package" theme.

**mx78, e09t** — Neither belongs in zy7k. Both are observability operations (Upptime config, CI cron schedule). Form a natural OBS-* sibling cluster with jdsx and 9ib2.

**1kwf.1** — Already correctly absorbed as zy7k.1's execution vehicle. The `blocks` dependency is visible and correct.

---

## 2. Evidence per bead

### mereka-lms-jdsx

- **Body summary:** Add `LOGIN_ISSUE_SUPPORT_LINK` to `lms_settings.py` MFE_CONFIG block. Verify `SESSION_COOKIE_DOMAIN` surfaces correctly after PR #1928.
- **Touched surfaces:** `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py` only.
- **Acceptance shape:** `smoke-authn-mfe.sh` emits no WARN for either key.
- **Fit with zy7k:** Weak. The `LOGIN_ISSUE_SUPPORT_LINK` key is **already committed** (line 99 of `lms_settings.py`). The remaining work is a one-time verification after PR #1928 lands. No SCSS, no npm, no Django template. Touching the same file as zy7k (lms_settings.py) is incidental — zy7k's phases do not modify that file.
- **Dependencies declared:** None.

### mereka-lms-9ib2

- **Body summary:** Wire `MEREKA_MFE_SENTRY_DSN` env var into bbi-infra K8s overlays for lms/cms/discovery/credentials on dev/staging/prod via ExternalSecret + strategic-merge patch. Blocked on OBS-001 phase 2 (Sentry project + DSN in Infisical).
- **Touched surfaces:** `deploy/k8s/` overlays in bbi-infrastructure repo (not this repo). `lms_settings.py` already reads `os.environ.get("MEREKA_MFE_SENTRY_DSN")` at line 123 — the plugin side is done.
- **Acceptance shape:** `printenv MEREKA_MFE_SENTRY_DSN` returns the DSN in pod; `/api/mfe_config/v1` returns `SENTRY_DSN` matching; JS error surfaces in Sentry within 2 min.
- **Fit with zy7k:** None. The lms_settings.py changes are already in place. Remaining work is K8s overlay surgery in bbi-infra, gated on a Sentry project existing. This is observability infrastructure, not brand/footer convergence.
- **Dependencies declared:** "Blocked on: phase 2" (prose, no formal dep link to any bead).

### mereka-lms-mx78

- **Body summary:** Add prod LMS domains (`academyv2.mereka.io`, `studio.*`, `apps.*`) to Upptime config at `~/infrastructure/upptime/.upptimerc.yml`.
- **Touched surfaces:** VPS `~/infrastructure/upptime/` — entirely outside this repo and zy7k's scope.
- **Acceptance shape:** External uptime monitoring detects prod outages.
- **Fit with zy7k:** None. Pure observability ops.

### mereka-lms-e09t

- **Body summary:** Convert `smoke-authn-mfe.yml` from `workflow_dispatch` to a 5-min cron against dev and 15-min cron against prod.
- **Touched surfaces:** `.github/workflows/smoke-authn-mfe.yml`.
- **Acceptance shape:** CI schedule runs; login flow assertion passes within 5/15 min window.
- **Fit with zy7k:** None. CI scheduling change, not brand/footer work.

### mereka-lms-1kwf.1

- **Body summary:** Port Mereka Frontend v2 footer into LMS/MFEs via plugin-first approach. 6 ACs covering structure, extension surfaces, no patch-spaghetti, all tenants, evidence bundle, docs.
- **Touched surfaces:** `infrastructure/tutor/themes/mereka/`, `infrastructure/tutor/plugins/`, `docs/branding/`, `docs/operations/`.
- **Acceptance shape:** Footer renders on all 5 prod surfaces; evidence bundle saved; docs updated.
- **Fit with zy7k:** Fully absorbed. Comment on bead confirms this (2026-04-22). Dependency `blocks mereka-lms-zy7k.1` is visible and correct. No further action needed.

---

## 3. Proposed bead graph changes

No changes to zy7k or its children are needed. The three commands below address the OBS sibling cluster and one missing formal dependency for 9ib2.

```bash
# jdsx: The LOGIN_ISSUE_SUPPORT_LINK key is already in lms_settings.py (line 99).
# Update bead body to reflect that the config-key work is done and only
# the PR-#1928 verification remains. This avoids the bead looking
# stale/misleading when an implementor picks it up.
br update mereka-lms-jdsx --body "LOGIN_ISSUE_SUPPORT_LINK already present in lms_settings.py (line 99). Remaining work: after PR #1928 (fix/mfe-config-session-cookie-domain) is merged and images rebuilt, run smoke-authn-mfe.sh and confirm SESSION_COOKIE_DOMAIN surfaces in /api/mfe_config/v1 with the correct value. Exit: smoke-authn-mfe.sh emits no WARN for either key."

# 9ib2: Add a formal OBS-001-phase-2 prerequisite once that bead is filed.
# Today that blocker is only in prose. When the Sentry project bead exists,
# run: br dep add mereka-lms-9ib2 <obs-001-phase2-bead-id>

# Group the four OBS beads under a common observability epic so they
# appear together in br list and br ready. Create the epic first:
br create -t epic -p P2 "OBS — MFE observability & runtime-config hygiene (synthetic, uptime, Sentry, config-key gaps)"
# Then link children (replace <obs-epic-id> with the ID returned above):
br update mereka-lms-jdsx  --parent <obs-epic-id>
br update mereka-lms-9ib2  --parent <obs-epic-id>
br update mereka-lms-mx78  --parent <obs-epic-id>
br update mereka-lms-e09t  --parent <obs-epic-id>
```

---

## 4. MFE_CONVERGENCE_PLAN.md updates

No structural changes required. If you want a one-line callout:

In the **"Parallel debts (same lane)"** section, add after the three existing bullets:

> **Runtime-config & observability hygiene (OBS cluster):** Separate sibling epic covers `LOGIN_ISSUE_SUPPORT_LINK` verification (jdsx), Sentry DSN K8s overlay wiring (9ib2), Upptime prod monitors (mx78), and authn-MFE cron synthetic (e09t). These do not depend on and do not block zy7k phases.

---

## 5. Open questions

1. Has the OBS-001 phase 2 bead (Sentry project creation + DSN provisioned in Infisical) been filed? 9ib2 references it in prose but there is no bead ID to dep-link against. File it before 9ib2 can be `br ready`.

2. `LOGIN_ISSUE_SUPPORT_LINK` is already in the plugin at line 99. Has it been verified to surface in `/api/mfe_config/v1` in dev? If yes, jdsx reduces to a one-line close note after PR #1928 verifies SESSION_COOKIE_DOMAIN. Confirm before scheduling an implementor.

3. The strategic-merge patch pattern referenced by 9ib2 (`mereka-platform-admin-emails.yaml`) was not found in the worktree — it lives in bbi-infrastructure. Confirm the correct file path before handing to implementor.
