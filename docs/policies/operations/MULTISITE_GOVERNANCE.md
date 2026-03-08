# Multisite Governance Checklist
_Audience: Platform Eng + Academic Ops • Last updated: 2026-02-07_

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

- [ ] Each org has at least **one instructor** and **one staff admin**.
- [ ] Platform admins (`gurpreet@biji-biji.com`, `malasari@mereka.my`) should hold both org roles for all tenant orgs.
- [ ] Run deterministic verifier instead of manual spot checks:
  - `STRICT=1 ./scripts/qa/verify-org-role-ownership.sh both`
- [ ] Remove inactive or duplicated role assignments during quarterly review.

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
CHECK_TIMEOUT_SECONDS=900 ./scripts/qa/run-multisite-governance-gates.sh --env both
STRICT=1 ./scripts/qa/verify-multisite-config.sh prod
STRICT=1 ./scripts/qa/verify-multisite-config.sh dev
STRICT=1 ./scripts/qa/verify-org-role-ownership.sh both
./scripts/qa/audit-auth-access.sh --mode internal --env both
```

Canonical gate:
- `run-multisite-governance-gates.sh` is the preferred one-command audit for multisite governance.
- It runs per-environment multisite config checks, org role ownership checks, auth surface checks, and hostname registry drift checks with timeout-safe per-check logs under `var/multisite-governance-gates/`.

`verify-multisite-config.sh` enforces per-site:
- `SiteConfiguration.enabled=true`
- `LMS_ROOT_URL`, `CMS_ROOT_URL`, `MFE_BASE_URL`
- `THEME_NAME`
- `course_org_filter`
- duplicate `SiteConfiguration` row detection (drift guard)

`verify-org-role-ownership.sh` enforces per-org:
- org exists (`MEREKA`, `BIJIBIJI`, `SKILLOURFUTURE`)
- at least one `OrgStaffRole` user
- at least one `OrgInstructorRole` user
- platform admins hold both roles in each org

## 7. Change Control

- [ ] Use `docs/runbooks/operations/RELEASE_CHECKLIST_DOMAIN_SECRETS.md` for any domain or secret changes.
- [ ] Log changes in `reports/2026/audits/CONFIG_REVIEW_2026-02-03.md`.
