# ADR Templates
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains the canonical templates for drafting new ADR records in the decision ledger.

## Start here

| If you need to... | Use this first | Then confirm against |
|---|---|---|
| Write a long-lived platform or governance decision | [`foundation-adr-template.md`](foundation-adr-template.md) | [`../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`](../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md) |
| Write a bounded domain decision | [`domain-adr-template.md`](domain-adr-template.md) | [`../../guides/standards/DOCS_SPECS_CONTRACT.md`](../../guides/standards/DOCS_SPECS_CONTRACT.md) if specs are involved |
| Record a migration decision | [`migration-adr-template.md`](migration-adr-template.md) | `docs/status/**` and `docs/evidence/**` if you also need active reporting or proof |
| Record a time-bounded exception | [`exception-adr-template.md`](exception-adr-template.md) | The current exception ADR rules in `docs/adr/**` |

## Use this directory for

- starting a new ADR in the correct shape
- choosing the right ADR type before authoring
- maintaining consistency across foundation, domain, migration, and exception decisions

## Available templates

- [`foundation-adr-template.md`](foundation-adr-template.md)
- [`domain-adr-template.md`](domain-adr-template.md)
- [`migration-adr-template.md`](migration-adr-template.md)
- [`exception-adr-template.md`](exception-adr-template.md)

## Do not use this directory for

- living architecture standards, which belong in `docs/concepts/architecture/**`
- open proposals, which belong in `docs/adr/rfc/**`
- operator runbooks or evidence material

## Review standard

- Pick the narrowest template that still matches the decision you are recording.
- If the content is still undecided, it belongs in `docs/adr/rfc/**`, not here.
- If the document starts to read like standing law rather than a dated decision record, move the normative guidance into `docs/concepts/architecture/**` and keep the ADR focused on the decision itself.
