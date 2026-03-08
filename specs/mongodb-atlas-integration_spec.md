---
title: "MongoDB Atlas Integration"
type: "feature_spec"
status: "completed"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/secrets-management_spec.md"
  - "specs/tutor-configuration_spec.md"
links:
  related_docs:
    - "docs/adr/001-mongodb-atlas.md"
    - "docs/architecture/MONGODB_ATLAS_MIGRATION.md"
    - "docs/architecture/DATABASE_ARCHITECTURE.md"
    - "docs/operations/MONGODB_PERMISSIONS_ISSUE.md"
    - "docs/runbooks/operations/TROUBLESHOOTING.md"
    - "docs/operations/DEPLOYMENT_RUNBOOK.md"
  related_specs:
    - "specs/secrets-management_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/forum-service-migration_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

MongoDB Atlas replaces the local in-cluster MongoDB containers that previously served Open edX. The two databases affected are the modulestore (course structure, blocks, and metadata used by LMS and CMS) and the forum database (posts, comments, and votes used by the forum service). Atlas is a managed MongoDB cluster hosted at `cluster-mereka-lms.2pjex4s.mongodb.net`, eliminating the need to operate, back up, and scale MongoDB ourselves.

## Why it matters

Running a stateful database inside Kubernetes introduces significant operational risk: manual backup management, no automatic failover, and complex scaling. Atlas removes all of that overhead while providing built-in monitoring, automated backups with point-in-time recovery, and seamless scaling. This directly improves platform reliability for Mereka Academy learners and reduces the on-call burden for the engineering team.

## Success looks like

- All LMS, CMS, and Forum traffic routes to Atlas with zero local MongoDB containers running in any environment.
- Learners experience no degradation in course load times (p95 read latency under 100ms from GKE to Atlas).
- The team spends zero hours per month on MongoDB operational tasks (backups, patching, failover).
- Atlas monitoring dashboard shows healthy connection counts and no authentication or timeout errors.

# Agent Contract

## Scope

This spec covers the integration of MongoDB Atlas as the managed database for Open edX modulestore (course structure) and forum data. It replaces local MongoDB containers with a cloud-hosted cluster to eliminate maintenance overhead and improve reliability.

See ADR-001 for architectural rationale: `docs/adr/001-mongodb-atlas.md`

## Non-goals

- MySQL Cloud SQL migration (handled separately)
- Redis managed service (currently in-cluster)
- MongoDB performance tuning (handled by Atlas autoscaling)
- Backup strategy (Atlas handles automated backups)

## Requirements

### Atlas Cluster

- The system MUST use the cluster: `cluster-mereka-lms.2pjex4s.mongodb.net`
- The system MUST connect via MongoDB SRV connection string (not standard connection string)
- The system MUST install `dnspython` for SRV record resolution
- The system MUST NOT deploy local MongoDB containers in any environment

### Database Configuration

The system MUST use the following databases on the Atlas cluster:

| Database | Purpose | Used By |
|----------|---------|---------|
| `openedx` | Modulestore (course structure, blocks, metadata) | LMS, CMS |
| `cs_comments_service` | Forum posts, comments, votes | Forum service |

### Connection String Format

- The system MUST use SRV connection strings: `mongodb+srv://user:pass@cluster-mereka-lms.2pjex4s.mongodb.net/`
- The system MUST include database name in connection string or application config
- The system MUST set `retryWrites=true` for write operation safety
- The system SHOULD set connection pool size based on service: `maxPoolSize=50`

### Secrets Management

- The system MUST store Atlas password in Infisical as `MEREKA_LMS_MONGODB_PASSWORD`
- The system MUST sync password to GCP Secret Manager
- The system MUST inject password into K8s pods via ExternalSecrets
- The system MUST NOT hardcode passwords in configuration files

### Python Dependencies

- The system MUST install `pymongo[srv]` to enable SRV connection support
- The system MUST install `dnspython>=2.0` for DNS resolution
- The Dockerfile MUST include: `RUN pip install "pymongo[srv]"`

### Network Access

- The system MUST add GKE cluster egress IPs to Atlas IP allowlist
- The system SHOULD use Atlas VPC peering for production (future enhancement)
- The system MUST NOT expose Atlas cluster to 0.0.0.0/0

### Non-Functional Requirements

- Read latency (p95) from GKE to Atlas MUST be <= 100ms for modulestore queries
- Write latency (p95) for course save operations MUST be <= 500ms
- Connection establishment time MUST be <= 2s (including SRV resolution)
- Atlas cluster availability MUST meet 99.95% uptime (Atlas M10+ SLA)
- Connection pool utilization SHOULD remain below 80% of `maxPoolSize` under normal load
- The system MUST support at least 200 concurrent connections across all services
- Secrets rotation MUST be achievable with zero downtime (rolling restart)
- Data at rest MUST be encrypted (Atlas default encryption at rest)
- Data in transit MUST use TLS 1.2 or higher (enforced by SRV connection)

## Acceptance Criteria

