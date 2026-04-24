# Wave 4 Reviewer Checklist

_Audience: Reviewers and coding agents • Owner: Platform Team • Last verified: 2026-03-09 • Status: historical reviewer checklist snapshot_

This is a historical reviewer checklist for the completed Wave 4 packet. It
does not define the current docs-program review front door.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

Retain this document only as historical reviewer-checklist context for the
completed Wave 4 packet.

Use this checklist for any PR that changes docs/specs knowledge surfaces.

## Control-plane checks

- `docs/` and `specs/` still remain separate filesystem roots.
- The change does not introduce split truth between a canonical file and a compatibility wrapper.
- Generated knowledge surfaces were refreshed through their generators, not hand-edited.

## Required gate

- Run `bash scripts/qa/run-knowledge-integrity-gates.sh`

## Review questions

- Is the changed file in the correct lane?
- If a wrapper exists, is its canonical target explicit and still justified?
- If a new generated surface exists, is there a `--check` path for drift detection?
- If metadata changed, do the shared catalog and graph still classify it correctly?
- If the change affects docs-program control surfaces, does the tracker still match the actual branch state?
