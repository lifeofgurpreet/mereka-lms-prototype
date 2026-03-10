---
title: Documentation Standards
owner: Platform Team
status: canonical
last_verified: 2026-03-09
canonical_root: docs/guides
doc_class: guide
summary: Baseline writing, placement, and review standards for canonical documentation in this repository.
tags:
  - docs
  - standards
  - writing
audience: All contributors
---

# Documentation Standards

This guide defines the baseline writing and structure standards for documentation in this repository. Use it with the documentation authority resolver and the docs/specs contract.

## Purpose

This standard exists to keep docs:
- easy to route,
- easy to review,
- consistent across roots,
- and hard to confuse with specs, runbooks, or proof.

## Pick the right artifact first

Before writing, decide what kind of thing you are producing.

- Use `docs/concepts/architecture/**` for living architecture, standards, and current policy-level narratives.
- Use `docs/guides/**` for human workflows, onboarding, and step-by-step guidance.
- Use `docs/ops/**` for operator procedures and quick references.
- Use `docs/reference/**` for factual reference material.
- Use `docs/policies/**` for rules, boundaries, and operational policy.
- Use `docs/meta/**` for docs-program internals, templates, standing orders, and transition ledgers.
- Use `docs/evidence/**` for active proof.
- Use `docs/status/**` for active reporting.
- Use `docs/adr/**` for decision history and open proposals.
- Use `specs/**` for normative intended behavior.

Do not place new canonical docs in transitional roots such as:
- `docs/operations/README.md` tombstone only
- `docs/onboarding/README.md`
- `docs/runbooks/README.md`
- `docs/architecture/README.md`

## Required metadata

Canonical and supporting docs must include:
- `Audience`
- `Owner`
- `Last verified`
- `Status`

Format:

```markdown
_Audience: <role> • Owner: <team> • Last verified: YYYY-MM-DD • Status: canonical|supporting|superseded_
```

## Document structure

Use a structure that matches the artifact type.

### Guides and runbook-style docs

1. Purpose
2. Prerequisites
3. Procedure
4. Verification
5. Troubleshooting or related links

### Reference docs

1. Purpose
2. Scope
3. Contracts, inventories, or factual sections
4. Related links

### Policy and standards docs

1. Scope
2. Rules
3. Boundaries or non-goals
4. Review/rejection criteria
5. Related links

### Evidence docs

1. Claim proved
2. Scope
3. Capture context
4. Proof artifacts
5. Result
6. Redaction and retention notes

### Status docs

1. Scope
2. Current state
3. Blockers and risks
4. Evidence links
5. Next action or next decision

## Writing style

### Do

- Use active voice.
- Prefer short factual sentences.
- Put the current fact, decision, or action first.
- Use lists when readers need to scan.
- Define acronyms on first use.
- Link readers to the canonical source instead of duplicating it.

### Do not

- Write history when the reader needs current truth.
- Hide the key outcome at the bottom of the page.
- Mix policy, runbook, and evidence into one document.
- Treat docs as the place to define intended product behavior that belongs in `specs/**`.

## Formatting conventions

- Use ATX headings: `#`, `##`, `###`.
- Keep one H1 per document.
- Use inline code for commands, file paths, URLs, variables, service names, and identifiers.
- Use fenced code blocks with a language tag for multi-line examples.
- Use tables only when comparison is genuinely easier in table form.

## Discoverability rules

- Every root or subroot that aggregates canonical docs should have a `README.md`.
- If your change makes something easier or harder to find, update the nearest canonical index in the same change.
- Update `docs/README.md` when the front door or hot-path reading set changes.
- A docs change is incomplete if a reader would need tribal knowledge to find the document afterward.

## Review standard

Reviewers should reject docs that:
- live under the wrong root,
- lack required metadata,
- point readers at superseded paths as if they were canonical,
- leave navigation worse than before,
- or duplicate another active canonical document without a clear reason.

## Minimal docs checks

Run these for docs control-plane or canonical-surface changes:

```bash
bash tools/docs/verify/verify-docs-policy.sh --range HEAD~1...HEAD
python3 tools/docs/verify/verify-doc-catalog-governance.py --range HEAD~1...HEAD
```

## Related docs

- [Documentation Authority Resolver](../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [Docs / Specs Contract](./DOCS_SPECS_CONTRACT.md)
- [Documentation Contributing Guide](../../CONTRIBUTING.md)
