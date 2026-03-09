---
title: ADR Numbering And Naming
owner: Platform Team
status: canonical
last_reviewed: 2026-03-09
canonical_root: docs/guides/standards
doc_class: guide
audience:
  - contributors
  - reviewers
summary: Defines the canonical ADR filename, numbering, and naming rules used by the repository.
tags:
  - docs.policy
  - docs.catalog
---

# ADR Numbering And Naming

## Naming Rule

Use:

`ADR-<zero-padded-number>-<lowercase-kebab-slug>.md`

Examples:
- `ADR-028-platform-sources-of-truth-and-control-planes.md`
- `ADR-038-commerce-system-of-record-and-reconciliation.md`

## Rules

- Numbers MUST NOT be reused.
- Status MUST NOT be embedded in filename.
- Dates MUST NOT be embedded in ADR filename.
- ADR README/index MUST be generated from manifest metadata.

## Current Overlay Rule

Wave 1 keeps existing `docs/adr/NNN-*.md` files in place.
New ADRs may continue `NNN-*.md` naming in-repo while display titles use `ADR-NNN` prefix.
