# MongoDB Atlas Operations Guide
_Audience: Operations & Developers • Owner: Infra Team • Last updated: 2026-02-11_

**Purpose**: Manage MongoDB Atlas integration for Open edX modulestore and forum data.

**TL;DR**: Atlas cluster at `cluster-mereka-lms.2pjex4s.mongodb.net` hosts 2 databases: `openedx` (courses) and `cs_comments_service` (forum). No local MongoDB containers. Connection via SRV strings. All secrets in Infisical.

---

## Cluster Information

**Cluster**: `cluster-mereka-lms.2pjex4s.mongodb.net`
**Provider**: MongoDB Atlas M10 (managed)
**Region**: Singapore (asia-southeast1)
**Tier**: M10 (2GB RAM, 10GB storage, auto-scaling enabled)

**Databases**:
- `openedx` - Modulestore (course structure, blocks, metadata) used by LMS/CMS
- `cs_comments_service` - Forum posts, comments, votes

**No local MongoDB**: All environments (local, production) connect to Atlas.

---

## Connection Details

### SRV Connection String

**Format**:
```
mongodb+srv://username:password@cluster-mereka-lms.2pjex4s.mongodb.net/dbname?retryWrites=true&maxPoolSize=50
```

**Required Python packages**:
- `pymongo[srv]` - Enables SRV connection support
- `dnspython>=2.0` - DNS resolution for SRV records

**Verify dependencies**:
```bash
# In LMS pod
kubectl exec -it -n mereka-lms deployment/lms -- pip list | grep -E "pymongo|dnspython"

# Should show:
# pymongo   4.x.x (with [srv] extras)
# dnspython 2.x.x
```

### Secrets

**Location**: Infisical `/k8s/mereka-lms`

| Secret | Purpose |
|--------|---------|
| `MEREKA_LMS_MONGODB_USERNAME` | Atlas database user |
| `MEREKA_LMS_MONGODB_PASSWORD` | Atlas password |
| `MEREKA_LMS_FORUM_MONGODB_SRV` | Complete SRV connection string for forum |

**Injected into K8s**: Via ExternalSecrets → `openedx-secrets`

**Rotation**: Update password in Atlas console → Update Infisical → Sync to GCP SM → Rolling restart pods

---

## Monitoring

### Atlas Dashboard

**Access**: https://cloud.mongodb.com/ (login with team credentials)

**Key metrics**:
- **Connections**: Should be 50-200 under normal load
- **Network**: Read/write latency (p95 <100ms from GKE)
- **Operations**: Queries, inserts, updates per second
- **Storage**: Disk usage (10GB max for M10, alerts at 80%)

### Health Check Commands

```bash
# Verify connection from LMS
kubectl exec -it -n mereka-lms deployment/lms -- python manage.py lms shell -c "
from pymongo import MongoClient
import os
uri = os.environ.get('FORUM_MONGODB_SRV')
client = MongoClient(uri)
print('Connection OK:', client.server_info()['version'])
"

# Check modulestore connection (LMS logs)
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -i mongodb

# Check forum database
kubectl exec -it -n mereka-lms deployment/lms -- bash -c '
mongo "$FORUM_MONGODB_SRV" --eval "db.getMongo()"
'
```

### Verification Script

```bash
./scripts/qa/verify-atlas-data-persistence.sh
```

Checks:
- ✅ SRV resolution succeeds
- ✅ Atlas cluster reachable
- ✅ Active connections present
- ✅ No authentication errors

---

## Common Operations

### Add GKE IP to Allowlist

**When**: Deploying to new GKE cluster or adding VPS access.

**Steps**:
1. Get cluster egress IP:
   ```bash
   kubectl run ip-check --rm -i --image=alpine/curl --restart=Never -- curl -s ifconfig.me
   ```

2. Add to Atlas:
   - Login to Atlas dashboard
   - Navigate to: Cluster → Network Access → IP Access List
   - Add IP address with description (e.g., "GKE Production Cluster")
   - Click "Confirm"

3. Verify:
   ```bash
   ./scripts/infra/check-atlas-allowlist.sh
   ```

**Script automation**:
```bash
# Uses Atlas CLI (requires ATLAS_PUBLIC_KEY, ATLAS_PRIVATE_KEY from Infisical)
./scripts/infra/ensure-atlas-allowlist-vps.sh
```

### Rotate Password

**When**: Routine 90-day rotation or security incident.

**Procedure**:

1. **Create new password in Atlas**:
   - Atlas Dashboard → Database Access → Edit user
   - Click "Edit Password" → Auto-generate → Copy

2. **Update Infisical**:
   - Navigate to `/k8s/mereka-lms`
   - Update `MEREKA_LMS_MONGODB_PASSWORD`
   - No trailing whitespace!

3. **Sync to GCP Secret Manager**:
   ```bash
   ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
   ```

4. **Force ExternalSecrets refresh**:
   ```bash
   kubectl annotate externalsecret openedx-secrets -n mereka-lms \
     force-sync="$(date +%s)" --overwrite
   ```

5. **Rolling restart**:
   ```bash
   kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
   kubectl rollout restart deployment/lms-worker deployment/cms-worker -n mereka-lms
   ```

