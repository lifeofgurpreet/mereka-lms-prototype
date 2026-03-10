# Documentation Metadata Model
_Audience: Contributors and tooling maintainers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This document defines the current metadata model for canonical documentation. It exists to reduce metadata split-brain without reopening repository topology.

## Scope

This model applies first to canonical hot-path docs under:

- `docs/concepts/architecture/**`
- `docs/ops/**`
- `docs/guides/standards/**`
- `docs/reference/**`
- `docs/policies/**`
- `docs/status/**`
- `docs/evidence/**`
- `docs/adr/**`
- `docs/adr/rfc/**`

Archive and transitional roots are out of scope for first-pass normalization.

## Objectives

The metadata model must support:

- deterministic classification of canonical docs
- controlled vocabulary for cross-document governance tags
- generation of catalogs and ADR views from document metadata
- CI validation of missing or malformed metadata

This wave does not build a full frontmatter-only compiler. It defines the schema and source model the compiler will follow.

## Source model

Current intended precedence is:

1. document frontmatter and in-document metadata
2. generated catalog and generated ADR surfaces
3. compatibility sidecars only when explicitly marked as generated

No generated file should become an independent truth plane.

## Common required fields

All canonical hot-path docs should provide these metadata fields:

| Field | Meaning |
| --- | --- |
| `title` | Human-readable title used in indexes and generated surfaces |
| `owner` | Team or function accountable for correctness |
| `status` | Lifecycle state such as `canonical`, `supporting`, `generated`, or `superseded` |
| `last_reviewed` | Date the document was last confirmed accurate |
| `canonical_root` | Owning root for routing and catalog classification |
| `doc_class` | Schema class for validation and generation |
| `summary` | One-line description used in generated navigation surfaces |
| `tags` | Small set of stable discovery labels |

## Canonical root values

Allowed canonical roots for active docs in this wave:

- `docs/concepts/architecture`
- `docs/ops`
- `docs/guides`
- `docs/reference`
- `docs/policies`
- `docs/meta`
- `docs/adr`
- `docs/evidence`
- `docs/status`

## Document classes

The metadata model supports these schema classes:

| `doc_class` | Use for |
| --- | --- |
| `architecture-standard` | Living architecture rules and standards |
| `adr` | Accepted, superseded, or exception ADRs |
| `rfc` | Proposed decisions and open architecture proposals |
| `ops-runbook` | Operator procedures, checklists, recovery docs |
| `guide` | Contributor or user how-to guidance |
| `reference` | Lookup material, matrices, inventories, contracts snapshots |
| `policy` | Durable operational or repository rules |
| `evidence` | Active proof packs and validation artifacts |
| `status` | Active reporting, readiness, incident, and migration posture |

## Class-specific additions

### `architecture-standard`

Additional recommended fields:

- `governs`
- `review_cycle`

### `adr`

Additional required fields:

- `adr_id`
- `decision_status`
- `decision_type`
- `governs`

Additional optional fields:

- `rollout_state`
- `supersedes`
- `superseded_by`
- `exception_expiry`

### `rfc`

Additional required fields:

- `adr_id`
- `proposal_state`
- `governs`

### `ops-runbook`

Additional recommended fields:

- `service_area`
- `verification_commands`

### `guide`

Additional recommended fields:

- `audience`
- `prerequisites`

### `reference`

Additional recommended fields:

- `reference_scope`
- `source_of_truth`

### `policy`

Additional recommended fields:

- `policy_scope`
- `enforced_by`

### `evidence`

Additional required fields:

- `claim`
- `evidence_date`

Additional recommended fields:

- `artifacts`
- `related_status`

### `status`

Additional required fields:

- `status_scope`
- `status_date`

Additional recommended fields:

- `blockers`
- `next_action`

## Controlled vocabulary

`governs` values must come from the controlled taxonomy in:

- [governs-taxonomy.yaml](./governs-taxonomy.yaml)

Free-text `governs` values are not acceptable for canonical docs once validation is enabled for that class.

## Schema mapping

Schema routing for each class is defined in:

- [doc-class-schema-map.yaml](./doc-class-schema-map.yaml)
- [frontmatter-schema.json](./frontmatter-schema.json)

## Transitional reality

This wave intentionally leaves two areas transitional:

- ADR metadata still includes compatibility sidecars while generator ownership is clarified
- the catalog still has a maintained generated-source layer before full compiler replacement

That is acceptable only if those layers are visibly generated or auxiliary, not silent second authorities.

## Review standard

Reviewers should reject changes when:

- a canonical hot-path doc is missing required common metadata
- `doc_class` does not match the document’s actual use
- `canonical_root` points at the wrong root
- `governs` uses uncontrolled values
- a generated metadata surface is edited without updating its source process

## Related docs

- [Documentation Authority Resolver](../../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [Documentation Standards](../../../guides/standards/DOCUMENTATION_STANDARDS.md)
- [Docs / Specs Contract](../../../guides/standards/DOCS_SPECS_CONTRACT.md)
