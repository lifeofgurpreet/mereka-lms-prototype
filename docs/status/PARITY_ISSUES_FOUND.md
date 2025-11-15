# Parity Issues Found
_Generated: 2025-11-12_

## 🔍 Issues Identified

### 1. ✅ Plugins - GOOD

**Current Local Config:**
```yaml
PLUGINS:
  - aspects
  - discovery
  - ecommerce
  - forum
  - mfe
  - notes      # ✅ Present
  - xqueue     # ✅ Present
```

**Status:** All expected plugins are enabled. Notes and XQueue containers are running.

### 2. ⚠️ Cloud IP in Local Config

**Found:**
```
ASPECTS_SUPERSET_DATABASE_HOST: 10.97.0.2
```

**Issue:** This is a cloud IP address that shouldn't be in local config.

**Impact:** Superset/Aspects analytics may try to connect to cloud database instead of local.

**Fix:**
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
tutor config save --set ASPECTS_SUPERSET_DATABASE_HOST=clickhouse
./ops/tutor/apply-patches.sh
tutor local restart superset
```

### 3. ✅ Container Count - GOOD

**Current:** 23 containers running + 1 init container (permissions) = 24 total  
**Status:** All containers accounted for. The `permissions` container is an init job that exits after completion (this is normal).

### 4. ✅ MFEs Parity - GOOD

**Status:** All 12 expected MFEs are present:
- account, authn, communications, course-authoring, discussions
- gradebook, learner-dashboard, learning, ora-grading
- orders, payment, profile

### 5. ✅ Database Config - GOOD

**Status:** Using local Docker services:
- MYSQL_HOST: mysql ✅
- MONGODB_HOST: mongodb ✅
- REDIS_HOST: redis ✅

### 6. ✅ Service Versions - NEEDS VERIFICATION

**Local Versions:**
- Discovery: overhangio/openedx-discovery:18.0.0
- Ecommerce: overhangio/openedx-ecommerce:18.0.1
- Forum: overhangio/openedx-forum:18.1.1
- Notes: overhangio/openedx-notes:18.0.0
- XQueue: overhangio/openedx-xqueue:18.0.0
- MFE: openedx-mfe:nightly

**Action:** Compare with production versions to ensure match.

## 📋 Fix Priority

1. **HIGH:** Fix cloud IP in Superset config (ASPECTS_SUPERSET_DATABASE_HOST)
2. **MEDIUM:** Verify service versions match production
3. **LOW:** Review MFE config URLs (currently using localhost - correct for local)

## 🔧 Quick Fix Script

```bash
#!/usr/bin/env bash
# Fix parity issues
set -euo pipefail

export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

echo "1. Fixing Superset database host (cloud IP -> local service)..."
tutor config save --set ASPECTS_SUPERSET_DATABASE_HOST=clickhouse

echo "2. Applying patches..."
./ops/tutor/apply-patches.sh

echo "3. Restarting Superset services..."
tutor local restart superset

echo "✅ Parity fixes applied!"
echo ""
echo "Verifying fix..."
grep ASPECTS_SUPERSET_DATABASE_HOST tutor_env/config.yml
```

## 📊 Summary

| Category | Status | Action Needed |
|----------|--------|--------------|
| Plugins | ✅ Good | All 7 plugins enabled |
| Database Config | ✅ Good | Using local Docker services |
| Cloud IPs | ⚠️ Found 1 | Fix Superset host (10.97.0.2 → clickhouse) |
| MFEs | ✅ Good | All 12 MFEs present |
| Containers | ✅ Good | 23 running + 1 init = 24 total |
| Versions | ⚠️ Unknown | Verify match with production |
| MFE Config | ✅ Good | URLs correct for local |

---

**Next Steps:** Run the fix script above, then re-run `./tools/check-parity.sh` to verify.

