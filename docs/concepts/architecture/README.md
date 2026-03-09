# Architecture Documentation
_Audience: Engineering Team • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This directory is the canonical architecture narrative and living-standards root for Mereka LMS.

## Use this root for

Come here when you need:
- current architecture standards,
- architecture-level contracts and audits,
- system-shape overviews,
- or architecture proposals that are still under evaluation.

## Authority boundary

- Living architecture standards live here.
- ADRs in `docs/adr/` remain the decision ledger.
- Legacy `docs/architecture/**` is transitional compatibility surface during Wave 2 and MUST NOT be treated as the winning authority root.
- Operator procedure lives in `docs/ops/**`.
- Proof lives in `docs/evidence/**`.
- Active status lives in `docs/status/**`.

## Start here

1. [ARCHITECTURE_CHARTER.md](ARCHITECTURE_CHARTER.md)
2. [DOCUMENTATION_AUTHORITY_RESOLVER.md](DOCUMENTATION_AUTHORITY_RESOLVER.md)
3. [CONTROL_PLANES.md](CONTROL_PLANES.md)
4. [TUTOR_AND_EXTENSION_MODEL.md](TUTOR_AND_EXTENSION_MODEL.md)
5. [IDENTITY_DOMAIN_BOUNDARIES.md](IDENTITY_DOMAIN_BOUNDARIES.md)
6. [TENANT_LIFECYCLE.md](TENANT_LIFECYCLE.md)
7. [DATA_GOVERNANCE.md](DATA_GOVERNANCE.md)
8. [AUTHORIZATION_MODEL.md](AUTHORIZATION_MODEL.md)
9. [DOCS_SPECS_CONTRACT.md](../../guides/standards/DOCS_SPECS_CONTRACT.md)
10. the proposal queue: [../../adr/rfc/README.md](../../adr/rfc/README.md)

## Fast routes by task

- Want the governing rule set:
  - start with the charter, resolver, and constitution standards
- Want frontend/runtime architecture:
  - go to `Frontend and runtime architecture`
- Want data, analytics, assessment, or service architecture:
  - go to `Analytics, assessment, and service architecture`
- Want repo cleanup or architecture program context:
  - go to `Programs, proposals, and repo hygiene`
- Want accepted decision history:
  - go to [../../adr/README.md](../../adr/README.md)
- Want unresolved design proposals:
  - go to [../../adr/rfc/README.md](../../adr/rfc/README.md)

## Infrastructure Architecture

- **[DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md)** - Database strategy (MySQL, MongoDB Atlas, Redis)
- **[ARCHITECTURE_MONGODB.md](ARCHITECTURE_MONGODB.md)** - Atlas-specific MongoDB architecture notes
- **[PRODUCTION_ARCHITECTURE_REALITY.md](PRODUCTION_ARCHITECTURE_REALITY.md)** - runtime reality and system-shape checkpoint
- **[MONGODB_ATLAS_MIGRATION.md](MONGODB_ATLAS_MIGRATION.md)** - historical Atlas migration closeout still useful as architecture context
- **[MULTISITE_ANALYSIS.md](../../../reports/2025/audits/MULTISITE_ANALYSIS.md)** - historical multi-site audit retained for comparison context
- **[ADR-025-deployment-boundary.md](../../adr/rfc/ADR-025-deployment-boundary.md)** - RFC retained outside the accepted ADR hot path

## Core standards and contracts

- **[CONTROL_PLANES.md](CONTROL_PLANES.md)** - governing rule for repository truth, GitOps truth, and render artifacts
- **[TUTOR_AND_EXTENSION_MODEL.md](TUTOR_AND_EXTENSION_MODEL.md)** - Tutor and extension methodology
- **[IDENTITY_DOMAIN_BOUNDARIES.md](IDENTITY_DOMAIN_BOUNDARIES.md)** - identity, federation, and root-domain boundary rules
- **[TENANT_LIFECYCLE.md](TENANT_LIFECYCLE.md)** - tenant lifecycle and isolation contract
- **[RELEASE_ROLLOUT_AND_REMOVAL.md](RELEASE_ROLLOUT_AND_REMOVAL.md)** - rollout, deprecation, and removal policy
- **[DATA_GOVERNANCE.md](DATA_GOVERNANCE.md)** - privacy, retention, and deletion law
- **[AUTHORIZATION_MODEL.md](AUTHORIZATION_MODEL.md)** - role and tenant-boundary authorization model

