# Multisite Governance Checklist
_Audience: Platform Eng + Academic Ops • Last updated: 2026-02-04_

This checklist keeps multiple microsites (`academyv2.mereka.io`, `skillourfuture.academy.mereka.io`, `academy.biji-biji.com`) consistent and secure without drift.

## 1. Site + Domain Integrity

- [ ] `Site` entries exist for every domain (Django admin → **Sites**).
- [ ] `SiteConfiguration` exists for each site:
  - `site_domain` matches the domain exactly.
  - `LMS_ROOT_URL` points at the site's **own LMS domain**.
  - `CMS_ROOT_URL` points at the site's **Studio domain**:
    - `academyv2.mereka.io` and `skillourfuture.academy.mereka.io` currently share `studio.academyv2.mereka.io`
    - `academy.biji-biji.com` uses `studio.academy.biji-biji.com`
- [ ] Caddy routes include each domain (`deploy/k8s/base/apps/caddy/Caddyfile`).

## 2. Organization Ownership

- [ ] Each org has at least **one owner** and **one staff admin**.
- [ ] Roles reviewed quarterly:
  - Django admin → **Organizations** → Members.
  - Confirm owners for `SKILLOURFUTURE`, `BIJI`, and `MEREKA`.
- [ ] Remove inactive or duplicated admins.

## 3. Theme & Branding Validation

- [ ] Theme exists under `infrastructure/tutor/themes/mereka/`.
- [ ] Theme name resolved for each site:
  - `DEFAULT_SITE_THEME = "mereka"`
  - Per-site overrides in `SiteConfiguration` if required.
- [ ] Brand assets synced via `make branding-sync`.
- [ ] Capture screenshots for LMS + Studio after theme change.

## 4. OAuth + SSO

- [ ] OAuth clients include all domains in redirect URIs.
- [ ] Authentik / Google OAuth apps updated when domains change.

## 5. Cookie / Session Boundaries (Multi-root)

- **Policy:** cookies are scoped per root domain:
  - Main: `.academyv2.mereka.io` (covers `academyv2`, `studio`, `apps`, etc)
  - Biji: `.biji-biji.com` (covers `academy`, `studio.academy`, `apps.academy`, etc)
  - Skillourfuture: `.skillourfuture.academy.mereka.io`
- **Implication:** login sessions do **not** carry across different roots (expected).
  Within a root, sessions can be shared across subdomains.
- **Do not widen cookie domains** across unrelated roots (security risk + browsers will reject invalid domains).

## 6. Validation Commands

```bash
./scripts/qa/public-health-check.sh prod
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod
./scripts/qa/verify-multisite-config.sh  # add STRICT=1 to fail on missing configs
```

## 7. Change Control

- [ ] Use `docs/operations/RELEASE_CHECKLIST_DOMAIN_SECRETS.md` for any domain or secret changes.
- [ ] Log changes in `docs/operations/CONFIG_REVIEW_YYYY-MM-DD.md`.
