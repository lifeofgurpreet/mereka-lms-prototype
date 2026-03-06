# Multisite UX Audit Report

**Assessment Date**: 2026-02-17
**Scope**: 3 production domains (academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io)
**Overall Status**: Infrastructure GREEN, Runtime AMBER (feature flag not yet enabled)
**Assessor**: Platform Engineering (mereka-lms-1rda.1)

---

## Executive Summary

This report documents the multisite UX audit for Mereka LMS production deployment across 3 root domains. The infrastructure foundation for multi-tenant branding is **complete and verified**, but runtime activation is blocked by `ENABLE_MULTI_TENANT_BRANDING=False`. The audit identified **10 findings** across 4 categories, with **3 quick wins** that can be completed in <4 hours combined.

### Key Findings

- **Infrastructure**: ✅ All architectural components in place (models, middleware, ConfigMap)
- **Code Audit**: ⚠️ 3 hardcoded domain references (tracked, medium risk)
- **Runtime Verification**: ⚠️ Feature flag disabled, 2/3 domains show SITE_NAME mismatches
- **Verification Coverage**: ✅ 15 verification scripts, comprehensive coverage

### Current State

| Dimension | Status | Blocker Count |
|-----------|--------|---------------|
| **Architecture Readiness** | 🟢 GREEN | 0 |
| **Runtime Activation** | 🟡 AMBER | 3 |
| **Verification Coverage** | 🟢 GREEN | 0 |
| **Operator Workflow** | 🟡 AMBER | 2 |
| **Scale Readiness (5-10 tenants)** | 🟡 AMBER | 4 |

**Total Blockers**: 9 (3 HIGH, 6 MEDIUM)
**Estimated Time to GREEN**: 2-3 days

### Verification Results

| Script | PASS | FAIL | WARN | SKIP |
|--------|------|------|------|------|
| `verify-multisite-ux-consistency.sh` | 15 | 1 | 4 | 0 |
| `verify-tenant-branding-runtime.sh --env prod` | 6 | 0 | 5 | 0 |
| `verify-mfe-branding.sh --env prod` | 56 | 1 | 0 | 1 |
| **TOTALS** | **77** | **2** | **9** | **1** |

---

## Severity-Ranked Findings Matrix

### Critical (Blocks Activation)

None. All critical findings are either fixed or tracked as MEDIUM (workarounds exist).

### High (Blocks Runtime Correctness)

| ID | Severity | Category | Description | Affected Domains | Current State | Owner | Effort | Related AC |
|----|----------|----------|-------------|------------------|---------------|-------|--------|------------|
| **F-005** | High | Missing Config | `ENABLE_MULTI_TENANT_BRANDING=False` blocks runtime branding | All | Open (feature flag disabled) | Platform Eng | 1h (config + restart) | AC-TBR-101 |
| **F-007** | High | Functional Gap | admin.academyv2.mereka.io returns HTTP 400 (enterprise portal routing) | academyv2.mereka.io | **PARTIAL** (ALLOWED_HOSTS fixed, provisioning pending) | Platform Eng | 2h (tenant provision) | AC-ENT-SSO-001 |
| **F-008** | High | Missing Config | Placeholder UUIDs in tenant code block activation | All | Open (needs real tenant UUIDs) | Platform Eng | 1h (search/replace + test) | AC-TBR-103 |

### Medium (UX Degradation)

