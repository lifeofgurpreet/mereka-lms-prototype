# Tenant Onboarding Playbook

**Status**: Active
**Last Updated**: 2026-02-18

## Overview

This playbook covers adding a new tenant subsite to Mereka Academy. A tenant gets its own domain, SiteConfiguration, organization, course catalog filter, and footer branding variant — all sharing the same Open edX LMS instance.

## Prerequisites

- kubectl access to `mereka-lms` namespace
- Push access to `mereka-lms` and `bbi-infrastructure` repos
- DNS control for the new domain (Cloudflare or external)

## Current Tenants

| Domain | Slug | Org | MFE Subdomain | CMS |
|--------|------|-----|---------------|-----|
| `academyv2.mereka.io` | mereka | MEREKA | `apps.academyv2.mereka.io` | `studio.academyv2.mereka.io` |
| `academy.biji-biji.com` | bijibiji | BIJIBIJI | `apps.academy.biji-biji.com` | Shared (studio.academyv2.mereka.io) |
| `skillourfuture.academy.mereka.io` | skillourfuture | SKILLOURFUTURE | Shared (`apps.academyv2.mereka.io`) | Shared (studio.academyv2.mereka.io) |

---

## Step 1: Plan Domain Mapping

Decide the domain structure for the new tenant:

```
# Option A: Subdomain of primary (recommended for internal tenants)
newclient.academy.mereka.io
apps.newclient.academy.mereka.io  # Only if dedicated MFE subdomain needed

# Option B: Custom domain (for partner-branded tenants)
academy.newclient.com
apps.academy.newclient.com        # Only if dedicated MFE subdomain needed
```

**Decision checklist**:
- [ ] Does the tenant need its own MFE subdomain? (Most share `apps.academyv2.mereka.io`)
- [ ] Does the tenant need a custom CMS/Studio URL? (Most share `studio.academyv2.mereka.io`)
- [ ] Is the domain a subdomain of `mereka.io` (Cloudflare managed) or external?

## Step 2: DNS Setup

### Mereka subdomain (Cloudflare-managed)

```bash
# Add CNAME pointing to the GKE ingress
# Cloudflare dashboard → mereka.io → DNS Records
# Type: CNAME, Name: newclient.academy, Content: academyv2.mereka.io
# Proxy: DNS-only (gray cloud) — required for Let's Encrypt cert
```

### External domain

The partner must add a CNAME record pointing to `academyv2.mereka.io` and set it to DNS-only mode.

## Step 3: Add to Site Registry

Edit `infrastructure/tutor/multisite-sites.yml`:

```yaml
# Add organization
organizations:
  # ... existing orgs ...
  - short_name: NEWCLIENT
    name: New Client Academy
    description: New Client microsite catalog.

# Add site
sites:
  # ... existing sites ...
  - domain: newclient.academy.mereka.io
    name: New Client Academy
    orgs:
      - NEWCLIENT
    site_values:
      domain: newclient.academy.mereka.io
      site_name: New Client Academy
      platform_name: New Client Academy
      LMS_ROOT_URL: https://newclient.academy.mereka.io
      CMS_ROOT_URL: https://studio.academyv2.mereka.io      # Shared Studio
      MFE_BASE_URL: https://apps.academyv2.mereka.io         # Shared MFE
      THEME_NAME: mereka
      ENABLE_COMPREHENSIVE_THEMING: true
      course_org_filter:
        - NEWCLIENT
      logo_image: https://newclient.academy.mereka.io/static/mereka/images/logo-horizontal.png
      logo_url: /
      favicon_path: mereka/images/favicon.ico
      homepage_banner_enabled: false
```

## Step 4: Add to Django Settings

Edit `infrastructure/tutor/apply-patches.sh`:

```python
# Add to extra_lms_hosts list
extra_lms_hosts = [
    "academy.biji-biji.com",
    "skillourfuture.academy.mereka.io",
    "newclient.academy.mereka.io",         # <-- ADD
]

# Add to extra_csrf_origins list
extra_csrf_origins = [
    "https://academy.biji-biji.com",
    "https://apps.academy.biji-biji.com",
    "https://skillourfuture.academy.mereka.io",
    "https://newclient.academy.mereka.io",  # <-- ADD
]
```

