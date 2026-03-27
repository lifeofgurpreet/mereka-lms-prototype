# Alternative Domain Branding Fix
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

<!-- Last verified: 2026-02-13 -->

**Issue**: The alternative domain `academy.biji-biji.com` shows incorrect branding/config (usually because it is
missing `django_site` + `SiteConfiguration` or is mapped to the wrong tenant).

**Expected**: Each LMS domain must render according to its own `SiteConfiguration`:
- `academyv2.mereka.io`: Mereka Academy
- `academy.biji-biji.com`: Biji-Biji Academy
- `skillourfuture.academy.mereka.io`: Skill Our Future

**Root Cause**: SiteConfiguration drift. Common causes:
- `django_site` row missing for a domain
- `SiteConfiguration` missing/disabled for a domain
- `LMS_ROOT_URL`/`CMS_ROOT_URL` unset or pointing at the wrong domain
- MFE config API being served via the wrong host header (causing the wrong site to be selected)

## Solution Overview

The fix involves:

1. **Canonical multisite definitions** - Ensure every served LMS domain has a `Site` + `SiteConfiguration`
   entry in the repo-owned definitions.
2. **Canonical apply flow** - Apply those definitions through one operator front door instead of invoking
   helper scripts directly.
3. **Updated documentation** - Align runbooks with the same canonical apply path and branding strategy.

## Changes Made

### 1. Canonical Multisite Definitions

File: `infrastructure/tutor/multisite-sites.yml`

**Contract**:
- Every served LMS domain must exist in the repo-owned multisite definitions.
- `academy.biji-biji.com` remains its own microsite:
  - `platform_name: "Biji-Biji Academy"`
  - `site_name: "Biji-Biji Academy"`
  - `THEME_NAME: "mereka"` (shared theme unless and until a dedicated tenant theme is introduced)
  - `course_org_filter: ["BIJIBIJI"]`

### 2. Canonical Deployment Script

File: `scripts/infra/apply-multisite-config.sh`

This is the canonical operator front door. It:
- selects the repo-owned multisite definitions for `prod`, `dev`, or `staging`
- runs the in-cluster Django multisite reconciliation helper through a guarded flow
- supports `--dry-run` by default and explicit confirmation for `--apply`

**Usage**:
```bash
# Preview changes (safe)
./scripts/infra/apply-multisite-config.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --env prod --dry-run

# Apply changes to production
./scripts/infra/apply-multisite-config.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --env prod --apply

# Apply to different namespace
./scripts/infra/apply-multisite-config.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --namespace production --env prod --apply
```

### 3. Updated Documentation

Runbooks and operator notes should point at `scripts/infra/apply-multisite-config.sh`
as the canonical entrypoint. The Django helper is an implementation detail, not an
operator-facing repair path.

## Deployment Instructions

### Prerequisites

- kubectl access to the target cluster
- LMS pods running in the namespace

### Step 1: Verify Current State

```bash
# Check LMS pods are running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms

# Test current branding on both domains
curl -I https://academyv2.mereka.io/
curl -I https://academy.biji-biji.com/
```

### Step 2: Preview Changes (Dry Run)

```bash
./scripts/infra/apply-multisite-config.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --env prod --dry-run
```

Expected output:
```
[dry-run] Would ensure organization MEREKA
[dry-run] Would ensure organization BIJIBIJI
[dry-run] Would ensure organization SKILLOURFUTURE
[dry-run] Would ensure site academyv2.mereka.io -> Mereka Academy
           course_org_filter=['MEREKA']
[dry-run] Would ensure site academy.biji-biji.com -> Biji-Biji Academy
           course_org_filter=['BIJIBIJI']
[dry-run] Would ensure site skillourfuture.academy.mereka.io -> Skill Our Future
           course_org_filter=['SKILLOURFUTURE']
```

### Step 3: Apply Changes

```bash
./scripts/infra/apply-multisite-config.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --env prod --apply
```

### Step 4: Restart LMS Pods (Optional but Recommended)

To ensure Django reloads the site configuration:

```bash
kubectl rollout restart deployment/lms -n mereka-lms

# Wait for rollout to complete
kubectl rollout status deployment/lms -n mereka-lms
```

### Step 5: Verify Changes

Test both domains in a browser:

