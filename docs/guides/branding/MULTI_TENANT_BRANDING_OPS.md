# Multi-Tenant Branding Operations Model

_Audience: Platform Engineering + Tenant Operations + Design Team_
_Bead: 2dcy.4 — Frontend: publish multi-tenant branding operations model_
_ACs: AC-FRONT-041, AC-FRONT-042, AC-FRONT-043, AC-FRONT-044_
_Last updated: 2026-02-18_

**Related Documents**:
- `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` — Required inputs, fallback rules, brand pack schema
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — Canonical branding workflow
- `specs/multi-tenancy-architecture_spec.md` — Architecture spec (Tier 4.1)
- `scripts/qa/verify-multi-tenant-branding-ops.sh` — Verification script for this document

---

## Table of Contents

1. [Branding Scope and Override Precedence](#1-branding-scope-and-override-precedence)
2. [Per-Tenant Onboarding Runbook](#2-per-tenant-onboarding-runbook)
3. [CI and Runtime Validation](#3-ci-and-runtime-validation)
4. [Owner, Signoff, and Escalation](#4-owner-signoff-and-escalation)

---

## 1. Branding Scope and Override Precedence

### 1.1 Branding Layers (Innermost = Highest Priority)

The platform uses a layered override system. Each layer can override values from the layer below it:

```
Layer 5 (highest): domain-specific runtime override — per-hostname SITE_VARIANTS in env.config.jsx
Layer 4:           MFE env.config.jsx tenant variant — LOGO_URL, SITE_NAME, PLATFORM_NAME
Layer 3:           plugin slot configuration — footer, header, sidebar slot overrides
Layer 2:           CSS variables from _tokens.scss — color tokens, font tokens, spacing
Layer 1 (lowest):  platform defaults — Mereka Academy defaults in mereka_lms.py / theme
```

### 1.2 Override Precedence Chain

```
platform defaults
  < tenant TenantSiteConfiguration (database record, provisioned by provision_tenant)
    < design tokens (_tokens.scss SCSS variables, CSS custom properties)
      < MFE env.config.jsx SITE_NAME / LOGO_URL / PLATFORM_NAME / FAVICON_URL
        < plugin slot config (footer slot → MerekaFooter with SITE_VARIANTS lookup)
          < SITE_VARIANTS[hostname] runtime lookup (highest, domain-specific)
```

**Rule**: A value at a higher layer always wins. A missing value at a higher layer falls through to the next lower layer. The platform never breaks if a tenant omits optional values — fallback is always present.

### 1.3 SITE_VARIANTS (Runtime Domain Override)

`SITE_VARIANTS` in `infrastructure/tutor/plugins/mereka_lms.py` maps hostnames to brand variant overrides for the MFE footer component (`MerekaFooter`). This is the highest-priority override layer.

```javascript
// Excerpt from MerekaFooter component (mfe-env-config patch in mereka_lms.py)
const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
const SITE_VARIANTS = {
  'academy.biji-biji.com': { brand: 'Biji-Biji Initiative', copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },
  'skillourfuture.academy.mereka.io': { brand: 'Skil Our Future', copyrightHolder: 'Skil Our Future', whatsapp: '601135271981' },
};
const variant = SITE_VARIANTS[hostname] || { brand: config.SITE_NAME || 'Mereka Academy', ... };
```

**To add a new domain variant**: add an entry to `SITE_VARIANTS` in `mereka_lms.py` (see onboarding runbook in Section 2).

### 1.4 Tenant Registry ConfigMap

The canonical registry of active tenants lives at:

```
deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml
```

This ConfigMap (`tenant-registry`) is the infrastructure-discoverable source of tenant slugs, primary domains, and alias domains. The canonical source of truth for live config is the `TenantConfig` database record created by `provision_tenant`.

**Current tenants**:

| Slug | Domain | Alias Domains |
|------|--------|---------------|
| `mereka-academy` | `academyv2.mereka.io` | _none_ |
| `biji-biji` | `academy.biji-biji.com` | _none_ |
| `skillourfuture` | `skillourfuture.academy.mereka.io` | _none_ |

### 1.5 Design Tokens

Design tokens are defined in `infrastructure/tutor/themes/mereka/scss/_tokens.scss`. These SCSS variables are compiled into CSS custom properties used by both the LMS theme and MFE SCSS.

Override flow for colors:
```
_tokens.scss (source of truth for brand colors)
  → theme.scss @import (LMS + CMS theme compilation)
    → MFE mereka.scss (MFE-specific overrides)
      → Paragon token overrides (SCSS variable → CSS custom property)
```

Tenant-specific color tokens are not currently implemented at the per-tenant level; all tenants share the same Mereka palette. Tenant visual differentiation is achieved via logos, site name, and footer copy (SITE_VARIANTS).

### 1.6 Plugin Slot Configuration

The MFE footer is rendered via a plugin slot (`footer-slot`). The slot is configured in the `mfe-env-config` Tutor patch in `mereka_lms.py`. The `MerekaFooter` component reads `SITE_VARIANTS[hostname]` to select the correct brand variant at runtime.

Plugin slot override precedence for footer:
```
1. Platform default footer (Open edX upstream)
   < 2. mfe-env-config patch (MerekaFooter component replaces slot default)
     < 3. SITE_VARIANTS[hostname] lookup inside MerekaFooter (domain override)
```

---

## 2. Per-Tenant Onboarding Runbook

This runbook covers the complete process for adding a new tenant's branding to the platform.

**Prerequisites**: Tenant slug, primary domain, brand assets (logos, favicon, brand colors), contact email.

---

### Step 1: DNS and Hostname Registration

**Owner**: Platform Engineering

1. Add a DNS record in Cloudflare for the tenant's primary domain pointing to the cluster's LoadBalancer IP or Cloudflare Tunnel:

   - For `*.academyv2.mereka.io` subdomains: create a CNAME to the GKE LoadBalancer.
   - For external domains (e.g., `academy.biji-biji.com`): create a CNAME or A record.
   - **Multi-level subdomains** (e.g., `tenant.academyv2.mereka.io`): Cloudflare Free SSL does NOT cover `*.*.mereka.dev`. Use DNS-only (gray cloud) with Let's Encrypt via cert-manager.

2. Verify DNS propagation:
   ```bash
   dig +short <tenant-domain>
   ```

3. Update the Caddy Ingress/Caddyfile if a new domain requires a new virtual host block. The `apply-patches.sh` script manages extra domain names via the `EXTRA_DOMAIN_NAMES` config key.

---

### Step 2: SITE_VARIANTS Entry in mereka_lms.py

**Owner**: Platform Engineering

Add the tenant's domain to the `SITE_VARIANTS` map in `infrastructure/tutor/plugins/mereka_lms.py`:

```javascript
const SITE_VARIANTS = {
  // Existing entries...
  'academy.biji-biji.com': { brand: 'Biji-Biji Initiative', copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },

  // New tenant entry:
  '<tenant-domain>': {
    brand: '<Tenant Display Name>',
    copyrightHolder: '<Copyright Holder Name>',
    whatsapp: '<WhatsApp number or empty string>',
  },
};
```

After editing `mereka_lms.py`, rebuild the MFE image or run the apply-patches workflow:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./infrastructure/tutor/apply-patches.sh
tutor images build mfe
```

---

### Step 3: Design Token Overrides (if needed)

**Owner**: Design Team → Platform Engineering

If the tenant requires distinct brand colors (not currently in use — all tenants share the Mereka palette), add tenant-scoped SCSS variables in `infrastructure/tutor/themes/mereka/scss/_tokens.scss`.

Current token structure:
```scss
// _tokens.scss
$brand-primary:   #E63946;  // Mereka red
$brand-secondary: #457B9D;  // Mereka blue
// ... additional tokens
```

For per-tenant colors: discuss with Platform Engineering — this requires a conditional SCSS approach or separate theme directory per tenant.

---

### Step 4: Plugin Slot Configuration (Footer, Header, Sidebar)

**Owner**: Platform Engineering

The footer slot is configured via the `mfe-env-config` Tutor patch in `mereka_lms.py`. No additional per-tenant slot config is needed if SITE_VARIANTS covers the tenant's branding needs.

For custom header or sidebar slots per tenant: add a tenant-specific `pluginConfig` entry in the `env.config.jsx` template in `mereka_lms.py`.

---

### Step 5: MFE env.config.jsx Tenant Variant

**Owner**: Platform Engineering

MFE-level config keys (LOGO_URL, FAVICON_URL, SITE_NAME, PLATFORM_NAME) are served via the `TenantSiteConfiguration.mfe_config` database field — set during provisioning (Step 7). These override the platform defaults visible in `env.config.jsx`.

For static overrides needed before provisioning, add a `SITE_VARIANTS` entry (Step 2).

---

### Step 6: ConfigMap and Secret Entries

**Owner**: Platform Engineering

1. Add the tenant to the tenant registry ConfigMap:

   ```yaml
   # deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml
   - slug: <tenant-slug>
     name: <Tenant Display Name>
     domain: <tenant-domain>
     enterprise_customer_uuid: "<uuid>"
     active: true
     alias_domains: []
   ```

2. Apply the updated ConfigMap to the cluster:
   ```bash
   kubectl apply -f deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml
   ```

3. If the tenant requires secrets (e.g., custom SMTP, SSO client secrets), add ExternalSecret entries in `deploy/k8s/base/secrets/external-secrets.yaml` and back the secrets in Infisical.

---

### Step 7: Tenant Provisioning via provision-tenant.sh

**Owner**: Platform Engineering

Run the provisioning script to create the `TenantConfig` database record and Django Site:

```bash
./scripts/tenants/provision-tenant.sh \
  --slug <tenant-slug> \
  --name "<Tenant Display Name>" \
  --domain <tenant-domain> \
  --contact-email <admin@tenant.com> \
  --country MY
```

The script wraps the Django `provision_tenant` management command and:
- Creates `TenantConfig` and `TenantSiteConfiguration` database records
- Sets `mfe_config` keys (LOGO_URL, SITE_NAME, PLATFORM_NAME, FAVICON_URL, SUPPORT_EMAIL)
- Associates the domain with the correct Django `Site`

For dry-run testing:
```bash
./scripts/tenants/provision-tenant.sh --slug <slug> --name "<name>" --domain <domain> --dry-run
```

---

### Step 8: Smoke Test Verification

**Owner**: Platform Engineering

After provisioning, verify the tenant's branding end-to-end:

```bash
# Verify tenant branding surfaces
./scripts/qa/verify-tenant-branding.sh

# Verify multi-domain resolution
./scripts/qa/verify-branding-multi-domain.sh

# Verify ConfigMap is correct
./scripts/qa/verify-tenant-configmap.sh

# Verify multi-tenancy foundation
./scripts/qa/verify-multi-tenancy-foundation.sh

# Run this document's verification script
./scripts/qa/verify-multi-tenant-branding-ops.sh
```

**Acceptance**: All verify scripts exit 0 before marking the tenant as live.

---

## 3. CI and Runtime Validation

### 3.1 Runtime: Domain Resolution to Branding

Runtime branding resolution follows this path:

```
HTTP request arrives at Caddy
  → Caddy routes by Host header to LMS/MFE pod
    → Django TenantResolutionMiddleware resolves tenant from request domain
      → TenantSiteConfiguration.mfe_config served to MFE
        → MFE env.config.jsx reads LOGO_URL, SITE_NAME, PLATFORM_NAME
          → MerekaFooter reads SITE_VARIANTS[window.location.hostname]
            → Tenant-specific brand rendered to user
```

The middleware (`infrastructure/tutor/plugins/multi-tenancy/middleware.py`) uses `request.get_host()` to look up the active `TenantConfig`, then injects branding into the request context.

### 3.2 CI Jobs and Coverage

The following CI jobs in `.github/workflows/ci.yml` protect multi-tenant branding:

| Verify Script | AC Coverage | What It Checks |
|---------------|-------------|----------------|
| `verify-tenant-branding-contract.sh` | TENANT branding ACs | Brand pack schema, fallback rules, MFE config keys |
| `verify-branding-multi-domain.sh` | Multi-domain branding | Domain → branding resolution, alias domain handling |
| `verify-multi-tenancy-foundation.sh` | AC-MTA-001..005 | TenantConfig model, middleware, provision_tenant command |
| `verify-tenant-configmap.sh` | Tenant registry | ConfigMap structure, required fields |
| `verify-tenant-branding.sh` | Tenant brand surfaces | Per-tenant logo/favicon/site-name |
| `verify-tenant-branding-runtime.sh` | Runtime resolution | Middleware integration, tenant context injection |
| `verify-a11y-tenant-branding.sh` | A11y per-tenant | Contrast, focus, accessible tenant logos |
| `verify-plugin-slot-migration-register.sh` | AC-8JAO9 | Plugin slot register + DOM override inventory |
| `verify-branding-token-integrity.sh` | AC-TOK-001..005 | Token cross-check, contrast gate |
| `verify-selector-to-slot-migration.sh` | AC-FRONT-021..025 | Selector → slot migration compliance |
| `verify-multitenant-brand-platform.sh` | Brand platform | End-to-end multi-tenant brand consistency |
| `verify-tenant-branding-matrix.sh` | Branding matrix | Tenant surface coverage matrix |

All scripts in the `monitoring-guardrails` CI job are syntax-checked (`bash -n`) before execution, ensuring no broken scripts reach the cluster.

### 3.3 Branding Regression Detection

1. **Per-commit**: `monitoring-guardrails` job runs `bash -n` syntax check on all verify scripts.
2. **Full pipeline**: Dedicated CI jobs run each branding verify script and fail the pipeline if any check fails.
3. **Screenshot regression**: Optional visual regression via `RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1 ./scripts/branding/run-branding-gates.sh prod`. Screenshots are captured by `scripts/qa/capture-branding-screenshots.sh`.
4. **Runtime monitoring**: PrometheusRule `prometheusrule-tenant-isolation.yaml` monitors tenant resolution errors and branding-related 5xx rates.

### 3.4 Adding a New Verify Script for a New Tenant

When a new tenant is onboarded, extend the following scripts to include the new tenant's domain:

- `scripts/qa/verify-tenant-branding.sh` — add tenant slug/domain to the coverage list
- `scripts/qa/verify-branding-multi-domain.sh` — add alias domains

Then add the new script (if created) to:
1. `monitoring-guardrails` `bash -n` block in `.github/workflows/ci.yml`
2. A dedicated CI job in `ci.yml`

---

## 4. Owner, Signoff, and Escalation

### 4.1 Tenant Branding Ownership

| Tenant | Primary Domain | Branding Owner | Operations Contact |
|--------|---------------|----------------|--------------------|
| **Mereka Academy** | `academyv2.mereka.io` | Platform Engineering | platform@mereka.io |
| **Biji-Biji Initiative** | `academy.biji-biji.com` | Biji-Biji Design Team | ops@biji-biji.com |
| **Skil Our Future** | `skillourfuture.academy.mereka.io` | Platform Engineering (delegated) | platform@mereka.io |

### 4.2 Signoff Requirements for Branding Changes

All branding changes require the following signoff before merging to `main`:

| Change Type | Required Signoff | Method |
|-------------|-----------------|--------|
| New tenant onboarding | Platform Engineering lead | PR approval + verify scripts PASS |
| Logo / favicon update | Design Team + Platform Engineering | Screenshot review in PR |
| SITE_VARIANTS update | Platform Engineering | PR approval + verify scripts PASS |
| _tokens.scss color change | Design Team + Platform Engineering | Screenshot review + contrast gate PASS |
| Caddy/DNS change | Platform Engineering lead | PR approval + DNS propagation verified |
| ConfigMap tenant registry update | Platform Engineering | PR approval |

**Screenshot review process**:
1. Run `RUN_SCREENSHOTS=1 ./scripts/branding/run-branding-gates.sh prod` before PR.
2. Attach screenshots to PR description.
3. Design Team reviews screenshots for visual correctness.
4. Platform Engineering reviews verify script output for gate compliance.

### 4.3 Escalation Path for Branding Regressions

**Definition of branding regression**: A production deployment where a tenant's logo, site name, colors, or footer renders incorrectly compared to the expected brand pack.

**Severity tiers**:

| Severity | Criteria | SLA |
|----------|----------|-----|
| **P1 (Critical)** | Branding for all tenants broken (platform-wide) | 4 hours to resolution |
| **P2 (High)** | Branding broken for one production tenant | 1 business day |
| **P3 (Medium)** | Minor branding drift (wrong color, wrong footer text) | 2 business days |
| **P4 (Low)** | Cosmetic issue (spacing, font weight) | Next sprint |

**Escalation path**:

```
1. Detection:
   - Automated: CI gate failure or PrometheusRule alert fires
   - Manual: Stakeholder reports via Slack or email

2. First response (Platform Engineering, on-call):
   - Check CI pipeline for failing verify scripts
   - Run: ./scripts/qa/verify-tenant-branding.sh
   - Check PrometheusRule alerts: kubectl get prometheusrule -n mereka-lms
   - Review recent merges to main for branding-related changes

3. P1/P2 escalation (if not resolved in 1 hour):
   - Escalate to Platform Engineering lead
   - Notify Design Team lead if visual regression confirmed
   - For domain/DNS issues: escalate to Platform Engineering + Cloudflare account owner

4. Resolution:
   - Fix via GitOps PR (no direct kubectl patching)
   - Re-run verify scripts before merging
   - Confirm PASS across: verify-tenant-branding.sh, verify-branding-multi-domain.sh,
     verify-multi-tenancy-foundation.sh
   - Post-resolution: document in incident log (docs/archive/evidence/operations/)

5. Post-mortem (P1 only):
   - Within 48 hours: root cause analysis
   - Update verify scripts if regression was not caught by existing checks
   - Update this document if process gap was identified
```

### 4.4 Branding Regression Incident Template

Use `docs/guides/branding/BRANDING_INCIDENT_TEMPLATE.md` to document any P1 or P2 branding regression. Complete the template fields before closing the incident.

### 4.5 Contacts

| Role | Contact |
|------|---------|
| Platform Engineering lead | platform@mereka.io |
| Design Team lead | design@mereka.io |
| Tenant Operations | ops@mereka.io |
| Cloudflare account | platform@mereka.io (DNS access) |
| On-call (P1 only) | Check team PagerDuty rotation |

---

_This document is verified by `scripts/qa/verify-multi-tenant-branding-ops.sh` (bead 2dcy.4)._
