# Tenant Config Handoff Guide

_Last updated: 2026-02-27_
_Audience: Platform Engineering, Tenant Onboarding_
_Bead: 31yg_
_ACs: AC-UI-601, AC-UI-602, AC-UI-603, AC-UI-604, AC-UI-605_

This guide defines the end-to-end handoff path for multi-tenant branding configuration in
Mereka LMS. It covers asset precedence, the new-tenant onboarding checklist, validation
commands, rollback and recovery actions, and links to related subsystem docs.

---

## AC-UI-601: Per-Tenant Asset and Config Precedence

### Asset Resolution Order

When the platform renders a page for a given hostname, branding assets are resolved in this
order (last match wins):

1. **Platform defaults** — `assets/branding/tokens.css`, `assets/branding/logo-mereka.svg`
2. **Tenant base** — `infrastructure/tutor/themes/mereka/` SCSS variables and overrides
3. **Domain-specific** — `SITE_VARIANTS[hostname]` in `infrastructure/tutor/plugins/mereka_lms.py`

If no domain-specific entry exists, the platform base branding is used. This means each
layer can be omitted to inherit from the layer above.

### Domain Mapping

Every hostname must be mapped in the `SITE_VARIANTS` dictionary inside `mereka_lms.py`:

```python
SITE_VARIANTS = {
    "academyv2.mereka.io": {
        "brand_name": "Mereka Academy",
        "copyright_holder": "Mereka Sdn Bhd",
        "whatsapp": "+60123456789",
        "logo_path": "mereka/images/logo-mereka.svg",
    },
    "academy.biji-biji.com": {
        "brand_name": "Biji-Biji Academy",
        "copyright_holder": "Biji-Biji Initiative",
        "whatsapp": "+60198765432",
        "logo_path": "mereka/images/logo-biji-biji.svg",
    },
}
```

The hostname key must match exactly what Caddy or the Ingress passes in the `Host` header.
The `SITE_VARIANTS` key is the lookup used by `MerekaFooter` at render time.

### Plugin Override Chain

Branding overrides flow through this chain:

```
mereka_lms.py (PLUGIN_SLOTS)
  └── footer_slot          ← per-tenant brand name, copyright, WhatsApp
  └── header_logo_slot     ← per-tenant logo
  └── learner_dashboard.sidebar.v1  ← sidebar CTA (shared)
      └── env.config.jsx (mfe-env-config patch)
          └── MerekaFooter component (reads window.location.hostname → SITE_VARIANTS)
```

Per-tenant widget overrides are defined inline in the `MerekaFooter` component JSX, keyed
by `window.location.hostname`. No separate per-tenant file is required; all variants live
in the single plugin file.

### Config Files Involved

| File | Role |
|------|------|
| `assets/branding/tokens.css` | Platform-wide design tokens (colour, spacing, typography) |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | MFE SCSS overrides (references `_tokens.scss`) |
| `infrastructure/tutor/themes/mereka/mfe/_tokens.scss` | SCSS token aliases for MFE build |
| `infrastructure/tutor/plugins/mereka_lms.py` | `SITE_VARIANTS` map, `PLUGIN_SLOTS`, `MerekaFooter` |
| `deploy/k8s/base/apps/` | K8s ConfigMaps (tenant registry, LMS settings) |
| `infrastructure/tutor/plugins/multi-tenancy/` | Django `TenantConfig` model and middleware |

---

## AC-UI-602: New Tenant Onboarding Checklist

Follow these steps in order when onboarding a new tenant. Each step has a verification
command to confirm completion before proceeding.

### Step 1 — Register domain/hostname in DNS (Cloudflare)

Add an A or CNAME record pointing the new tenant domain to the cluster LoadBalancer IP or
Cloudflare Tunnel endpoint.

- For `*.mereka.dev` subdomains: orange-cloud (Cloudflare proxied) is fine.
- For multi-level subdomains (e.g., `tenant.academy.mereka.io`): use DNS-only (gray cloud)
  and provision a Let's Encrypt cert via cert-manager.

```bash
# Verify DNS resolves
dig +short <tenant-domain>
```

### Step 2 — Add hostname to Caddy/Ingress routing

Update the Caddyfile patch in `infrastructure/tutor/apply-patches.sh` or the Ingress
manifest in `deploy/k8s/base/apps/` to accept the new hostname:

