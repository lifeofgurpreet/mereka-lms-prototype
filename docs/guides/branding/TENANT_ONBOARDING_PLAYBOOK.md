# Tenant Onboarding Playbook

> **Bead**: mereka-lms-1j86
> **ACs**: AC-UX-150, AC-UX-151, AC-UX-152, AC-UX-153, AC-UX-154
> **Audience**: Platform Engineering + Enterprise Ops
> **Owner**: platform-engineering
> **Last Updated**: 2026-02-19

**This is the single entry-point playbook for onboarding new enterprise tenants onto Mereka Academy Open edX.**

Related deep-dive docs (read before implementing):
- [`MULTI_TENANT_BRANDING_OPS.md`](MULTI_TENANT_BRANDING_OPS.md) — Full branding ops model (layers, per-tenant runbook, CI, escalation)
- [`TENANT_BRANDING_CONTRACT.md`](TENANT_BRANDING_CONTRACT.md) — Required inputs, RAG matrix, brand pack schema
- [`BRANDING_OPERATING_MODEL.md`](BRANDING_OPERATING_MODEL.md) — Change types, signoff, change queue
- [`../../ops/runbooks/VISUAL_PARITY_CHECKPOINTS.md`](../../ops/runbooks/VISUAL_PARITY_CHECKPOINTS.md) — Visual release gates
- [`docs/archive/superseded/runbooks/tenant-provisioning-runbook.md`](../../archive/superseded/runbooks/tenant-provisioning-runbook.md) — K8s provisioning runbook
- [`specs/multi-tenancy-architecture_spec.md`](../../../specs/multi-tenancy-architecture_spec.md) — Architecture spec (Tier 4.1)

---

## AC-UX-150: Required Config Keys and Ownership

### Minimum Required Inputs for a New Tenant

| Key | Location | Required | Example |
|-----|----------|----------|---------|
| Tenant slug | `provision_tenant --slug` | ✅ | `client-corp` |
| Tenant name | `provision_tenant --name` | ✅ | `"Client Corp"` |
| Tenant domain | `provision_tenant --domain` | ✅ | `client.academyv2.mereka.io` |
| Contact email | `provision_tenant --contact-email` | ✅ | `admin@clientcorp.com` |
| Country | `provision_tenant --country` | ✅ | `MY` |
| DNS record | Cloudflare + K8s Ingress | ✅ | `client.academyv2.mereka.io → rke2-prod ingress` |
| Caddy host block | `deploy/k8s/base/apps/caddy/Caddyfile` | ✅ | `http://client.academyv2.mereka.io { ... }` |
| ALLOWED_HOSTS entry | `infrastructure/tutor/apply-patches.sh` | ✅ | Added to CSRF_TRUSTED_ORIGINS list |
| SITE_VARIANTS entry | `infrastructure/tutor/plugins/mereka_lms.py` | ✅ | `'client.academyv2.mereka.io': { brand: '...', ... }` |
| Logo assets | Theme static dir or ConfigMap | ✅ | `logo.png`, `logo-horizontal.png`, `favicon.ico` |
| `configmap-tenants.yaml` entry | `deploy/k8s/base/apps/` | ✅ | `slug: client-corp` |

### Optional Per-Tenant Overrides

| Key | Location | Purpose |
|-----|----------|---------|
| `_tokens.scss` overrides | `infrastructure/tutor/themes/mereka/lms/static/` | Brand color/font token overrides |
| Plugin slot config | `mereka_lms.py` `PLUGIN_SLOTS.add_item(...)` | Custom header/footer/sidebar widget |
| ExternalSecret entry | `deploy/k8s/base/secrets/external-secrets.yaml` | Tenant-specific secrets |
| Enterprise SSO (SAML/OIDC) | `enterprise-sso-secrets` ExternalSecret | If SAML IdP required |

### Ownership

| Role | Responsibility |
|------|---------------|
| Platform Engineering | DNS, Caddy, K8s manifests, apply-patches.sh, mereka_lms.py |
| Design | Logo assets, color tokens, brand pack schema |
| Enterprise Ops | Tenant contact, contract, credential handover |
| Engineering Lead | Signoff for production deployment |

---

## AC-UX-151: Existing Tenant Path Validation

### Active Tenants

