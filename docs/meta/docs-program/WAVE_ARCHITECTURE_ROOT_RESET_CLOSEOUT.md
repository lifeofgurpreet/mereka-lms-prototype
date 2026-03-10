# Wave Architecture Root Reset Closeout
_Audience: Reviewers and maintainers • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

## Outcome

`docs/architecture/**` has been retired as an active documentation root.

Final shape:

```text
docs/architecture/
  README.md
```

## Deleted

- wrapper docs under `docs/architecture/constitution/**`
- wrapper docs under `docs/architecture/overviews/**`
- wrapper docs under `docs/architecture/rfc/**`
- dead diagrams under `docs/architecture/diagrams/**`
- top-level wrapper docs:
  - `ADR_LANGUAGE_STYLE.md`
  - `ADR_NUMBERING_AND_NAMING.md`
  - `AGENT_WORKPACKETS.md`
  - `ARCHITECTURE.md`
  - `FOUNDATIONS_PROGRAM.md`
  - `PROGRAM_UPDATE_V2_BRIEF.md`
  - `charter.md`
  - `decision-map.md`

## Moved

- `docs/architecture/bundle-rules.yaml` -> `docs/concepts/architecture/bundle-rules.yaml`
- `docs/architecture/glossary.yaml` -> `docs/concepts/architecture/glossary.yaml`

## Canonical Owners After Reset

- living architecture: `docs/concepts/architecture/**`
- ADRs and RFCs: `docs/adr/**`
- standards and process-writing guidance: `docs/guides/standards/**`
- docs-program governance and migration records: `docs/meta/docs-program/**`

## Guardrail

`tools/docs/verify/verify_legacy_architecture_root.py` now enforces that `docs/architecture/**` contains no substantive files beyond the tombstone `README.md`, and `tools/docs/verify/verify-docs-policy.sh` runs that guard in policy gates.

## Validation

- `python3 tools/docs/verify/verify_legacy_architecture_root.py --repo-root .`
- `python3 tools/docs/verify/build-doc-catalog.py --root .`
- `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
- `python3 tools/knowledge/build_knowledge_catalog.py --repo-root .`
- `python3 tools/knowledge/build_knowledge_graph.py --repo-root .`
- `bash scripts/qa/run-knowledge-integrity-gates.sh`

## Remaining Risks

- archive, evidence, and historical planning material still mention `docs/architecture/**` in places where the old root is part of historical context; this is acceptable so long as those paths are not treated as living authority
- older ADR compatibility scripts (`build_decision_graph.py`, `verify_adr_manifest.py`) still operate on a legacy manifest shape; that drift predates this wave and was not expanded here
