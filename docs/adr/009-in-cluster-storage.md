# ADR-009: In-Cluster MySQL/Redis vs Cloud SQL/Memorystore

**Status**: Accepted
**Date**: 2026-02-10
**Deciders**: Platform Team
**Related**: [ADR-001: MongoDB Atlas](001-mongodb-atlas.md)

## Context

The Mereka Academy platform requires persistent storage for:
- **MySQL 8**: Course data, user data, enrollment records (Open edX primary database)
- **Redis**: Caching, Celery message broker, event bus (Redis Streams)

We needed to decide between:
1. Running MySQL and Redis in-cluster with PersistentVolumeClaim (PVC) backed storage
2. Using Google Cloud managed services (Cloud SQL for MySQL, Memorystore for Redis)

Considerations included:
- Cost (managed vs self-hosted)
- Operational overhead
- Backup and disaster recovery
- Performance and latency
- Current scale and projected growth
- Comparison to our MongoDB decision (we chose Atlas for MongoDB in [ADR-001](001-mongodb-atlas.md))

## Decision

We chose **in-cluster deployment** for both MySQL and Redis, backed by GKE PersistentVolumes.

## Consequences

### Positive
- **Cost savings**: ~$200-300/month savings compared to Cloud SQL + Memorystore
- **Lower latency**: In-cluster communication avoids network hops
- **Simpler networking**: No Cloud SQL proxy configuration
- **Full control**: Can tune MySQL and Redis configurations freely
- **No vendor lock-in**: Can migrate to any Kubernetes cluster
- **Terraform retained**: Cloud SQL/Memorystore Terraform modules kept for future use

### Negative
- **Operational overhead**: Manual backup scripts, monitoring, and upgrades
- **No automatic failover**: High availability requires custom orchestration
- **Backup complexity**: Must implement and verify custom backup pipelines
- **Recovery time**: Longer recovery than managed services (no point-in-time restore)
- **No built-in read replicas**: Scaling reads requires manual replication setup

## Alternatives Considered

### Cloud SQL for MySQL + Memorystore for Redis
- Fully managed with automatic backups and failover
- Built-in monitoring and alerting
- Point-in-time recovery
- Automatic minor version upgrades
- **Rejected because**: ~$200-300/month cost not justified at current scale (~1000 users, ~50 courses), operational overhead manageable with existing scripts, in-cluster performance sufficient

### Percona Operator for MySQL + Redis Operator
- Kubernetes-native with automated backups and high availability
- Lower cost than Cloud SQL/Memorystore
- **Rejected because**: Adds complexity, operators require learning curve, current scale doesn't justify operator overhead

## Implementation Notes

### MySQL 8
- **Deployment**: StatefulSet with single replica
- **Storage**: 50GB PVC with `standard-rwo` StorageClass (GCE Persistent Disk)
- **Backups**: Daily automated backups to Google Cloud Storage via `scripts/infra/backup-db.sh`
- **Retention**: 7 daily backups, 4 weekly backups
- **Monitoring**: Prometheus exporter sidecar for metrics
- **Authentication**: Native password plugin (`mysql_native_password`) for Open edX compatibility

### Redis
- **Deployment**: StatefulSet with single replica
- **Storage**: 10GB PVC for AOF (Append-Only File) persistence
- **Persistence**: AOF enabled with `appendfsync everysec` for balance of durability and performance
- **Backups**: Daily snapshots to GCS via `redis-cli BGSAVE` + GCS upload
- **Monitoring**: Redis exporter for Prometheus metrics
- **Configuration**:
  - Max memory: 8GB with `allkeys-lru` eviction policy for cache keys
  - AOF persistence for Streams and Celery queues
  - Separate logical databases for cache (0), Celery (1), Streams (2)

### Backup Verification
- Monthly backup restoration tests (automated via `scripts/infra/test-backup-restore.sh`)
- Backup success/failure alerts via Prometheus + Alertmanager

## Scale-Out Plan

If the platform grows beyond in-cluster capacity:

### MySQL Scale-Out Triggers
- Database size > 100GB (approaching PVC limits)
- Query latency p95 > 500ms sustained
- Connection pool exhaustion (> 80% utilization sustained)
- Need for read replicas (read-heavy workload)

### Redis Scale-Out Triggers
- Memory usage > 80% sustained
- Event stream lag > 10k messages
- Eviction rate > 1000 evictions/sec

### Migration Path to Managed Services
1. Terraform modules already exist in `infrastructure/terraform/modules/`
2. Create Cloud SQL instance with same schema (use `tutor local do backup-db` for export)
3. Create Memorystore instance with same Redis version
4. Update Kubernetes secrets with Cloud SQL/Memorystore connection strings
5. Deploy Cloud SQL proxy sidecar for LMS/CMS pods
6. Rolling restart to pick up new connections
7. Verify data integrity and performance
8. Decommission in-cluster MySQL/Redis after 7-day monitoring period

## Cost Comparison (Monthly, Asia-Southeast1)

| Component | In-Cluster | Managed Service | Delta |
|-----------|-----------|-----------------|-------|
| MySQL 8 | ~$15 (50GB PVC) | ~$150 (Cloud SQL db-n1-standard-1) | +$135 |
| Redis | ~$10 (10GB PVC) | ~$80 (Memorystore 5GB M1) | +$70 |
| **Total** | **~$25** | **~$230** | **+$205** |

At current scale, the 9x cost increase is not justified. Re-evaluate when user count exceeds 10,000 or database size exceeds 100GB.

## References

- [ADR-001: MongoDB Atlas](001-mongodb-atlas.md) - Contrasting decision for document storage
- [Tutor Documentation: Database Configuration](https://docs.tutor.edly.io/configuration.html)
- [GKE Persistent Volumes](https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes)
- [Terraform Modules](../../infrastructure/terraform/modules/) - Retained for future use
