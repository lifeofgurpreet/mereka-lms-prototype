# MongoDB Architecture - Production vs Local
_Last updated: 2025-11-12_

## 🏗️ Architecture

### Production/Staging
**Uses MongoDB Atlas** (Managed Service)
- **Service:** MongoDB Atlas M10 cluster
- **Cost:** $87/month (production), M0 FREE (staging)
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

### Local Development
**Uses Local MongoDB Container**
- **Service:** Docker container `tutor_local-mongodb-1`
- **Cost:** Free (local resources)
- **Connection:** `mongodb://mongodb:27017`
- **Same databases:** `openedx`, `cs_comments_service`

**Why Local?**
- ✅ No cloud costs during dev
- ✅ Works offline
- ✅ Fast (no network latency)
- ✅ Isolated from production

## 📊 Data Flow

### Current State

```
Production (Staging):
┌─────────────────────────────────────┐
│  MongoDB Atlas (M10)                │
│  ├─ openedx                         │
│  │  ├─ modulestore.structures      │  ← 74 courses (MCT + Kajabi)
│  │  ├─ modulestore.definitions     │  ← XBlock content
│  │  └─ modulestore.active_versions │  ← Published courses
│  └─ cs_comments_service            │  ← Forum posts
└─────────────────────────────────────┘
         ↓
    SYNC NEEDED
         ↓
Local Development:
┌─────────────────────────────────────┐
│  tutor_local-mongodb-1              │
│  ├─ openedx                         │
│  │  ├─ modulestore.structures      │  ← Currently: 5 empty skeletons
│  │  ├─ modulestore.definitions     │  ← Currently: minimal
│  │  └─ modulestore.active_versions │  ← Currently: 5 courses
│  └─ cs_comments_service            │  ← Currently: empty
└─────────────────────────────────────┘
```

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

## 📝 Configuration

### Production (Atlas)
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

1. **Production:** Always use Atlas
2. **Staging:** Use Atlas M0 (free) or M2 (cost-effective)
3. **Local Dev:** Use local container
4. **Sync regularly:** Keep local in sync with production for testing
5. **Never point local at production Atlas:** Use sync script instead

---

**Summary:** Production uses Atlas (correct!), local uses container (correct!). We just need to sync the data!



