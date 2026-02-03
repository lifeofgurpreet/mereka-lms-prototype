# Local/Production Parity Strategy
_For Coding Agents • Last updated: 2025-11-12_

## 🎯 Overview

This document outlines the strategy for maintaining parity between local development and production/staging environments. **The goal:** Ensure what works locally will work in production, and vice versa.

## 📊 Current State Assessment

### What's Running Locally

**Containers (24 total):**
- ✅ LMS + LMS Worker
- ✅ CMS (Studio) + CMS Worker
- ✅ MFE (Micro-Frontends)
- ✅ Discovery
- ✅ Ecommerce + Ecommerce Worker
- ✅ Forum
- ✅ Notes
- ✅ XQueue + XQueue Consumer
- ✅ MySQL (local)
- ✅ MongoDB (local)
- ✅ Redis (local)
- ✅ Elasticsearch
- ✅ Caddy (reverse proxy)
- ✅ SMTP (mailhog)
- ✅ ClickHouse (analytics)
- ✅ Superset + Workers (analytics)

**MFEs Available Locally:**
- ✅ authn (authentication/login)
- ✅ account (account settings)
- ✅ profile (user profile)
- ✅ learning (course content)
- ✅ learner-dashboard (dashboard)
- ✅ course-authoring (course creation)
- ✅ gradebook (grades)
- ✅ discussions (forums)
- ✅ communications (messages)
- ✅ orders (order history)
- ✅ payment (payment processing)
- ✅ ora-grading (ORA grading)

### What's Running in Production/Staging

**Services (Kubernetes):**
- ✅ LMS + LMS Worker
- ✅ CMS (Studio) + CMS Worker
- ✅ MFE (Micro-Frontends)
- ✅ Discovery
- ✅ Ecommerce + Ecommerce Worker
- ✅ Forum
- ✅ Notes
- ✅ XQueue + XQueue Consumer
- ✅ Cloud SQL (MySQL)
- ✅ MongoDB Atlas (managed)
- ✅ Redis (managed)
- ✅ Elasticsearch (managed)
- ✅ Caddy (ingress)

**MFEs Available in Production:**
- Same as local (should match)

## 🔍 Parity Checklist

### 1. Services Parity

**Check what's running:**
```bash
# Local
docker ps --filter "name=tutor_local" --format "{{.Names}}" | sort

# Production (Kubernetes)
kubectl get pods -n mereka-lms -o name | sort
```

**Expected Match:**
- LMS, CMS, MFE, Discovery, Ecommerce, Forum, Notes, XQueue should exist in both

### 2. Database Parity

**Current State:**
- **Local:** Fresh MySQL/MongoDB databases (empty or demo data)
- **Production:** Cloud SQL + MongoDB Atlas (real user data)

**Strategy:**
- **Development:** Use local databases (isolated)
- **Testing:** Optionally sync production schema (without data)
- **Production:** Never sync local data to production

### 3. Configuration Parity

**Check config differences:**
```bash
# Local config
cat tutor_env/config.yml | grep -E "HOST|PORT|VERSION"

# Production config (if accessible)
kubectl get configmap -n mereka-lms -o yaml | grep -E "HOST|PORT|VERSION"
```

**Key Differences (Expected):**
- **Database hosts:** `mysql` (local) vs Cloud SQL IP (production)
- **MongoDB:** `mongodb` (local) vs Atlas connection string (production)
- **Redis:** `redis` (local) vs managed Redis (production)
- **S3/Storage:** Local vs GCS buckets (production)

### 4. MFE Parity

**Check available MFEs:**
```bash
# Local
docker exec tutor_local-mfe-1 ls -la /openedx/dist/ | grep "^d"

# Production (check Caddyfile or config)
kubectl exec -n mereka-lms deploy/mfe -- ls -la /openedx/dist/ | grep "^d"
```

**Expected:** Same MFEs in both environments

### 5. Plugin Parity

**Check enabled plugins:**
```bash
# Local
grep PLUGINS tutor_env/config.yml

# Production (check config)
kubectl get configmap -n mereka-lms -o yaml | grep PLUGINS
```

**Expected Plugins:**
- mfe, discovery, notes, ecommerce, xqueue, forum, aspects

## 🚨 Common Parity Issues

