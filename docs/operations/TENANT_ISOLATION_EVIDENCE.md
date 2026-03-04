# Tenant Isolation Evidence

> **Bead**: mereka-lms-115d.24
> **Last updated**: 2026-02-18
> **Audience**: Platform Eng, QA, On-call

This document is the canonical evidence record for tenant isolation across the three production
domains of the Mereka Open edX platform. It covers per-tenant branding markers, authn failure
behavior, enterprise domain host matrix, cross-tenant isolation controls, and the rollback drill
for branding regressions.

**Related documents**:
- [`TENANT_BRANDING_MATRIX.md`](TENANT_BRANDING_MATRIX.md) — per-domain brand config
- [`OPENEDX_HOSTNAMES.md`](OPENEDX_HOSTNAMES.md) — full hostname registry
- [`FOOTER_VARIANT_MATRIX.md`](FOOTER_VARIANT_MATRIX.md) — per-domain footer skins

---

## Tenant Domain Registry

| Domain | Brand Name | Footer Text | Page Title | Logo URL |
|--------|------------|-------------|------------|----------|
| `academyv2.mereka.io` | Mereka Academy | "© MEREKA" | "Mereka Academy" | `/static/images/logo.png` |
| `academy.biji-biji.com` | Biji-Biji Academy | "© Biji-Biji Initiative" | "Biji-Biji Academy" | `/static/images/logo.png` |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | "© MEREKA" | "Skill Our Future Academy" | `/static/images/logo.png` |

### Per-Tenant Branding Markers

Each tenant domain is identified at runtime by three branding markers rendered in the UI:

1. **Footer text** — copyright holder and brand name, injected by `MerekaFooter` via `SITE_VARIANTS`
   in `infrastructure/tutor/plugins/mereka_lms.py`.
2. **Page title** — `<title>` tag set from `config.SITE_NAME` (LMS setting) per domain.
3. **Service/logo marker** — logo URL served from the LMS base URL (`/static/images/logo.png`);
   per-domain logo override is a planned Phase 3 enhancement.

The `SITE_VARIANTS` map in `mereka_lms.py` drives all footer/title branding at runtime:

```js
const SITE_VARIANTS = {
  'academyv2.mereka.io':           { brand: 'Mereka Academy',            copyrightHolder: 'MEREKA',               whatsapp: '601135271981' },
  'academy.biji-biji.com':         { brand: 'Biji-Biji Academy',         copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },
  'skillourfuture.academy.mereka.io':      { brand: 'Skill Our Future Academy',  copyrightHolder: 'MEREKA',               whatsapp: '601135271981' },
};
```

---

## AC-UI-202: Authn Failure Matrix

### Login Failure Scenarios

| Scenario | Input | Expected Behavior |
|----------|-------|-------------------|
| Wrong password | Valid email + bad password | 200 with branded error message on `/login` |
| Unknown email | Non-existent email | 200 with branded error message on `/login` |
| Expired session | Stale session cookie | Redirect to `/login` (302) |
| SSO failure | OIDC provider unreachable | Redirect to branded error page |

**Behavior**: All login failure responses remain on the per-tenant domain. The domain-aware
`MerekaFooter` and `SITE_VARIANTS` ensure error pages carry the correct brand for the originating
domain. There is no cross-tenant leakage in the error response.

### Unauthorized Redirect Matrix

| Route | Unauthenticated User | Expected Redirect |
|-------|---------------------|-------------------|
| `/dashboard` | Anonymous | 302 → `/login?next=/dashboard` |
| `/courses/<key>/courseware/` | Anonymous | 302 → `/login?next=...` |
| `apps.academyv2.mereka.io/learner-dashboard/` | Anonymous | 302 → branded login page |
| `apps.academy.biji-biji.com/learner-dashboard/` | Anonymous | 302 → branded login page |
| `/admin/` | Non-staff user | 302 → `/admin/login/` |
| `/api/*` (DRF) | Unauthenticated | 401 JSON response |

**Branded 403/error pages**: Unauthorized access to restricted paths returns a 403 response
rendered with the originating domain's branding (footer text, page title). The `TenantResolutionMiddleware`
resolves the tenant before the view, so error templates receive the correct tenant context.

### Enterprise Domain Host Matrix

| Domain | LMS Hostname | MFE Apps Host | Studio Host |
|--------|-------------|---------------|-------------|
| Mereka Academy | `academyv2.mereka.io` | `apps.academyv2.mereka.io` | `studio.academyv2.mereka.io` |
| Biji-Biji Academy | `academy.biji-biji.com` | `apps.academy.biji-biji.com` | `studio.academy.biji-biji.com` |
| Skill Our Future | `skillourfuture.academy.mereka.io` | `apps.skillourfuture.academy.mereka.io` | *(not yet provisioned)* |

