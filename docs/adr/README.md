# Architecture Decision Ledger

_Generated from ADR frontmatter. Do not hand-edit._

## Read First

- [Hot path](./_generated/hot-path.md)
- [History map](./_generated/history-map.md)
- [RFC queue](./rfc/README.md)
- [ADR templates](./templates/README.md)

## Current Law

Only current accepted ADRs remain at this root.

| ADR | Title | Type | Rollout | Path |
|---|---|---|---|---|
| ADR-006 | Tutor Plugin-Based Configuration Resilience | domain | active | [006-tutor-plugin-based-configuration.md](006-tutor-plugin-based-configuration.md) |
| ADR-013 | Studio SSO Bypass Middleware | exception | temporary | [013-studio-sso-bypass-middleware.md](013-studio-sso-bypass-middleware.md) |
| ADR-018 | Purchase Gateway Replaces Legacy Oscar Ecommerce | migration | active | [018-purchase-gateway-replaces-oscar-ecommerce.md](018-purchase-gateway-replaces-oscar-ecommerce.md) |
| ADR-019 | Tutor Upgrade Cadence and EOL Policy | foundation | active | [019-tutor-upgrade-policy.md](019-tutor-upgrade-policy.md) |
| ADR-021 | Open edX / Tutor Deployment Methodology | foundation | active | [021-openedx-tutor-methodology.md](021-openedx-tutor-methodology.md) |
| ADR-022 | Session Cookie SameSite Policy and Stale Cookie Mitigation | exception | temporary | [022-session-cookie-samesite-policy.md](022-session-cookie-samesite-policy.md) |
| ADR-024 | True Multi-Tenancy for Subsites (Biji-Biji, SkillOurFuture) | foundation | active | [024-multi-tenancy-true-tenants.md](024-multi-tenancy-true-tenants.md) |
| ADR-025 | CSP Nonce Migration — Removing unsafe-eval / unsafe-inline | domain | active | [025-csp-nonce-migration.md](025-csp-nonce-migration.md) |
| ADR-028 | Platform Sources of Truth and Control Planes | foundation | active | [028-platform-sources-of-truth-and-control-planes.md](028-platform-sources-of-truth-and-control-planes.md) |
| ADR-029 | Identity, Session, and Domain-Boundary Strategy | foundation | active | [029-identity-session-and-domain-boundary-strategy.md](029-identity-session-and-domain-boundary-strategy.md) |
| ADR-030 | Feature Flag and Rollout Lifecycle | foundation | active | [030-feature-flag-and-rollout-lifecycle.md](030-feature-flag-and-rollout-lifecycle.md) |
| ADR-031 | Deprecation and Removal Policy | foundation | active | [031-deprecation-and-removal-policy.md](031-deprecation-and-removal-policy.md) |
| ADR-032 | Data Governance, PII, Retention, and Deletion | foundation | active | [032-data-governance-pii-retention-and-deletion.md](032-data-governance-pii-retention-and-deletion.md) |
| ADR-033 | Tenant Lifecycle Contract | foundation | active | [033-tenant-lifecycle-contract.md](033-tenant-lifecycle-contract.md) |

## Historical Decisions

Historical ADRs remain discoverable but are not part of the default read path.

| ADR | Title | Path |
|---|---|---|
| ADR-001 | MongoDB Atlas vs Local MongoDB | [historical/001-mongodb-atlas.md](historical/001-mongodb-atlas.md) |
| ADR-002 | Multisite Architecture | [historical/002-multisite-architecture.md](historical/002-multisite-architecture.md) |
| ADR-003 | Image Build Pipeline | [historical/003-image-build-pipeline.md](historical/003-image-build-pipeline.md) |
| ADR-004 | Secrets Management | [historical/004-secrets-management.md](historical/004-secrets-management.md) |
| ADR-005 | Domain Migration (legacy environment → academyV2) | [historical/005-domain-migration.md](historical/005-domain-migration.md) |
| ADR-007 | Forum Service Migration from Ruby to Python | [historical/007-forum-migration-ruby-to-python.md](historical/007-forum-migration-ruby-to-python.md) |
| ADR-008 | Redis Streams as Event Bus | [historical/008-redis-streams-event-bus.md](historical/008-redis-streams-event-bus.md) |
| ADR-009 | In-Cluster MySQL/Redis vs Cloud SQL/Memorystore | [historical/009-in-cluster-storage.md](historical/009-in-cluster-storage.md) |
| ADR-010 | Monorepo Architecture | [historical/010-monorepo-architecture.md](historical/010-monorepo-architecture.md) |
| ADR-012 | Eliminate Runtime CSS ConfigMap Overlay | [historical/012-no-runtime-css-overlay.md](historical/012-no-runtime-css-overlay.md) |
| ADR-023 | Enterprise Images GHCR Migration | [historical/023-enterprise-images-ghcr-migration.md](historical/023-enterprise-images-ghcr-migration.md) |
| ADR-026 | CI/CD Build Pipeline Lessons Learned (ARC Migration, March 2026) | [historical/026-cicd-build-pipeline-lessons.md](historical/026-cicd-build-pipeline-lessons.md) |

## RFC Queue

Proposals stay out of the accepted ADR hot path until accepted.

| RFC | Title | Path |
|---|---|---|
| ADR-027 | Deployment Contract — Ownership Lanes Between App and GitOps Repos | [rfc/027-deployment-contract-ownership-lanes.md](rfc/027-deployment-contract-ownership-lanes.md) |
| ADR-034 | Event Contract and Transport Independence | [rfc/034-event-contract-and-transport-independence.md](rfc/034-event-contract-and-transport-independence.md) |
| ADR-035 | Frontend Runtime Composition and Dependency Alignment | [rfc/035-frontend-runtime-composition-and-dependency-alignment.md](rfc/035-frontend-runtime-composition-and-dependency-alignment.md) |
| ADR-036 | Cache Topology and Invalidation Strategy | [rfc/036-cache-topology-and-invalidation-strategy.md](rfc/036-cache-topology-and-invalidation-strategy.md) |
| ADR-037 | Async Task User-Facing Contract | [rfc/037-async-task-user-facing-contract.md](rfc/037-async-task-user-facing-contract.md) |
| ADR-038 | Commerce System of Record and Reconciliation | [rfc/038-commerce-system-of-record-and-reconciliation.md](rfc/038-commerce-system-of-record-and-reconciliation.md) |
| ADR-039 | Translations and Internationalization Strategy | [rfc/039-translations-and-internationalization-strategy.md](rfc/039-translations-and-internationalization-strategy.md) |
| ADR-040 | Internal Packages, Plugins, and Versioning Policy | [rfc/040-internal-packages-plugins-and-versioning-policy.md](rfc/040-internal-packages-plugins-and-versioning-policy.md) |
| ADR-041 | Authorization and Role-Boundary Model | [rfc/041-authorization-and-role-boundary-model.md](rfc/041-authorization-and-role-boundary-model.md) |
| RFC-claim-based-role-sync | Claim-Based Role Sync | [rfc/RFC-claim-based-role-sync.md](rfc/RFC-claim-based-role-sync.md) |
| RFC-learning-slot-expansion-proposal | Learning Slot Expansion Proposal | [rfc/RFC-learning-slot-expansion-proposal.md](rfc/RFC-learning-slot-expansion-proposal.md) |

## Authority Order

1. ADR frontmatter in the file itself
2. ADR body content in the file itself
3. Generated projections under `docs/adr/_generated/`
4. Generated compatibility maps (`manifest.yaml`, `classification-map.yaml`, `status-map.yaml`) if still consumed by tooling