If the tenant has a dedicated MFE subdomain, also add it to `extra_csrf_origins`:
```python
    "https://apps.newclient.academy.mereka.io",  # Only if dedicated MFE
```

## Step 5: Add Footer Variant

Edit `infrastructure/tutor/plugins/mereka_lms.py`, find the `SITE_VARIANTS` object in MerekaFooter:

```javascript
const SITE_VARIANTS = {
  'academyv2.mereka.io': { brand: 'Mereka Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
  'academy.biji-biji.com': { brand: 'Biji-Biji Academy', copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },
  'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
  'newclient.academy.mereka.io': { brand: 'New Client Academy', copyrightHolder: 'New Client', whatsapp: '601135271981' },  // <-- ADD
};
```

## Step 6: Provision Tenant

Run the provisioning script:

```bash
./scripts/tenants/provision-tenant.sh \
  --slug newclient \
  --name "New Client Academy" \
  --domain newclient.academy.mereka.io \
  --contact-email admin@newclient.com \
  --country MY
```

Or dry-run first:
```bash
./scripts/tenants/provision-tenant.sh \
  --slug newclient \
  --name "New Client Academy" \
  --domain newclient.academy.mereka.io \
  --dry-run
```

This creates:
- Django Site + SiteConfiguration
- Organization (if not exists)
- EnterpriseCustomer record
- TenantConfig record (multi-tenancy plugin)

## Step 7: Commit and Deploy

Follow the merge-first protocol (see `docs/operations/MERGE_FIRST_DEPLOYMENT_PROTOCOL.md`):

```bash
# 1. Create feature branch
git checkout -b feat/tenant-newclient

# 2. Commit changes
git add infrastructure/tutor/multisite-sites.yml \
       infrastructure/tutor/apply-patches.sh \
       infrastructure/tutor/plugins/mereka_lms.py
git commit -m "feat(tenancy): onboard newclient tenant"

# 3. Push and create PR
git push -u origin feat/tenant-newclient
gh pr create --title "feat(tenancy): onboard newclient" --body "..."

# 4. Merge to main
gh pr merge --merge --delete-branch

# 5. If image rebuild needed (theme/MFE changes):
#    Follow BRANDING_RELEASE_RUNBOOK.md steps 1-3
```

## Step 8: Verify

```bash
# Runtime branding check (all domains including new one)
./scripts/qa/verify-tenant-branding-runtime.sh

# MFE config for new domain
curl -s https://newclient.academy.mereka.io/api/mfe_config/v1 | python3 -m json.tool

# Expected output includes:
# "SITE_NAME": "New Client Academy"
# "LMS_BASE_URL": "https://newclient.academy.mereka.io"

# Full multisite governance (prod only)
./scripts/qa/run-multisite-governance-gates.sh --env prod

# Tenant isolation verification
./scripts/qa/verify-tenant-isolation.sh
```

---

## Rollback

If the new tenant breaks existing domains:

### Quick rollback (< 5 min)

```bash
# 1. Disable SiteConfiguration in Django admin
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c "
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
site = Site.objects.get(domain='newclient.academy.mereka.io')
sc = SiteConfiguration.objects.get(site=site)
sc.enabled = False
sc.save()
print('Disabled SiteConfiguration for newclient.academy.mereka.io')
"

# 2. Verify existing domains still work
for domain in academyv2.mereka.io academy.biji-biji.com skillourfuture.academy.mereka.io; do
  echo "$domain: $(curl -so /dev/null -w '%{http_code}' https://$domain/api/mfe_config/v1)"
done
```

### Full rollback (revert code changes)

```bash
# 1. Revert the commit
git revert HEAD
git push

# 2. ArgoCD auto-syncs the revert
# 3. Verify all domains
./scripts/qa/verify-tenant-branding-runtime.sh
```

---

## Domain Governance Rules

