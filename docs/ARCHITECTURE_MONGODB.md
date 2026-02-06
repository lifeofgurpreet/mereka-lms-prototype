# MongoDB Architecture - Production vs Local
_Last updated: 2026-02-06_

## 🏗️ Architecture

### Production (GKE)
**Hybrid today** (target is Atlas-only)

- Forum uses **MongoDB Atlas** (managed service).
- LMS/CMS modulestore currently uses the **in-cluster MongoDB** service unless
  `MONGODB_HOST` is explicitly set to Atlas.

Target state:
- Atlas-only for both `openedx` (modulestore) and `cs_comments_service` (forum)
- Remove in-cluster MongoDB once modulestore is migrated and verified

### Dev (VPS kind)
Depends on environment:
- Forum commonly uses Atlas (with allowlist automation).
- Modulestore may use in-cluster MongoDB unless explicitly pointed to Atlas.

### MongoDB Atlas (Managed Service)
- **Service:** MongoDB Atlas M10 cluster
- **Cost:** Production M10; dev may use a smaller Atlas tier or a separate DB
- **Region:** AWS `ap-southeast-1`
- **Connection:** `mongodb+srv://` URI
- **Databases:**
  - `openedx` - Course content (modulestore)
  - `cs_comments_service` - Forum discussions

**Why Atlas?**
- ✅ Managed service (no maintenance)
- ✅ Automatic backups
- ✅ High availability
- ✅ Scaling
- ✅ **Recommended by Open edX** for production

### Local Laptop (Optional)
**Uses Local MongoDB Container** (only for `tutor local`, not K8s)
- **Service:** Docker container `tutor_local-mongodb-1`
- **Cost:** Free (local resources)
- **Connection:** `mongodb://mongodb:27017`
- **Same databases:** `openedx`, `cs_comments_service`

**Why Optional?**
- ✅ Works offline for laptop-only development
- ✅ Avoids touching shared Atlas data

## 📊 Data Flow

### Current State (Verified 2026-02-06)

```
Production (GKE):
┌─────────────────────────────────────┐
│  MongoDB Atlas                      │
│  └─ cs_comments_service             │  ← Forum posts
├─────────────────────────────────────┤
│  In-cluster MongoDB (Deployment)    │
│  └─ openedx                         │  ← LMS/CMS modulestore (today)
└─────────────────────────────────────┘
```

**Implication:** Atlas-only is not yet true end-to-end. Treat modulestore cutover
as a planned migration with explicit verification and rollback.

## 🔄 Syncing Production to Local

### Step 1: Get Atlas URI

```bash
# From Google Secret Manager
ATLAS_URI=$(gcloud secrets versions access latest --secret=mongodb-atlas-uri)

# Or ask infrastructure team
```

### Step 2: Run Sync

```bash
ATLAS_URI=$ATLAS_URI ./scripts/infra/sync-mongodb-from-production.sh
```

This will:
1. Dump `openedx` and `cs_comments_service` from Atlas
2. Restore to local MongoDB
3. Verify course count

### Step 3: Verify

```bash
# Check course count
docker exec tutor_local-mongodb-1 mongosh openedx --quiet --eval \
  "db['modulestore.active_versions'].countDocuments({})"

# Should show 74 courses (or however many are in production)

# View in browser
open http://studio.localhost
# Login: admin / admin123
```

## 📈 User Data Clarification

**84,379 users includes:**
- ✅ MCT (Microsoft Community Training) users
- ✅ Kajabi users (already migrated!)
- ✅ Both systems combined

**NOT separate pools** - they're all in MySQL `auth_user` table now.

## 🎓 Course Data Clarification

**74 course IDs in `student_courseenrollment`:**
- These are MCT course IDs
- Format: `course-v1:MEREKA+MEKA-{number}+RUN-{number}`
- Content exists in **production Atlas**
- NOT in local MongoDB yet (need to sync)

**Kajabi courses:**
- Also in production Atlas (part of the 74)
- Or separate course IDs (need to verify with production dump)

## 🚨 Important Notes

1. **Atlas is recommended by Open edX** for production
   - We're doing it right!
   - Local MongoDB for dev is also correct

2. **Course content lives in MongoDB** (not MySQL)
   - MySQL = enrollments, users, metadata
   - MongoDB = course structure, XBlocks, content

3. **Forums use separate database** (`cs_comments_service`)
   - Also in Atlas (production)
   - Also in local MongoDB (dev)

4. **We need to sync regularly**
   - Production Atlas → Local MongoDB
   - To get latest courses for dev/testing

5. **Atlas requires SRV DNS support**
   - Open edX images must include `dnspython`
   - Install via `pip install "pymongo[srv]"` during image build

## 📝 Configuration

### Production (Target: Atlas-only)
```yaml
RUN_MONGODB: false
MONGODB_URI: "mongodb+srv://..."
MONGODB_HOST: ""
MONGODB_PORT: ""
```

### Local (Container)
```yaml
RUN_MONGODB: true
MONGODB_URI: ""
MONGODB_HOST: mongodb
MONGODB_PORT: 27017
```

## ✅ Best Practices

1. **Production + Dev (K8s):** Always use Atlas
2. **Local Laptop:** Use local container only for `tutor local`
3. **Sync regularly:** Keep local in sync with production for testing
4. **Never point local at production Atlas:** Use sync script instead
5. **Keep SRV support installed:** Ensure `pymongo[srv]` is in Open edX images

---

**Summary:** Production uses Atlas (correct!), local uses container (correct!). We just need to sync the data!