| Tenant | Domain | SITE_VARIANTS | Logo Path | Status |
|--------|--------|--------------|-----------|--------|
| Mereka Academy | `academyv2.mereka.io` | `academyv2.mereka.io` entry | `static/mereka/images/logo.png` | ✅ LIVE |
| Biji-Biji Initiative | `academy.biji-biji.com` | `academy.biji-biji.com` entry | `static/mereka/images/logo.png` (shared) | ✅ LIVE |
| Skill Our Future | `skillourfuture.academy.mereka.io` | `skillourfuture.academy.mereka.io` entry | Themed logo URL confirmed | ✅ LIVE |

### Validation Evidence

All three tenants validated live on 2026-02-19:
- HTTP 200 on all landing pages ✅
- MFE authn bundle serving correctly ✅
- `verify-multi-tenant-branding-ops.sh`: PASS 19/19 ✅
- `verify-tenant-branding-contract.sh`: PASS 38/38 ✅
- `verify-visual-parity-checkpoints.sh`: PASS 42/42 ✅

### Biji-Biji (`academy.biji-biji.com`) Path

1. Domain registered in Cloudflare (DNS-only, gray cloud — multi-level subdomain)
2. Caddy host block in `deploy/k8s/base/apps/caddy/Caddyfile` proxies to LMS
3. `SITE_VARIANTS` entry: `{ brand: 'Biji-Biji Academy', copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' }`
4. `ALLOWED_HOSTS` + `CSRF_TRUSTED_ORIGINS` includes `academy.biji-biji.com`
5. TenantConfig provisioned via `provision_tenant.sh`

### Skillourfuture (`skillourfuture.academy.mereka.io`) Path

1. Subdomain under `academyv2.mereka.io` on rke2-prod — same wildcard cert
2. `SITE_VARIANTS` entry: `{ brand: 'Skill Our Future Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' }`
3. Themed logo URL confirmed serving (homepage_logo_url contains `skillourfuture` hostname)
4. MFE config serves correctly via `/api/mfe_config/v1`

---

## AC-UX-152: Plugin-First Pattern + Deprecated Patching Boundaries

### Plugin-First Principle (ADR-014)

All UI customizations MUST flow through Tutor plugin hooks. Direct modification of Open edX source files or built MFE output is prohibited.

| ✅ Allowed | ❌ Prohibited |
|------------|---------------|
| `hooks.Filters.ENV_PATCHES.add_item("mfe-env-config", ...)` | Editing `tutor_env/env/plugins/mfe/build/mfe/env.config.jsx` directly |
| `hooks.Filters.CONFIG_DEFAULTS.add_items(...)` | Hardcoding values in `tutor_env/config.yml` |
| `apply-patches.sh` for Tutor-generated template patching | Patching upstream edx-platform Python/Mako files |
| `PLUGIN_SLOTS.add_item(...)` when `tutormfe.hooks` available | String-replacing compiled MFE JS bundles |
| SCSS overrides via Indigo theme + `_tokens.scss` | Overriding Paragon component internals via `!important` chains |

### apply-patches.sh Boundary

`apply-patches.sh` is acceptable **only** for:
1. Patching **Tutor-generated files** (`tutor_env/env/`) that are regenerated on `tutor config save`
2. Fixing upstream bugs that cannot be addressed via Tutor hooks
3. Migration debt while waiting for upstream slot support (e.g., footer_slot pending `tutormfe.hooks`)

**Not acceptable**:
- Patching committed repo files (use PR instead)
- Patching enterprise MFE images (use initContainer sanitization instead — see `admin-portal-deployment.yaml`)
- Bypassing `PLUGIN_SLOTS` when the hook is available

### Current Deprecation Status

| Approach | Status | Replacement |
|----------|--------|-------------|
| `apply-patches.sh` footer block (165 lines) | ACTIVE — migration debt | Remove when `tutormfe.hooks.PLUGIN_SLOTS` available (Tutor v22+) |
| CSS `.navbar .navbar-brand` logo override | ACTIVE — HIGH risk | Replace with `header_logo_slot` PLUGIN_SLOTS wiring |
| SCSS `[data-testid*="learner-dashboard"]` | ACTIVE — HIGH risk | Replace with `learner_dashboard.sidebar.v1` PLUGIN_SLOTS |
| `sanitize-enterprise-index-html` initContainer | ACTIVE — VALID | Permanent until enterprise MFE rebuilt with `ENABLE_NEW_RELIC=false` |

---

## AC-UX-153: QA Command Set for Tenant Landing Page + A11y Smoke

### Quick tenant validation (run after onboarding a new tenant):

