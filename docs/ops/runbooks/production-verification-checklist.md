# Production Verification Checklist
_Audience: SRE + Platform Ops • Owner: Docs Team • Last verified: 2026-03-06 • Status: canonical_

## 🎯 Purpose

Verify that production environment has:
- Proper multi-site configuration
- Correct user distribution (Skill Our Future ~80K, Mereka 100K+)
- MFE authn URL working
- Organizations and sites configured

## 📋 Verification Steps

### 0. Quick Public Health Check

```bash
./scripts/qa/public-health-check.sh prod
CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
```

### 1. Check Organizations

```bash
# Via kubectl
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from organizations.models import Organization
print('Organizations:')
for org in Organization.objects.all():
    print(f'  {org.short_name}: {org.name} (active: {org.active})')
"

# Expected:
#   BIJIBIJI: Biji-Biji Academy (active: True)
#   SKILLOURFUTURE: Skill Our Future (active: True)
```

### 2. Check Sites

```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
from site_configuration.models import SiteConfiguration
print('Sites:')
for site in Site.objects.all():
    config = SiteConfiguration.objects.filter(site=site).first()
    print(f'  {site.domain}: {site.name}')
    if config:
        import json
        values = json.loads(config.site_values) if isinstance(config.site_values, str) else config.site_values
        orgs = values.get('course_org_filter', [])
        print(f'    Organizations: {orgs}')
"

# Expected:
#   academyv2.mereka.io: academyv2.mereka.io
#   academy.biji-biji.com: Biji-Biji Academy
#     Organizations: ['BIJIBIJI']
#   skillourfuture.academy.mereka.io: Skill Our Future
#     Organizations: ['SKILLOURFUTURE']
```

### 3. Check User Distribution

```bash
# This is complex - users aren't directly linked to orgs
# Need to check via course enrollments or other methods
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.auth import get_user_model
from student.models import CourseEnrollment
from course_overviews.models import CourseOverview
User = get_user_model()

# Total users
total = User.objects.count()
active = User.objects.filter(is_active=True).count()
print(f'Total users: {total}')
print(f'Active users: {active}')

# Check enrollments by org
print('\\nEnrollments by organization:')
for org_short_name in ['BIJIBIJI', 'SKILLOURFUTURE', 'MEREKA']:
    courses = CourseOverview.objects.filter(org=org_short_name)
    enrollments = CourseEnrollment.objects.filter(course_id__in=[c.id for c in courses])
    unique_users = enrollments.values('user_id').distinct().count()
    print(f'  {org_short_name}: {unique_users} unique users enrolled')
"
```

### 4. Check MFE Authn URL

```bash
# Check if MFE authn is accessible
curl -I https://apps.academyv2.mereka.io/authn/login

# Check MFE config API
curl 'https://academyv2.mereka.io/api/mfe_config/v1?mfe=authn' | jq .

# Expected: Should return JSON with BASE_URL, LOGIN_URL, etc.
```

### 5. Check Course Counts

```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from course_overviews.models import CourseOverview
from organizations.models import Organization

print('Courses by organization:')
for org in Organization.objects.all():
    count = CourseOverview.objects.filter(org=org.short_name).count()
    print(f'  {org.short_name}: {count} courses')
"
```

### 6. Verify Multi-Site Routing

```bash
# Check if sites are accessible
curl -I https://academyv2.mereka.io
curl -I https://academy.biji-biji.com
curl -I https://skillourfuture.academy.mereka.io

# Check site-specific content
curl https://skillourfuture.academy.mereka.io | grep -i "skill our future"
curl https://academy.biji-biji.com | grep -i "biji-biji"
```

## 📊 Expected Results

### Organizations
- ✅ BIJIBIJI exists
- ✅ SKILLOURFUTURE exists
- ✅ Both are active

### Sites
- ✅ academyv2.mereka.io (main)
- ✅ academy.biji-biji.com (Biji-Biji)
- ✅ skillourfuture.academy.mereka.io (Skill Our Future)

### Users
- ⚠️ **Need to verify:** Actual distribution
- Expected: Skill Our Future ~80,000
- Expected: Mereka 100,000+
- Expected: Biji-Biji unknown

### MFE
- ✅ MFE authn URL accessible
- ✅ MFE config API working
- ✅ Same as local setup

## 🚨 If Issues Found

### Missing Organizations
```bash
# Preview canonical multisite reconciliation first
./scripts/infra/apply-multisite-config.sh \
  --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster \
  --env prod \
  --dry-run

# Apply only through the canonical multisite front door
ALLOW_PROD_APPLY=1 \
CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG \
./scripts/infra/apply-multisite-config.sh \
  --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster \
  --env prod \
  --apply
```

### Missing Sites
Same as above. Do not invoke the bootstrap helper directly; use the canonical
`scripts/infra/apply-multisite-config.sh` flow so the repo definitions and the
runtime write path stay aligned.

### MFE Not Working
- Check MFE container logs
- Verify Caddy routing
- Check MFE config API

## 📝 Documentation

After verification, update:
- `docs/archive/reports/status/OPERATIONAL_STATUS.md` with production findings
- `reports/2025/audits/MULTISITE_ANALYSIS.md` with actual distribution
- `docs/ops/quickref/access-urls.md` with verified URLs

---

**Status:** ⚠️ **NEEDS VERIFICATION**  
**Priority:** **HIGH** - Critical for understanding data distribution  
**Next:** Run verification commands and document findings