MFE apps served at `apps.{domain}/` inherit the tenant branding from `SITE_VARIANTS` embedded in
the MFE bundle at build time. Each MFE reads `window.location.hostname` to select the correct
`SITE_VARIANTS` entry.

---

## AC-UI-204: Route Expectations per Hostname

| Hostname | Route Pattern | Notes |
|----------|--------------|-------|
| `academyv2.mereka.io` | `/`, `/login`, `/dashboard`, `/courses/*`, `/api/*` | Primary LMS |
| `academy.biji-biji.com` | `/`, `/login`, `/dashboard`, `/courses/*`, `/api/*` | Tenant LMS alias |
| `skillourfuture.academy.mereka.io` | `/`, `/login`, `/dashboard` | Tenant LMS alias |
| `apps.academyv2.mereka.io` | `/authn/login`, `/learner-dashboard/`, `/learning/`, `/profile/`, `/account/`, `/course-authoring/` | MFE frontend |
| `apps.academy.biji-biji.com` | `/authn/login`, `/learner-dashboard/`, `/learning/`, `/profile/`, `/account/` | MFE frontend |
| `studio.academyv2.mereka.io` | `/`, `/course/*`, `/api/v1/*` | Studio CMS |
| `studio.academy.biji-biji.com` | `/`, `/course/*` | Studio CMS alias |

**Drift check command**:
```bash
./scripts/qa/list-openedx-hostnames.sh --env prod
./scripts/qa/map-openedx-host-routing.sh --env prod --format json
```

See [`OPENEDX_HOSTNAMES.md`](OPENEDX_HOSTNAMES.md) for the full hostname registry.

### Evidence Artifacts

Isolation evidence snapshots are written to:
```
var/operations/tenant-isolation-{domain}-{timestamp}.json
```

Example:
```
var/operations/tenant-isolation-academyv2.mereka.io-20260218T1200Z.json
var/operations/tenant-isolation-academy.biji-biji.com-20260218T1200Z.json
var/operations/tenant-isolation-skillourfuture.academy.mereka.io-20260218T1200Z.json
```

Each artifact captures: HTTP status, session cookie domain, CSRF origin header, footer text
assertion, and page title assertion for the given domain at the time of capture.

---

## AC-UI-205: Cross-Tenant Isolation Controls

No shared state between tenants is the core guarantee. The following controls enforce isolation:

### SESSION_COOKIE_DOMAIN

Studio sets `SESSION_COOKIE_NAME = "studio_session_id"` (distinct from LMS `"sessionid"`) and
`SESSION_COOKIE_DOMAIN = None` (host-only). This prevents the Studio session cookie being readable
by the LMS domain or any other tenant subdomain.

For the LMS, `SESSION_COOKIE_DOMAIN` is set to the specific tenant domain (e.g.,
`.academyv2.mereka.io`) via Django sites framework — it does not span across tenant domains.

**Isolation guarantee**: A session established on `academy.biji-biji.com` is never accessible
to `academyv2.mereka.io`. The isolated session prevents any cross-tenant user identity bleed.

### SITE_ID Separation

Each tenant domain maps to a distinct Django `Site` record (SITE_ID). The `TenantResolutionMiddleware`
resolves the current site from the `Host` header on every request:

```python
# infrastructure/tutor/plugins/multi-tenancy/mereka_tenancy/middleware.py
class TenantResolutionMiddleware:
    def __call__(self, request):
        tenant = TenantConfig.objects.filter(domain=request.get_host()).first()
        request.tenant = tenant
        return self.get_response(request)
```

The Django sites framework ensures `SITE_ID`-scoped data (permissions, site-specific settings)
is isolated per tenant. No shared state flows between SITE_ID boundaries.

### CSRF Trusted Origins

`CSRF_TRUSTED_ORIGINS` in `infrastructure/tutor/apply-patches.sh` is set to the explicit list
of tenant domains:

```python
CSRF_TRUSTED_ORIGINS = [
    "https://academyv2.mereka.io",
    "https://academy.biji-biji.com",
    "https://skillourfuture.academy.mereka.io",
    "https://apps.academyv2.mereka.io",
    "https://apps.academy.biji-biji.com",
    "https://studio.academyv2.mereka.io",
]
```

CSRF tokens are not shared across domains — each tenant origin must be explicitly listed.
A cross-tenant CSRF forgery attempt fails because the `Referer` header does not match the
tenant origin.

### No Shared State Summary

| Control | Mechanism | Scope |
|---------|-----------|-------|
| Session isolation | `SESSION_COOKIE_DOMAIN` per tenant | Per-domain cookies |
| User identity | Django Sites + SITE_ID | Per-site user scoping |
| CSRF protection | Per-origin trusted list | No cross-domain forgery |
| Branding data | `SITE_VARIANTS` keyed by hostname | Per-domain UI data |
| TenantConfig | `TenantResolutionMiddleware` | Per-request resolution |

---

