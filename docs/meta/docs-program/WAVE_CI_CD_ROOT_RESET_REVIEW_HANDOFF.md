# Wave CI/CD Root Reset Review Handoff

## Review target

Retire `docs/ci-cd/**` as a duplicate live root and leave only a tombstone README.

## Reviewer focus

1. Confirm `docs/ops/ci-cd/**` is now the only living CI/CD operator root.
2. Confirm no active docs, specs, infra, or scripts depend on deleted `docs/ci-cd/**` files.
3. Confirm `docs/ci-cd/README.md` is tombstone-only.
4. Confirm the legacy CI/CD guard fails if substantive files reappear under `docs/ci-cd/**`.

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
