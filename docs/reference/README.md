# Reference Docs

`docs/reference/**` is the canonical reference root.

Use this root when the question is factual rather than procedural:
- contracts, inventories, registries, and matrices
- system facts an operator or engineer needs to look up
- stable reference material that supports policy or runbooks

## Start here

| If you need to... | Start here | Then go deeper in |
|---|---|---|
| Check architecture contracts, inventories, or audits | `docs/reference/architecture/**` | `docs/architecture/**` if you need the governing model |
| Check runtime matrices, hostnames, or service reference | `docs/reference/operations/**` | `docs/ops/**` if you need the execution procedure |
| Check migration source reference or API maps | `docs/reference/migrations/**` | `docs/status/migrations/**` if you need live migration status |
| Decide whether something belongs in reference at all | `docs/architecture/README.md` | `docs/guides/standards/DOCS_SPECS_CONTRACT.md` if the question is docs vs specs |

## Live subroots

- [`architecture/**`](architecture/README.md) for contracts, inventories, and architecture-facing reference
- [`operations/**`](operations/README.md) for runtime matrices, hostnames, access posture, and deploy reference
- [`contracts/**`](contracts/) for canonical verifier/identity/deprecation contracts
- [`governance/**`](governance/) for canonical deprecation and authority-cleanup ledgers
- [`analytics/**`](analytics/README.md) for analytics-related factual and migration reference
- [`migrations/**`](migrations/README.md) for source-system and migration reference
- [`generated/**`](generated/) for generated reference views derived from canonical registries

## Do not use this root for

- step-by-step procedures,
- active status updates,
- proof bundles,
- policy rules that belong in `docs/policies/**`,
- or historical/archive material.

## Read pattern

1. Start here when the question is “what is true right now?”
2. If you need rules or constraints, move to [`../architecture/README.md`](../architecture/README.md) or `docs/policies/**`.
3. If you need steps to execute, move to `docs/ops/**`.
