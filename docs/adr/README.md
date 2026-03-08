# Architecture Decision Records

_Generated from `docs/adr/manifest.yaml`. Do not hand-edit._

## Accepted, historical, and exception ADRs

| ADR | Title | Status | Type | Path |
|---|---|---|---|---|
| ADR-001 | ADR-001: MongoDB Atlas vs Local MongoDB | accepted | domain | [001-mongodb-atlas.md](001-mongodb-atlas.md) |
| ADR-002 | ADR-002: Multisite Architecture | accepted | domain | [002-multisite-architecture.md](002-multisite-architecture.md) |
| ADR-003 | ADR-003: Image Build Pipeline | accepted | domain | [003-image-build-pipeline.md](003-image-build-pipeline.md) |
| ADR-004 | ADR-004: Secrets Management | accepted | domain | [004-secrets-management.md](004-secrets-management.md) |
| ADR-005 | ADR-005: Domain Migration (legacy environment → academyV2) | accepted | migration | [005-domain-migration.md](005-domain-migration.md) |
| ADR-006 | --- | accepted | domain | [006-tutor-plugin-based-configuration.md](006-tutor-plugin-based-configuration.md) |
| ADR-007 | ADR-007: Forum Service Migration from Ruby to Python | accepted | migration | [007-forum-migration-ruby-to-python.md](007-forum-migration-ruby-to-python.md) |
| ADR-008 | ADR-008: Redis Streams as Event Bus | accepted | domain | [008-redis-streams-event-bus.md](008-redis-streams-event-bus.md) |
| ADR-009 | ADR-009: In-Cluster MySQL/Redis vs Cloud SQL/Memorystore | accepted | domain | [009-in-cluster-storage.md](009-in-cluster-storage.md) |
| ADR-010 | ADR-010: Monorepo Architecture | accepted | domain | [010-monorepo-architecture.md](010-monorepo-architecture.md) |
| ADR-011 | ADR-011: Convention-Based Spec Verification (V3) | accepted | domain | [011-convention-based-spec-verification.md](011-convention-based-spec-verification.md) |
| ADR-012 | ADR-012: Eliminate Runtime CSS ConfigMap Overlay | accepted | migration | [012-no-runtime-css-overlay.md](012-no-runtime-css-overlay.md) |
| ADR-013 | Studio SSO Bypass Middleware | accepted | exception | [013-studio-sso-bypass-middleware.md](013-studio-sso-bypass-middleware.md) |
| ADR-014 | ADR-014: MFE Branding Strategy - Migration Path Analysis | accepted | domain | [014-mfe-branding-strategy.md](014-mfe-branding-strategy.md) |
| ADR-015 | ADR-015: Mobile Push Notification Provider Selection | accepted | domain | [015-mobile-push-notification-provider.md](015-mobile-push-notification-provider.md) |
| ADR-016 | ADR-016: Android App Support Decision | deferred | domain | [016-android-app-support-decision.md](016-android-app-support-decision.md) |
| ADR-017 | ADR-017: Analytics Target Decision (Aspects/Superset Deployment) | accepted | migration | [017-analytics-target-decision.md](017-analytics-target-decision.md) |
| ADR-018 | Purchase Gateway Replaces Legacy Oscar Ecommerce | accepted | migration | [018-purchase-gateway-replaces-oscar-ecommerce.md](018-purchase-gateway-replaces-oscar-ecommerce.md) |
| ADR-019 | ADR-019: Tutor Upgrade Cadence and EOL Policy | accepted | foundation | [019-tutor-upgrade-policy.md](019-tutor-upgrade-policy.md) |
| ADR-020 | ADR-020: Tracing Scope and Pilot Decision for Mereka LMS | accepted | domain | [020-tracing-scope-and-pilot-decision.md](020-tracing-scope-and-pilot-decision.md) |
| ADR-021 | --- | accepted | foundation | [021-openedx-tutor-methodology.md](021-openedx-tutor-methodology.md) |
| ADR-022 | Session Cookie SameSite Policy and Stale Cookie Mitigation | accepted | exception | [022-session-cookie-samesite-policy.md](022-session-cookie-samesite-policy.md) |
| ADR-023 | --- | accepted | domain | [023-enterprise-images-ghcr-migration.md](023-enterprise-images-ghcr-migration.md) |
| ADR-024 | --- | accepted | foundation | [024-multi-tenancy-true-tenants.md](024-multi-tenancy-true-tenants.md) |
| ADR-025 | --- | accepted | domain | [025-csp-nonce-migration.md](025-csp-nonce-migration.md) |
| ADR-026 | --- | accepted | domain | [026-cicd-build-pipeline-lessons.md](026-cicd-build-pipeline-lessons.md) |
| ADR-028 | Platform Sources of Truth and Control Planes | accepted | foundation | [028-platform-sources-of-truth-and-control-planes.md](028-platform-sources-of-truth-and-control-planes.md) |
| ADR-029 | Identity, Session, and Domain-Boundary Strategy | accepted | foundation | [029-identity-session-and-domain-boundary-strategy.md](029-identity-session-and-domain-boundary-strategy.md) |
| ADR-030 | Feature Flag and Rollout Lifecycle | accepted | foundation | [030-feature-flag-and-rollout-lifecycle.md](030-feature-flag-and-rollout-lifecycle.md) |
| ADR-031 | Deprecation and Removal Policy | accepted | foundation | [031-deprecation-and-removal-policy.md](031-deprecation-and-removal-policy.md) |
| ADR-032 | Data Governance, PII, Retention, and Deletion | accepted | foundation | [032-data-governance-pii-retention-and-deletion.md](032-data-governance-pii-retention-and-deletion.md) |
| ADR-033 | Tenant Lifecycle Contract | accepted | foundation | [033-tenant-lifecycle-contract.md](033-tenant-lifecycle-contract.md) |

