# Wave Branding Root Reset Review Handoff

_Audience: Reviewers • Owner: Platform Team • Last verified: 2026-04-14 • Status: historical review handoff snapshot_

> Historical handoff for a completed root-retirement wave.
>
> The review target below is the reset wave's closure condition, not the
> current branding routing model.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

## Historical Review Target

Retire `docs/branding/**` as a duplicate live root and leave only a tombstone README.

## Historical Reviewer Focus

1. Confirm `docs/guides/branding/**` is now the only living branding root.
2. Confirm no active docs/specs/infra surfaces still depend on deleted `docs/branding/**` files.
3. Confirm `docs/branding/README.md` is tombstone-only and does not behave like a front door.
4. Confirm the branding-root guard fails if substantive files reappear under `docs/branding/**`.

## Current Review Focus

1. `docs/guides/branding/**` remains the branding guidance root.
2. Historical branding-reset records must not be treated as active front-door
   guidance.

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