- [ ] AC-001: `tutor local logs lms | grep mongodb` shows SRV connection attempts
- [ ] AC-002: `kubectl logs -l app.kubernetes.io/name=lms | grep "Connected to MongoDB"` succeeds
- [ ] AC-003: Course creation in Studio persists to Atlas `openedx` database
- [ ] AC-004: Forum posts persist to Atlas `cs_comments_service` database
- [ ] AC-005: No local MongoDB container exists: `docker ps | grep mongodb` returns nothing (local)
- [ ] AC-006: No MongoDB StatefulSet exists: `kubectl get statefulset mongodb` returns not found (K8s)
- [ ] AC-007: Atlas cluster shows active connections in monitoring dashboard
- [ ] AC-008: `pymongo[srv]` installed: `pip list | grep pymongo` shows extras
- [ ] AC-009: DNS resolution succeeds: `nslookup cluster-mereka-lms.2pjex4s.mongodb.net` returns results

## Edge Cases

### DNS Resolution Failure

**Symptom**: Connection fails with "getaddrinfo failed" or "Name or service not known"

**Cause**: `dnspython` not installed or DNS resolver can't reach MongoDB DNS

**Recovery**:
```bash
# Verify dnspython installed
kubectl exec -it lms-pod -- pip list | grep dnspython

# If missing, rebuild image with pymongo[srv]
tutor images build openedx
```

### IP Allowlist Block

**Symptom**: Connection times out or "connection refused"

**Cause**: GKE egress IP not in Atlas IP allowlist

**Recovery**:
```bash
# Get GKE NAT IPs
gcloud compute addresses list --filter="purpose:NAT"

# Add to Atlas via UI or CLI
atlas accessLists create <IP>/32 --projectId <PROJECT_ID>
```

### Connection Pool Exhaustion

**Symptom**: Requests fail with "connection pool exhausted" or timeout

**Cause**: Too many concurrent requests, pool size too small

**Recovery**: Increase `maxPoolSize` in connection string:
```python
MONGODB_URI = "mongodb+srv://user:pass@cluster/db?maxPoolSize=100"
```

### Atlas Maintenance Window

**Symptom**: Periodic connection failures during scheduled maintenance

**Cause**: Atlas performs rolling upgrades weekly

**Mitigation**:
- Atlas handles maintenance transparently (replica set failover)
- Application MUST retry failed operations (built into `retryWrites=true`)
- Monitor Atlas maintenance schedule in dashboard

### Cross-Region Latency

**Symptom**: Slow course load times, forum delays

**Cause**: Atlas cluster in different region than GKE cluster

**Recovery**: Migrate Atlas cluster to same region as GKE (requires downtime)

## Observability

### Logs

- Connection events: `grep "mongodb" tutor_env/logs/lms.log`
- SRV resolution: `grep "SRV lookup" tutor_env/logs/lms.log`
- Connection pool stats: `grep "connection pool" tutor_env/logs/lms.log`

### Metrics

Atlas provides built-in metrics:
- Connections (current, available, total)
- Operations per second (reads, writes)
- Query execution time
- Disk IOPS and storage usage

LMS/CMS should expose:
- MongoDB query duration histogram
- Connection pool wait time
- Failed connection attempts

### Alerts

Atlas built-in alerts:
- SHOULD alert if connections exceed 80% of maximum
- MUST alert if disk usage exceeds 80%
- MUST alert if replica set member goes down

Application alerts:
- MUST alert if MongoDB connection fails for >1 minute
- SHOULD alert if query latency p99 exceeds 500ms

### Dashboards

- Atlas monitoring dashboard: cluster health, connections, operations, storage
- Grafana dashboard: application-side MongoDB query latency, connection pool usage, error rates
- Link: Atlas console > Project > Cluster > Metrics (URL configured per environment)

## Rollout & Rollback

### Initial Migration

```bash
# 1. Export data from local MongoDB
tutor local do dump mongodb > mongodb-backup.archive

# 2. Create Atlas cluster and databases
# (Done via Atlas UI or Terraform)

# 3. Import data to Atlas
mongorestore --uri="mongodb+srv://user:pass@cluster-mereka-lms.2pjex4s.mongodb.net" \
  --archive=mongodb-backup.archive

# 4. Update Tutor config to use Atlas
tutor config save \
  --set MONGODB_HOST=cluster-mereka-lms.2pjex4s.mongodb.net \
  --set MONGODB_DATABASE=openedx \
  --set MONGODB_USE_SSL=true

# 5. Rebuild images (picks up pymongo[srv])
tutor images build openedx forum

# 6. Restart services
tutor k8s restart

# 7. Verify data integrity
# Check course count, forum posts, etc.
```

### Rollback to Local MongoDB

If Atlas migration fails:

```bash
# 1. Restore local MongoDB container
# Remove MongoDB disable flag from config

# 2. Import backup
tutor local do restore mongodb < mongodb-backup.archive

# 3. Revert config
tutor config save \
  --set MONGODB_HOST=mongodb \
  --set MONGODB_DATABASE=openedx \
  --set MONGODB_USE_SSL=false

# 4. Restart
tutor local restart
```

## Open Questions

1. Should we use Atlas VPC peering or IP allowlist for production?
2. What's the optimal connection pool size for LMS/CMS/Forum services?
3. Should we enable Atlas performance monitoring (adds cost)?
4. How do we handle Atlas cluster upgrades (M10 -> M20 scaling)?
5. Should we replicate Atlas cluster across regions for disaster recovery?
6. What's the backup retention policy (Atlas default is 2 days)?
