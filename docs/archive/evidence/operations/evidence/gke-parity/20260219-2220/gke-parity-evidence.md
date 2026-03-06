# GKE Production Parity Evidence

> **Bead**: mereka-lms-3037 (Lane Lock)
> **Date**: 2026-02-19T22:20 UTC
> **Branch**: feat/23ry2-spec-dedupe-normalize
> **Operator**: WhiteCliff

---

## Scope (from OrangeSnow 3037)

1. Admin runtime issue (`403 undefined_license_key`, `405`) — FIXED
2. Studio branding parity — FIXED
3. Dashboard surface parity — VERIFIED
4. Footer parity (Mereka Frontend v2) — VERIFIED/IMPROVED

---

## 1. Admin Runtime Fix

**Root cause**: `enterprise-mfe-env.js` had internal cluster URLs with wrong ports, inaccessible from browser.

| Field | Before | After |
|-------|--------|-------|
| `ENTERPRISE_CATALOG_API_BASE_URL` | `https://academyv2.mereka.io/enterprise/api/v1` (→ 404) | `https://admin.academyv2.mereka.io/api/enterprise-catalog` |
| `ENTERPRISE_ACCESS_BASE_URL` | `http://enterprise-access:8000` (internal, wrong port 8000 vs 18270) | `https://admin.academyv2.mereka.io/api/enterprise-access` |
| `LICENSE_MANAGER_URL` | `http://license-manager:8000` (internal, wrong port 8000 vs 18170) | `https://admin.academyv2.mereka.io/api/license-manager` |
| `ENTERPRISE_SUBSIDY_BASE_URL` | `http://enterprise-subsidy:8000` (internal, wrong port 8000 vs 18280) | `https://admin.academyv2.mereka.io/api/enterprise-subsidy` |

**Caddy routes added** to `deploy/k8s/base/apps/caddy/Caddyfile` (admin.academyv2.mereka.io block):
- `/api/enterprise-catalog/*` → `enterprise-catalog:8160` (strip prefix)
- `/api/enterprise-access/*` → `enterprise-access:18270` (strip prefix)
- `/api/license-manager/*` → `license-manager:18170` (strip prefix)
- `/api/enterprise-subsidy/*` → `enterprise-subsidy:18280` (strip prefix)

Same-origin routing (admin subdomain) → no CORS complications.

**Files changed**:
- `deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js`
- `deploy/k8s/base/apps/caddy/Caddyfile`

---

## 2. Studio Branding Parity

**Root cause**: Studio (CMS) served default Open edX footer with `edX Inc.` trademark text
and external `https://logos.openedx.org/open-edx-logo-tag.png` CDN image.

**Fix**: Created `infrastructure/tutor/themes/mereka/cms/templates/footer.html`
with a minimal Mereka-branded footer:
- Copyright `© YYYY Mereka Academy` (no edX trademark text)
- Links: LMS + support@mereka.io
- No external CDN references

**Footer parity before/after**:

- Before: 25 PASS / 0 FAIL / 3 WARN (CMS footer absent WARN present)
- After: 28 PASS / 0 FAIL / 2 WARN (CMS footer WARN resolved)

Studio authoring branding: **failures=0** (all CTA selectors, no Google fonts)

---

## 3. Dashboard Surface Parity

**Unauthenticated behaviour**: `/dashboard` → 302 → authn MFE (expected)
- Authn MFE shell served correctly (200, authn bundle present)
- No Google fonts in authn shell CSS
- MFE config branding fields present

**Post-login experience (from source)**: LMS dashboard uses mereka theme:
- `mereka-overrides.css` loaded via `lms/templates/head-extra.html`
- Contains `--mereka-color-teal`, Poppins/Lato fonts, branding-rev marker
- LMS footer shows Mereka Academy branding (no Google fonts)
- Deep branding audit: PASS

---

## 4. Footer Parity (Mereka Frontend v2)

Footer parity verification: **28 PASS / 0 FAIL / 2 WARN**

Remaining WARNs (documented, non-blocking):
- Enterprise MFE portals use Open edX default footer (recommendation #4, deferred)
- LMS Mako footer has "Powered by Open edX" with Mereka name nearby (partial co-branding, deferred)

Policy compliance: footer slot-only: **15 PASS / 0 FAIL / 1 WARN**

---

## Route Matrix — 10/10 PASS

| Result | Code | Surface | URL |
|--------|------|---------|-----|
| PASS | 200 | academy | https://academyv2.mereka.io/ |
| PASS | 200 | admin | https://admin.academyv2.mereka.io/ |
| PASS | 200 | studio | https://studio.academyv2.mereka.io/ |
| PASS | 200 | authn | https://apps.academyv2.mereka.io/authn/login |
| PASS | 200 | ecommerce | https://ecommerce.academyv2.mereka.io/dashboard/ |
| PASS | 200 | credentials | https://credentials.academyv2.mereka.io/admin/login/ |
| PASS | 200 | skillourfuture | https://skillourfuture.academy.mereka.io/ |
| PASS | 200 | biji-biji | https://academy.biji-biji.com/ |
| PASS | 200 | preview | https://preview.academyv2.mereka.io/ |
| PASS | 200 | forum | https://forum.academyv2.mereka.io/heartbeat |

10 PASS / 0 WARN / 0 FAIL

---

## Branding Gates Summary

| Gate | Exit | Notes |
|------|------|-------|
| `run-branding-gates.sh prod` (deep) | **0** | All checks pass |
| `verify-studio-authoring-branding.sh prod` | **0** | failures=0 |
| `verify-footer-parity.sh` | **0** | 28 PASS / 0 FAIL / 2 WARN |
| Audit surface | **0** | gaps=4 strict=0 (MFE revision only, bz9p) |

Remaining 4 gaps: MFE authn CSS revision `2026-02-08-pass4` vs source `2026-02-18-us7`
(all require MFE image rebuild — tracked as bz9p)

---

## Evidence Files

```
docs/archive/evidence/operations/evidence/gke-parity/20260219-2220/
├── gke-parity-evidence.md          (this file)
├── route-matrix.txt                 (10-surface route check)
├── branding-gates-deep.log          (EXIT 0)
├── footer-parity.log                (EXIT 0, 28 PASS / 0 FAIL / 2 WARN)
└── studio-branding.log              (EXIT 0, failures=0)
```