```bash
# Verify domain mapping in apply-patches.sh
grep '<tenant-domain>' infrastructure/tutor/apply-patches.sh
```

### Step 3 — Add SITE_VARIANTS entry in mereka_lms.py

Add the new hostname to the `SITE_VARIANTS` dict in
`infrastructure/tutor/plugins/mereka_lms.py`:

```python
"<tenant-domain>": {
    "brand_name": "<Brand Name>",
    "copyright_holder": "<Legal Entity>",
    "whatsapp": "<+country-number>",
    "logo_path": "mereka/images/logo-<slug>.svg",
},
```

```bash
# Verify SITE_VARIANTS entry exists
grep '<tenant-domain>' infrastructure/tutor/plugins/mereka_lms.py
```

### Step 4 — Configure tenant-specific assets (logo, favicon, CSS variables)

Copy the tenant logo to `infrastructure/tutor/themes/mereka/lms/static/images/` and the
favicon to `infrastructure/tutor/themes/mereka/lms/static/images/`. CSS variable overrides
that differ from the platform defaults belong in a per-tenant SCSS partial referenced from
`mereka.scss`.

```bash
# Verify logo file exists
ls infrastructure/tutor/themes/mereka/lms/static/images/logo-<slug>.svg
```

### Step 5 — Create/update tenant ConfigMap entry

Add a `TenantConfig` entry in the tenant registry ConfigMap at
`deploy/k8s/base/apps/tenant-registry-configmap.yaml` (if applicable):

```yaml
tenants:
  - hostname: <tenant-domain>
    site_id: <N>
    brand_slug: <slug>
```

Apply to cluster:

```bash
kubectl apply -f deploy/k8s/base/apps/tenant-registry-configmap.yaml -n mereka-lms
```

### Step 6 — Run provision-tenant.sh

If this is a K8s-managed tenant:

```bash
./scripts/tenants/provision-tenant.sh <tenant-domain>
```

### Step 7 — Re-run apply-patches.sh and rebuild MFE

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./infrastructure/tutor/apply-patches.sh
tutor images build mfe
tutor local restart
```

### Step 8 — Verify domain mapping

```bash
# Verify the domain resolves and returns HTTP 200
curl -sI https://<tenant-domain> | head -5
```

Expected: `HTTP/2 200` (or `HTTP/1.1 200`).

### Step 9 — Verify branding: footer shows correct brand name

```bash
# Verify the footer brand name is served correctly
curl -s https://<tenant-domain> | grep -i "<Brand Name>"
```

### Step 10 — Screenshot review and signoff

Capture screenshots of:
- Homepage footer
- Login page
- Dashboard

Confirm the correct logo, brand name, copyright holder, and colour scheme appear. Get
signoff from the tenant stakeholder before marking the onboarding complete.

---

## AC-UI-603: Validation Commands

Use these commands to validate a tenant's branding and plugin config.

### Domain resolution

```bash
# Verify tenant domain resolves correctly
curl -sI https://<tenant-domain> | head -5
```

### SITE_VARIANTS entry

```bash
# Verify SITE_VARIANTS entry exists in mereka_lms.py
grep '<tenant-domain>' infrastructure/tutor/plugins/mereka_lms.py
```

### MerekaFooter host variant coverage

```bash
# Verify the MerekaFooter component covers the new hostname
grep 'SITE_VARIANTS' infrastructure/tutor/plugins/mereka_lms.py | head -3
```

### Design token integrity

```bash
# Verify _tokens.scss references the platform token file
grep 'tokens' infrastructure/tutor/themes/mereka/mfe/_tokens.scss | head -5
```

### Existing verify scripts

```bash
# Full footer slot evidence + rollback guard (bead 2dcy.8)
./scripts/qa/verify-footer-slot-evidence-rollback.sh

# Multi-tenant branding ops validation
./scripts/qa/verify-tenant-branding-contract.sh

# Tenant brand pack schema
./scripts/qa/verify-brand-pack-schema.sh

# Plugin-slot wiring chain
./scripts/qa/verify-plugin-slot-wiring.sh

