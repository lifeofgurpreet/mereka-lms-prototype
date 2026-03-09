# Reference Docs

`docs/reference/**` is the canonical reference root.

Use this root when the question is factual rather than procedural:
- contracts, inventories, registries, and matrices
- system facts an operator or engineer needs to look up
- stable reference material that supports policy or runbooks

## Start here

| If you need to... | Start here | Then go deeper in |
|---|---|---|
| Check architecture contracts, inventories, or audits | `docs/reference/architecture/**` | `docs/concepts/architecture/**` if you need the governing law |
| Check runtime matrices, hostnames, or service reference | `docs/reference/operations/**` | `docs/ops/**` if you need the execution procedure |
| Check migration source reference or API maps | `docs/reference/migrations/**` | `docs/status/migrations/**` if you need live migration status |
| Decide whether something belongs in reference at all | `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md` | `docs/guides/standards/DOCS_SPECS_CONTRACT.md` if the question is docs vs specs |

Do not use these roots as the winning reference surface:
- `docs/operations/**`
- `docs/concepts/**` for factual inventories
- `docs/archive/**`

## Typical contents

- architecture reference and inventories
- operations reference and matrices
- migration and integration reference material

## What this root is not

Do not use this root for:
- step-by-step procedures,
- active status updates,
- proof bundles,
- or policy rules that belong in `docs/policies/**`.

Reference docs answer:
- what exists,
- what is configured,
- what contracts or inventories are current.

## How to use this root well

1. Start here when the question is “what is true right now?”
2. If you need rules or constraints, leave this root and move to `docs/policies/**` or `docs/concepts/architecture/**`.
3. If you need steps to execute, leave this root and move to `docs/ops/**`.

For the full authority contract, read:
- [`../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`](../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
