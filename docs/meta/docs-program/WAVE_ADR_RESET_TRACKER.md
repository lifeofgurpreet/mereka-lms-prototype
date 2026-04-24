# Wave ADR Reset Tracker

_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-04-14 • Status: historical tracker snapshot_

This document is retained as historical ADR-reset context.
It does not define the current docs-program execution front door or the
current architecture front door.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

## Objective

Reset `docs/adr/` into a pre-launch decision ledger:
- current accepted ADRs only at `docs/adr/` root
- historical ADRs under `docs/adr/historical/`
- proposals under `docs/adr/rfc/`
- non-ADR documents moved out of ADR space
- generated surfaces derived from ADR frontmatter, not hand-authored manifest truth

## Packet Plan

### Packet A
- Create tracker and target tree
- Lock classification for every ADR-shaped file
- Lock target root current-law set

### Packet B
- Move obvious non-ADR material out of ADR space
- Rewrite affected internal references

### Packet C
- Move historical ADRs into `docs/adr/historical/`
- Move `ADR-027` into the RFC queue
- Remove root proposal stubs from the accepted hot path

### Packet D
- Normalize frontmatter on current-law ADRs and RFCs
- Trim active ADRs so they read as decisions, not notebooks

### Packet E
- Generate ADR README and ledger projections
- Add ADR ledger gates
- Leave closeout + review handoff

## Locked Classification

### Current accepted ADR root
- `docs/adr/006-tutor-plugin-based-configuration.md`
- `docs/adr/013-studio-sso-bypass-middleware.md`
- `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`
- `docs/adr/019-tutor-upgrade-policy.md`
- `docs/adr/021-openedx-tutor-methodology.md`
- `docs/adr/022-session-cookie-samesite-policy.md`
- `docs/adr/024-multi-tenancy-true-tenants.md`
- `docs/adr/025-csp-nonce-migration.md`
- `docs/adr/028-platform-sources-of-truth-and-control-planes.md`
- `docs/adr/029-identity-session-and-domain-boundary-strategy.md`
- `docs/adr/030-feature-flag-and-rollout-lifecycle.md`
- `docs/adr/031-deprecation-and-removal-policy.md`
- `docs/adr/032-data-governance-pii-retention-and-deletion.md`
- `docs/adr/033-tenant-lifecycle-contract.md`

### Historical ADRs
- `docs/adr/historical/001-mongodb-atlas.md`
- `docs/adr/historical/002-multisite-architecture.md`
- `docs/adr/historical/003-image-build-pipeline.md`
- `docs/adr/historical/004-secrets-management.md`
- `docs/adr/historical/005-domain-migration.md`
- `docs/adr/historical/007-forum-migration-ruby-to-python.md`
- `docs/adr/historical/008-redis-streams-event-bus.md`
- `docs/adr/historical/009-in-cluster-storage.md`
- `docs/adr/historical/010-monorepo-architecture.md`
- `docs/adr/historical/012-no-runtime-css-overlay.md`
- `docs/adr/historical/023-enterprise-images-ghcr-migration.md`
- `docs/adr/historical/026-cicd-build-pipeline-lessons.md`

### RFC queue
- `docs/adr/rfc/027-deployment-contract-ownership-lanes.md`
- `docs/adr/rfc/034-event-contract-and-transport-independence.md`
- `docs/adr/rfc/035-frontend-runtime-composition-and-dependency-alignment.md`
- `docs/adr/rfc/036-cache-topology-and-invalidation-strategy.md`
- `docs/adr/rfc/037-async-task-user-facing-contract.md`
- `docs/adr/rfc/038-commerce-system-of-record-and-reconciliation.md`
- `docs/adr/rfc/039-translations-and-internationalization-strategy.md`
- `docs/adr/rfc/040-internal-packages-plugins-and-versioning-policy.md`
- `docs/adr/rfc/041-authorization-and-role-boundary-model.md`
- `docs/adr/rfc/RFC-claim-based-role-sync.md`
- `docs/adr/rfc/RFC-learning-slot-expansion-proposal.md`

### Move out of ADR space entirely
- `docs/guides/standards/SPEC_VERIFICATION_METHOD.md` from `docs/adr/011-convention-based-spec-verification.md`
- `docs/programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md` from `docs/adr/014-mfe-branding-strategy.md`
- `docs/programs/mobile/PUSH_NOTIFICATION_PROVIDER_DECISION.md` from `docs/adr/015-mobile-push-notification-provider.md`
- `docs/programs/mobile/ANDROID_SUPPORT_DECISION.md` from `docs/adr/016-android-app-support-decision.md`
- `docs/programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md` from `docs/adr/017-analytics-target-decision.md`
- `docs/programs/observability/TRACING_PILOT_DECISION.md` from `docs/adr/020-tracing-scope-and-pilot-decision.md`

## Target Hot Path

The generated hot path must stay at 12 documents or fewer. Default target:
- ADR-021
- ADR-028
- ADR-029
- ADR-030
- ADR-031
- ADR-032
- ADR-033
- ADR-006
- ADR-018
- ADR-013
- ADR-022
- ADR-024

## Open Questions To Resolve In-Wave

- Whether any active ADR still needs a second-pass trim after the first normalization sweep.
