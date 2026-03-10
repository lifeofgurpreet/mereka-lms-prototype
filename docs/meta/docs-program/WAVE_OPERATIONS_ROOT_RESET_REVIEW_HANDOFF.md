# Wave Operations Root Reset Review Handoff

## Review Focus

Review this wave as a root-retirement cleanup, not an operator-content rewrite.

Confirm:

- `docs/operations/**` is reduced to a tombstone root
- active references now resolve to `docs/ops/**`, `docs/reference/operations/**`, `docs/policies/operations/**`, `docs/evidence/operations/**`, or `docs/status/**`
- no wrapper forest remains under the retired root
- the new guard prevents re-growth

## Intended End State

```text
docs/operations/
  README.md
```

## Key Validator

- `python3 tools/docs/verify/verify_legacy_operations_root.py --repo-root .`
