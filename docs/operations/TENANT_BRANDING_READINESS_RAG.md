# Tenant Branding Readiness - RAG Assessment Matrix

_Audience: Platform Engineering + Operations • Last updated: 2026-02-17_

**Purpose**: Machine-checkable readiness assessment for multi-tenant branding activation.

**Spec Reference**: `specs/multi-tenancy-architecture_spec.md`
**Contract Reference**: `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`

---

## Assessment Summary

This matrix tracks readiness across 5 dimensions to activate production multi-tenant branding (ENABLE_MULTI_TENANT_BRANDING=True).

**Legend**:
- **GREEN**: Production-ready, no blockers
- **AMBER**: Working but needs attention before scale
- **RED**: Blocks activation, must fix before enabling

**Last Assessment**: 2026-02-17
**Overall Status**: AMBER (3 GREEN, 2 AMBER)
**Target for GREEN**: Complete first tenant provisioning + activation + zero-downtime brand-pack workflow

---

## Dimension 1: Architecture Readiness

**Status**: 🟢 **GREEN**

### Evidence

| Component | Status | File Reference |
|-----------|--------|----------------|
| TenantSiteMapping model | ✅ Complete | `infrastructure/tutor/custom-apps/openedx_tenant_cache/models.py:14-101` |
| TenantSiteConfiguration model | ✅ Complete | `infrastructure/tutor/custom-apps/openedx_tenant_cache/models.py:103-177` |
| TenantResolutionMiddleware | ✅ Complete | `infrastructure/tutor/custom-apps/mereka_tenancy/middleware.py` |
| inject_mfe_branding() | ✅ Complete | `infrastructure/tutor/custom-apps/openedx_tenant_cache/branding.py:109-137` |
| provision_tenant management command | ✅ Complete | `infrastructure/tutor/custom-apps/openedx_tenant_cache/management/commands/provision_tenant.py` |
| apply_tenant_branding management command | ✅ Complete | `infrastructure/tutor/custom-apps/openedx_tenant_cache/management/commands/apply_tenant_branding.py` |
| Tutor plugin integration | ✅ Complete | `infrastructure/tutor/plugins/mereka_lms.py` |
| Theme directory structure | ✅ Complete | `infrastructure/tutor/themes/mereka/tenants/` |
| K8s tenant registry ConfigMap | ✅ Complete | `deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml` |

### Gaps

None. All architectural components are in place.

### Action to Reach GREEN

Already GREEN. Maintain code coverage and prevent regressions.

---

## Dimension 2: Runtime Activation Readiness

**Status**: 🟡 **AMBER**

### Evidence

| Component | Status | Gap |
|-----------|--------|-----|
| ENABLE_MULTI_TENANT_BRANDING flag | 🟡 AMBER | Currently set to False (not activated) |
| First tenant (mereka) | 🟡 AMBER | Not yet provisioned via provision_tenant command |
| Domain mapping (3 production domains) | ✅ Complete | academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io |
| Middleware registration | ✅ Complete | TenantResolutionMiddleware in MIDDLEWARE |
| Plugin installed | ✅ Complete | mereka_lms plugin active |
| Database tables exist | ✅ Complete | openedx_tenant_cache_* tables created |
| Theme assets synced | ✅ Complete | Single `mereka` theme deployed |
| Placeholder UUIDs | 🔴 RED | Hardcoded UUIDs in code need replacement with real tenant UUIDs |

### Gaps

1. **Feature flag disabled**: `ENABLE_MULTI_TENANT_BRANDING=False` in production
2. **First tenant not provisioned**: Mereka Academy tenant exists conceptually but not in database via provision_tenant workflow
3. **Placeholder UUIDs**: Code contains test UUIDs instead of real tenant UUIDs from database

### Action to Reach GREEN

1. Run `./scripts/tenants/provision-tenant.sh --from-env scripts/tenants/mereka-tenant.env` (production)
2. Verify tenant provisioning: `./scripts/qa/verify-tenant-isolation.sh`
3. Set `ENABLE_MULTI_TENANT_BRANDING=True` in Tutor config
4. Apply patches and restart: `./infrastructure/tutor/apply-patches.sh && tutor k8s restart`
5. Verify branding gates pass: `./scripts/branding/run-branding-gates.sh prod`