| ID | Severity | Category | Description | Affected Domains | Current State | Owner | Effort | Related AC |
|----|----------|----------|-------------|------------------|---------------|-------|--------|------------|
| **F-001** | Medium | Hardcoded Domain | `DISCUSSIONS_MICROFRONTEND_URL` hardcoded to apps.academyv2.mereka.io | academy.biji-biji.com, skillourfuture | **FIXED** (PR #35) | Frontend | 30min (dynamic URL) | AC-MSUX-002 |
| **F-002** | Medium | Hardcoded Domain | Nginx `proxy_set_header Host academyv2.mereka.io` breaks SiteConfiguration | academy.biji-biji.com, skillourfuture | **FIXED** (PR #35) | Platform Eng | 30min (use `$http_host`) | AC-MSUX-002 |
| **F-006** | Medium | Visual Inconsistency | No brand color tokens (`--mereka-color-*`) in MFE config API | All | **FIXED** (PR #36) | Frontend | 2h (add tokens to MFE_CONFIG) | AC-UI-002 |
| **F-010** | Medium | Ops Workflow | Zero-downtime brand-pack update workflow undocumented | All | Tracked | Platform Eng | 4h (test + document) | AC-TBR-005 |

### Low (Edge Cases)

| ID | Severity | Category | Description | Affected Domains | Current State | Owner | Effort | Related AC |
|----|----------|----------|-------------|------------------|---------------|-------|--------|------------|
| **F-004** | Low | Fixed/Pass | Session/CSRF cookies are host-only (multi-site compatible) | All | **FIXED** | - | - | AC-MSUX-002 |
| **F-009** | Low | Missing Config | Footer SITE_VARIANTS only has 3 domains, no wildcard/fallback | Future tenants | **FIXED** (PR #35) | Frontend | 1h (add fallback logic) | AC-TBR-103 |

---

## Detailed Findings

### F-001: DISCUSSIONS_MICROFRONTEND_URL Hardcoded (Medium)

**File**: `infrastructure/tutor/plugins/mereka_lms.py:79`

**Current Code**:
```python
DISCUSSIONS_MICROFRONTEND_URL = "https://apps.academyv2.mereka.io/discussions"
```

**Impact**: Users on `academy.biji-biji.com` get redirected to `apps.academyv2.mereka.io/discussions`, breaking domain consistency.

**Fix** (30min):
```python
# Line 79 — Use dynamic MFE base URL
if "DISCUSSIONS_MICROFRONTEND_URL" not in globals():
    DISCUSSIONS_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/discussions"
```

**Verification**:
```bash
./scripts/qa/verify-multisite-ux-consistency.sh | grep DISCUSSIONS_MICROFRONTEND_URL
# Expected: PASS
```

**Related AC**: AC-MSUX-002 (Verifier detects hardcoded domain references)

---

### F-002: Nginx Proxy Host Header Hardcoded (Medium)

**File**: `infrastructure/tutor/plugins/mereka_lms.py:862`

**Current Code**:
```nginx
proxy_set_header Host academyv2.mereka.io;
```

**Impact**: LMS always sees `Host: academyv2.mereka.io`, breaking SiteConfiguration resolution for alternative domains.

**Fix** (30min):
```nginx
proxy_set_header Host $http_host;  # Preserve original Host header
```

**Verification**:
```bash
./scripts/qa/verify-multisite-ux-consistency.sh | grep -A 2 "proxy_set_header"
# Expected: PASS (not hardcoded)
```

**Related AC**: AC-MSUX-002

---

### F-003: MFE_CONFIG Uses Dynamic MEREKA_*_BASE_URL Variables (Fixed)

**File**: `deploy/k8s/base/apps/openedx/settings/lms/production.py:661-689`

**Status**: ✅ **FIXED** — MFE_CONFIG uses dynamic variables:
```python
MFE_CONFIG = {
    "BASE_URL": MEREKA_MFE_DOMAIN,
    "LMS_BASE_URL": MEREKA_LMS_BASE_URL,  # Resolved per-request
    "LOGO_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/{DEFAULT_SITE_THEME}/images/logo.png",
}
```

**Verification**: `verify-multisite-ux-consistency.sh` reports **PASS** for this check.

---

### F-004: Session/CSRF Cookies Are Host-Only (Fixed)

**File**: `deploy/k8s/base/apps/openedx/settings/lms/production.py:649-650`

**Status**: ✅ **FIXED**:
```python
SESSION_COOKIE_DOMAIN = None  # Host-only
CSRF_COOKIE_DOMAIN = None     # Host-only
```

**Verification**: `verify-multisite-ux-consistency.sh` reports **PASS**.

---

### F-005: ENABLE_MULTI_TENANT_BRANDING=False (High)

**File**: `tutor_env/config.yml`

**Current State**: Feature flag disabled in production.

**Impact**: Multi-tenant branding runtime is not active — all checks in `verify-tenant-branding-runtime.sh` would SKIP.

**Fix** (1 hour):
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set ENABLE_MULTI_TENANT_BRANDING=True
./infrastructure/tutor/apply-patches.sh
tutor k8s restart
```

**Verification**:
```bash
./scripts/qa/verify-tenant-branding-runtime.sh --env prod
# Expected: PASS (6 pass, 0 skip)
```

**Related AC**: AC-TBR-101, AC-TBR-102, AC-TBR-103

---

### F-006: No Brand Color Tokens in MFE Config API (Medium)

**Symptom**: Runtime verifier reports:
```
[WARN] AC-TBR-102: No brand color tokens (--mereka-color-*) found for academyv2.mereka.io
```

**Root Cause**: MFE config API (`/api/mfe_config/v1`) doesn't include CSS custom properties. Tokens are in `tokens.css` at build time, not runtime.

**Impact**: Visual inconsistency if tenants expect runtime color token injection.

**Fix** (2 hours):
1. Add brand color tokens to `MFE_CONFIG` in `production.py`:
   ```python
   MFE_CONFIG = {
       # ... existing config
       "BRAND_PRIMARY": "#2d898b",
       "BRAND_SECONDARY": "#f05a28",
       # ... other tokens
   }
   ```
2. Update MFE to read tokens from config API.

**Verification**:
```bash
curl -s https://academyv2.mereka.io/api/mfe_config/v1 | grep BRAND_PRIMARY
# Expected: "BRAND_PRIMARY": "#2d898b"
```

**Related AC**: AC-UI-002 (Branding system spec)

---

### F-007: admin.academyv2.mereka.io Returns HTTP 400 (High)

**Symptom**: `curl -I https://admin.academyv2.mereka.io` returns HTTP 400 (Bad Request).

**Curl Evidence** (2026-02-17):
```
$ curl -sI https://admin.academyv2.mereka.io
HTTP/2 400
```
Django returns 400 when the `Host` header is not in `ALLOWED_HOSTS`.

**Root Cause**: The hostname `admin.academyv2.mereka.io` is present in Caddy routing (`deploy/k8s/base/apps/caddy/Caddyfile:220`) but is **NOT** in:
- `deploy/k8s/base/apps/openedx/settings/lms/production.py` `ALLOWED_HOSTS`
- `infrastructure/tutor/plugins/mereka_lms.py` `MEREKA_LMS_EXTRA_HOSTS`

Caddy forwards the request to the LMS pod, but Django rejects it because `admin.academyv2.mereka.io` is not an allowed host.

**Impact**: Enterprise admin portal inaccessible. Not a security risk (Django safely rejects unknown hosts).

**Fix** (30 min):
1. Add `admin.academyv2.mereka.io` to `ALLOWED_HOSTS` in production.py or via `MEREKA_LMS_EXTRA_HOSTS` env var
2. Rebuild/restart LMS: `tutor k8s restart lms`

**Verification**:
```bash
curl -sI https://admin.academyv2.mereka.io | head -1
# Expected: HTTP/2 200 (or 302 redirect to login)
```

**Related AC**: AC-ENT-SSO-001

---

### F-008: Placeholder UUIDs in Code (High)

**File**: Multiple files in `infrastructure/tutor/custom-apps/`

**Symptom**: Hardcoded test UUIDs cause runtime errors when activated.

**Impact**: Feature flag activation will fail.

**Fix** (1 hour):
1. Get real tenant UUIDs from database:
   ```bash
   kubectl exec -n mereka-lms -it deploy/lms -- \
     python manage.py shell -c "from openedx_tenant_cache.models import TenantSiteMapping; \
     for t in TenantSiteMapping.objects.all(): print(f'{t.domain}: {t.enterprise_customer_uuid}')"
   ```
2. Replace placeholder UUIDs in code:
   ```bash
   grep -r "00000000-0000-0000-0000-000000000000" infrastructure/tutor/
   # Update with real UUIDs
   ```

**Verification**:
```bash
grep -r "00000000-0000-0000-0000-000000000000" infrastructure/tutor/
# Expected: 0 matches
```

**Related AC**: AC-TBR-103

---

### F-009: Footer SITE_VARIANTS Missing Wildcard/Fallback (Low)

**File**: `infrastructure/tutor/plugins/mereka_lms.py:664-668`

**Current Code**:
```javascript
const SITE_VARIANTS = {
  'academyv2.mereka.io': { brand: 'Mereka Academy', ... },
  'academy.biji-biji.com': { brand: 'Biji-Biji Academy', ... },
  'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', ... },
};
const variant = SITE_VARIANTS[hostname] || { brand: siteName, copyrightHolder: 'MEREKA', ... };
```

**Impact**: Future tenant domains not in SITE_VARIANTS will fall back to default MEREKA branding.

**Fix** (1 hour):
```javascript
// Fallback logic with better defaults
const variant = SITE_VARIANTS[hostname] || {
  brand: config.SITE_NAME || 'Mereka Academy',
  copyrightHolder: config.PLATFORM_NAME || 'MEREKA',
  whatsapp: config.WHATSAPP_NUMBER || '601135271981',
};
```

**Verification**:
```bash
./scripts/qa/verify-tenant-branding-runtime.sh --env prod --target https://newdomain.mereka.io
# Expected: Footer renders with SITE_NAME from config
```

**Related AC**: AC-TBR-103

---

### F-010: Zero-Downtime Brand-Pack Workflow Undocumented (Medium)

**Symptom**: Operators don't have clear instructions for adding/updating tenant branding assets without downtime.

**Impact**: Risk of image rebuilds or service restarts during tenant provisioning.

**Fix** (4 hours):
1. Test workflow:
   - Upload logo to `infrastructure/tutor/themes/mereka/tenants/<slug>/assets/logo.png`
   - Run `./scripts/branding/sync-branding.sh`
   - Update `TenantSiteConfiguration.logo_url` in database
   - Flush Redis cache
   - Verify change propagates without restart
2. Document in `docs/operations/TENANT_PROVISIONING.md` or create separate runbook.

**Verification**:
```bash
# After workflow execution:
./scripts/branding/run-branding-gates.sh prod
# Expected: All gates PASS
```

**Related AC**: AC-TBR-005

---

## Quick-Win Matrix (Top 10)

Ranked by: **low risk + high impact + small effort**

| Rank | ID | Description | Effort | Risk | Impact | Blocking Dependencies | Verification |
|------|----|-----------|----|------|--------|---------------------|--------------|
| **1** | F-002 | Fix Nginx Host header (use `$http_host`) | 30min | Low | High | None | `verify-multisite-ux-consistency.sh` |
| **2** | F-001 | Use dynamic DISCUSSIONS_MICROFRONTEND_URL | 30min | Low | Medium | None | `verify-multisite-ux-consistency.sh` |
| **3** | F-008 | Replace placeholder UUIDs with real tenant UUIDs | 1h | Low | High | F-007 (provision tenant first) | `grep -r "00000000-0000-0000-0000-000000000000"` |
| **4** | F-005 | Enable ENABLE_MULTI_TENANT_BRANDING=True | 1h | Medium | High | F-007, F-008 | `verify-tenant-branding-runtime.sh --env prod` |
| **5** | F-009 | Add footer fallback logic for new tenants | 1h | Low | Low | None | `verify-tenant-branding-runtime.sh --target https://newdomain.mereka.io` |
| **6** | F-007 | Provision Mereka Academy tenant | 2h | Medium | High | None | `verify-tenant-isolation.sh` |
| **7** | F-006 | Add brand color tokens to MFE_CONFIG | 2h | Medium | Medium | None | `curl -s .../api/mfe_config/v1 \| grep BRAND_PRIMARY` |
| **8** | F-010 | Document zero-downtime brand-pack workflow | 4h | Low | Medium | F-007 (test with real tenant) | `docs/operations/TENANT_PROVISIONING.md` |
| 9 | - | Run full branding gates post-activation | 30min | Low | High | F-004, F-005 | `./scripts/branding/run-branding-gates.sh prod` |
| 10 | - | Load test with 3 tenants (100 concurrent users) | 1d | Medium | High | F-007 (2+ tenants) | Performance metrics |

**Recommended Sprint 1** (First 5 quick wins):
- **Total Effort**: 5 hours
- **Total Risk**: Low-Medium
- **Total Impact**: High
- **Blockers**: F-007 must complete before F-003, F-004

---

## Verification Commands

### Pre-Activation Checks
```bash
# 1. Check Tutor config (before activation)
export TUTOR_ROOT="$(pwd)/tutor_env"
grep ENABLE_MULTI_TENANT_BRANDING tutor_env/config.yml
# Expected: ENABLE_MULTI_TENANT_BRANDING: false

# 2. Verify infrastructure readiness
./scripts/qa/verify-tenant-model.sh
./scripts/qa/verify-tenant-middleware.sh
./scripts/qa/verify-tenant-configmap.sh
# Expected: All PASS

# 3. Check multisite UX consistency (code audit)
./scripts/qa/verify-multisite-ux-consistency.sh
# Expected: 15 PASS, 1 FAIL, 4 WARN
```

### Post-Activation Checks
```bash
# 4. Enable feature flag
./scripts/infra/tutor-config-save.sh --set ENABLE_MULTI_TENANT_BRANDING=True
./infrastructure/tutor/apply-patches.sh
tutor k8s restart

# 5. Verify runtime activation
./scripts/qa/verify-tenant-branding-runtime.sh --env prod
# Expected: 6 PASS, 0 FAIL, 0 SKIP, 5 WARN

# 6. Full branding gates
./scripts/branding/run-branding-gates.sh prod
# Expected: All PASS

# 7. MFE branding check
./scripts/qa/verify-mfe-branding.sh --env prod
# Expected: 56+ PASS, 0 FAIL

# 8. Multisite governance gates
./scripts/qa/run-multisite-governance-gates.sh --env prod
# Expected: All PASS
```

---

## Implementation Estimates

### Phase 1: Single Tenant Activation (1-2 days)
| Task | Effort | Owner | Dependencies |
|------|--------|-------|--------------|
| Fix F-002 (Nginx Host header) | 30min | Platform Eng | None |
| Fix F-001 (Discussions URL) | 30min | Frontend | None |
| Provision Mereka Academy tenant (F-007) | 2h | Platform Eng | None |
| Replace placeholder UUIDs (F-008) | 1h | Platform Eng | F-007 |
| Enable ENABLE_MULTI_TENANT_BRANDING (F-005) | 1h | Platform Eng | F-007, F-008 |
| Verify branding gates pass | 30min | QA | F-005 |
| Document brand-pack workflow (F-010) | 4h | Platform Eng | F-007 |
| **TOTAL** | **9.5h** | - | - |

### Phase 2: Multi-Tenant Validation (1-2 days)
| Task | Effort | Owner | Dependencies |
|------|--------|-------|--------------|
| Provision 2 test tenants | 2h | Platform Eng | Phase 1 complete |
| Upload distinct branding for each | 1h | Ops | Phase 1 complete |
| Add brand color tokens (F-006) | 2h | Frontend | None |
| Add footer fallback logic (F-009) | 1h | Frontend | None |
| Verify isolation (cross-tenant checks) | 1h | QA | 2 test tenants |
| Run load test (3 tenants, 100 users each) | 1d | QA + Platform | 2 test tenants |
| Document asset storage strategy | 2h | Platform Eng | Load test results |
| **TOTAL** | **1d + 9h** | - | - |

### Phase 3: Production Scale (ongoing)
| Task | Effort | Owner | Frequency |
|------|--------|-------|-----------|
| Monitor cache hit rates (target: >90%) | 30min | Ops | Weekly |
| Monitor query performance (p95 <300ms) | 30min | Ops | Weekly |
| Add CDN if asset delivery bottleneck | 1d | Platform Eng | As needed |
| Review MFE build strategy at 5+ tenants | 4h | Platform Eng | At 5 tenants |
| **ONGOING** | - | - | - |

---

## Ownership Map

| Category | Owner | Findings | Estimated Effort |
|----------|-------|----------|------------------|
| **Platform Engineering** | Platform Eng | F-002, F-005, F-007, F-008, F-010 | 9h (Quick Wins) + 4h (Phase 2) |
| **Frontend** | Frontend | F-001, F-006, F-009 | 3.5h (Quick Wins) |
| **QA** | QA | Verification + Load Test | 2h (Verification) + 1d (Load Test) |
| **Operations** | Ops | Monitoring + Provisioning | Ongoing |

---

## Related Documents

### Source Documents (Audit Inputs)
- `docs/concepts/architecture/MULTISITE_UX_CONSISTENCY.md` — Hardcoded domain audit findings
- `docs/operations/TENANT_BRANDING_READINESS_RAG.md` — 5-dimension readiness assessment
- `docs/operations/TENANT_BRANDING_TROUBLESHOOTING.md` — Known edge cases

### Verification Scripts
- `scripts/qa/verify-multisite-ux-consistency.sh` — Multi-site UX consistency audit
- `scripts/qa/verify-tenant-branding-runtime.sh` — Runtime branding verification
- `scripts/qa/verify-mfe-branding.sh` — MFE branding checks
- `scripts/qa/verify-tenant-isolation.sh` — Cross-tenant isolation checks
- `scripts/branding/run-branding-gates.sh` — Comprehensive branding gate suite

### Specifications
- `specs/branding-system_spec.md` — Branding system spec (AC-UI-*, AC-MSUX-*)
- `specs/multi-tenancy-architecture_spec.md` — Multi-tenancy architecture spec (AC-TBR-*)
- `specs/cross-cutting-requirements_spec.md` — Platform-wide requirements

### Configuration Files
- `infrastructure/tutor/plugins/mereka_lms.py` — Main Tutor plugin (SITE_VARIANTS, DISCUSSIONS_MICROFRONTEND_URL)
- `deploy/k8s/base/apps/openedx/settings/lms/production.py` — LMS production settings (MFE_CONFIG, cookie domains)
- `deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml` — K8s tenant registry ConfigMap

### Runbooks & Guides
- `docs/operations/TENANT_PROVISIONING.md` — Tenant provisioning workflow
- `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` — Tenant branding contract
- `docs/concepts/architecture/multi-tenancy-overview.md` — Multi-tenancy architecture overview

---

## Changelog

| Date | Change | Assessor |
|------|--------|----------|
| 2026-02-17 | Initial multisite UX audit report | Platform Engineering (mereka-lms-1rda.1) |

---

## Next Steps

### Immediate (This Sprint)
1. ~~**Quick Win #1**: Fix Nginx Host header (F-002)~~ — ✅ **DONE** (PR #35)
2. ~~**Quick Win #2**: Fix Discussions URL (F-001)~~ — ✅ **DONE** (PR #35)
3. ~~**Quick Win #4**: Add footer fallback logic (F-009)~~ — ✅ **DONE** (PR #35)
4. ~~**Quick Win #5**: Add admin.academyv2.mereka.io to ALLOWED_HOSTS (F-007 partial)~~ — ✅ **DONE** (PR #35)
5. **Quick Win #3**: Replace placeholder UUIDs (F-008) — 1h
6. Provision Mereka Academy tenant (F-007) — 2h
7. Enable ENABLE_MULTI_TENANT_BRANDING (F-005) — 1h

**Total Sprint Effort**: ~4 hours remaining (4/9 quick wins completed)

### Next Sprint
1. Add brand color tokens (F-006) — 2h
2. Document brand-pack workflow (F-010) — 4h
3. Provision 2 test tenants — 2h
4. Run load test (3 tenants, 100 users) — 1d

### Future Work
1. Add CDN for tenant asset delivery (if bottleneck)
2. Review MFE build strategy at 5+ tenants
3. Evaluate per-tenant MFE images vs. runtime plugin framework

---

**Report Status**: Ready for review and action
**Recommended Approval**: Platform Engineering Lead
**Escalation Path**: If blockers persist beyond estimated effort, escalate to Architecture Review Board