### Issue 1: Missing MFE in Production

**Symptoms:** MFE works locally but 404s in production

**Fix:**
1. Rebuild MFE image: `tutor images build mfe`
2. Push to registry: `tutor images push mfe`
3. Update production: `tutor k8s upgrade mfe`

### Issue 2: Database Schema Mismatch

**Symptoms:** Migrations fail in production but work locally

**Fix:**
1. Check migration status: `tutor local do migrate` vs production
2. Ensure same Open edX version: `grep OPENEDX_VERSION tutor_env/config.yml`
3. Run migrations in production: `kubectl exec -n mereka-lms deploy/lms -- python manage.py lms migrate`

### Issue 3: Config Differences

**Symptoms:** Feature works locally but not in production

**Fix:**
1. Compare configs (see above)
2. Update production config: `tutor k8s config save --set KEY=value`
3. Restart affected services

## 📋 Development Strategy

### Daily Workflow

1. **Work Locally First**
   - Make changes locally
   - Test locally
   - Verify locally

2. **Verify Parity Before Deploy**
   - Check services match
   - Check config matches (where applicable)
   - Check MFEs match

3. **Deploy to Staging**
   - Test in staging
   - Compare with local

4. **Deploy to Production**
   - Only after staging verification
   - Monitor for issues

### Data Strategy

**Local Development:**
- ✅ Use local databases (isolated)
- ✅ Use demo/test data
- ✅ Reset databases as needed

**Staging:**
- ✅ Use production-like data (sanitized)
- ✅ Can sync schema from production
- ✅ Never sync sensitive data

**Production:**
- ✅ Use real production data
- ✅ Never sync from local
- ✅ Backup before changes

### Configuration Strategy

**Local:**
- Use Docker service names: `mysql`, `mongodb`, `redis`
- Use localhost URLs: `localhost`, `*.localhost`
- Use local storage (Docker volumes)

**Production:**
- Use managed services: Cloud SQL, MongoDB Atlas, Redis
- Use production URLs: `academyv2.mereka.io`
- Use GCS buckets for storage

**Shared:**
- Same Open edX versions
- Same plugin versions
- Same MFE versions
- Same theme/branding

## 🔧 Parity Verification Script

Create a script to check parity:

```bash
#!/usr/bin/env bash
# Check local/production parity
set -euo pipefail

echo "=== Services Parity ==="
echo "Local containers:"
docker ps --filter "name=tutor_local" --format "{{.Names}}" | wc -l

echo "=== MFEs Parity ==="
echo "Local MFEs:"
docker exec tutor_local-mfe-1 ls -la /openedx/dist/ 2>/dev/null | grep "^d" | awk '{print $NF}' | grep -v "^\.$" | sort

echo "=== Config Parity ==="
echo "Open edX Version:"
grep OPENEDX_VERSION tutor_env/config.yml || echo "Not set"

echo "Plugins:"
grep PLUGINS tutor_env/config.yml || echo "Not set"
```

## 📝 Parity Maintenance Checklist

**Before Deploying:**

- [ ] Services match (same containers/services)
- [ ] MFEs match (same MFEs available)
- [ ] Config matches (same versions, plugins)
- [ ] Database schema matches (migrations run)
- [ ] Theme/branding matches
- [ ] Tested locally first

**After Deploying:**

- [ ] Verify services start correctly
- [ ] Verify MFEs load correctly
- [ ] Verify database connections work
- [ ] Verify URLs accessible
- [ ] Monitor logs for errors

## 🎓 Best Practices

1. **Always develop locally first**
   - Don't make changes directly in production
   - Test locally before deploying

2. **Keep versions in sync**
   - Same Open edX version locally and production
   - Same plugin versions
   - Same MFE versions

3. **Document differences**
   - Some differences are expected (database hosts, URLs)
   - Document intentional differences
   - Fix unintentional differences

4. **Regular parity checks**
   - Run parity check script weekly
   - Compare configs after major changes
   - Verify MFEs after rebuilds

5. **Data isolation**
   - Never sync production data to local
   - Use sanitized data for testing
   - Reset local databases as needed

---

**Remember:** Parity doesn't mean identical—it means functionally equivalent. Local uses Docker services, production uses managed services, but both should provide the same functionality.

