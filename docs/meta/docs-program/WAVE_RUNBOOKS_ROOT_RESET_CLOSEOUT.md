# Wave Runbooks Root Reset Closeout

## End state

`docs/runbooks/**` is retired as an active documentation root.

Final shape:

```text
docs/runbooks/
  README.md
```

The canonical living runbooks root is now `docs/ops/runbooks/**`.

## What changed

- Rewrote active repo references from `docs/runbooks/**` to `docs/ops/runbooks/**`
  for the duplicate runbook surface.
- Deleted duplicate files under:
  - `docs/runbooks/operations/**`
  - `docs/runbooks/architecture/**`
  - `docs/runbooks/migrations/**`
  - `docs/runbooks/LMS_RUNTIME_CLOSURE_RUNBOOK.md`
- Kept `docs/runbooks/README.md` only as a tombstone redirect.
- Refreshed generated surfaces impacted by the collapse:
  - `docs/catalog.json`
  - `generated/catalogs/docs-catalog.json`
  - `generated/catalogs/knowledge-catalog.json`
  - `generated/contracts/cross-repo-manifest.json`
  - `generated/contracts/release-obligations.md`
  - `generated/graphs/knowledge-graph.json`

## Canonical ownership now

- Runbooks: `docs/ops/runbooks/**`
- Ops references: `docs/reference/operations/**`
- Ops policies: `docs/policies/operations/**`
- Docs-program governance: `docs/meta/docs-program/**`

## Guardrail

`tools/docs/verify/verify_legacy_runbooks_root.py` prevents regrowth by failing when:

- any file other than `docs/runbooks/README.md` exists under `docs/runbooks/**`
- active documentation or workflow surfaces still rely on `docs/runbooks/**` as a live root

This guard is enforced through `tools/docs/verify/verify-docs-policy.sh`.

## Validation

```bash
python3 tools/knowledge/build_knowledge_catalog.py --repo-root .
python3 tools/knowledge/build_knowledge_graph.py --repo-root .
python3 tools/contracts/build_cross_repo_manifest.py --repo-root . --range origin/main...HEAD
python3 tools/contracts/build_release_obligations.py --repo-root . --range origin/main...HEAD
python3 tools/docs/verify/build-doc-catalog.py --root .
python3 tools/docs/verify/verify_legacy_runbooks_root.py --repo-root .
bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
```

## Remaining risk

Archive/report/verification surfaces still mention historical `docs/runbooks/**` paths.
That is acceptable as historical evidence, but they must not be used as active read-first
guidance.
