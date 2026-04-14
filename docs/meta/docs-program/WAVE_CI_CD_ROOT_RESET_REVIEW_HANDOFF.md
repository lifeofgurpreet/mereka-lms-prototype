# Wave CI/CD Root Reset Review Handoff

_Audience: Reviewers • Owner: Platform Team • Last verified: 2026-04-14 • Status: historical review handoff snapshot_

> Historical handoff for a completed root-retirement wave.
>
> The review target below is the reset wave's closure condition, not the
> current CI/CD routing model.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

## Historical Review Target

Retire `docs/ci-cd/**` as a duplicate live root and leave only a tombstone README.

## Historical Reviewer Focus

1. Confirm `docs/ops/ci-cd/**` is now the only living CI/CD operator root.
2. Confirm no active docs, specs, infra, or scripts depend on deleted `docs/ci-cd/**` files.
3. Confirm `docs/ci-cd/README.md` is tombstone-only.
4. Confirm the legacy CI/CD guard fails if substantive files reappear under `docs/ci-cd/**`.

## Current Review Focus

1. `docs/ops/ci-cd/**` remains the CI/CD operator root.
2. Historical CI/CD reset records must not be treated as active front-door
   guidance.

## Expected final shape

```text
docs/ci-cd/
  README.md
```

## Validation commands

```bash
python3 tools/docs/verify/verify_legacy_ci_cd_root.py --repo-root .
python3 tools/docs/verify/build-doc-catalog.py --root .
bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
```

## Residual accepted history

- Historical topology ledgers may still mention `docs/ci-cd/**`.
- Those references are historical only and are exempt from the active-root guard.
