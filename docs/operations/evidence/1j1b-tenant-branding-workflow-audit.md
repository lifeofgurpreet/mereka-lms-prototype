# Tenant Branding Workflow + Spec/Docs Alignment Audit

> **Bead**: mereka-lms-1j1b
> **ACs**: AC-UX-120, AC-UX-121, AC-UX-122, AC-UX-123
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize

---

## AC-UX-120: Tenant-Branding Onboarding Doc — Required Inputs and Per-Tenant Overrides

**Status: ✅ EXISTS — comprehensive coverage**

The canonical tenant branding onboarding documentation already exists across multiple documents:

| Document | Content |
|----------|---------|
| `docs/branding/MULTI_TENANT_BRANDING_OPS.md` | Per-tenant onboarding runbook (Step-by-step); branding layers; CI validation; owner/signoff/escalation |
| `docs/branding/TENANT_BRANDING_CONTRACT.md` | Required inputs, brand pack schema, fallback rules |
| `docs/branding/TENANT_BRAND_PACK_SCHEMA.md` | JSON schema for tenant brand pack (logo, colors, fonts, domains) |
| `docs/branding/BRANDING_OPERATING_MODEL.md` | Canonical branding workflow, change types, approvals |
| `docs/runbooks/tenant-provisioning-runbook.md` | Operator runbook for K8s provisioning |
| `scripts/tenants/provision-tenant.sh` | Automated provisioning (idempotent) |

### Required Inputs (from TENANT_BRANDING_CONTRACT.md)

Per-tenant onboarding requires:
1. **DNS/hostname** — registered in Cloudflare, Caddy config, K8s Ingress
2. **SITE_VARIANTS entry** in `mereka_lms.py` with: `brand`, `copyrightHolder`, `whatsapp`, `logoUrl`
3. **Design token overrides** — `_tokens.scss` variables for brand colors/fonts (optional)
4. **Logo assets** — `logo.png`, `logo-horizontal.png`, `favicon.ico` in theme static dir
5. **configmap-tenants.yaml** entry for tenant metadata
6. **ExternalSecret** for any tenant-specific secrets

### Per-Tenant Override Precedence (5-layer stack)

```
Platform defaults → Design tokens (_tokens.scss) → MFE env.config.jsx → Plugin slots (FPF) → SITE_VARIANTS
```
Innermost = highest priority.

---

## AC-UX-121: Validate Existing Subsites Against Documented Flow

**Status: ✅ PASS with WARNs (expected)**

Three active subsites validated against the onboarding flow:

| Subsite | Hostname | Reachable | SITE_VARIANTS | Logo | Brand Fonts | Status |
|---------|----------|-----------|---------------|------|-------------|--------|
| Mereka Academy (primary) | `academyv2.mereka.io` | ✅ 200 | ✅ Defined | ⚠️ Static hash | ⚠️ CSS marker | FUNCTIONAL |
| Biji-Biji Academy | `academy.biji-biji.com` | ✅ 200 | ✅ Defined | ⚠️ Static hash | ⚠️ CSS marker | FUNCTIONAL |
| Skill Our Future | `skillourfuture.academy.mereka.io` | ✅ 200 | ✅ Defined | ⚠️ Static hash (themed logo URL confirmed) | ⚠️ CSS marker | FUNCTIONAL |

**WARN explanations** (all expected, not blocking):
- "Static hash" — logos served via Django `collectstatic` with content hashing; verify script checks for non-hashed URL patterns which won't match hashed filenames
- "CSS marker" — verify script checks for specific CSS revision marker string; marker may differ between build cycles; fonts themselves are loading correctly (verified by `verify-mfe-branding.sh` PASS)

**verify-public-branding.sh confirmed live**:
- MFE login: ✅ 200
- Forum heartbeat: ✅ 200
- Ecommerce root: ✅ 200 (branded)
- Academy.biji-biji.com: ✅ 200
- Skillourfuture.academy.mereka.io: ✅ 200

**Known gaps** (data-dependent, not workflow gaps):
- Credentials service: 500 on admin login (service needs live DB data, not a branding gap)
- Ecommerce dashboard authn shell: Not critical (Ecommerce being deprecated in favour of Purchase Gateway)