- **[COPY_TERMINOLOGY_CONTRACT.md](COPY_TERMINOLOGY_CONTRACT.md)** - copy and terminology rules that shape user-facing consistency
- **[CSS_SCOPING_AUDIT.md](CSS_SCOPING_AUDIT.md)** - CSS scoping audit for branded and multisite surfaces
- **[INTERACTION_STATE_CONTRACT.md](INTERACTION_STATE_CONTRACT.md)** - interaction-state rules for UI behavior
- **[PERFORMANCE_BUDGETS.md](PERFORMANCE_BUDGETS.md)** - architecture-level performance budget contract
- **[GDPR_COMPLIANCE.md](GDPR_COMPLIANCE.md)** - architecture-level privacy and compliance framing
- **[MULTISITE_UX_CONSISTENCY.md](MULTISITE_UX_CONSISTENCY.md)** - multisite experience consistency rules

## Frontend and runtime architecture

- **[BRAND_PARITY.md](BRAND_PARITY.md)** - parity target for branded surfaces
- **[DESIGN_TOKENS_MIGRATION.md](DESIGN_TOKENS_MIGRATION.md)** - token migration architecture and rollout shape
- **[FOOTER_PARITY.md](FOOTER_PARITY.md)** - footer experience parity contract
- **[FOOTER_SLOT_MIGRATION.md](FOOTER_SLOT_MIGRATION.md)** - migration path for footer-slot architecture
- **[MFE_RUNTIME_CONFIG.md](MFE_RUNTIME_CONFIG.md)** - runtime MFE configuration contract
- **[MFE_ROUTE_TO_DIST_CONTRACT.md](MFE_ROUTE_TO_DIST_CONTRACT.md)** - route-to-dist ownership mapping
- **[MFE_SELECTOR_DECISION_LOG.md](MFE_SELECTOR_DECISION_LOG.md)** - selector strategy decisions and rationale
- **[MFE_SELECTOR_AUDIT.md](MFE_SELECTOR_AUDIT.md)** - selector audit output for current surface coverage
- **[MFE_SELECTOR_OVERRIDE_INVENTORY.md](MFE_SELECTOR_OVERRIDE_INVENTORY.md)** - known selector override inventory
- **[MFE_PLUGIN_SLOT_INVENTORY.md](MFE_PLUGIN_SLOT_INVENTORY.md)** - plugin-slot inventory for runtime composition
- **[MFE_COMPLETE_LIST.md](MFE_COMPLETE_LIST.md)** - canonical MFE surface inventory
- **[MFE_VERSIONS.md](MFE_VERSIONS.md)** - MFE version inventory
- **[FPF_PLUGIN_SLOT_REGISTRY.md](FPF_PLUGIN_SLOT_REGISTRY.md)** - frontend plugin framework slot registry
- **[OEP48_BRAND_PACKAGE.md](OEP48_BRAND_PACKAGE.md)** - brand package contract for OEP-48 alignment
- **[OEP65_MODULE_READINESS.md](OEP65_MODULE_READINESS.md)** - module readiness against OEP-65 style runtime composition
- **[TUTOR_PATCHES_INVENTORY.md](TUTOR_PATCHES_INVENTORY.md)** - Tutor patch inventory that should shrink over time
- **[PARAGON_V22_TOKEN_AUDIT.md](PARAGON_V22_TOKEN_AUDIT.md)** - Paragon/token audit reference
- **[TOKEN_GENERATION_PIPELINE.md](TOKEN_GENERATION_PIPELINE.md)** - token-generation source pipeline
- **[TOKEN_REFERENCE_INTEGRITY.md](TOKEN_REFERENCE_INTEGRITY.md)** - token reference integrity rules
- **[MOBILE_TOKEN_PARITY.md](MOBILE_TOKEN_PARITY.md)** - parity expectations for mobile token consumption

## Analytics, assessment, and service architecture

- **[ANALYTICS_DECISION_GATE.md](ANALYTICS_DECISION_GATE.md)** - decision gate for analytics direction
- **[ANALYTICS_DRIFT_GUARDRAILS.md](ANALYTICS_DRIFT_GUARDRAILS.md)** - guardrails against analytics architecture drift
- **[ASPECTS_DEPLOYMENT_READINESS.md](ASPECTS_DEPLOYMENT_READINESS.md)** - readiness posture for Aspects deployment
- **[ASSESSMENT_AUDIT.md](ASSESSMENT_AUDIT.md)** - assessment surface audit
- **[ASSESSMENT_EPIC_CLOSURE.md](ASSESSMENT_EPIC_CLOSURE.md)** - assessment closure record
- **[ASSESSMENT_XQUEUE_EVIDENCE.md](ASSESSMENT_XQUEUE_EVIDENCE.md)** - xqueue evidence and architecture notes
- **[AUDIT_LOGGING_ASSESSMENT.md](AUDIT_LOGGING_ASSESSMENT.md)** - audit-logging assessment
- **[CATALOG_DISCOVERY_AUDIT.md](CATALOG_DISCOVERY_AUDIT.md)** - discovery/catalog audit
- **[LEGACY_COURSEWARE_AUDIT.md](LEGACY_COURSEWARE_AUDIT.md)** - legacy courseware audit
- **[MULTI_BRAND_MULTI_SITE.md](MULTI_BRAND_MULTI_SITE.md)** - architecture framing for multi-brand multi-site operation
- **[OSCAR_DEPRECATION.md](OSCAR_DEPRECATION.md)** - legacy Oscar deprecation notes
- **[PROCTORING_INTEGRATION.md](PROCTORING_INTEGRATION.md)** - proctoring architecture and integration boundary
- **[PURCHASE_GATEWAY.md](PURCHASE_GATEWAY.md)** - purchase gateway architecture overview
- **[VIDEO_PIPELINE.md](VIDEO_PIPELINE.md)** - video pipeline architecture
- **[VIDEO_HOSTING_COST_COMPARISON.md](VIDEO_HOSTING_COST_COMPARISON.md)** - video hosting cost comparison retained as active architecture reference
- **[PRODUCT_KPI_FRAMEWORK.md](PRODUCT_KPI_FRAMEWORK.md)** - KPI architecture framing for product analytics

