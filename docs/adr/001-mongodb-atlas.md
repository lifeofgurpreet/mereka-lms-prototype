# ADR-001: MongoDB Atlas vs Local MongoDB

**Status**: Accepted
**Date**: 2026-02-03
**Deciders**: Platform Team

## Context

Open edX uses MongoDB for the course modulestore and forum service. We needed to decide between:
1. Running MongoDB locally in Kubernetes
2. Using MongoDB Atlas (managed service)

Considerations included:
- Operational overhead
- Cost
- Reliability and backups
- Performance

## Decision

We chose **MongoDB Atlas** (managed service) for production workloads.

## Consequences

### Positive
- Zero operational overhead for MongoDB management
- Automatic backups and point-in-time recovery
- Built-in monitoring and alerting
- Easy scaling without downtime
- Geo-distributed replicas available if needed

### Negative
- Higher cost than self-managed (~$50-100/month for M10 tier)
- Data egress charges for cross-region access
- Dependency on external service
- Requires network connectivity from GKE to Atlas

## Alternatives Considered

### Local MongoDB in Kubernetes
- Lower cost (only compute resources)
- Full control over configuration
- **Rejected because**: Significant operational overhead, backup complexity, no automatic failover

### Percona MongoDB Operator
- Kubernetes-native MongoDB management
- Automatic failover and backups
- **Rejected because**: Still requires significant expertise, adds complexity

## Implementation Notes

- **Atlas cluster**: `cluster-mereka-lms.2pjex4s.mongodb.net`
- **Databases**: `openedx` (modulestore), `cs_comments_service` (forum)
- **Connection**: Username + password stored in Infisical (`MEREKA_LMS_MONGODB_USERNAME`, `MEREKA_LMS_MONGODB_PASSWORD`), synced to K8s
- **Required roles**: MongoDB user must have `readWrite` on both `openedx` and `cs_comments_service`
- **Local MongoDB**: Target state is Atlas-only, but do not assume this is true in every environment until verified.

### Current State (Verified 2026-02-07)

- **Forum**: uses Atlas (via `MONGODB_HOST` configured to a `*.mongodb.net` host).
- **LMS/CMS modulestore**: uses Atlas in production (`MONGODB_HOST` + Atlas-aware settings patches).
- **Legacy in-cluster MongoDB deployment** (`Deployment/mongodb`) has been retired in production after a Velero pre-op backup.
- **Legacy in-cluster MongoDB service** (`Service/mongodb`) is being removed through the production overlay GitOps patch.

Cutover status: complete for active modulestore and forum paths; enforce Atlas-only via runtime gates to prevent regression.

## Migration Path

If migrating from local MongoDB to Atlas:
1. Export data from local MongoDB
2. Import to Atlas cluster
3. Update connection strings in settings
4. Remove local MongoDB deployment

**Note**: This ADR records the intended architecture. Always verify the live configuration (`MONGODB_HOST` in LMS/CMS + forum) and confirm legacy in-cluster resources remain absent.