1. **One domain per tenant**: Each tenant gets exactly one primary LMS domain
2. **Shared infrastructure**: All tenants share Studio (`studio.academyv2.mereka.io`), Redis, MySQL, MongoDB
3. **Course isolation**: Use `course_org_filter` in SiteConfiguration to restrict visible courses per domain
4. **Cookie isolation**: `SESSION_COOKIE_DOMAIN = None` (host-only) — no cross-domain cookie leakage
5. **CSRF isolation**: Each domain's HTTPS origin must be in `CSRF_TRUSTED_ORIGINS`
6. **Footer branding**: MerekaFooter SITE_VARIANTS map provides per-domain brand text at runtime
7. **Logo/theme**: All tenants currently share the `mereka` theme. Custom themes are Phase 2 scope.

---

## Verification Command Matrix (AC-US7-102)

Run these commands after onboarding a new tenant. Each command must PASS before rollout.

| # | Command | Scope | Expected | Fixture |
|---|---------|-------|----------|---------|
| 1 | `./scripts/qa/verify-tenant-branding-runtime.sh` | All domains | PASS 13+ / FAIL 0 | Checks SITE_NAME, LOGO_URL, LMS_BASE_URL, footer variant per domain |
| 2 | `./scripts/qa/verify-mfe-branding.sh` | MFE pod + dist | PASS 47+ / FAIL 0 | Checks theme CSS, favicon, logo, brand color absence, asset integrity |
| 3 | `./scripts/qa/verify-multisite-ux-consistency.sh` | Repo + pod | PASS 18+ / FAIL 0 | Checks for hardcoded domains, dynamic config, CI gates |
| 4 | `./scripts/qa/verify-tenant-isolation.sh` | K8s cluster | PASS 42+ / FAIL 0 | Checks SiteConfiguration, org ownership, course filter |
| 5 | `./scripts/qa/verify-mfe-route-smoke.sh` | All MFE routes | PASS 24+ / FAIL 0 | HTTP smoke for all Caddyfile routes + a11y checks |
| 6 | Domain route smoke (inline) | 3 tenant hosts | HTTP 200 each | See below |

### Domain route smoke (one-liner)

```bash
for domain in academyv2.mereka.io academy.biji-biji.com skillourfuture.academy.mereka.io; do
  code=$(curl -so /dev/null -w "%{http_code}" "https://$domain/" 2>/dev/null)
  mfe=$(curl -so /dev/null -w "%{http_code}" "https://$domain/api/mfe_config/v1" 2>/dev/null)
  echo "$domain: LMS=$code MFE_CONFIG=$mfe"
done
```

Expected: `LMS=200 MFE_CONFIG=200` for each domain.

### Per-tenant MFE config fixture

```bash
# Extract key fields for evidence
curl -s "https://<domain>/api/mfe_config/v1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in ['SITE_NAME', 'LMS_BASE_URL', 'LOGO_URL', 'FAVICON_URL']:
    print(f'  {k}: {d.get(k, \"MISSING\")}')
"
```

---

## Drift Repair Commands (AC-US7-103)

### SiteConfiguration drift

**Symptom**: Domain returns wrong SITE_NAME or default Open edX branding.

```bash
# Check current SiteConfiguration
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c "
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
for sc in SiteConfiguration.objects.filter(enabled=True):
    print(f'{sc.site.domain}: {sc.site_values.get(\"SITE_NAME\", \"UNSET\")}')
"

# Repair: re-provision the tenant
./scripts/tenants/provision-tenant.sh \
  --slug <slug> --name "<name>" --domain <domain>
```

**Owner**: Platform team. **Evidence**: Before/after output of SiteConfiguration query.

### ALLOWED_HOSTS / CSRF drift

**Symptom**: 400 Bad Request or 403 CSRF Forbidden on new domain.

```bash
# Check if domain is in ALLOWED_HOSTS
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c "
from django.conf import settings
print([h for h in settings.ALLOWED_HOSTS if 'newclient' in h])
print([o for o in settings.CSRF_TRUSTED_ORIGINS if 'newclient' in o])
"

# Repair: re-run apply-patches.sh and rebuild
./infrastructure/tutor/apply-patches.sh
# Then follow BRANDING_RELEASE_RUNBOOK.md for image rebuild + deploy
```

**Owner**: Infrastructure team. **Evidence**: grep output from production.py settings.

### Footer variant missing

**Symptom**: Footer shows "Mereka Academy" instead of tenant-specific brand.

