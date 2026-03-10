# Wave Architecture Root Reset Review Handoff
_Audience: Reviewers • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

## Review Goal

Confirm that `docs/architecture/**` no longer behaves like a living peer root and that the surviving content has one canonical home elsewhere.

## Review Focus

1. `docs/architecture/README.md` is a tombstone only.
2. No substantive file remains under `docs/architecture/**`.
3. `bundle-rules.yaml` and `glossary.yaml` now live only under `docs/concepts/architecture/`.
4. Active references now resolve to canonical roots:
   - `docs/concepts/architecture/**`
   - `docs/adr/**`
   - `docs/reference/architecture/**`
   - `docs/meta/docs-program/**`
5. The legacy-root guard fails if a new file appears under `docs/architecture/**`.

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

- The folder still exists only as a tombstone README for compatibility and discovery.
- Historical/archive materials may still mention `docs/architecture/**` as part of migration history; those references are not the living authority path.
