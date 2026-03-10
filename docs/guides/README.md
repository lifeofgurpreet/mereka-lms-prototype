# Guides

`docs/guides/**` is the canonical guidance root.

Use this root when the question is instructional:
- how a person should perform a workflow
- onboarding, operator guidance, or contributor guidance
- human-oriented “how to” material that is not itself a runbook or policy

## Start here

| If you need to... | Start here | Then go deeper in |
|---|---|---|
| Get oriented by role | [`INDEX_BY_AUDIENCE.md`](INDEX_BY_AUDIENCE.md) | The specific guide root below |
| Use the platform handbook to find URLs, tenant rules, or escalation paths | [`platform/PLATFORM_START_HERE.md`](platform/PLATFORM_START_HERE.md) | [`../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`](../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md) and [`../reference/platform/TEAM_TOPOLOGY_REFERENCE.md`](../reference/platform/TEAM_TOPOLOGY_REFERENCE.md) |
| Set up locally or learn the daily dev workflow | `onboarding/` | `../ops/quickref/README.md` for fast operator commands |
| Operate or administer the platform | `admin/` | `../ops/README.md` for runtime procedures |
| Work on branding execution | `branding/` | `../reference/architecture/README.md` for frontend/runtime reference |
| Understand writing rules and docs governance | `standards/` | `../CONTRIBUTING.md` for the contributor workflow |

Do not use these roots as the winning guidance surface:
- `docs/onboarding/**`
- `docs/guides/branding/README.md`
- `docs/operations/README.md` tombstone only
- `docs/archive/**`

## Main guide surfaces

- [`INDEX_BY_AUDIENCE.md`](INDEX_BY_AUDIENCE.md) for audience-first navigation
- `platform/` for the handbook front door, generated platform references, and escalation routing
- `onboarding/` for setup and local workflow guidance
- `admin/` for platform/operator guidance
- `branding/` for brand execution guidance
- `standards/` for documentation and governance standards

## What this root is not

Do not use this root for:
- runtime runbooks that belong in `docs/ops/**`,
- factual inventories that belong in `docs/reference/**`,
- policy rules that belong in `docs/policies/**`,
- or active proof and status that belong in `docs/evidence/**` and `docs/status/**`.

## Resolver

For the authority contract behind this root, read:
- [`../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`](../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
