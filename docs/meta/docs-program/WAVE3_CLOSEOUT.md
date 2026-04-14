# Wave 3 Closeout

_Audience: Reviewers, contributors, and agents • Owner: Platform Team • Last verified: 2026-03-09 • Status: historical closeout snapshot_

This is a historical closeout for the completed Wave 3 twin-root normalization
packet. It does not define the current docs-program execution or review front
door.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

Retain this document only as historical closeout context for the completed
Wave 3 packet.

## What became truthful

- Proposal material that did not belong in the normative root lane was moved into `specs/proposals/` with compatibility wrappers left behind only where active references still exist.
- Generated spec surfaces now distinguish compatibility wrappers from live normative specs instead of rendering wrappers as root truth.
- The spec toolchain now treats normative, proposal, plan, and testplan lanes as first-class inputs.
- Frontmatter enforcement is aligned with lane reality, and the coverage report reflects actual missing metadata, remaining residue, and legacy status usage.
- Taxonomy enforcement now covers all lane files and no longer silently permits retired legacy status values.

## What remains residue

- No top-level non-normative root residue remains.
- No required metadata gaps remain across normative, proposal, or plan/testplan lanes.
- No legacy status hits remain.

## What was intentionally not collapsed

- `specs/data-migrations-kajabi-mct_spec.md` remains normative by explicit decision because it still carries uniquely normative contract material.
- `specs/plans/data-migrations-kajabi-mct_plan.md` remains the execution companion and was not collapsed into the root spec.

## Recommended next packet

- Refresh the branch for review: regenerate proof once more if needed during PR prep, verify wrappers are still required by live references, and prepare a compact reviewer handoff summarizing intentional normative holdouts and compatibility-wrapper policy.