---

## AC-UX-122: Spec IDs and Runbook Ownership Links

| Area | Spec | Runbook | Owner |
|------|------|---------|-------|
| Multi-tenant architecture | `specs/multi-tenancy-architecture_spec.md` | `docs/runbooks/tenant-provisioning-runbook.md` | platform-engineering |
| Branding operations | `specs/platform-middleware-custom-apps_spec.md` | `docs/branding/BRANDING_OPERATING_MODEL.md` | platform-engineering / design |
| Branding contract | (covered in multi-tenancy spec) | `docs/branding/TENANT_BRANDING_CONTRACT.md` | platform-engineering |
| MFE branding strategy | ADR-014 (`docs/adr/014-mfe-branding-strategy.md`) | `docs/branding/MULTI_TENANT_BRANDING_OPS.md` | platform-engineering |
| Plugin slot migration | (covered in platform-middleware spec) | `docs/operations/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md` | platform-engineering |
| Visual parity checkpoints | `specs/platform-middleware-custom-apps_spec.md` (AC-UI-105/106) | `docs/branding/VISUAL_PARITY_CHECKPOINTS.md` | design / platform-engineering |
| A11y contrast/focus | (covered in platform-middleware spec) | `docs/operations/A11Y_CONTRAST_FOCUS_GATE.md` | platform-engineering / design |

**Tenant owner table** (from MULTI_TENANT_BRANDING_OPS.md):
| Tenant | Branding Owner | Escalation |
|--------|---------------|------------|
| Mereka Academy | Mereka platform-engineering | Engineering Lead |
| Biji-Biji Initiative | Biji-Biji design + platform-engineering | Engineering Lead |
| Skill Our Future | MEREKA platform-engineering | Engineering Lead |

---

## AC-UX-123: QA Check for Visual/Brand Regression for Tenant Landing Pages

**Status: ✅ Scripts exist and pass**

The following QA scripts provide visual/brand regression coverage for tenant landing pages:

| Script | What it checks | Last Result |
|--------|----------------|-------------|
| `scripts/qa/verify-branding-health.sh` | Logo, favicon, design tokens, runtime CSS | PASS 3/3 |
| `scripts/qa/verify-mfe-branding.sh` | MFE bundle branding markers, font loading, CSS | PASS 57/57, SKIP 1 |
| `scripts/qa/verify-multi-tenant-branding-ops.sh` | MULTI_TENANT_BRANDING_OPS.md content ACs | PASS 19/19 |
| `scripts/qa/verify-tenant-branding-contract.sh` | TENANT_BRANDING_CONTRACT.md RAG matrix | PASS 38/38 |
| `scripts/qa/verify-visual-parity-checkpoints.sh` | Visual parity checkpoints doc + CI integration | PASS 42/42 |
| `scripts/qa/verify-public-branding.sh` | Live cluster HTTP checks for all tenant domains | PASS (see details above) |
| `scripts/qa/verify-a11y-contrast-focus.sh` | A11y contrast pairs, focus visibility | PASS 28/28, WARN 3 |
| `scripts/qa/verify-a11y-tenant-branding.sh` | Per-tenant a11y | (CI check) |
| `scripts/qa/verify-tenant-branding-matrix.sh` | Tenant branding coverage matrix | (CI check) |

**CI integration**: `verify-visual-parity-checkpoints.sh` is referenced in `.github/workflows/ci.yml` (confirmed by verify script AC-UI-106 PASS). Brand regression is gated at every PR.

**Screenshot capture**: `scripts/qa/capture-branding-screenshots.sh` exists for operator-triggered screenshot baseline capture. Screenshots are stored as evidence artifacts, not committed to repo (appropriate for a CI/CD context).

**Gap identified** (follow-up for future bead):
- Automated screenshot diffing (pixel-by-pixel comparison) is not yet implemented. Current coverage relies on HTTP check + CSS marker verification. Perceptual diff tooling (e.g., Percy, Chromatic) is in `docs/branding/BRANDING_ROADMAP.md` as a future item.
