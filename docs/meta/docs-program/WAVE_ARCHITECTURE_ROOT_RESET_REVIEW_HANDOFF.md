# Wave Architecture Root Reset Review Handoff
_Audience: Reviewers • Owner: Platform Team • Last verified: 2026-04-14 • Status: historical review handoff snapshot_

> Historical handoff for a superseded reset model.
>
> The review instructions below reflect the reset wave's target state, not the
> current repo model. Today, `docs/architecture/**` is the stable architecture
> front-door root.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

## Historical Review Goal

Confirm that `docs/architecture/**` no longer behaves like a living peer root and that the surviving content has one canonical home elsewhere.

## Historical Review Focus

1. `docs/architecture/README.md` is a tombstone only.
2. No substantive file remains under `docs/architecture/**`.
3. `bundle-rules.yaml` and `glossary.yaml` now live only under `docs/concepts/architecture/`.
4. Active references now resolve to canonical roots:
   - `docs/concepts/architecture/**`
   - `docs/adr/**`
   - `docs/reference/architecture/**`
   - `docs/meta/docs-program/**`
5. The legacy-root guard fails if a new file appears under `docs/architecture/**`.

## Current Review Focus

1. `docs/architecture/**` remains the stable architecture front-door root.
2. `docs/concepts/architecture/**` remains bounded to retained explicitly
   canonical standards and deep reference.
3. Read-first architecture routing goes through:
   - `docs/architecture/README.md`
   - `docs/architecture/PLATFORM_AUTHORITY_MAP.md`
4. Historical reset-wave artifacts are not allowed to overrule the current
   restored root model.

## Key Files

- `docs/architecture/README.md`
- `docs/concepts/architecture/bundle-rules.yaml`
- `docs/concepts/architecture/glossary.yaml`
- `tools/docs/verify/verify_legacy_architecture_root.py`
- `tools/docs/verify/verify-docs-policy.sh`
- `.github/workflows/docs-policy.yml`

## Validation Commands

```bash
python3 tools/docs/verify/verify_legacy_architecture_root.py --repo-root .
python3 tools/docs/verify/build-doc-catalog.py --root .
bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
python3 tools/knowledge/build_knowledge_catalog.py --repo-root .
python3 tools/knowledge/build_knowledge_graph.py --repo-root .
bash scripts/qa/run-knowledge-integrity-gates.sh
```

## Residue

- The historical reset wave expected the folder to remain only as a tombstone
  README for compatibility and discovery.
- Historical/archive materials may still mention `docs/architecture/**` as part of migration history; those references are not the living authority path.
