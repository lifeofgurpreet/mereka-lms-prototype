# Architecture Governance Overlay
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-04-14 • Status: historical overlay snapshot_

This document is retained as historical ADR-overlay governance context.
It does not define the current docs-program execution front door or the current
architecture front door.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

The ADR corpus and generated bundles referenced below remain historical
governance context, not the active docs-program control plane.

## Purpose

This document records the earlier architecture-governance overlay model for
Mereka LMS. It was an overlay re-platform on top of the existing ADR corpus in
`docs/adr/`, but it is no longer the active control plane.

Wave 1 is in-place:
- ADR file paths remain stable.
- Governance is introduced via metadata, manifest, validators, and generated bundles.
- Physical ADR reshaping is deferred until graph/index/redirect tooling is mature.

## Knowledge Model

The architecture system is split into five layers:

- Constitution: living standards that define what MUST be true now.
- ADRs: lightweight historical decision records.
- RFCs: undecided future proposals.
- Contracts: machine-checkable compatibility surfaces.
- Runbooks and evidence: operator procedures and proof, linked from decisions rather than embedded inside them.

## Sources Of Truth

- Charter: `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`
- Govern vocabulary: `docs/concepts/architecture/glossary.yaml`
- Bundle rules: `docs/concepts/architecture/bundle-rules.yaml`
- ADR corpus: `docs/adr/*.md`
- ADR file frontmatter under `docs/adr/**`
- ADR generated outputs: `generated/`
- Contradictions register: `docs/meta/docs-program/ADR_CONTRADICTIONS_REGISTER.md`
- Compatibility manifest (generated from ADR frontmatter): `docs/adr/manifest.yaml`
- Classification map (generated from ADR frontmatter): `docs/adr/classification-map.yaml`
- Status map (generated from ADR frontmatter): `docs/adr/status-map.yaml`

## Progressive Disclosure Model

Agents MUST read:
1. `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`
2. `generated/adr-bundles/00-foundations.md`
3. One domain bundle relevant to changed files
4. Any linked migration/exception ADRs required by `depends_on` / `read_next`

Agents MUST NOT bulk-load the full ADR corpus unless explicitly required.

## Official Source Policy

For Open edX/Tutor architecture and operations guidance:
- MUST use official sources first:
  - `https://docs.openedx.org`
  - `https://docs.tutor.edly.io`
- SHOULD use OEP pages referenced by ADR metadata (`related_oep`).
- MUST treat non-official summaries as secondary.

## Operating Rules

- ADR indexes/maps are generated artifacts, not hand-maintained truth.
- Living standards carry review cadence; historical ADRs do not need to act as a perpetual review queue.
- Proposed architecture work should move toward RFC form instead of expanding the active ADR surface indefinitely.
- New exception ADRs MUST include `expiry_date` and `removal_condition`.
- Contradictions MUST be logged before they are rewritten.
- Decision text MUST separate architecture policy from runbook/evidence material.