## Programs, proposals, and repo hygiene

- **[BUILD_OPTIMIZATIONS_REFACTOR.md](BUILD_OPTIMIZATIONS_REFACTOR.md)** - build optimization program context
- **[OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md](OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md)** - repo hygiene audit tracker
- **[OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md](OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md)** - execution board for repo audit work
- **[OPENEDX_REPO_AUDIT_IMPLEMENTOR_KICKOFF.md](OPENEDX_REPO_AUDIT_IMPLEMENTOR_KICKOFF.md)** - implementor kickoff packet
- **[OPENEDX_REPO_AUDIT_IMPLEMENTOR_PR_TEMPLATE.md](OPENEDX_REPO_AUDIT_IMPLEMENTOR_PR_TEMPLATE.md)** - PR template for audit slices
- **[OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md](OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md)** - detailed audit implementor specs
- **[OPENEDX_REPO_AUDIT_ISSUE_215_PACKET.md](OPENEDX_REPO_AUDIT_ISSUE_215_PACKET.md)** - issue-level audit work packet
- **[OPENEDX_REPO_AUDIT_ISSUE_216_PACKET.md](OPENEDX_REPO_AUDIT_ISSUE_216_PACKET.md)** - issue-level audit work packet
- **[OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md](OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md)** - issue-level audit work packet
- **[OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md](OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md)** - issue-level audit work packet
- **[OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md](OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md)** - issue-level audit work packet
- **[OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md](OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md)** - issue-level audit work packet
- **[OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md](OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md)** - issue-level audit work packet
- **[OPENEDX_REPO_AUDIT_ISSUE_222_PACKET.md](OPENEDX_REPO_AUDIT_ISSUE_222_PACKET.md)** - issue-level audit work packet
- **[LEARNING_SLOT_EXPANSION_PROPOSAL.md](LEARNING_SLOT_EXPANSION_PROPOSAL.md)** - architecture proposal still in evaluation

## Open edX Service Overviews

- **[badges-credentials-overview.md](../../../specs/archive/badges-credentials-overview.md)** - Digital badges and credentials system
- **[content-libraries-overview.md](content-libraries-overview.md)** - content library architecture overview
- **[enterprise-services-overview.md](enterprise-services-overview.md)** - enterprise service architecture overview
- **[multi-tenancy-overview.md](multi-tenancy-overview.md)** - multi-tenancy architecture overview
- **[notification-pipeline-overview.md](notification-pipeline-overview.md)** - notification architecture overview
- **[proctoring-architecture-overview.md](proctoring-architecture-overview.md)** - proctoring architecture overview
- **[purchase-gateway-overview.md](purchase-gateway-overview.md)** - purchase gateway architecture overview

## What does not belong here

Do not use this root for:
- operator procedures that belong in `docs/ops/**`,
- active proof that belongs in `docs/evidence/**`,
- active status that belongs in `docs/status/**`,
- or accepted decision history that belongs in `docs/adr/**`.

## Related Documentation

- **Architecture Decision Records:** [../../adr/](../../adr/) - Formal ADR ledger
- **Operator Docs:** [../../ops/](../../ops/) - Canonical operator runbooks and quick references
- **Specifications:** [../../../specs/](../../../specs/) - Normative intended behavior
- **Legacy architecture compatibility root:** [../../architecture/README.md](../../architecture/README.md)

## Contributing

When adding new architecture documentation:
1. Add a descriptive filename.
2. Include metadata with audience, owner, last verified date, and status.
3. Update this README when discoverability changes.
4. Route the content to the right artifact type before writing:
   - living architecture standard in this directory
   - ADR for accepted decision history
   - RFC for undecided design
   - ops/evidence/status if the content is procedure, proof, or reporting
