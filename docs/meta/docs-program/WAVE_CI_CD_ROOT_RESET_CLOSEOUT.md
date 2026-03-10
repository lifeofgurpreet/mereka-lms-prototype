# Wave CI/CD Root Reset Closeout

## End state

`docs/ci-cd/**` is retired as an active documentation root.

Final shape:

```text
docs/ci-cd/
  README.md
```

The canonical living CI/CD operator root is now `docs/ops/ci-cd/**`.

## What changed

- Kept `docs/ci-cd/README.md` as a tombstone redirect.
- Deleted duplicate CI/CD wrapper docs from `docs/ci-cd/**`.
- Updated active front-door and contribution guidance to describe the retired-root state correctly.
- Added a guard that blocks `docs/ci-cd/**` from regrowing as a living root.
- Refreshed generated docs catalogs affected by the root collapse.

## Canonical ownership now

- CI/CD operator guidance: `docs/ops/ci-cd/**`
- Docs-program governance: `docs/meta/docs-program/**`

## Guardrail

`tools/docs/verify/verify_legacy_ci_cd_root.py` prevents regrowth by failing when:

- any file other than `docs/ci-cd/README.md` exists under `docs/ci-cd/**`
- active documentation, infra, or workflow surfaces still rely on `docs/ci-cd/**` as a living root

This guard is enforced through `tools/docs/verify/verify-docs-policy.sh`.

## Validation

```bash
python3 tools/docs/verify/verify_legacy_ci_cd_root.py --repo-root .
python3 tools/docs/verify/build-doc-catalog.py --root .
bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
```

## Remaining risk

Historical ledgers may still mention `docs/ci-cd/**` as part of earlier topology plans. That is acceptable as historical context, but not as living guidance.
