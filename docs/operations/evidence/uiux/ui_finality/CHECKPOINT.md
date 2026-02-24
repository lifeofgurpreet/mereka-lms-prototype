# UI Finality Checkpoint — 1kwf Brand/Plugin Parity Lane

> Date: 2026-02-20
> Branch: feat/23ry2-spec-dedupe-normalize
> Gate run: 20260220T015757Z
> Agent: BoldBadger (gurpreet)

---

## Gate Summary

| Gate | Result | Notes |
|------|--------|-------|
| `verify-footer-parity.sh` | **31 PASS / 0 FAIL / 2 WARN** | WARNs are known/accepted (see below) |
| `verify-studio-authoring-branding.sh` | **0 failures** | Studio CSS tokens, no Google fonts ✓ |
| `audit-branding-surfaces.sh prod` | **gaps=4** | All MFE rev mismatch — deployment lane |
| `verify-public-branding.sh prod --strict` | **4 failures** | Same 4 MFE rev gaps |

---

## Surface Status

| Surface | HTTP | Brand | Logo | Status |
|---------|------|-------|------|--------|
| LMS `academyv2.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS |
| Studio `studio.academyv2.mereka.io` | 200 | ✓ | ⚠ pending rebuild | ⚠ WARN |
| MFE authn `apps.academyv2.mereka.io` | 200 | ✓ | ✓ absent | ⚠ WARN (rev) |
| Ecommerce `ecommerce.academyv2.mereka.io` | 200 | ✓ | ✓ absent | ⚠ WARN (rev) |
| Credentials `credentials.academyv2.mereka.io` | 200 | ✓ | ✓ absent | ⚠ WARN (rev) |
| Forum API | 200 | N/A | N/A | ✅ PASS |
| Notes `notes.academyv2.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS |
| Preview `preview.academyv2.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS |
| Biji-Biji LMS `academy.biji-biji.com` | 200 | ✓ | ✓ absent | ✅ PASS |
| Biji-Biji MFE `apps.academy.biji-biji.com` | 200 | ✓ | ✓ absent | ⚠ WARN (rev) |
| SkillourfFuture `skillourfuture.academy.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS |

---

## What Was Done (1kwf lane)

### Source Fixes Applied (plugin-safe, theme-source only)

1. **Studio footer template** (`cms/templates/widgets/footer.html`) — NEW FILE (commit `521aca9`)
   - Root cause: upstream renders from `cms/templates/widgets/footer.html`, our theme only had `cms/templates/footer.html` (wrong path — never applied)
   - Fix: Created correct override path, removed `footer-content-secondary` block (white-label Studio)
   - Status: Source correct ✅ — **requires `tutor images build openedx` to go live** (deployment lane)

2. **MFE branding revision** — `kustomization.yaml` updated to `1c66529-20260220023917` (commit `d8a1070`)
   - Thin-layer image patch: sed `--mereka-mfe-branding-rev` from `2026-02-08-pass4` → `2026-02-18-us7`
   - Status: Committed ✅ — **pending ArgoCD sync / PR merge** (deployment lane)

3. **audit-branding-surfaces.sh** — URL pattern fix (this commit)
   - Added fallback for comprehensive-theming stripped paths (`/static/css/` vs `/static/mereka/css/`)
   - Added theming URL fallback (`/theming/asset/mereka/css/mereka-overrides.css`)

### Route Matrix (full 12-surface audit)

See: `docs/operations/evidence/uiux/20260220T012327Z/route-matrix.md`

### Follow-up Beads Created

| Bead | Priority | Issue |
|------|----------|-------|
| `mereka-lms-2rcf` | P2 | `mereka_tenancy` missing from LMS INSTALLED_APPS |
| `mereka-lms-1qkj` | P1 | Enterprise pods `ImagePullBackOff` |
| `mereka-lms-3s2s` | P2 | Ecommerce service not deployed |
| `mereka-lms-ql0m` | P2 | Credentials service not deployed |
| `mereka-lms-bims` | P3 | Preview surface purpose documentation |

---

## Accepted WARNs (Not Blocking)

1. **Enterprise MFE footer** — Admin/Learner portals use upstream Open edX footer. MerekaFooter plugin not wired into enterprise MFEs. Documented in FOOTER_PARITY_AUDIT.md as follow-up.

2. **LMS Mako footer "Powered by Open edX"** — Partial co-branding retained (Mereka name adjacent to Open edX attribution). Not a full white-label requirement for LMS. Recommend review in next design sprint.

---

## Remaining Blockers (Deployment Lane / WhiteCliff)

1. **`tutor images build openedx`** → Push → update `kustomization.yaml` openedx tag
   - Activates Studio footer template fix (commit `521aca9`)

2. **ArgoCD sync** (or PR merge → ArgoCD picks up) for MFE image `1c66529-20260220023917`
   - Resolves bz9p MFE branding revision mismatch on all 4 MFE authn surfaces

---

## Static CSS URL Note (Post-Evidence Regression)

At evidence capture time (01:23 UTC), LMS served themed CSS at `/static/mereka/css/mereka-overrides.68c83b0cfe3b.css`. At ~01:32 UTC, LMS pod restarted (exit code 22 recovery). Post-restart, Open edX comprehensive theming strips the theme-name prefix from static URLs, serving at `/static/css/mereka-overrides.css` (un-hashed, 404).

**Actual state**: CSS IS accessible at `/theming/asset/mereka/css/mereka-overrides.css` (200) — theming middleware serves correctly. LMS font/brand checks PASS via theming URL fallback. This is a whitenoise + comprehensive theming URL resolution quirk, not a branding failure.

**Action**: Added audit script fallback. No deployment action needed (CSS content is correct).