6. **Verify**:
   ```bash
   ./scripts/qa/verify-atlas-data-persistence.sh
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50 | grep -i "mongodb\|connection"
   ```

### Check Connection Pool Usage

**Atlas dashboard** → Cluster → Metrics → Connections

**Ideal**: 50-150 connections under normal load
**Warning**: >180 connections (approaching maxPoolSize=200)
**Critical**: Connection pool exhaustion errors in logs

**If pool exhausted**:
```bash
# Scale up LMS replicas (distributes connections)
kubectl scale deployment/lms --replicas=3 -n mereka-lms

# Or increase maxPoolSize in connection string
# (requires config change + rebuild)
```

---

## Troubleshooting

### DNS Resolution Failure

**Symptom**: `getaddrinfo failed` or `Name or service not known`

**Cause**: `dnspython` not installed or DNS resolver unreachable.

**Fix**:
```bash
# Verify dnspython
kubectl exec -it -n mereka-lms deployment/lms -- pip show dnspython

# If missing, rebuild image with pymongo[srv]
tutor images build openedx -a PIP_COMMAND=pip
# (v21 defaults to uv pip which breaks loremipsum; use pip)
```

### Connection Timeout

**Symptom**: Connection hangs or times out after 30s.

**Possible causes**:
1. **IP not allowlisted**:
   ```bash
   ./scripts/infra/check-atlas-allowlist.sh
   ./scripts/infra/ensure-atlas-allowlist-vps.sh  # Auto-fix
   ```

2. **Atlas cluster paused** (M0 free tier only, not M10):
   - Check Atlas dashboard → Cluster status
   - Resume cluster if paused

3. **Network policy blocking egress**:
   ```bash
   # Test from pod
   kubectl exec -it -n mereka-lms deployment/lms -- \
     nc -zv cluster-mereka-lms.2pjex4s.mongodb.net 27017
   ```

### Authentication Failure

**Symptom**: `Authentication failed` or `Incorrect credentials`

**Causes**:
1. **Trailing whitespace in password**:
   ```bash
   ./scripts/infra/normalize-mysql-secrets.sh  # Also strips MongoDB passwords
   ```

2. **Password mismatch** (Infisical ≠ Atlas):
   - Verify in Atlas: Database Access → View user
   - Re-sync from Infisical (source of truth):
     ```bash
     ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
     kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
     kubectl rollout restart deployment/lms -n mereka-lms
     ```

### Slow Queries

**Symptom**: Course load times >5s, learner timeouts.

**Diagnose**:
1. Check Atlas Performance Advisor → Slow queries
2. Look for missing indexes on frequently queried fields

**Fix**:
- Atlas auto-suggests indexes
- Apply recommended indexes via Atlas UI or `mongosh`

**Escalation**: If consistent slow queries, consider upgrading to M20 tier.

---

## Backup and Recovery

**Atlas handles backups automatically**:
- **Continuous backups**: Enabled (point-in-time recovery)
- **Snapshot frequency**: Every 6 hours
- **Retention**: 2 days (configurable up to 365 days)

**Access backups**: Atlas Dashboard → Cluster → Backup

**Restore procedure**:
1. Atlas Dashboard → Backup → Select snapshot
2. Click "Restore"
3. Choose target: "Download" (for local restore) or "Restore to cluster"
4. If restoring to cluster, creates new cluster with data

**Test restore** (quarterly DR drill):
```bash
# Documented in disaster-recovery spec
./scripts/qa/audit-velero.sh  # Includes Atlas backup verification
```

---

## Performance Tuning

### Connection Pool Size

**Current**: `maxPoolSize=50`

**Adjust if needed** (in Tutor config):
```yaml
MONGODB_CONNECTION_OPTIONS:
  maxPoolSize: 100  # Increase for high-traffic
  minPoolSize: 10
  maxIdleTimeMS: 300000
```

### Read Preference

**Current**: Primary (default)

**For analytics queries** (non-critical reads):
```python
# Use secondaryPreferred to reduce primary load
collection.find(...).read_preference(ReadPreference.SECONDARY_PREFERRED)
```

---

## Related Resources

**Specs**: `specs/mongodb-atlas-integration_spec.md` (9 ACs, 100% complete)

**ADR**: `docs/adr/001-mongodb-atlas.md` - Architectural rationale

**Scripts**:
- `scripts/infra/check-atlas-allowlist.sh` - Verify IP allowlist
- `scripts/infra/ensure-atlas-allowlist-vps.sh` - Auto-add IPs
- `scripts/qa/verify-atlas-data-persistence.sh` - Health check
- `scripts/infra/mongodb-atlas-cutover.sh` - Historical migration script

**Operations Docs**:
- `docs/operations/MONGODB_PERMISSIONS_ISSUE.md` - Permission troubleshooting
- `docs/architecture/DATABASE_ARCHITECTURE.md` - Complete DB architecture

**Atlas CLI**: https://www.mongodb.com/docs/atlas/cli/stable/
- Install: `brew install mongodb-atlas-cli`
- Login: `atlas login --publicKey $ATLAS_PUBLIC_KEY --privateKey $ATLAS_PRIVATE_KEY`
- List clusters: `atlas clusters list`