```bash
# Check SITE_VARIANTS in MFE pod
kubectl exec -n mereka-lms deploy/mfe -- \
  grep -o "'[a-z.]*.mereka.io'" /openedx/env.config.js 2>/dev/null | sort -u

# Repair: add domain to SITE_VARIANTS in mereka_lms.py, rebuild MFE image
```

**Owner**: Frontend team. **Evidence**: grep output showing domain presence/absence.

---

## CI / Manual Gate Checklist (AC-US7-104)

Before rolling out a new tenant to production, ALL gates must pass:

### Pre-merge gates (CI)

- [ ] `bash -n scripts/qa/verify-tenant-branding-runtime.sh` — syntax valid
- [ ] `bash -n scripts/qa/verify-mfe-branding.sh` — syntax valid
- [ ] `bash -n scripts/qa/verify-tenant-isolation.sh` — syntax valid
- [ ] PR approved by at least 1 reviewer

### Post-merge gates (manual)

- [ ] `verify-tenant-branding-runtime.sh` — PASS (all domains)
- [ ] `verify-mfe-branding.sh` — PASS (MFE pod checks)
- [ ] `verify-tenant-isolation.sh` — PASS (SiteConfiguration + org checks)
- [ ] Domain route smoke — HTTP 200 for all tenant domains
- [ ] MFE config fixture — correct SITE_NAME, LMS_BASE_URL, LOGO_URL per domain
- [ ] `verify-gitops-drift.sh` — no drift between source and GitOps overlay

### Artifact naming rules

Evidence artifacts MUST follow this naming convention:

```
var/evidence/tenant-onboarding/<slug>-<YYYYMMDD>/
├── tenant-branding-runtime.log
├── mfe-branding.log
├── tenant-isolation.log
├── domain-smoke.log
├── mfe-config-<domain>.json
└── summary.md
```

---

## Evidence Template (AC-US7-105)

Copy this template for each tenant onboarding. Fill in results and attach to the PR or release notes.

```markdown
# Tenant Onboarding Evidence: <Tenant Name>

**Date**: YYYY-MM-DD
**Operator**: <name>
**Domain**: <domain>
**Slug**: <slug>
**PR**: #<number>

## Pre-Rollout Checklist

| Gate | Result | Notes |
|------|--------|-------|
| DNS resolves | PASS/FAIL | `dig +short <domain>` |
| SiteConfiguration created | PASS/FAIL | provision-tenant.sh output |
| ALLOWED_HOSTS includes domain | PASS/FAIL | grep from production.py |
| CSRF_TRUSTED_ORIGINS includes domain | PASS/FAIL | grep from production.py |
| SITE_VARIANTS includes domain | PASS/FAIL | grep from env.config.js |

## Post-Rollout Verification

| Script | Result | Summary |
|--------|--------|---------|
| verify-tenant-branding-runtime.sh | PASS X / FAIL Y | |
| verify-mfe-branding.sh | PASS X / FAIL Y | |
| verify-tenant-isolation.sh | PASS X / FAIL Y | |
| Domain route smoke | HTTP <code> | |

## MFE Config Snapshot

| Key | Value |
|-----|-------|
| SITE_NAME | |
| LMS_BASE_URL | |
| LOGO_URL | |
| FAVICON_URL | |

## Rollback Plan

- [ ] Quick rollback tested (disable SiteConfiguration)
- [ ] Full rollback path documented (git revert)

## Sign-off

- [ ] Platform team: <name>
- [ ] Verified by: <name>
```

---

## Related Documents

- `infrastructure/tutor/multisite-sites.yml` — Canonical site registry
- `docs/operations/TENANT_BRANDING_SURFACE_MATRIX.md` — Per-domain verification matrix
- `docs/operations/MERGE_FIRST_DEPLOYMENT_PROTOCOL.md` — Deployment protocol
- `docs/operations/BRANDING_RELEASE_RUNBOOK.md` — Image build + deploy steps
- `scripts/tenants/provision-tenant.sh` — Provisioning script
- `specs/multi-site-domains_spec.md` — Domain configuration spec
- `specs/multi-tenancy-architecture_spec.md` — Multi-tenancy architecture spec
