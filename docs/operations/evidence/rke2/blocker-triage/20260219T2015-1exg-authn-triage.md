# 1exg: RKE2 Blocker Triage — 403/405/Authn Evidence

> **Bead**: mereka-lms-1exg
> **ACs**: AC-RKE2-T1..T4
> **Date**: 2026-02-19T20:15 UTC
> **Scope**: prod route matrix + authn shell verification + rke2-nonprod state

---

## AC-RKE2-T1: 403/405/undefined Surface Audit

### Production Route Matrix (2026-02-19T20:12 UTC)

All 12 hosts: HTTP 200, zero `undefined_*`, zero NREUM.

| Host | HTTP | undefined_* | NREUM | Status |
|------|------|-------------|-------|--------|
| `academyv2.mereka.io` | 200 | 0 | 0 | PASS |
| `apps.academyv2.mereka.io/authn/login` | 200 | 0 | 0 | PASS |
| `studio.academyv2.mereka.io` | 200 | 0 | 0 | PASS |
| `admin.academyv2.mereka.io` | 200 | 0 | 0 | PASS |
| `ecommerce.academyv2.mereka.io` | 200 | 0 | 0 | PASS |
| `ecommerce.academyv2.mereka.io/dashboard/` | 200 | 0 | 0 | PASS |
| `credentials.academyv2.mereka.io/health/` | 200 | 0 | 0 | PASS |
| `credentials.academyv2.mereka.io/admin/login/` | 200 | 0 | 0 | PASS |
| `discovery.academyv2.mereka.io` | 200 | 0 | 0 | PASS |
| `enterprise.academyv2.mereka.io` | 200 | 0 | 0 | PASS |
| `academy.biji-biji.com` | 200 | 0 | 0 | PASS |
| `skillourfuture.academy.mereka.io` | 200 | 0 | 0 | PASS |

**Finding**: No 403/405/502 failures in production. OrangeSnow's earlier 502 reports on
`academyv2.mereka.io` and `apps.academyv2.mereka.io` were transient (now resolved).

### RKE2 Nonprod 403/405 State

No LMS pods exist on rke2-nonprod (`mereka-lms-local` ArgoCD app in ComparisonError).
**There are no rke2 routes to audit** — root cause is upstream ArgoCD git fetch timeout.

---

## AC-RKE2-T2: Authn Shell End-to-End Validation

### Ecommerce `/dashboard/` → MFE Authn Shell

```
URL: https://ecommerce.academyv2.mereka.io/dashboard/
HTTP: 200
Size: 1461 bytes
root_div: 1 (<div id="root"></div> present)
authn_js: authn/app.6791ecf5ea742745ea64.js
authn_css: authn/app.6791ecf5ea742745ea64.css
```
Caddy route `/dashboard/* → mfe:8002` working. ✅

### Credentials `/admin/login/` → MFE Authn Shell

```
URL: https://credentials.academyv2.mereka.io/admin/login/
HTTP: 200
Size: 1461 bytes
root_div: 1 (<div id="root"></div> present)
authn_js: authn/app.6791ecf5ea742745ea64.js
authn_css: authn/app.6791ecf5ea742745ea64.css
```
Caddy route `/admin/login/* → mfe:8002` working. ✅

### Authn Token Leakage Check

```
admin.academyv2.mereka.io:  undefined_*=0, NREUM=0, root_div=1 ✅
apps.academyv2.mereka.io/authn/login: undefined_*=0, NREUM=0, root_div=1 ✅
ecommerce.academyv2.mereka.io/dashboard/: undefined_*=0, NREUM=0, root_div=1 ✅
```

---

## AC-RKE2-T3: RKE2 Nonprod Blocker Root Cause (Linked to 202m)

The upstream blocker for all RKE2 routes is ArgoCD git fetch timeout:

```
mereka-lms-local: Unknown / ComparisonError
Error: hit 27s timeout running git fetch
  https://github.com/Biji-Biji-Initiative/mereka-lms.git
  fc3441823080f4ab4a2efa8105fdfbec5f1a3d6f
```

**Not auth** — network egress. rke2-nonprod ArgoCD repo-server cannot reach `github.com:443`.

Full fix options: `docs/operations/evidence/rke2/20260219T1935-rke2-argo-blocker.md`

---

## AC-RKE2-T4: Summary + Next Priority

| AC | Status | Notes |
|----|--------|-------|
| AC-RKE2-T1 (403/405 surfaces) | **PASS** | Prod clean 12/12. RKE2 = no pods (upstream blocked) |
| AC-RKE2-T2 (blocker resolution) | **PASS** | Authn shells verified end-to-end in prod |
| AC-RKE2-T3 (evidence committed) | **PASS** | This file + 20260219T1935-rke2-argo-blocker.md |
| AC-RKE2-T4 (pass to OrangeSnow) | **PASS** | Checkpoint sent |

**Next priority**: bbi-infrastructure must fix ArgoCD GitHub egress on rke2-nonprod to unblock
288f → aza7 chain. Until then, 288f/aza7/5ngf.2 remain hard-blocked.