1. **Main domain**: https://academyv2.mereka.io
   - Should show "Mereka Academy" in header
   - Footer should show Mereka branding
   - Homepage should display Mereka logo

2. **Alternative domain**: https://academy.biji-biji.com
   - Should show identical branding to main domain
   - Same "Mereka Academy" header
   - Same footer
   - Same logo

3. **Skill Our Future domain**: https://skillourfuture.academy.mereka.io
   - Should show "Skill Our Future" branding
   - Custom homepage hero banner

## Technical Details

### Django Site Configuration

Open edX uses Django's sites framework (`django.contrib.sites`) to support multiple domains. Each domain requires:

1. **Site entry** in `django_site` table:
   - `domain`: The hostname (e.g., `academy.biji-biji.com`)
   - `name`: Display name

2. **Site Configuration** in `site_configuration_siteconfiguration` table:
   - `site_id`: Foreign key to django_site
   - `enabled`: Boolean flag
   - `site_values`: JSON with configuration overrides including:
     - `platform_name`: Shows in page titles and headers
     - `site_name`: Used in various UI elements
     - `THEME_NAME`: Which theme directory to use
     - `ENABLE_COMPREHENSIVE_THEMING`: Enable theme system
     - `course_org_filter`: Which organizations' courses to show
     - `logo_image`: URL to logo
     - `favicon_path`: Path to favicon

### Biji-Biji Is a Separate Client Site

`academy.biji-biji.com` is its **own client microsite**, with its own organization (`BIJIBIJI`) and catalog. It is
not an alias of the main `academyv2.mereka.io` site. This means:

- Biji-Biji has a distinct `django_site` + `SiteConfiguration`
- Courses are filtered to `BIJIBIJI` org content
- Branding can diverge independently from the main Mereka Academy site

### Optional: Distinct Biji-Biji Branding

If/when `academy.biji-biji.com` needs a dedicated theme:

1. Create a new theme directory: `assets/branding/tenants/biji-biji/`
2. Update the site configuration for `academy.biji-biji.com`:
   ```python
   "THEME_NAME": "biji-biji",
   "platform_name": "Biji-Biji Academy",
   "site_name": "Biji-Biji Academy",
   ```
3. Keep the Biji-Biji catalog filter:
   ```python
   "course_org_filter": ["BIJIBIJI"],
   ```

## Troubleshooting

### Issue: Changes Not Appearing After Apply

**Solution**: Restart LMS pods to force Django to reload site configuration:
```bash
kubectl rollout restart deployment/lms -n mereka-lms
```

### Issue: 404 or 500 Errors on Alternative Domain

**Potential causes**:
1. DNS not properly configured
2. Domain not in ALLOWED_HOSTS
3. CSRF_TRUSTED_ORIGINS missing the domain

**Verify**:
```bash
# Check DNS resolves
dig academy.biji-biji.com

# Check Caddy/Nginx config includes domain
kubectl exec -n mereka-lms deploy/caddy -- cat /etc/caddy/Caddyfile | grep biji-biji
kubectl exec -n mereka-lms deploy/nginx -- cat /etc/nginx/nginx.conf | grep biji-biji

# Check Django settings
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "from django.conf import settings; print(settings.ALLOWED_HOSTS)"
```

### Issue: Database Connection Failed

**Check**:
1. LMS pod can reach MySQL (should be able to - it's using existing Django DB config)
2. Database credentials are correct in lms.env.yml

**Debug**:
```bash
# Test database connection from LMS pod
kubectl exec -n mereka-lms deploy/lms -- python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.production')
import django
django.setup()
from django.db import connection
connection.ensure_connection()
print('Database connection successful!')
"
```

## References

- **Multisite Documentation**: `docs/concepts/architecture/multi-tenancy-overview.md`
- **Canonical Multisite Definitions**: `infrastructure/tutor/multisite-sites.yml`
- **Canonical Deployment Script**: `scripts/infra/apply-multisite-config.sh`
- **Configuration File**: `infrastructure/tutor/multisite-sites.yml`
- **Django Sites Framework**: https://docs.djangoproject.com/en/3.2/ref/contrib/sites/
- **Open edX Site Configuration**: https://github.com/openedx/edx-platform/tree/master/openedx/core/djangoapps/site_configuration