**Estimated effort**: 2-4 hours (provisioning + verification + rollout)

---

## Dimension 3: Verification Coverage

**Status**: 🟢 **GREEN**

### Evidence

| Script | Purpose | Status |
|--------|---------|--------|
| `scripts/qa/verify-tenant-model.sh` | TenantSiteMapping/Config model structure | ✅ Complete |
| `scripts/qa/verify-tenant-middleware.sh` | Middleware integration | ✅ Complete |
| `scripts/qa/verify-tenant-configmap.sh` | K8s ConfigMap template | ✅ Complete |
| `scripts/qa/verify-tenant-provisioning.sh` | Management command structure | ✅ Complete |
| `scripts/qa/verify-tenant-isolation-patterns.sh` | Cross-tenant isolation checks | ✅ Complete |
| `scripts/qa/verify-tenant-branding.sh` | Tenant branding asset checks | ✅ Complete |
| `scripts/branding/run-branding-gates.sh` | Comprehensive branding gate suite | ✅ Complete |
| `scripts/qa/verify-branding-multi-domain.sh` | Multi-domain branding verification | ✅ Complete |
| `scripts/qa/verify-public-branding.sh` | Public-facing branding checks | ✅ Complete |
| `scripts/qa/verify-mfe-branding.sh` | MFE branding verification | ✅ Complete |
| `scripts/qa/verify-studio-branding.sh` | Studio branding checks | ✅ Complete |
| `scripts/qa/verify-mfe-image-branding.sh` | MFE image contract verification | ✅ Complete |
| `scripts/qa/verify-studio-authoring-branding.sh` | Studio authoring flow branding | ✅ Complete |
| `scripts/branding/verify-branding-css.sh` | CSS token verification | ✅ Complete |
| `scripts/branding/verify-token-drift.sh` | Token provenance tracking | ✅ Complete |

**Total**: 15+ verification scripts covering source, runtime, and live branding checks.

### Gaps

None. Verification coverage is comprehensive.

### Action to Reach GREEN

Already GREEN. Add any new verifiers for tenant-specific branding contracts as needed.

---

## Dimension 4: Operator Workflow

**Status**: 🟡 **AMBER**

### Evidence

| Workflow | Status | Documentation |
|----------|--------|---------------|
| Provision new tenant | ✅ Complete | `docs/operations/TENANT_PROVISIONING.md` |
| DNS configuration | ✅ Complete | `docs/operations/TENANT_PROVISIONING.md:299-307` |
| SSO setup | ✅ Complete | `docs/operations/TENANT_PROVISIONING.md:325-330` |
| Upload branding assets | 🟡 AMBER | `docs/operations/TENANT_PROVISIONING.md:334-343` (requires image rebuild) |
| Catalog creation | ✅ Complete | `docs/operations/TENANT_PROVISIONING.md:347-350` |
| Subscription plans | ✅ Complete | `docs/operations/TENANT_PROVISIONING.md:352-357` |
| Isolation verification | ✅ Complete | `docs/operations/TENANT_PROVISIONING.md:360-362` |
| Rollback/offboarding | ✅ Complete | `docs/operations/TENANT_PROVISIONING.md:429-476` |
| Zero-downtime brand-pack update | 🔴 RED | Not documented (blocks scale) |

### Gaps

1. **Brand-pack workflow not documented**: No clear process for adding/updating tenant branding assets without image rebuild
2. **Asset sync unclear**: Current workflow shows `cp` to theme dir + `sync-branding.sh` but doesn't specify collectstatic/restart requirements
3. **MFE branding update unclear**: When tenant updates logo, what's the deployment process? (rebuild MFE image vs. runtime asset URL update)

### Action to Reach GREEN

1. Document zero-downtime brand-pack workflow in contract (AC-TBR-005)
2. Clarify asset sync requirements: static assets vs. database config
3. Test workflow: update Mereka logo → verify change propagates without downtime
4. Add workflow to `docs/operations/TENANT_PROVISIONING.md` or create separate runbook

**Estimated effort**: 4-6 hours (test workflow + document + verify)

---

## Dimension 5: Scale Readiness (5-10 Tenants)

**Status**: 🟡 **AMBER**

### Evidence

