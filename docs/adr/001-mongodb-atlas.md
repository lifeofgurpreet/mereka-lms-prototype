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

- Atlas cluster: `mereka-lms-cluster` in GCP `asia-southeast1`
- Connection string stored in Kubernetes Secret
- IP allowlist configured for GKE node IPs
