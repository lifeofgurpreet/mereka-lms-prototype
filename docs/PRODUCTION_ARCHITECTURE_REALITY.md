# Production Architecture - The Real Setup
_Last updated: 2025-11-12 • Reality Check_

## 🔍 What We Actually Have

### Production MongoDB
- **NOT Atlas M10/M0** - It's a MongoDB **POD** in Kubernetes
- **Location:** `mereka-lms` namespace, `mongodb` deployment
- **Databases:** `openedx` (courses), `admin`, `config`, `local`
- **Courses:** Only **2 courses** currently (SKILLOURFUTURE org)
  - `SKILLOURFUTURE/MCTCAT-24`
  - `SKILLOURFUTURE/MCTCAT-16`

### Users: ALL MCT (No Kajabi Yet)
- **Total users:** 84,378
- **MCT users:** 84,378 (100%)
- **Kajabi users:** 0 (not imported yet)
- **Evidence:** `auth_userprofile.meta` field has `kajabi_contact_id: None` for all users

### Course Enrollments Mystery
- **MySQL has:** 137,468 enrollments across 74 unique `course_id`s
- **MongoDB has:** Only 2 courses
- **Conclusion:** Most course IDs in enrollments don't have content in modulestore yet
  - Historical data from MCT migration
  - Courses need to be created/imported

### Domain Mapping
- **SKILLOURFUTURE courses** → `skillourfuture.academy.mereka.io`
- **Main site (future Kajabi)** → `localhost` (dev) or main domain (prod)
- **BIJIBIJI courses** → `academy.biji-biji.com` (when created)

## 📊 User Tagging Strategy

### Current State
All users have `meta` field in `auth_userprofile`:
```python
{'kajabi_contact_id': None, 'kajabi_customer_id': None}
```

### When Kajabi Users Are Imported
```python
# MCT user
{'kajabi_contact_id': None, 'kajabi_customer_id': None}

# Kajabi user
{'kajabi_contact_id': '12345', 'kajabi_customer_id': '67890'}
```

### How to Identify
```sql
-- Count MCT users (no Kajabi ID)
SELECT COUNT(*) FROM auth_userprofile 
WHERE meta LIKE '%: None%' OR meta NOT LIKE '%kajabi%';

-- Count Kajabi users (has Kajabi ID)
SELECT COUNT(*) FROM auth_userprofile 
WHERE meta LIKE '%kajabi_contact_id%' 
AND meta NOT LIKE '%: None%';
```

## 🔄 Syncing to Local (Repeatable Process)

### One-Command Setup
```bash
./scripts/shared/setup-local.sh
```

This will:
1. Set up Python environment
2. Configure Tutor for local
3. Build Docker images (if needed)
4. Initialize databases
5. Create multi-site organizations
6. Create admin user
7. **Optionally** sync from production (if connected to cluster)

### Manual Production Sync
```bash
# Connect to production cluster
gcloud container clusters get-credentials mereka-lms \
  --region asia-southeast1

# Run sync
./scripts/shared/sync-from-production.sh
```

This syncs:
- ✅ MongoDB course content (from production pod)
- ✅ User tagging (MCT vs Kajabi markers)
- ✅ Course-domain mappings (SKILLOURFUTURE → skillourfuture site)

### For Other Developers
```bash
# On any new machine
git clone <repo>
cd mereka.academy
./scripts/shared/setup-local.sh  # One command!

# Later, to get latest courses
./scripts/shared/sync-from-production.sh
```

## 🎓 Course Organization

### Current Production Courses
| Course ID | Organization | Mapped Domain |
|-----------|--------------|---------------|
| `MCTCAT-24` | SKILLOURFUTURE | skillourfuture.academy.mereka.io |
| `MCTCAT-16` | SKILLOURFUTURE | skillourfuture.academy.mereka.io |

### When Kajabi Courses Are Imported
They will be under a different organization (e.g., `MEREKA`) and mapped to the main domain.

## 🚨 Key Corrections from Previous Assumptions

1. ❌ **NOT using MongoDB Atlas** - Using Kubernetes pod
2. ❌ **NOT 74 courses** - Only 2 courses currently in modulestore
3. ❌ **NOT mixed Kajabi+MCT users** - All MCT users (84,378)
4. ✅ **User tagging infrastructure exists** - Via `meta` field
5. ✅ **Multi-org setup correct** - SKILLOURFUTURE, BIJIBIJI, etc.

## 📝 TODO: Kajabi Import

When Kajabi courses are imported:

1. **Users will have Kajabi IDs** in `meta` field
2. **Courses will be in modulestore** under appropriate org
3. **Domain mapping will work** via SiteConfiguration
4. **Sync script will pull both** MCT and Kajabi courses

## ✅ What Works Now

- ✅ One-click local setup
- ✅ Production MongoDB sync
- ✅ User source tracking (ready for Kajabi)
- ✅ Multi-site domain mapping
- ✅ Repeatable across developers/machines

## 📚 Scripts Created

1. **`scripts/shared/setup-local.sh`** - Complete one-click setup
2. **`scripts/shared/sync-from-production.sh`** - Sync MongoDB + tag users
3. **`tools/verify-setup.sh`** - Verify everything works
4. **`scripts/qa/analyze-local-data.sh`** - Check what you have locally

---

**Bottom line:** Production uses a MongoDB pod (not Atlas), has 2 courses (not 74), all users are MCT (no Kajabi yet). Everything is now set up to be repeatable and ready for Kajabi import!



