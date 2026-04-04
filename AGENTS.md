<coding_guidelines>
# AGENTS.md — Agent Operating Guide

> Pointer file only. This file defines **how agents should navigate authority**.
> It must not duplicate architecture, runbook, or contract content.

## Read First (in order)

1. [PLATFORM_AUTHORITY_MAP.md](docs/architecture/PLATFORM_AUTHORITY_MAP.md)
2. [PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md](docs/architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md)
3. [AGENT_EXECUTION_WORKFLOW.md](docs/reference/operations/AGENT_EXECUTION_WORKFLOW.md)
4. [MASTER_LAUNCH_ROADMAP_2026-04-04.md](docs/status/active/MASTER_LAUNCH_ROADMAP_2026-04-04.md)

## Hard Rules (summary)

1. Layer first, tool second.
2. Never promote from a dirty worktree.
3. Use release-object-driven promotion.
4. Never patch generated artifacts without patching generator/build path.
5. Never rerun runtime proof against a known-unpatched live bundle.
6. Every incident leaves a stronger regression guard.
7. All active surfaces remain in scope until removed from authority.
8. Infisical is secret authority; identity systems own identities.

## Quick Reference

| Question | Canonical doc |
|---|---|
| What layer owns this symptom? | [PLATFORM_AUTHORITY_MAP.md](docs/architecture/PLATFORM_AUTHORITY_MAP.md) |
| What is the sanctioned promotion path? | [PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md](docs/architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md) |
| What verifier proves which lane? | [VERIFIER_CONTRACT_CATALOG.md](docs/reference/contracts/VERIFIER_CONTRACT_CATALOG.md) |
| Where do smoke identities live? | [SMOKE_ACCOUNT_REGISTRY_2026-04-04.md](docs/status/active/SMOKE_ACCOUNT_REGISTRY_2026-04-04.md) |
| Which docs are canonical vs superseded? | [DEPRECATION_LEDGER.md](docs/reference/governance/DEPRECATION_LEDGER.md) |
| How should agents execute incidents/fixes? | [AGENT_EXECUTION_WORKFLOW.md](docs/reference/operations/AGENT_EXECUTION_WORKFLOW.md) |

## Docs Separation Rule

| Location | Role |
|---|---|
| `docs/status/active/` | current operational state |
| `docs/architecture/` | stable system model |
| `docs/reference/contracts/` | verifier/identity/deprecation contracts |
| `docs/reference/operations/` | operating procedures |
| `docs/ops/runbooks/` | deterministic operator runbooks |

## Repo-Specific Guardrails

- `tenant-registry.yaml` is launch scope authority for active surfaces.
- OIDC endpoint ownership is infra-overlay territory; do not assume app-repo edits win.
- Caddy + ingress + settings interactions are multi-layer; collect runtime evidence before patching.
- Treat CI queue stalls as infra class after bounded wait; do not loop indefinitely.

</coding_guidelines>
