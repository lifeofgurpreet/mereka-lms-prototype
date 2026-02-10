# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) documenting significant architectural decisions made for the Mereka LMS project.

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](001-mongodb-atlas.md) | MongoDB Atlas vs Local MongoDB | Accepted | 2026-02-03 |
| [ADR-002](002-multisite-architecture.md) | Multisite Architecture | Accepted | 2026-02-03 |
| [ADR-003](003-image-build-pipeline.md) | Image Build Pipeline | Accepted | 2026-02-03 |
| [ADR-004](004-secrets-management.md) | Secrets Management | Accepted | 2026-02-03 |
| [ADR-005](005-domain-migration.md) | Domain Migration (legacy environment → academyV2) | Accepted | 2026-02-03 |
| [ADR-006](006-tutor-plugin-based-configuration.md) | Tutor Plugin-Based Configuration Resilience | Proposed | 2026-02-10 |
| [ADR-007](007-forum-migration-ruby-to-python.md) | Forum Service Migration from Ruby to Python | Accepted and Implemented | 2026-02-10 |
| [ADR-008](008-redis-streams-event-bus.md) | Redis Streams as Event Bus | Accepted | 2026-02-10 |
| [ADR-009](009-in-cluster-storage.md) | In-Cluster MySQL/Redis vs Cloud SQL/Memorystore | Accepted | 2026-02-10 |
| [ADR-010](010-monorepo-architecture.md) | Monorepo Architecture | Accepted | 2026-02-10 |

## ADR Template

When creating new ADRs, use this template:

```markdown
# ADR-NNN: Title

**Status**: Proposed | Accepted | Deprecated | Superseded
**Date**: YYYY-MM-DD
**Deciders**: [list of people involved]

## Context

[Describe the issue that requires a decision]

## Decision

[Describe the decision made]

## Consequences

### Positive
- [List positive outcomes]

### Negative
- [List negative outcomes or trade-offs]

## Alternatives Considered

[List alternatives that were considered but not chosen]
```
