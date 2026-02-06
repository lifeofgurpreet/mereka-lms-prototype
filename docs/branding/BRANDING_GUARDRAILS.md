# Branding Guardrails (Source Of Truth)
_Audience: Platform Eng + Product Eng • Last updated: 2026-02-06_

This doc exists to make branding changes predictable and low-drama.

## The 3 Sources Of Truth

1. Canonical design-system tokens:
   - `assets/branding/tokens.css` (vendored from `bbbi-mereka-brand-assets`)
2. Runtime legacy theme delivery (LMS/Studio):
   - `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css`
   - This is what the HTML loads via `*/templates/head-extra.html`
3. Runtime MFE delivery (Paragon):
   - `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
   - Requires rebuilding the MFE image to go live

## What We Verify (Before Deploy)

Run from repo root:

```bash
# Strictest, preferred gate
BRANDING_LEVEL=deep ./scripts/branding/verify-branding-health.sh
```

What this enforces:
- Logos/favicons/fonts exist and are wired correctly
- The runtime override CSS carries deep branded selectors (course cards, courseware, Studio wrapper)
- Tokens drift is caught (`assets/branding/tokens.css` matches runtime exports)

## What We Verify (After Deploy, Live)

```bash
CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod
./scripts/qa/capture-branding-screenshots.sh prod
```

Notes:
- `verify-public-branding.sh` checks the main domain plus the client microsites (`academy.biji-biji.com`,
  `skillourfuture.academy.mereka.io`).
- If `BRANDING_LEVEL=deep` fails live but passes locally, production is running an older `openedx` image.

## Most Common Failure Modes

1. Deep branding looks absent on production
   - Cause: cluster is still running an older `openedx` image and hasn’t picked up the new override CSS.
   - Fix: rebuild + deploy `openedx` image and rerun `BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod`.

2. MFE pages look unbranded even when LMS is perfect
   - Cause: MFE styling is baked into the MFE image; CSS changes in `mfe/mereka.scss` don’t apply until rebuild.
   - Fix: rebuild + deploy the MFE image.

3. “Worked right after deploy, broken later”
   - Cause: cached HTML references old hashed assets, or a partial rollout.
   - Fix: rerun `verify-public-branding.sh` (it busts cache on homepage fetch). If real users are impacted,
     purge CDN cache for `/` and retry.

## Deployment Reference

Use `docs/operations/THEME_DEPLOYMENT.md` as the canonical deployment runbook.

