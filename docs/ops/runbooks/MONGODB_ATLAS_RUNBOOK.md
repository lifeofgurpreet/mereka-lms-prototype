# MongoDB Atlas Runbook
_Audience: Platform Eng + SRE • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for MongoDB Atlas integration with Mereka Academy.

> **Spec**: `specs/mongodb-atlas-integration_spec.md`
> **Testmap**: `specs/testmaps/mongodb-atlas-integration_spec.testmap.yml`
> **ADR**: `docs/adr/historical/001-mongodb-atlas.md`

## Architecture

- **Cluster**: `cluster-mereka-lms.2pjex4s.mongodb.net`
- **Databases**: `openedx` (modulestore), `cs_comments_service` (forum)
- **Connection**: SRV protocol via `pymongo[srv]`
- **Password**: Stored in Infisical as `MEREKA_LMS_MONGODB_PASSWORD`

## Prerequisites

- MongoDB Atlas console access
- Atlas CLI or `mongosh` with Atlas connection string
- Access to production GKE cluster

---

## Verify Atlas Health > Active Connections

### Procedure
1. Log in to MongoDB Atlas console
2. Navigate to cluster `cluster-mereka-lms` > Metrics
3. Check active connections:
   - Normal range: 10-50 connections
   - Alert threshold: > 100 connections
4. Alternatively, via mongosh:
   ```bash
   mongosh "mongodb+srv://cluster-mereka-lms.2pjex4s.mongodb.net/openedx" --eval "db.serverStatus().connections"
   ```

### Acceptance
- Active connections within normal range (10-50)
- No connection pool exhaustion warnings
- Connection count stable over time (no leaks)

---

## Atlas Maintenance Windows

### Procedure
1. Check Atlas maintenance schedule in console:
   - Navigate to Project Settings > Maintenance Window
2. Verify `retryWrites=true` is in connection string:
   ```bash
   kubectl get secret openedx-mongodb -n mereka-lms -o jsonpath='{.data.MONGODB_HOST}' | base64 -d
   ```
3. Verify maintenance window does not overlap with peak usage hours (09:00-17:00 MYT)

### Acceptance
- Atlas maintenance window is configured during off-peak hours
- `retryWrites=true` is set in connection string
- Application handles Atlas failover transparently (no user-visible errors)

---

## Latency Verification

### Procedure
1. Access Atlas Performance Advisor:
   - Navigate to cluster > Performance Advisor
2. Check query latency metrics:
   - Read latency target: < 50ms p95
   - Write latency target: < 100ms p95
3. Check network latency from GKE to Atlas:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python -c "
   import time, pymongo
   client = pymongo.MongoClient('mongodb+srv://...')
   start = time.time()
   client.admin.command('ping')
   print(f'Ping: {(time.time()-start)*1000:.1f}ms')
   "
   ```

### Acceptance
- Read latency < 50ms p95
- Write latency < 100ms p95
- Network ping to Atlas < 20ms (Singapore region)
- No slow query warnings in Performance Advisor