# Token drift guard (undefined CSS variable references)
./scripts/qa/verify-token-drift.sh
```

### This guide's own verification script

```bash
./scripts/qa/verify-tenant-config-handoff.sh
```

---

## AC-UI-604: Rollback and Recovery Actions

### Rollback: misconfigured domain

If a SITE_VARIANTS entry causes incorrect branding or a broken render:

```bash
# 1. Revert the commit that added the bad entry
git log --oneline --grep="<tenant-slug>" | head -3
git revert <commit-sha>

# 2. Re-run patches
export TUTOR_ROOT="$(pwd)/tutor_env"
./infrastructure/tutor/apply-patches.sh

# 3. Rebuild and restart MFE
tutor images build mfe
tutor local restart
```

### Recovery: broken branding (fallback brand)

If the SITE_VARIANTS lookup fails for a hostname, `MerekaFooter` falls back to the
platform default brand (Mereka Academy). No action is required to activate the fallback —
the component's default case in the `SITE_VARIANTS` lookup handles it automatically.

To confirm the fallback is active:

```bash
curl -s https://<tenant-domain> | grep -i "Mereka Academy"
```

### Rollback: ConfigMap misconfiguration

If the tenant-registry ConfigMap causes LMS startup failures:

```bash
# Roll back the LMS deployment to the previous revision
kubectl rollout undo deployment/lms -n mereka-lms

# Verify rollback succeeded
kubectl rollout status deployment/lms -n mereka-lms
```

### Emergency rollback: full plugin revert

If the entire `mereka_lms.py` plugin needs to be reverted:

```bash
# Find the last known-good commit for the plugin
git log --oneline -- infrastructure/tutor/plugins/mereka_lms.py | head -5

# Revert
git revert <commit-sha>

# Re-apply patches and restart
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

The `try/except ImportError` guard in `mereka_lms.py` ensures the plugin degrades safely
if `tutormfe.hooks.PLUGIN_SLOTS` is unavailable (e.g., after a Tutor version change):

```python
try:
    from tutormfe.hooks import PLUGIN_SLOTS
    PLUGIN_SLOTS.add_item(("footer_slot", { ... }))
    _PLUGIN_SLOTS_AVAILABLE = True
except ImportError:
    _PLUGIN_SLOTS_AVAILABLE = False
```

Check the `_PLUGIN_SLOTS_AVAILABLE` flag in logs to confirm whether slot wiring is active.

---

## AC-UI-605: Enterprise Host and Subsystem Mappings

### Related Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| Multi-Tenant Branding Ops | `docs/operations/MULTITENANT_BRAND_PLATFORM.md` | Brand platform gate, per-tenant branding matrix |
| Branding Operating Model | `docs/guides/branding/BRANDING_OPERATING_MODEL.md` | Canonical branding workflow, non-negotiable rules |
| Tenant Branding Contract | `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` | Contract between tenant config and rendering layer |
| Brand Pack Schema | `docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md` | Required fields for a tenant brand pack |
| Legacy Footer Removal | `docs/operations/LEGACY_FOOTER_REMOVAL.md` | Rollback steps for footer slot migration |
| Multisite Config | `docs/concepts/architecture/MULTISITE.md` | Hostname routing and SITE_ID configuration |
| Enterprise Navigation | `docs/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md` | Enterprise host mapping and navigation |

### Plugin and Config Files

| File | Purpose |
|------|---------|
| `infrastructure/tutor/plugins/mereka_lms.py` | Central plugin: `SITE_VARIANTS`, `PLUGIN_SLOTS`, `MerekaFooter` |
| `infrastructure/tutor/plugins/multi-tenancy/` | Django app: `TenantConfig`, `TenantResolutionMiddleware` |
| `deploy/k8s/base/apps/` | K8s ConfigMaps including tenant registry |
| `assets/branding/tokens.css` | Platform-wide design tokens |
| `infrastructure/tutor/themes/mereka/mfe/_tokens.scss` | MFE SCSS token aliases |

### Enterprise Host Reference

| Hostname | Brand | Notes |
|----------|-------|-------|
| `academyv2.mereka.io` | Mereka Academy | Primary enterprise host |
| `academy.biji-biji.com` | Biji-Biji Academy | Learner-facing host |
| `skillourfuture.academy.mereka.io` | Skill Our Future | Government programme host |

For the full subsystem mapping (Studio, MFEs, discovery, forum), see
`docs/concepts/architecture/MULTISITE.md` and the Caddyfile template in
`infrastructure/tutor/apply-patches.sh`.
