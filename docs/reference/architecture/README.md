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

## Core references

- Platform and runtime contracts:
  [`API_CONTRACTS.md`](API_CONTRACTS.md),
  [`DEPLOYMENT_CONTRACT.md`](DEPLOYMENT_CONTRACT.md),
  [`RESOURCE_OWNERSHIP_MATRIX.md`](RESOURCE_OWNERSHIP_MATRIX.md),
  [`TUTOR_PATCHES_INVENTORY.md`](TUTOR_PATCHES_INVENTORY.md)
- Frontend and composition:
  [`FPF_PLUGIN_SLOT_REGISTRY.md`](FPF_PLUGIN_SLOT_REGISTRY.md),
  [`MFE_COMPLETE_LIST.md`](MFE_COMPLETE_LIST.md),
  [`MFE_RUNTIME_CONFIG.md`](MFE_RUNTIME_CONFIG.md),
  [`MFE_ROUTE_TO_DIST_CONTRACT.md`](MFE_ROUTE_TO_DIST_CONTRACT.md),
  [`MFE_PLUGIN_SLOT_INVENTORY.md`](MFE_PLUGIN_SLOT_INVENTORY.md),
  [`MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`](MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md)
- Theming and token systems:
  [`OEP48_BRAND_PACKAGE.md`](OEP48_BRAND_PACKAGE.md),
  [`TOKEN_GENERATION_PIPELINE.md`](TOKEN_GENERATION_PIPELINE.md),
  [`TOKEN_REFERENCE_INTEGRITY.md`](TOKEN_REFERENCE_INTEGRITY.md),
  [`PARAGON_V22_TOKEN_AUDIT.md`](PARAGON_V22_TOKEN_AUDIT.md)
- Audits and analysis still used as reference:
  [`ASPECTS_DEPLOYMENT_READINESS.md`](ASPECTS_DEPLOYMENT_READINESS.md),
  [`CSS_SCOPING_AUDIT.md`](CSS_SCOPING_AUDIT.md),
  [`PRODUCT_KPI_FRAMEWORK.md`](PRODUCT_KPI_FRAMEWORK.md)

## Do not use this directory for

- accepted decisions, which belong in `docs/adr/**`
- living architecture law, which belongs in `docs/concepts/architecture/**`
- operator procedures, which belong in `docs/ops/**`

## How To Use This Root Well

1. Use this root to answer factual questions about structure, contracts, or inventories.
2. If you need to know what rule governs the system, leave this root and go to [`../../concepts/architecture/README.md`](../../concepts/architecture/README.md) or [`../../policies/README.md`](../../policies/README.md).
3. If you need execution steps, leave this root and go to [`../../ops/README.md`](../../ops/README.md).
