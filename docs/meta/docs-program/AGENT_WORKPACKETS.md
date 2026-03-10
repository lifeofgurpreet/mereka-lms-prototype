# Agent Work Packets
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

## Packet 00 — Corpus Stabilization

Owner: Corpus Cartographer

Deliverables:
- `docs/meta/docs-program/ADR_CONTRADICTIONS_REGISTER.md`
- `docs/adr/status-map.yaml` (generated compatibility view from ADR frontmatter)
- `docs/adr/classification-map.yaml` (generated compatibility view from ADR frontmatter)
- coverage of ADRs declared by file frontmatter under `docs/adr/**`

## Packet 01 — Overlay Scaffolding

Owner: Harness Engineer

Deliverables:
- `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`
- `docs/concepts/architecture/glossary.yaml`
- `docs/concepts/architecture/bundle-rules.yaml`
- ADR templates
- ADR suite scripts
- decision graph generator
- generated bundle framework under `generated/adr-bundles/`

## Packet 02 — Constitutional ADRs

Owner: Constitution Author

Deliverables:
- ADR-028..ADR-033 with invariant-driven language

## Packet 03 — Contradiction Resolution

Owner: Splitter/Extractor + Domain Owners

Deliverables:
- explicit resolution notes and supersession links
- runbook/evidence extraction where ADRs are overloaded

## Packet 04 — CI Blocking

Owner: Harness Engineer

Deliverables:
- ADR suite in CI
- failure on missing manifest/frontmatter links and expired exceptions

## Packet 05 — Constitution Extraction

Owner: Constitution Author

Deliverables:
- living standards derived from ADR-019, ADR-021, ADR-028 through ADR-033
- ADR scope reduced to decision history where practical
