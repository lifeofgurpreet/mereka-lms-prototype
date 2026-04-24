# Tenant Site Configuration Seed Runbook

> Bead: mereka-lms-cm9c  
> Owner: platform team  
> Last updated: 2026-04-23

## What this covers

Each tenant needs two types of Django Site rows for Studio SSO sign-in redirects to
work correctly:

1. **Primary LMS row** — `domain` matches the tenant's LMS hostname.  
   `MerekaStudioSigninRedirectMiddleware` resolves the tenant by stripping the
   `studio.` prefix and looking up this row.

2. **Bridge row** (if Studio and LMS share different base domains) — `domain` matches
   the hostname the middleware resolves to after stripping `studio.`, even if that
   differs from the primary LMS domain.  
   `LMS_ROOT_URL` in the bridge row's `site_values` must still point to the canonical
   LMS root so the middleware rewrites to the correct host.

### Why a bridge row is required for SOF (production)

| Component | Domain |
|-----------|--------|
| LMS primary Site row | `skillourfuture.academy.mereka.io` |
| Studio host | `studio.skillourfuture.academyv2.mereka.io` |
| Candidate after prefix strip | `skillourfuture.academyv2.mereka.io` |

The candidate (`academyv2`) does not match the primary row (`academy`) because they
are on different second-level paths. Without the bridge row, `_lms_root_url_for_host`
returns `None` and the signin redirect is not rewritten — the user lands on
`apps.academyv2.mereka.io/authn/login` (primary tenant) instead of the SOF authn page.

The bridge row for `skillourfuture.academyv2.mereka.io` was added to
`infrastructure/tutor/multisite-sites.yml` to fix bead cm9c.

## Required rows per tenant (production)

| Tenant | Primary LMS domain | Bridge domain (if needed) |
|--------|--------------------|--------------------------|
| Mereka | `academyv2.mereka.io` | — (Studio is `studio.academyv2.mereka.io`, same base) |
| Biji-Biji | `academy.biji-biji.com` | — (Studio is `studio.academy.biji-biji.com`, same base) |
| SOF | `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` |

## Collision-guard failure mode for bridge rows

`apply-multisite-config.sh` runs `validate_site_host_ownership` before any DB write.
It checks that `domain`, `LMS_ROOT_URL`, `CMS_ROOT_URL`, and `MFE_BASE_URL` hosts are
each owned by exactly one tenant row (allowlisting is only available for `CMS_ROOT_URL`
and `MFE_BASE_URL` on dev/staging hosts).

A naively written bridge row that sets `LMS_ROOT_URL` to the same canonical LMS host
as the primary row will fail with:

```
BLOCKING ERRORS:
 - LMS_ROOT_URL host 'skillourfuture.academy.mereka.io' is shared by tenants
   ['skillourfuture.academy.mereka.io', 'skillourfuture.academyv2.mereka.io']
   (must be unique or allowlisted)
```

**Rule for bridge rows — two keys, not one:**

1. Set `LMS_ROOT_URL` to the bridge domain itself (unique host, no collision).
2. Set `CANONICAL_LMS_ROOT_URL` to the real tenant LMS root.

`MerekaStudioSigninRedirectMiddleware._lms_root_url_for_host` reads
`CANONICAL_LMS_ROOT_URL` preferentially over `LMS_ROOT_URL`, so the signin
redirect lands on the correct tenant LMS regardless.

Do NOT set `CMS_ROOT_URL` or `MFE_BASE_URL` on bridge rows — those hosts are
already owned by the primary row and will trigger the uniqueness guard.

## Verification command

Run inside an LMS pod to inspect current Site rows:

```bash
kubectl exec -n <namespace> <lms-pod> -- \
  python manage.py lms shell -c "
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
for s in Site.objects.all().order_by('domain'):
    cfg = getattr(s, 'configuration', None)
    vals = (cfg.site_values or {}) if cfg else {}
    lms_root = vals.get('LMS_ROOT_URL') or ''
    canonical = vals.get('CANONICAL_LMS_ROOT_URL') or ''
    extra = f'  CANONICAL={canonical!r}' if canonical else ''
    print(f'{s.domain!r:60s} LMS_ROOT_URL={lms_root!r}{extra}')
"
```

Expected output includes both the primary row and the bridge row for SOF:

```
'academy.biji-biji.com'               LMS_ROOT_URL='https://academy.biji-biji.com'
'academyv2.mereka.io'                 LMS_ROOT_URL='https://academyv2.mereka.io'
'skillourfuture.academy.mereka.io'    LMS_ROOT_URL='https://skillourfuture.academy.mereka.io'
'skillourfuture.academyv2.mereka.io'  LMS_ROOT_URL='https://skillourfuture.academyv2.mereka.io'  CANONICAL='https://skillourfuture.academy.mereka.io'
```

## Remediation — add a missing Site row

If the bridge row is absent, re-run the multisite bootstrap:

```bash
# Dry run first
ENVIRONMENT=prod ./scripts/infra/apply-multisite-config.sh \
  --context rke2-prod \
  --namespace mereka-lms \
  --env prod \
  --dry-run

# Apply (requires CONFIRM_APPLY_MULTISITE_CONFIG token)
CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG \
ALLOW_PROD_APPLY=1 \
  ./scripts/infra/apply-multisite-config.sh \
  --context rke2-prod \
  --namespace mereka-lms \
  --env prod \
  --apply
```

## Diagnosing missing rows from logs

When `MerekaStudioSigninRedirectMiddleware` cannot find a Site row for a Studio host it
emits a `WARNING` (added bead cm9c):

```
WARNING mereka_multisite MerekaStudioSigninRedirectMiddleware: no Site row for
host=studio.skillourfuture.academyv2.mereka.io, candidates=['studio.skillourfuture.academyv2.mereka.io',
'skillourfuture.academyv2.mereka.io']; signin redirect will not be rewritten ...
```

Search for this pattern in CMS pod logs:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=cms --tail=500 \
  | grep 'no Site row for host='
```

## Adding a new tenant

When onboarding a new tenant that uses a different base domain for Studio vs LMS:

1. Add the primary LMS site row to `infrastructure/tutor/multisite-sites.yml`.
2. If `studio.<x>.<base-studio-domain>` strips to a domain that does not match the
   primary LMS row's domain, add a bridge row following the two-key pattern:
   - `domain`: the stripped candidate (i.e., `<x>.<base-studio-domain>`)
   - `LMS_ROOT_URL`: the bridge domain itself (NOT the canonical LMS root — required
     to avoid the seeder's uniqueness guard collision on `LMS_ROOT_URL`)
   - `CANONICAL_LMS_ROOT_URL`: the real canonical LMS root URL for the tenant
   - Do NOT set `CMS_ROOT_URL` or `MFE_BASE_URL` (owned by the primary row)
   - Copy `platform_name`, `THEME_NAME`, `course_org_filter`, brand colors from primary
3. Re-run `apply-multisite-config.sh --env prod --apply`.
4. Verify using the shell command above.
