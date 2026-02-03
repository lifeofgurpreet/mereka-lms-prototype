# Deploy Alternative Domain Branding Fix - Quick Guide

## Pre-Deployment Checklist

- [ ] Reviewed ALTERNATIVE_DOMAIN_FIX_SUMMARY.md
- [ ] Tested dry-run successfully
- [ ] Confirmed kubectl access to cluster
- [ ] Notified stakeholders of deployment

## Deployment Commands

### Step 1: Test Dry Run
```bash
cd /home/gurpreet/projects/k8s/mereka-lms
./scripts/infra/apply-multisite-config.sh --dry-run
```

**Expected Output:**
```
Organizations to create/update:
  - MEREKA: Mereka Academy
  - BIJIBIJI: Biji-Biji Academy
  - SKILLOURFUTURE: Skill Our Future

Sites to create/update:
  - academyv2.mereka.io: Mereka Academy
  - academy.biji-biji.com: Mereka Academy
  - skillourfuture.academy.mereka.io: Skill Our Future
```

### Step 2: Apply Configuration
```bash
./scripts/infra/apply-multisite-config.sh --apply
```

**Expected Output:**
```
Created/Updated organization: MEREKA - Mereka Academy
Created/Updated organization: BIJIBIJI - Biji-Biji Academy
Created/Updated organization: SKILLOURFUTURE - Skill Our Future

Created/Updated site: academyv2.mereka.io - Mereka Academy
Created/Updated site configuration for: academyv2.mereka.io
  - platform_name: Mereka Academy
  - theme: mereka
  - organizations: ['MEREKA']

... (similar for other domains)
```

### Step 3: Restart LMS Pods
```bash
kubectl rollout restart deployment/lms -n mereka-lms
kubectl rollout status deployment/lms -n mereka-lms
```

**Wait for:** `deployment "lms" successfully rolled out`

### Step 4: Verify Changes

#### Test Main Domain
```bash
curl -I https://academyv2.mereka.io/
# Should return 200 OK
```

Browser test:
- Visit: https://academyv2.mereka.io
- Check: Header shows "Mereka Academy"
- Check: Logo displays correctly

#### Test Alternative Domain (THE FIX TARGET)
```bash
curl -I https://academy.biji-biji.com/
# Should return 200 OK
```

Browser test:
- Visit: https://academy.biji-biji.com
- Check: Header shows "Mereka Academy" (NOT "My Open edX")
- Check: Footer matches main domain
- Check: Logo displays correctly
- Check: Same branding as academyv2.mereka.io

#### Test Skill Our Future Domain
```bash
curl -I https://skillourfuture.academy.mereka.io/
# Should return 200 OK
```

Browser test:
- Visit: https://skillourfuture.academy.mereka.io
- Check: Header shows "Skill Our Future"
- Check: Custom hero banner displays

## Verification Checklist

### Visual Verification
- [ ] academyv2.mereka.io shows "Mereka Academy" in header
- [ ] academy.biji-biji.com shows "Mereka Academy" in header (NOT "My Open edX")
- [ ] Both domains show identical Mereka logo
- [ ] Both domains show identical footer
- [ ] skillourfuture.academy.mereka.io shows "Skill Our Future"

### Functional Verification
- [ ] Can login on academyv2.mereka.io
- [ ] Can login on academy.biji-biji.com
- [ ] Course catalog shows on both domains
- [ ] Navigation works on both domains

### Technical Verification
```bash
# Check LMS pods are healthy
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms

# Check logs for errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50

# Verify site configuration in database (if needed)
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
for site in Site.objects.all():
    config = SiteConfiguration.objects.filter(site=site).first()
    if config:
        print(f'{site.domain}: {config.site_values.get(\"platform_name\")}')"
```

## Troubleshooting

### Issue: Changes not appearing after apply

**Solution 1:** Clear browser cache
```bash
# Or use incognito/private mode
```

**Solution 2:** Restart LMS pods
```bash
kubectl rollout restart deployment/lms -n mereka-lms
```

**Solution 3:** Check Django site configuration
```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
sites = Site.objects.all()
for site in sites:
    print(f'Site: {site.domain} - {site.name}')"
```

### Issue: 500 errors on alternative domain

**Check logs:**
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -i error
```

**Common causes:**
- Database connection issues
- Missing site configuration
- Theme not found

### Issue: Still shows "My Open edX"

**Verify site configuration was applied:**
```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
config = SiteConfiguration.objects.get(site__domain='academy.biji-biji.com')
print('Enabled:', config.enabled)
print('Platform name:', config.site_values.get('platform_name'))
print('Theme:', config.site_values.get('THEME_NAME'))"
```

If configuration is correct but still shows wrong branding:
1. Restart LMS pods
2. Clear browser cache
3. Check nginx/caddy configuration includes the domain

## Rollback

If critical issues occur:

```bash
# Restart to previous pod state
kubectl rollout undo deployment/lms -n mereka-lms

# Or manually update site configuration via Django admin
# Visit: https://academyv2.mereka.io/admin/sites/site/
```

## Post-Deployment

- [ ] Notify stakeholders of completion
- [ ] Update monitoring alerts if needed
- [ ] Document any issues encountered
- [ ] Update this guide with lessons learned

## Success Criteria

The fix is successful when:
1. academy.biji-biji.com homepage shows "Mereka Academy" (not "My Open edX")
2. academy.biji-biji.com footer matches academyv2.mereka.io
3. Both domains show identical branding
4. No errors in LMS logs
5. Users can login and access courses on both domains

## Timing

- Dry run: ~10 seconds
- Apply configuration: ~30 seconds
- LMS pod restart: ~2-3 minutes
- Total downtime: ~3 minutes (during pod restart)

## Approval

Before executing:
- [ ] Technical reviewer approval
- [ ] Product owner approval
- [ ] Deployment window scheduled

Executed by: _________________
Date: _________________
Result: _________________
