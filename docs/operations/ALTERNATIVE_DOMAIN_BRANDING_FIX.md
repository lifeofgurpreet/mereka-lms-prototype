# Alternative Domain Branding Fix

**Issue**: The alternative domain `academy.biji-biji.com` shows default Open edX branding instead of Mereka Academy branding.

**Expected**: Both `academyv2.mereka.io` and `academy.biji-biji.com` should display identical Mereka Academy branding.

**Root Cause**: The multisite bootstrap script was missing site configuration for the main domain (`academyv2.mereka.io`) and the alternative domain was incorrectly configured with a separate "Biji-Biji Academy" identity instead of sharing the Mereka Academy brand.

## Solution Overview

The fix involves:

1. **Updated multisite configuration** - Added site configuration for `academyv2.mereka.io` and changed `academy.biji-biji.com` to use Mereka Academy branding
2. **Created deployment script** - New script to apply multisite configuration to production database
3. **Updated documentation** - Aligned configuration files with the correct branding strategy

## Changes Made

### 1. Updated Multisite Bootstrap Script

File: `scripts/shared/multisite_bootstrap.py`

**Changes**:
- Added `MEREKA` organization definition
- Added site configuration for `academyv2.mereka.io` (main domain)
- Changed `academy.biji-biji.com` configuration to use Mereka Academy branding (not Biji-Biji Academy)
- Both domains now share:
  - `platform_name: "Mereka Academy"`
  - `site_name: "Mereka Academy"`
  - `THEME_NAME: "mereka"`
  - `course_org_filter: ["MEREKA"]`

### 2. Created Deployment Script

File: `scripts/infra/apply-multisite-config.sh`

A new script that:
- Finds the LMS pod in the target namespace
- Copies the multisite bootstrap script to the pod
- Executes it against the production database
- Supports dry-run mode for safety

**Usage**:
```bash
# Preview changes (safe)
./scripts/infra/apply-multisite-config.sh --dry-run

# Apply changes to production
./scripts/infra/apply-multisite-config.sh --apply

# Apply to different namespace
./scripts/infra/apply-multisite-config.sh --namespace production --apply
```

### 3. Updated Configuration File

File: `infrastructure/tutor/multisite-sites.yml`

Aligned with the multisite bootstrap script to ensure consistency across documentation.

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
./scripts/infra/apply-multisite-config.sh --dry-run
```

Expected output:
```
[dry-run] Would ensure organization MEREKA
[dry-run] Would ensure organization BIJIBIJI
[dry-run] Would ensure organization SKILLOURFUTURE
[dry-run] Would ensure site academyv2.mereka.io -> Mereka Academy
           course_org_filter=['MEREKA']
[dry-run] Would ensure site academy.biji-biji.com -> Mereka Academy
           course_org_filter=['MEREKA']
[dry-run] Would ensure site skillourfuture.academy.mereka.io -> Skill Our Future
           course_org_filter=['SKILLOURFUTURE']
```

### Step 3: Apply Changes

```bash
./scripts/infra/apply-multisite-config.sh --apply
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

`academy.biji-biji.com` is its **own client microsite**, with its own organization (`BIJIBIJI`) and catalog. It is not an alias of the main `academyv2.mereka.io` site. This means:

- Biji-Biji has a distinct `django_site` + `SiteConfiguration`
- Courses are filtered to `BIJIBIJI` org content
- Branding can diverge independently from the main Mereka Academy site

### Optional: Distinct Biji-Biji Branding

If/when `academy.biji-biji.com` needs a dedicated theme:

1. Create a new theme directory: `infrastructure/tutor/themes/biji-biji/`
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

- **Multisite Documentation**: `docs/operations/MULTISITE.md`
- **Multisite Bootstrap Script**: `scripts/shared/multisite_bootstrap.py`
- **Deployment Script**: `scripts/infra/apply-multisite-config.sh`
- **Configuration File**: `infrastructure/tutor/multisite-sites.yml`
- **Django Sites Framework**: https://docs.djangoproject.com/en/3.2/ref/contrib/sites/
- **Open edX Site Configuration**: https://github.com/openedx/edx-platform/tree/master/openedx/core/djangoapps/site_configuration
