---
id: ADR-008
title: Redis Streams as Event Bus
decision_status: accepted
decision_type: domain
rollout_state: historical
owner: platform-team
created: '2026-02-10'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next: []
governs: []
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions: []
expiry_date: null
removal_condition: null
historical_reason: No longer read-first law for pre-launch platform; retained as domain
  history.
---
<!-- markdownlint-disable -->

# ADR-008: Redis Streams as Event Bus

**Status**: Accepted
**Date**: 2026-02-10
**Deciders**: Platform Team
**Related**: [specs/cross-cutting-requirements_spec.md](../../specs/cross-cutting-requirements_spec.md)

<!-- Last verified: 2026-02-13 -->

## Context

The Mereka Academy platform requires an event bus for asynchronous communication between services, including:
- Purchase events from the purchase-gateway to entitlement-engine
- Enrollment events to trigger analytics pipelines
- User activity events for audit logging
- Multi-tenant event streams requiring isolation

We evaluated event bus technologies considering:
- Operational overhead
- Existing infrastructure
- Event volume and throughput requirements
- Multi-tenancy support
- Team expertise

## Decision

We chose **Redis Streams** as the platform-wide event bus technology.

## Consequences

### Positive
- Redis is already deployed in-cluster for caching and Celery queuing
- Zero additional infrastructure to maintain
- Native consumer group support for competing consumers
- Built-in message acknowledgment and retry
- Sufficient for current event volume (< 1000 events/sec)
- Simple operational model (backup, monitoring already in place)
- Native support in Python (redis-py), Node.js, and other languages
- Low latency (in-cluster communication)

### Negative
- No native multi-data-center replication (not needed for current deployment)
- Limited to in-memory storage (requires persistence configuration)
- Less feature-rich than dedicated event streaming platforms (Kafka, Pulsar)
- Consumer groups require manual coordination for scaling

## Alternatives Considered

### Apache Kafka
- Industry-standard event streaming platform
- Strong durability and replication guarantees
- Excellent for high-volume event streams (> 10k events/sec)
- **Rejected because**: Significant operational overhead, requires dedicated cluster, Zookeeper/KRaft management, overkill for current event volume

### Google Cloud Pub/Sub
- Fully managed, no operational overhead
- Auto-scaling, strong durability
- **Rejected because**: Higher cost for persistent connections, adds external dependency, vendor lock-in, cross-cloud latency for GKE egress

### RabbitMQ
- Mature message broker with rich routing capabilities
- Already familiar to team (used in some Open edX contexts)
- **Rejected because**: Another service to maintain, Redis already deployed, Streams API sufficient for current needs

### NATS JetStream
- Lightweight, high-performance streaming
- Lower operational overhead than Kafka
- **Rejected because**: Additional service to deploy and maintain, team unfamiliar with NATS ecosystem

## Implementation Notes

- **Stream naming convention**: `mereka:events:<domain>:<entity>` (e.g., `mereka:events:purchases:completed`)
- **Consumer groups**: Services create consumer groups with service name as group ID
- **Tenant isolation**: Events include `tenant_id` field; consumers filter by tenant
- **Persistence**: Redis configured with AOF (Append-Only File) persistence for durability
- **Monitoring**: Prometheus metrics for stream length, consumer lag, processing rate
- **Idempotency**: Consumers must implement deduplication using event ID
- **Message format**: JSON-encoded events with `event_id`, `tenant_id`, `timestamp`, `event_type`, and `payload` fields

### Example Event Structure

```json
{
  "event_id": "01HQZX8F2N9Q7VKJP3S6TBMR8W",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-02-10T12:34:56.789Z",
  "event_type": "purchase.completed",
  "payload": {
    "order_id": "ORD-12345",
    "course_id": "course-v1:MerekaAcademy+CS101+2026",
    "amount": 99.00,
    "currency": "USD"
  }
}
```

## Migration Path

Services currently using direct synchronous calls or Celery tasks for event-driven workflows should migrate to Redis Streams:

1. Identify event-driven workflows (e.g., purchase → enrollment)
2. Define event schema and stream naming
3. Implement event publisher in producing service
4. Implement event consumer in consuming service with idempotency
5. Deploy both services with feature flag to enable stream-based flow
6. Monitor and verify event delivery
7. Remove legacy synchronous call after verification
8. Remove feature flag

## Scalability Considerations

Redis Streams is sufficient for current scale (< 1000 events/sec). If event volume exceeds Redis capacity:

- **Short-term**: Vertical scaling (increase Redis memory and CPU)
- **Long-term**: Migrate to Kafka or Pulsar with consumer compatibility layer (event format remains the same)

## References

- [Redis Streams Documentation](https://redis.io/docs/data-types/streams/)
- [Cross-Cutting Requirements Spec](../../specs/cross-cutting-requirements_spec.md#5-technology-decisions-platform-wide)
- [Redis Streams Tutorial](https://redis.io/docs/data-types/streams-tutorial/)
