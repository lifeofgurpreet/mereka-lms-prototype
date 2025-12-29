# Multi-Site Setup Analysis
_Critical: Local vs Production Comparison • Last updated: 2025-11-12_

## 🚨 Critical Findings

### Local Database Status

**Users:**
- **Total:** 84,379 users
- **Active:** 53,537 users
- **Staff:** 3 users
- **Superusers:** 3 users

**Courses:**
- **Total Courses:** 73 unique courses (from enrollments)
- **Course Overviews:** 0 (needs indexing)
- **Top Course:** `course-v1:MEREKA+MEKA-2148875088+RUN-2148875088` (52,098 enrollments)

**Enrollments:**
- **Total:** 137,463 enrollments
- **Unique Users:** 68,976 users enrolled
- **Unique Courses:** 73 courses

### ⚠️ MISSING: Multi-Site Configuration

**Organizations:**
- ❌ **0 organizations configured** (should have BIJIBIJI, SKILLOURFUTURE)
- ❌ Organizations table exists but is empty

**Sites:**
- ❌ **Only default sites** (example.com, localhost)
- ❌ Missing: `academy.biji-biji.com`
- ❌ Missing: `skillourfuture.staging.academy.mereka.io`
- ❌ Missing: Main Mereka site configuration

**Expected Organizations:**
1. **BIJIBIJI** - Biji-Biji Academy
2. **SKILLOURFUTURE** - Skill Our Future (~80,000 users expected)
3. **MEREKA** - Main site (100,000+ users expected)

## 📊 Data Analysis

### Course Distribution
All courses appear to be from **MEREKA** organization:
- Course IDs: `course-v1:MEREKA+MEKA-*`
- Largest course: 52,098 enrollments
- Multiple courses with 9,000+ enrollments

### User Distribution
**Cannot determine** user distribution by organization because:
- Organizations not configured
- Users not linked to organizations in database
- Need production data to verify actual distribution

## 🔍 Production Comparison Needed

### Questions to Answer:
1. **Does production have organizations configured?**
   - Check: `SELECT * FROM organizations_organization;`
   - Check: `SELECT * FROM django_site;`

2. **What's the actual user distribution?**
   - Skill Our Future: ~80,000 users?
   - Mereka: 100,000+ users?
   - Biji-Biji: Unknown count?

3. **Does production have MFE authn URL?**
   - Check: `https://apps.staging.academy.mereka.io/authn/login`
   - Check: MFE config API response

4. **Are courses organized by organization?**
   - Check course org assignments
   - Verify course_org_filter works

## 🛠️ Required Actions

### 1. Set Up Multi-Site Locally

```bash
# Apply multi-site configuration
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
python tools/multisite_bootstrap.py --apply
```

This will:
- Create BIJIBIJI and SKILLOURFUTURE organizations
- Configure sites for Biji-Biji and Skill Our Future
- Set up course organization filters

### 2. Index Courses

```bash
# Generate course overviews
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms reindex_courses
```

### 3. Verify Production Setup

**Check production organizations:**
```bash
# Via Cloud SQL proxy or kubectl exec
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from organizations.models import Organization
for org in Organization.objects.all():
    print(f'{org.short_name}: {org.name}')
"
```

**Check production sites:**
```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
for site in Site.objects.all():
    print(f'{site.domain}: {site.name}')
"
```

**Check production MFE:**
```bash
curl https://apps.staging.academy.mereka.io/authn/login
curl 'https://staging.academy.mereka.io/api/mfe_config/v1?mfe=authn'
```

### 4. Sync Production Data (If Needed)

**DO NOT** sync production data to local without:
- Understanding data distribution
- Verifying user counts match expectations
- Ensuring organizations are properly configured
- Backing up local data first

## 📋 Verification Checklist

### Local Setup
- [ ] Organizations created (BIJIBIJI, SKILLOURFUTURE)
- [ ] Sites configured (academy.biji-biji.com, skillourfuture.staging...)
- [ ] Course overviews indexed
- [ ] Multi-site routing works
- [ ] Course filters work per site

### Production Verification
- [ ] Organizations exist in production
- [ ] Sites configured in production
- [ ] User distribution verified
- [ ] MFE authn URL accessible
- [ ] Course organization filters work

### Data Comparison
- [ ] Local user count matches expected
- [ ] Production user count verified
- [ ] Course counts match
- [ ] Enrollment distribution understood

## 🎯 Next Steps

1. **Immediate:** Run multi-site bootstrap locally
2. **Verify:** Check production configuration
3. **Compare:** Understand data distribution
4. **Document:** Update operational status
5. **Test:** Verify multi-site functionality

---

**Status:** ⚠️ **MULTI-SITE NOT CONFIGURED LOCALLY**  
**Action Required:** Run `python tools/multisite_bootstrap.py --apply`  
**Production Check:** Verify production has proper multi-site setup

