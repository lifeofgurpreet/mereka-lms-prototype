# Policy Docs

`docs/policies/**` is the canonical policy root.

Use this root when the question is normative:
- what MUST or MUST NOT be true
- governance rules and architectural policy
- operational or architecture constraints that are enforced over time

## Start here

| If you need to... | Start here | Then go deeper in |
|---|---|---|
| Check design rules, UX constraints, or architecture guardrails | `docs/policies/architecture/**` | `docs/architecture/**` for the stable architecture context |
| Check operator safety, service posture, or runtime governance | `docs/policies/operations/**` | `docs/ops/**` if you need the execution procedure afterward |
| Resolve a disagreement about where a rule belongs | `docs/architecture/README.md` | `docs/guides/standards/DOCS_SPECS_CONTRACT.md` for docs/spec routing |

Do not use these roots as live policy authority:
- `docs/operations/README.md` tombstone only
- `docs/runbooks/README.md` tombstone only
- `docs/archive/**`

## Typical contents

- architecture policies
- operations policies
- cross-cutting governance rules that support the charter and resolver

## What this root is not

Do not use this root for:
- factual inventories that belong in `docs/reference/**`,
- operator procedures that belong in `docs/ops/**`,
- active proof that belongs in `docs/evidence/**`,
- or active status reporting that belongs in `docs/status/**`.

Policy docs answer:
- what is required,
- what is forbidden,
- what boundary must continue to hold over time.

## How to use this root well

1. Start here when the question is “what rule should govern this change?”
2. If you need facts or inventories, leave this root and move to `docs/reference/**`.
3. If you need execution steps, leave this root and move to `docs/ops/**`.

For the full authority contract, read:
- [`../architecture/README.md`](../architecture/README.md)
- [`../architecture/PLATFORM_AUTHORITY_MAP.md`](../architecture/PLATFORM_AUTHORITY_MAP.md)
