# Issue #220 Implementation Packet - Multi-Tenancy Declarative Source of Truth

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/220  
Parent: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214  
Status: audit-to-implementation handoff

## Goal

Reduce tenant onboarding blast radius by driving DB, routing, and MFE config changes from one declarative tenant registry.

## Confirmed Risks

- Tenant onboarding currently spans several systems and scripts:
  - Django management command (`provision_tenant`)
  - shell wrappers (`provision-tenant.sh`, `provision-mfe-config.sh`)
  - Caddy and config artifacts
  - DNS and security settings
  - branding and enterprise setup
- `deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml` is explicitly marked bootstrap/reference, not canonical source.
- Manual post-provision steps remain high and error-prone.

---

## PR Strategy (recommended 3 PRs)

1. `PR-220-A` canonical registry schema + parser
2. `PR-220-B` orchestrated apply pipeline
3. `PR-220-C` drift detection and policy enforcement

---

## PR-220-A (Canonical Tenant Registry)

### File Changes

1. Add canonical registry:
   - `tenants/registry.yaml`
2. Add schema/validator:
   - `scripts/tenants/validate-tenant-registry.sh`
3. Add docs:
   - `docs/operations/TENANT_REGISTRY_CONTRACT.md`

### Registry Minimum Fields

- `slug`
- `display_name`
- `lms_domain`
- `mfe_domain`
- `studio_domain` (if used)
- `enterprise_customer_uuid` (optional pre-existing)
- `course_org_filter`
- `branding_profile`
- `active`

### Acceptance Criteria

- `AC-220-A1`: one validated registry file defines all active tenants.
- `AC-220-A2`: schema validation fails on missing or malformed tenant fields.

### Verification Commands

```bash
./scripts/tenants/validate-tenant-registry.sh
yq e '.tenants[].slug' tenants/registry.yaml
```

---

## PR-220-B (Orchestrated Apply)

### File Changes

1. Add orchestrator:
   - `scripts/tenants/apply-tenant-registry.sh`
2. Add generation step:
   - `scripts/tenants/render-tenant-configmap.sh`
3. Update existing scripts to become sub-commands/helpers:
   - `scripts/tenants/provision-tenant.sh`
   - `scripts/tenants/provision-mfe-config.sh`

### Orchestrator Behavior

For each tenant entry:
1. ensure Django tenant records (`Site`, `SiteConfiguration`, `EnterpriseCustomer`, `TenantConfig`)
2. apply MFE config overlay
3. emit/update generated bootstrap configmap
4. produce checklist output for external DNS actions (if still manual).

### Acceptance Criteria

- `AC-220-B1`: one command applies tenant registry idempotently.
- `AC-220-B2`: re-running apply does not duplicate tenant records.
- `AC-220-B3`: generated configmap is derived from registry, not hand-edited.

### Verification Commands

```bash
./scripts/tenants/apply-tenant-registry.sh --dry-run
./scripts/tenants/apply-tenant-registry.sh --tenant <slug> --dry-run
```

---

## PR-220-C (Drift Detection)

### File Changes

1. Add drift checker:
   - `scripts/qa/verify-tenant-registry-drift.sh`
2. CI/workflow integration:
   - `.github/workflows/tenant-isolation-check.yml`
   - `.github/workflows/ci.yml` (offline consistency check)

### Drift Dimensions

- Registry vs generated configmap
- Registry vs runtime DB tenant records (runtime mode)
- Registry vs documented tenant domain matrix.

### Acceptance Criteria

- `AC-220-C1`: CI fails when registry and generated configmap diverge.
- `AC-220-C2`: runtime audit mode reports missing/extra tenant records.

### Rollback Plan

1. Keep existing per-tenant scripts functional during transition.
2. If orchestrator fails, use existing manual scripts while patching registry tooling.
3. Do not revert to hand-editing generated configmap once registry adopted.

### Verification Commands

```bash
./scripts/qa/verify-tenant-registry-drift.sh --mode local
./scripts/qa/verify-tenant-isolation-gates.sh --offline
```
