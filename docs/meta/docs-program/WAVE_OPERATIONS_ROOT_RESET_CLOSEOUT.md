# Wave Operations Root Reset Closeout

## Outcome

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

## Guardrail

`tools/docs/verify/verify_legacy_operations_root.py` now fails if:

- any substantive file remains under `docs/operations/**` besides `README.md`
- active docs, scripts, deploy config, or infrastructure docs still depend on `docs/operations/**` as a living root

## Validation

- `python3 tools/docs/verify/verify_legacy_operations_root.py --repo-root .`
- `python3 tools/docs/verify/build-doc-catalog.py --root .`
- `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