| Component | Status | Scaling Consideration |
|-----------|--------|----------------------|
| Single-theme architecture | 🟡 AMBER | Current: one `mereka` theme with tenant overlays. Unclear if this scales to 10 tenants. |
| Tenant directory structure | ✅ Complete | `themes/mereka/tenants/<slug>/` defined but empty |
| Database queries | ✅ Complete | Queryset filtering with `enterprise_customer_uuid` index |
| Cache strategy | ✅ Complete | Redis caching with 5-min TTL (branding.py:20) |
| Asset storage | 🟡 AMBER | No CDN or object storage strategy for tenant assets |
| MFE build strategy | 🔴 RED | Currently rebuilds entire MFE image. Unclear if per-tenant MFE builds are needed. |
| Load test evidence | 🔴 RED | No load testing with >1 tenant |

### Gaps

1. **Single-theme architecture**: All tenants share one theme with runtime overlays. Needs validation at 5-10 tenants.
2. **Asset storage strategy**: Static assets stored in theme directory. No CDN/S3 strategy for scale.
3. **MFE build strategy**: One MFE image for all tenants. If tenant needs custom footer component, unclear if runtime injection suffices.
4. **No load test**: No evidence that system performs with 10 tenants at production traffic.
5. **Tenant directory empty**: Structure defined but no tenants populated (first tenant not provisioned).

### Action to Reach GREEN

1. **Provision 2-3 test tenants** (Mereka + 2 fictional tenants) to validate architecture
2. **Test brand-pack workflow** at scale: add/update assets for 3 tenants, verify isolation
3. **Document asset storage strategy**: theme dir vs. CDN vs. S3 (with tradeoffs)
4. **MFE build strategy decision**: runtime injection only vs. per-tenant MFE images (document in ADR)
5. **Run load test**: Simulate 3 tenants with 100 concurrent users each, verify no cross-contamination

**Estimated effort**: 1-2 days (provision tenants + test + document + load test)

---

## Blocking Issues Summary

| Issue | Impact | Owner | Estimated Fix |
|-------|--------|-------|---------------|
| ENABLE_MULTI_TENANT_BRANDING=False | Cannot test runtime activation | Platform Eng | 1 hour (config + restart) |
| First tenant not provisioned | No real tenant data to verify | Platform Eng | 2 hours (provision + verify) |
| Placeholder UUIDs in code | Runtime errors when activated | Platform Eng | 1 hour (search/replace + test) |
| Zero-downtime brand-pack workflow undocumented | Ops cannot add tenants without risk | Platform Eng | 4 hours (test + document) |
| No load test with >1 tenant | Unknown performance at scale | QA + Platform | 1 day (setup + run + analyze) |

**Total estimated effort to GREEN**: 2-3 days

---

## Recommended Activation Path

### Phase 1: Single Tenant Activation (1-2 days)
1. ✅ Provision Mereka Academy tenant
2. ✅ Set ENABLE_MULTI_TENANT_BRANDING=True
3. ✅ Verify branding gates pass
4. ✅ Document brand-pack workflow
5. ✅ Test workflow: update logo without downtime

### Phase 2: Multi-Tenant Validation (1-2 days)
1. ✅ Provision 2 test tenants (fictional orgs)
2. ✅ Upload distinct branding for each
3. ✅ Verify isolation (cross-tenant checks)
4. ✅ Run load test (3 tenants, 100 users each)
5. ✅ Document asset storage strategy

### Phase 3: Production Scale (ongoing)
1. ✅ Monitor cache hit rates (target: >90%)
2. ✅ Monitor query performance (p95 <300ms)
3. ✅ Add CDN if asset delivery becomes bottleneck
4. ✅ Review MFE build strategy at 5+ tenants

---

## Related Documents

- **Contract**: `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`
- **Provisioning**: `docs/operations/TENANT_PROVISIONING.md`
- **Architecture**: `docs/concepts/architecture/multi-tenancy-overview.md`
- **Spec**: `specs/multi-tenancy-architecture_spec.md`
- **Branding Model**: `docs/guides/branding/BRANDING_OPERATING_MODEL.md`
- **Verifier**: `scripts/qa/verify-tenant-branding-contract.sh`

---

## Changelog

| Date | Change | Assessor |
|------|--------|----------|
| 2026-02-17 | Initial RAG assessment | Claude Agent (task 2rg1) |
