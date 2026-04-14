# Wave Operations Root Reset Closeout

_Audience: Reviewers and maintainers • Owner: Platform Team • Last verified: 2026-04-14 • Status: historical closeout snapshot_

> Historical closeout for a completed root-retirement wave.
>
> This file records the retirement of `docs/operations/**`. It does not define
> current operator routing.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

## Historical Wave Outcome

`docs/operations/**` is no longer a living documentation root.

The end state is:

- `docs/operations/README.md` only
- live operator procedures under `docs/ops/**`
- live operations reference under `docs/reference/operations/**`
- live operations policy under `docs/policies/operations/**`
- evidence under `docs/evidence/operations/**`
- status and migration reporting under `docs/status/**`

## Deleted Surface

The superseded wrapper set under `docs/operations/*.md`, `docs/operations/postmortems/**`, and `docs/operations/ops-evidence/**` was removed after repo-internal references were rewritten to canonical homes.

## Current Canonical Model

- operator procedures: `docs/ops/**`
- operations reference: `docs/reference/operations/**`
- operations policy: `docs/policies/operations/**`
- `docs/operations/**` is retained only as a tombstone root

## Historical Guardrail

`tools/docs/verify/verify_legacy_operations_root.py` now fails if:

- any substantive file remains under `docs/operations/**` besides `README.md`
- active docs, scripts, deploy config, or infrastructure docs still depend on `docs/operations/**` as a living root

## Validation

- `python3 tools/docs/verify/verify_legacy_operations_root.py --repo-root .`
- `python3 tools/docs/verify/build-doc-catalog.py --root .`
- `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
