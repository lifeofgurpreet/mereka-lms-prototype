# Wave Runbooks Root Reset Review Handoff

## Review target

Confirm that `docs/runbooks/**` is no longer a living peer root and that operator runbooks
now live only under `docs/ops/runbooks/**`.

## Review focus

1. `docs/runbooks/**` contains only `README.md`.
2. Active repo references have been rewritten away from deleted `docs/runbooks/**` paths.
3. Machine-backed surfaces were refreshed after the collapse.
4. The new guard fails if the retired root regrows.

## Key files

- `docs/runbooks/README.md`
- `tools/docs/verify/verify_legacy_runbooks_root.py`
- `tools/docs/verify/verify-docs-policy.sh`
- `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md`
- `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_CLOSEOUT.md`

## Validation

```bash
python3 tools/docs/verify/verify_legacy_runbooks_root.py --repo-root .
bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
```

## Expected conclusion

`docs/runbooks/**` remains only as a tombstone compatibility root. New canonical runbook
content must live under `docs/ops/runbooks/**`.
