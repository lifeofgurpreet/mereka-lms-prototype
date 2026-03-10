# Wave Branding Root Reset Review Handoff

## Review target

Retire `docs/branding/**` as a duplicate live root and leave only a tombstone README.

## Reviewer focus

1. Confirm `docs/guides/branding/**` is now the only living branding root.
2. Confirm no active docs/specs/infra surfaces still depend on deleted `docs/branding/**` files.
3. Confirm `docs/guides/branding/README.md` is tombstone-only and does not behave like a front door.
4. Confirm the branding-root guard fails if substantive files reappear under `docs/branding/**`.

## Expected final shape

```text
docs/branding/
  README.md
```

## Validation commands

```bash
python3 tools/docs/verify/verify_legacy_branding_root.py --repo-root .
python3 tools/docs/verify/build-doc-catalog.py --root .
bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
```

## Residual accepted history

- Historical ledgers may still discuss `docs/branding/**` as an older topology choice.
- Those references are historical only and are exempt from the active-root guard.
