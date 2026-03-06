# Multi-Tenant Branding Operations Model — Evidence Report

**Bead:** 2dcy.4 — Frontend: publish multi-tenant branding operations model
**Date:** 2026-02-18
**ACs:** AC-FRONT-041, AC-FRONT-042, AC-FRONT-043, AC-FRONT-044
**Verification script:** `scripts/qa/verify-multi-tenant-branding-ops.sh`
**Ops model document:** `docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md`

---

## What the Ops Model Covers

`docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md` is the canonical reference for multi-tenant
branding operations on the Mereka Academy Open edX platform. It covers:

1. **Branding scope and override precedence** (AC-FRONT-041): The five-layer branding stack
   (platform defaults → design tokens → MFE env.config.jsx → plugin slots → SITE_VARIANTS),
   the override precedence chain, how `SITE_VARIANTS` maps hostnames to brand variants, and
   the role of `_tokens.scss` and `configmap-tenants.yaml` in tenant branding.

2. **Per-tenant onboarding runbook** (AC-FRONT-042): Step-by-step instructions for adding a
   new tenant, covering DNS/hostname registration (Cloudflare, Caddy, Ingress), `SITE_VARIANTS`
   entry in `mereka_lms.py`, design token overrides, plugin slot configuration, MFE
   `env.config.jsx` variant setup, ConfigMap / Secret entries, provisioning via
   `provision-tenant.sh`, and smoke test verification.

3. **CI and runtime validation** (AC-FRONT-043): How domain resolution flows through
   `TenantResolutionMiddleware` to branding at the MFE layer; CI jobs and the verify scripts
   that protect multi-tenant branding surfaces; how to add new verify coverage for new tenants;
   regression detection via CI gates, screenshot testing, and PrometheusRule alerting.

4. **Owner, signoff, and escalation** (AC-FRONT-044): Per-tenant branding ownership table
   (Mereka Academy, Biji-Biji Initiative, Skil Our Future), signoff requirements by change
   type (PR approval, screenshot review, contrast gate), and a five-step escalation path with
   P1/P2/P3/P4 severity tiers and SLAs.

---

## AC Pass/Fail Summary

| AC | Description | Result |
|----|-------------|--------|
| AC-FRONT-041 | Branding scope and override precedence published in `docs/branding` | PASS |
| AC-FRONT-042 | Per-tenant onboarding runbook (hostnames, assets, config keys) in one document | PASS |
| AC-FRONT-043 | CI and runtime validation of tenant branding changes defined | PASS |
| AC-FRONT-044 | Owner/signoff expectations and escalation contacts for branding regressions | PASS |

**Overall: PASS**

---

## Verification Output

Run `./scripts/qa/verify-multi-tenant-branding-ops.sh` to reproduce:

```
========================================================
Multi-Tenant Branding Operations Model Verifier (bead 2dcy.4)
AC-FRONT-041..044
========================================================

AC-FRONT-041: Branding scope and override precedence
  PASS: MULTI_TENANT_BRANDING_OPS.md exists
  PASS: Document contains 'override precedence' section
  PASS: Document references SITE_VARIANTS
  PASS: Document references design tokens (_tokens.scss)
  PASS: Document references plugin slot configuration
  PASS: Document references tenant registry ConfigMap

AC-FRONT-042: Per-tenant onboarding runbook
  PASS: Document contains onboarding / new tenant steps
  PASS: Document references DNS/hostname registration steps
  PASS: Document references provision-tenant.sh
  PASS: Document references ConfigMap entries in onboarding
  PASS: Document includes smoke test / verification step in runbook

AC-FRONT-043: CI and runtime validation
  PASS: Document references CI validation
  PASS: Document references runtime branding resolution
  PASS: Document references at least 3 existing verify scripts by name (found: 7)
  PASS: Document references branding regression detection

AC-FRONT-044: Owner, signoff, and escalation
  PASS: Document contains owner / ownership section
  PASS: Document contains signoff / approval expectations
  PASS: Document contains escalation path
  PASS: Document names branding owners for at least 2 tenants (found: 3)

========================================================
Summary
========================================================

  PASS: 19
  FAIL: 0
  WARN: 0

All checks passed.
```

---

## Related Documents

| Document | Purpose |
|----------|---------|
| `docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md` | This bead's ops model (primary deliverable) |
| `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` | Brand pack schema, MFE config keys, fallback rules |
| `docs/guides/branding/BRANDING_OPERATING_MODEL.md` | Canonical branding workflow (single-tenant baseline) |
| `scripts/qa/verify-multi-tenant-branding-ops.sh` | Verification script for this bead |
| `scripts/tenants/provision-tenant.sh` | Tenant provisioning script referenced in runbook |
| `deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml` | Tenant registry ConfigMap |
| `infrastructure/tutor/plugins/mereka_lms.py` | SITE_VARIANTS and plugin slot configuration source |
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | Design token SCSS source |