## AC-UI-203: Rollback Drill — Branding Regression Recovery

Use this drill when a branding regression is detected on a production tenant domain (e.g., wrong
footer text, missing logo, incorrect page title).

### Detection Signals

- Footer text shows wrong brand name (e.g., "Mereka Academy" on `academy.biji-biji.com`)
- Page `<title>` does not match the expected tenant brand name
- Logo URL returns 404
- `./scripts/qa/verify-tenant-branding-matrix.sh` reports FAIL

### Step-by-Step Restore Sequence

**Step 1: Identify the regression source**

```bash
# Check which MFE image tag is currently deployed
kubectl get deployment mfe -n mereka-lms \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Confirm SITE_VARIANTS in the deployed image (offline check)
kubectl exec -n mereka-lms deploy/mfe -- \
  grep -r "SITE_VARIANTS" /openedx/dist/ 2>/dev/null | head -5
```

**Step 2: Identify the last known-good image tag**

```bash
# List recent MFE image tags in the registry
gcloud artifacts docker tags list \
  ghcr.io/biji-biji-initiative/mereka-lms/mfe \
  --sort-by=~UPDATE_TIME --limit=10
```

**Expected output**: A table of image tags with timestamps. Identify the tag deployed before
the regression (check ArgoCD history or `git log deploy/k8s/overlays/production/`).

**Step 3: Roll back the MFE image tag**

```bash
# In the bbi-infrastructure GitOps repo, update the MFE image tag:
# deploy/k8s/overlays/production/kustomization.yaml
#   images:
#     - name: mfe
#       newTag: <previous-good-tag>

# Then commit and let ArgoCD sync, OR force a manual rollout:
kubectl set image deployment/mfe mfe=ghcr.io/biji-biji-initiative/mereka-lms/mfe:<previous-tag> \
  -n mereka-lms
```

**Step 4: Verify the rollback**

```bash
# Wait for rollout to complete
kubectl rollout status deployment/mfe -n mereka-lms --timeout=120s

# Confirm footer text per domain (offline check via SITE_VARIANTS)
./scripts/qa/verify-tenant-branding-matrix.sh
```

**Expected output**: `32 PASS / 0 FAIL / 0 WARN` (or similar all-PASS result).

**Step 5: Validate live branding on each tenant domain**

```bash
# Probe each domain for expected footer content
for domain in academyv2.mereka.io academy.biji-biji.com skillourfuture.academy.mereka.io; do
  echo "Checking $domain..."
  curl -s "https://$domain" | grep -o 'MEREKA\|Biji-Biji Initiative\|Skill Our Future' | head -1
done
```

**Expected output**:
```
Checking academyv2.mereka.io...
MEREKA
Checking academy.biji-biji.com...
Biji-Biji Initiative
Checking skillourfuture.academy.mereka.io...
MEREKA
```

**Step 6: Escalation path**

If Steps 1–5 do not resolve the regression:

1. Check ArgoCD sync status: `argocd app get mereka-lms` (confirm last sync was successful)
2. Check the Caddy routing layer: `kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=50`
3. Verify `TenantConfig` records in Django admin (`/admin/multi_tenancy/tenantconfig/`)
4. Page the on-call engineer via the standard escalation path (PagerDuty)
5. Create a bead issue under `mereka-lms` for post-incident review

### Config-Level Rollback (non-image regression)

If the regression is in `SITE_VARIANTS` config (not image):

```bash
# Revert the offending commit in mereka_lms.py
git revert <commit-sha>

# Rebuild and redeploy MFE
tutor images build mfe
tutor local restart mfe  # local
# OR for production: push image, update tag in GitOps repo, let ArgoCD sync
```

---

## References

- [`TENANT_BRANDING_MATRIX.md`](TENANT_BRANDING_MATRIX.md) — per-tenant brand config + rollback plan
- [`OPENEDX_HOSTNAMES.md`](OPENEDX_HOSTNAMES.md) — hostname registry + drift check commands
- [`FOOTER_VARIANT_MATRIX.md`](FOOTER_VARIANT_MATRIX.md) — per-domain footer skin matrix
- [`infrastructure/tutor/plugins/mereka_lms.py`](../../infrastructure/tutor/plugins/mereka_lms.py) — `SITE_VARIANTS` source
- [`infrastructure/tutor/plugins/multi-tenancy/`](../../infrastructure/tutor/plugins/multi-tenancy/) — TenantConfig + middleware
- [`infrastructure/tutor/apply-patches.sh`](../../infrastructure/tutor/apply-patches.sh) — CSRF_TRUSTED_ORIGINS patch
- [`scripts/qa/verify-tenant-branding-matrix.sh`](../../scripts/qa/verify-tenant-branding-matrix.sh) — branding verification
- [`scripts/qa/verify-tenant-isolation-evidence.sh`](../../scripts/qa/verify-tenant-isolation-evidence.sh) — this doc's verification script