```bash
# 1. Branding health (assets, tokens, CSS)
bash scripts/qa/verify-branding-health.sh

# 2. Multi-tenant branding ops model compliance
bash scripts/qa/verify-multi-tenant-branding-ops.sh

# 3. Tenant branding contract (RAG matrix)
bash scripts/qa/verify-tenant-branding-contract.sh

# 4. MFE branding (bundle markers, font loading, CSS)
bash scripts/qa/verify-mfe-branding.sh

# 5. Visual parity checkpoints (release gate)
bash scripts/qa/verify-visual-parity-checkpoints.sh

# 6. A11y contrast + focus
bash scripts/qa/verify-a11y-contrast-focus.sh

# 7. Tenant UI smoke (CI gate)
bash scripts/qa/verify-tenant-ui-smoke.sh

# 8. Public URL smoke (live cluster check for all domains)
bash scripts/qa/verify-public-branding.sh

# 9. Enterprise MFE NREUM regression guard
bash scripts/qa/verify-enterprise-mfe-nreum-clean.sh

# 10. Full a11y regression lane
bash scripts/qa/verify-a11y-regression-lane.sh
```

### Expected results for a healthy tenant

| Script | Expected |
|--------|---------|
| `verify-branding-health.sh` | PASS 3/3 |
| `verify-multi-tenant-branding-ops.sh` | PASS 19/19 |
| `verify-tenant-branding-contract.sh` | PASS 38/38 |
| `verify-mfe-branding.sh` | PASS ≥50 |
| `verify-visual-parity-checkpoints.sh` | PASS ≥40 |
| `verify-a11y-contrast-focus.sh` | PASS ≥25, FAIL 0 |
| `verify-tenant-ui-smoke.sh` | PASS 33/33 |
| `verify-public-branding.sh` | Tenant domain returns HTTP 200 |
| `verify-enterprise-mfe-nreum-clean.sh` | PASS (or SKIP if no enterprise portals) |

### Screenshot capture (operator-triggered, not CI)

```bash
# Capture baseline screenshots for all tenant landing pages
bash scripts/qa/capture-branding-screenshots.sh
# Output: var/smoke/screenshots/YYYY-MM-DD/
```

---

## AC-UX-154: Engineering → Ops Handoff Checklist

Use this checklist when handing off a new tenant from engineering to operations.

### Pre-Handoff (Engineering completes)

- [ ] `provision_tenant.sh` run successfully (idempotent, no errors)
- [ ] DNS record live and resolving to rke2-prod ingress
- [ ] Caddy host block deployed and routing correctly (`curl -I https://new-tenant.domain/`)
- [ ] `SITE_VARIANTS` entry in `mereka_lms.py` merged and deployed
- [ ] Logo assets in theme static dir or ConfigMap (logo.png, favicon.ico)
- [ ] `verify-public-branding.sh` → new tenant domain returns HTTP 200
- [ ] `verify-mfe-branding.sh` → PASS (no font/CSS failures)
- [ ] `verify-a11y-contrast-focus.sh` → PASS (contrast compliance confirmed)
- [ ] Screenshot baseline captured (`capture-branding-screenshots.sh`)
- [ ] Evidence doc created in `docs/archive/evidence/operations/` with all verify outputs
- [ ] ArgoCD sync verified (no OutOfSync apps)

### Handoff Deliverables (Engineering → Ops)

- [ ] Tenant slug + domain confirmed
- [ ] Admin user credentials (created via `manage.py createsuperuser`)
- [ ] LMS URL + Studio URL + MFE URL
- [ ] SAML/SSO configuration (if applicable) — cert/key in GCP SM
- [ ] Branding assets archive (logo.png, favicon, tokens.scss)
- [ ] Evidence doc path in repo
- [ ] Screenshot baseline path (`var/smoke/screenshots/`)
- [ ] Known WARNs and their resolution timelines

### Post-Handoff (Operations confirms)

- [ ] Admin login works on new tenant domain
- [ ] Course catalog visible
- [ ] Branding renders correctly (logo, footer, colors)
- [ ] Mobile responsive check
- [ ] Enterprise SSO login tested (if configured)
- [ ] Support contact configured in SITE_VARIANTS (whatsapp, email)

### Escalation

If any item fails post-handoff:
1. **P1 (site down)**: Ping Engineering Lead immediately → 30-min SLA
2. **P2 (branding wrong)**: Create `docs/guides/branding/BRANDING_INCIDENT_TEMPLATE.md` entry → 4-hour SLA
3. **P3 (cosmetic)**: File GitHub issue → next sprint
4. **P4 (future enhancement)**: Add to `docs/status/active/BRANDING_ROADMAP_2026-02-08.md`
