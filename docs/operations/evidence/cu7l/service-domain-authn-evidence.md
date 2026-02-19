# Service-Domain Authn Routing Evidence — cu7l

> **Bead**: mereka-lms-cu7l (AC-SRV-001..005)
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize
> **Operator**: WhiteCliff

---

## Summary

| AC | Result | Notes |
|----|--------|-------|
| AC-SRV-001 | **PASS** | ecommerce /dashboard returns 200 (authn shell) |
| AC-SRV-002 | **PASS** | ecommerce /dashboard/ follows to authn MFE shell (`<div id="root"></div>`) |
| AC-SRV-003 | **PASS** | credentials /admin/login follows to authn MFE shell |
| AC-SRV-004 | **PASS** | credentials /admin/login/ same result |
| AC-SRV-005 | **PASS** | `BRANDING_LEVEL=deep` gates exit 0, all live checks pass |

**Overall: PASS** — All service-domain authn routes live and serving correct shell.

---

## Route Verification

### 1. `curl -I https://ecommerce.academyv2.mereka.io/dashboard`

```
HTTP/2 200
date: Thu, 19 Feb 2026 11:11:46 GMT
strict-transport-security: max-age=31536000; includeSubDomains
```

### 2. `curl -L https://ecommerce.academyv2.mereka.io/dashboard/`

```html
<!doctype html><html lang="en-us"><head><title>Authentication</title>...
<script defer="defer" src="/authn/app.6791ecf5ea742745ea64.js"></script>
<link href="/authn/app.6791ecf5ea742745ea64.css" rel="stylesheet">
...
<body><div id="root"></div>...</body></html>
```

**✓ `<div id="root"></div>` present** — authn shell confirmed

### 3. `curl -L https://credentials.academyv2.mereka.io/admin/login`

```html
<!doctype html><html lang="en-us"><head><title>Authentication</title>...
<script defer="defer" src="/authn/app.6791ecf5ea742745ea64.js"></script>
<link href="/authn/app.6791ecf5ea742745ea64.css" rel="stylesheet">
...
<body><div id="root"></div>...</body></html>
```

**✓ `<div id="root"></div>` present** — authn shell confirmed

### 4. `curl -L https://credentials.academyv2.mereka.io/admin/login/`

Same output as above — authn shell with `/authn/app.*` assets.

**✓ `<div id="root"></div>` present**

---

## Branding Gates (`BRANDING_LEVEL=deep`)

```
==> Branding gates completed.
EXIT: 0
```

All live route checks pass:
```
✓ Ecommerce root landing is branded
✓ Ecommerce dashboard reachable (200)
✓ Ecommerce dashboard uses authn shell
✓ Ecommerce dashboard authn CSS includes Mereka branding markers (revision differs from local source)
✓ Credentials root landing is branded
✓ Credentials admin login reachable (200)
✓ Credentials admin login uses authn shell
✓ Credentials admin login authn CSS includes Mereka branding markers (revision differs from local source)
```

Note: "revision differs from local source" = controlled gap documented in 2qpt evidence. The MFE
branding markers (gradient, font, etc.) ARE present — the only delta is the revision tag itself.

---

## GitOps Path

Changes deployed via ArgoCD tracking `bbi-infrastructure` at ref `8c21077`:

| Change | Commit |
|--------|--------|
| Caddyfile `/dashboard` + `/dashboard/*` routes for ecommerce authn shell | `07bd676` (mereka-lms) |
| Caddyfile `/admin/login` + `/admin/login/*` routes for credentials authn shell | `07bd676` (mereka-lms) |
| bbi-infrastructure base ref bumped from `648c34ae` → `8c21077` | `9c79361` (bbi-infrastructure) |

No local patch-only changes — all configuration is in GitOps-tracked manifests.

---

## MFE Revision Exception (AC-SRV-004)

`STRICT_MFE_BRANDING_REV=1` would show 4 failures because:
- Deployed MFE CSS: revision `2026-02-08-pass4` (image `b732a7d-20260210161437`, built 2026-02-10)
- Source `mereka.scss`: revision `2026-02-18-us7` (bumped 2026-02-18)

This is a build-time image gap, not a routing or config error. Full analysis in:
`docs/operations/evidence/2qpt/mfe-revision-parity-evidence.md`

Resolution: rebuild MFE image. Non-blocking for cu7l acceptance (branding markers ARE present,
routes ARE serving authn shell correctly).
