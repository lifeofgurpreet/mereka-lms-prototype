# Architecture Reference
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this root when you need factual architecture reference: contracts, inventories, matrices, and audits that still serve as current reference. Start here to answer “what does the system look like right now?” Do not use this root for architecture law, ADR history, or operator procedures.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Understand the platform/runtime contract surface | [`API_CONTRACTS.md`](API_CONTRACTS.md) | [`../../concepts/architecture/README.md`](../../concepts/architecture/README.md) |
| Check deployment boundaries or ownership | [`DEPLOYMENT_CONTRACT.md`](DEPLOYMENT_CONTRACT.md) | [`../../policies/operations/README.md`](../../policies/operations/README.md) |
| Understand the MFE/runtime composition surface | [`MFE_RUNTIME_CONFIG.md`](MFE_RUNTIME_CONFIG.md) | [`MFE_COMPLETE_LIST.md`](MFE_COMPLETE_LIST.md) |
| Inspect plugin slots or override inventory | [`FPF_PLUGIN_SLOT_REGISTRY.md`](FPF_PLUGIN_SLOT_REGISTRY.md) | [`MFE_PLUGIN_SLOT_INVENTORY.md`](MFE_PLUGIN_SLOT_INVENTORY.md) |
| Check design-token or theming reference | [`TOKEN_GENERATION_PIPELINE.md`](TOKEN_GENERATION_PIPELINE.md) | [`OEP48_BRAND_PACKAGE.md`](OEP48_BRAND_PACKAGE.md) |
| Read an architecture audit still used as current reference | [`CSS_SCOPING_AUDIT.md`](CSS_SCOPING_AUDIT.md) | [`../../status/readiness/README.md`](../../status/readiness/README.md) if you need active validation status |

## Use this directory for

- architecture inventories and matrices
- runtime/config contracts and reference tables
- component, plugin, token, and module reference material
- architecture audits that are still used as current reference

## Common contributor routes

| Question | Start here | If that is not enough |
|---|---|---|
| "What does the runtime or integration contract look like?" | [`API_CONTRACTS.md`](API_CONTRACTS.md) or [`DEPLOYMENT_CONTRACT.md`](DEPLOYMENT_CONTRACT.md) | Move to `docs/concepts/architecture/**` for governing standards |
| "Which frontend surface or module owns this behavior?" | [`MFE_COMPLETE_LIST.md`](MFE_COMPLETE_LIST.md) or [`MFE_RUNTIME_CONFIG.md`](MFE_RUNTIME_CONFIG.md) | Move to `docs/ops/**` if you need execution steps |
| "Is this still just an audit, or is it the current status?" | The relevant audit here | Move to `docs/status/**` if you need current rollout posture |

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

## How To Use This Root Well

1. Use this root to answer factual questions about structure, contracts, or inventories.
2. If you need to know what rule governs the system, leave this root and go to [`../../concepts/architecture/README.md`](../../concepts/architecture/README.md) or [`../../policies/README.md`](../../policies/README.md).
3. If you need execution steps, leave this root and go to [`../../ops/README.md`](../../ops/README.md).

## Review standard

- A file here should help answer “what exists?” or “what is the current contract?” quickly.
- If a document starts prescribing enduring technical law, move that rule to `docs/concepts/architecture/**` or `docs/policies/**`.
- If a document starts reading like a playbook, move it to `docs/ops/**`.