## RFC queue

Proposed decisions are kept out of the accepted ADR hot path and tracked here until accepted.

| RFC | Title | Status | Type | Path |
|---|---|---|---|---|
| ADR-027 | --- | proposed | foundation | [027-deployment-contract-ownership-lanes.md](027-deployment-contract-ownership-lanes.md) |
| ADR-034 | Event Contract and Transport Independence | proposed | domain | [rfc/034-event-contract-and-transport-independence.md](rfc/034-event-contract-and-transport-independence.md) |
| ADR-035 | Frontend Runtime Composition and Dependency Alignment | proposed | domain | [rfc/035-frontend-runtime-composition-and-dependency-alignment.md](rfc/035-frontend-runtime-composition-and-dependency-alignment.md) |
| ADR-036 | Cache Topology and Invalidation Strategy | proposed | domain | [rfc/036-cache-topology-and-invalidation-strategy.md](rfc/036-cache-topology-and-invalidation-strategy.md) |
| ADR-037 | Async Task User-Facing Contract | proposed | domain | [rfc/037-async-task-user-facing-contract.md](rfc/037-async-task-user-facing-contract.md) |
| ADR-038 | Commerce System of Record and Reconciliation | proposed | domain | [rfc/038-commerce-system-of-record-and-reconciliation.md](rfc/038-commerce-system-of-record-and-reconciliation.md) |
| ADR-039 | Translations and Internationalization Strategy | proposed | domain | [rfc/039-translations-and-internationalization-strategy.md](rfc/039-translations-and-internationalization-strategy.md) |
| ADR-040 | Internal Packages, Plugins, and Versioning Policy | proposed | domain | [rfc/040-internal-packages-plugins-and-versioning-policy.md](rfc/040-internal-packages-plugins-and-versioning-policy.md) |
| ADR-041 | Authorization and Role-Boundary Model | proposed | domain | [rfc/041-authorization-and-role-boundary-model.md](rfc/041-authorization-and-role-boundary-model.md) |
