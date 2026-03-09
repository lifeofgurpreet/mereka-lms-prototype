# Architecture Reference
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains reference material that describes the current architecture surface without acting as living policy or decision history.

## Use this directory for

- architecture inventories and matrices
- runtime/config contracts and reference tables
- component, plugin, token, and module reference material
- architecture audits that are still used as current reference

## Platform and runtime contracts

- [`API_CONTRACTS.md`](API_CONTRACTS.md) for service and API contract reference
- [`DEPLOYMENT_CONTRACT.md`](DEPLOYMENT_CONTRACT.md) for deployment-boundary reference
- [`ASPECTS_DEPLOYMENT_READINESS.md`](ASPECTS_DEPLOYMENT_READINESS.md) for current Aspects readiness reference
- [`RESOURCE_OWNERSHIP_MATRIX.md`](RESOURCE_OWNERSHIP_MATRIX.md) for component ownership mapping
- [`TUTOR_PATCHES_INVENTORY.md`](TUTOR_PATCHES_INVENTORY.md) for Tutor patch reference inventory

## Frontend and composition reference

- [`FORUM_UI_THEMING.md`](FORUM_UI_THEMING.md) for forum theming reference
- [`FPF_PLUGIN_SLOT_REGISTRY.md`](FPF_PLUGIN_SLOT_REGISTRY.md) for plugin-slot reference
- [`MFE_COMPLETE_LIST.md`](MFE_COMPLETE_LIST.md) for canonical MFE inventory
- [`MFE_PLUGIN_SLOT_INVENTORY.md`](MFE_PLUGIN_SLOT_INVENTORY.md) for active slot inventory
- [`MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`](MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md) for migration tracking
- [`MFE_ROUTE_TO_DIST_CONTRACT.md`](MFE_ROUTE_TO_DIST_CONTRACT.md) for route-to-dist mapping
- [`MFE_RUNTIME_CONFIG.md`](MFE_RUNTIME_CONFIG.md) for runtime config reference
- [`MFE_SELECTOR_AUDIT.md`](MFE_SELECTOR_AUDIT.md) for selector audit reference
- [`MFE_SELECTOR_DECISION_LOG.md`](MFE_SELECTOR_DECISION_LOG.md) for selector decisions
- [`MFE_SELECTOR_OVERRIDE_INVENTORY.md`](MFE_SELECTOR_OVERRIDE_INVENTORY.md) for override inventory
- [`MFE_VERSIONS.md`](MFE_VERSIONS.md) for version inventory
- [`MOBILE_TOKEN_PARITY.md`](MOBILE_TOKEN_PARITY.md) for mobile token parity reference
- [`OEP48_BRAND_PACKAGE.md`](OEP48_BRAND_PACKAGE.md) for brand package reference
- [`OEP65_MODULE_READINESS.md`](OEP65_MODULE_READINESS.md) for module-readiness reference
- [`PARAGON_V22_TOKEN_AUDIT.md`](PARAGON_V22_TOKEN_AUDIT.md) for Paragon audit reference
- [`THEMING_GENERATED_ARTIFACT_CONTRACT.md`](THEMING_GENERATED_ARTIFACT_CONTRACT.md) for generated-theming artifact rules
- [`TOKEN_GENERATION_PIPELINE.md`](TOKEN_GENERATION_PIPELINE.md) for token pipeline reference
- [`TOKEN_REFERENCE_INTEGRITY.md`](TOKEN_REFERENCE_INTEGRITY.md) for token integrity reference

## Audits and analysis still used as reference

- [`CSS_SCOPING_AUDIT.md`](CSS_SCOPING_AUDIT.md) for CSS scoping coverage
- [`PRODUCT_KPI_FRAMEWORK.md`](PRODUCT_KPI_FRAMEWORK.md) for KPI architecture framing

## Do not use this directory for

- accepted decisions, which belong in `docs/adr/**`
- living architecture law, which belongs in `docs/concepts/architecture/**`
- operator procedures, which belong in `docs/ops/**`
