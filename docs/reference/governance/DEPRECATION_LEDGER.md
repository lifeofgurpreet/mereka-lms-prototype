# DEPRECATION_LEDGER
_Audience: Operators, reviewers, and docs agents · Owner: Platform Team · Status: canonical_

This ledger tracks document overlap and deprecation state using evidence-backed
labels only.

## Status labels

- **canonical**: current authority owner
- **detailed-reference**: useful detail, not authority owner
- **status-only**: operational snapshot, not stable model
- **superseded**: replaced by canonical successor
- **deprecated in source truth**: explicitly marked deprecated by source authority
- **remove-later (verify-first)**: candidate for removal once references are cleared
- **proposed**: intent exists but no ratified source evidence yet

## Canonical/superseded map

| Path | Classification | Why | Successor / authority |
|---|---|---|---|
| `docs/architecture/PLATFORM_AUTHORITY_MAP.md` | canonical | stable authority boundary owner | this file |
| `docs/architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md` | canonical | sanctioned build→proof path owner | this file |
| `docs/reference/operations/AGENT_EXECUTION_WORKFLOW.md` | canonical | agent working method owner | this file |
| `docs/reference/contracts/VERIFIER_CONTRACT_CATALOG.md` | canonical | proof-lane contract owner | this file |
| `docs/reference/operations/VERIFIER_CONTRACT_CATALOG.md` | detailed-reference | script-level detail only | `docs/reference/contracts/VERIFIER_CONTRACT_CATALOG.md` |
| `docs/architecture/AUTHORITY_MATRIX.md` | superseded | older tool-centric matrix | `docs/architecture/PLATFORM_AUTHORITY_MAP.md` |
| `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md` | detailed-reference | broad docs-program resolver, not incident flow owner | architecture + governance canonicals |
| `docs/concepts/architecture/RELEASE_ROLLOUT_AND_REMOVAL.md` | detailed-reference | policy/standards context | `docs/architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md` |
| `docs/status/active/MASTER_LAUNCH_ROADMAP_2026-04-04.md` | status-only | active execution state | status root |
| `docs/status/active/ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md` | status-only | operational runtime board | status root |
| `docs/status/active/ACTIVE_SURFACE_STATUS_BOARD_2026-04-04.md` | status-only | compressed operational board | status root |
| `docs/status/active/SMOKE_ACCOUNT_REGISTRY_2026-04-04.md` | status-only | active provisioning status | status root + contract docs |
| `docs/status/active/RUNTIME_TRUTH_LEDGER_TRACKER_2026-04-03.md` | proposed (verify-first) | referenced in prompts but not present in this branch snapshot | create only from proved runtime evidence |
| `AGENTS.md` | canonical (pointer) | repo entrypoint for agent navigation | points to canonical docs |
| `docs/architecture/README.md` | canonical index | architecture root index | this file |
| `docs/concepts/architecture/README.md` | detailed-reference index | concepts/standards index | architecture root canonicals |
| `docs/status/active/README.md` | status-only index | active status index | status root |
| `docs/reference/README.md` | canonical reference index | reference root index | this file |
| `docs/reference/architecture/README.md` | detailed-reference index | architecture reference inventory index | `docs/architecture/**` for stable model ownership |
| `docs/reference/operations/README.md` | detailed-reference index | operations reference index | reference root |

## Fact-scrubbed deprecation items

| Item | Current label | Evidence source | Notes |
|---|---|---|---|
| app-repo non-local overlays (`deploy/k8s/overlays/rke2-nonprod`, `staging`, `production`) | remove-later (verify-first) | in-file deprecation markers (e.g., `DEPRECATED`, `boundary.debt`) | removal timing must be ratified before declaring dates |
| legacy ecommerce host surfaces | deprecated in source truth | `deploy/k8s/tenancy/tenant-registry.yaml` entries marked deprecated | keep as redirect or remove from authority |
| old verifier assumptions | verify-first | runtime incidents + verifier mismatch records | do not mark removed until successor checks are wired |
| branch/stash cleanup claims | proposed | no governance artifact proving completion | track separately from deprecation facts |
| frozen infra assertions | verify-first | must be backed by explicit frozen markers (e.g., `FROZEN.md`) | avoid plan-language without source proof |

## Stale wording corrections required

| Topic | Required stance |
|---|---|
| launch scope | all active surfaces in scope until removed from authority |
| smoke credentials | identity authority != GitHub secrets; Infisical is secret authority |
| verifier claims | green outside lane is not launch proof |
| deprecation timing | use evidence-backed labels, not speculative waves |

## Related

- [PLATFORM_AUTHORITY_MAP.md](../../architecture/PLATFORM_AUTHORITY_MAP.md)
- [PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md](../../architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md)
- [AGENT_EXECUTION_WORKFLOW.md](../operations/AGENT_EXECUTION_WORKFLOW.md)
