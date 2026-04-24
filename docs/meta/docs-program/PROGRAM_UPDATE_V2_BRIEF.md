# Program Update — Read Before Execution
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-04-14 • Status: historical brief snapshot_

This is a historical brief for the ADR-governance overlay wave. It does not
define the current execution front door for the docs program.

For current starting points, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)
- [../../architecture/README.md](../../architecture/README.md) for current
  architecture front doors

The ADR corpus in `docs/adr/` remains the decision ledger, not the sole
authoritative starting state for current architecture or docs-program work.

## Historical Execution Rules For V2

1. Wave 1 is an in-place governance overlay, not a physical ADR move.
2. ADR-027 remains Deployment Contract; constitutional ADR sequence starts at ADR-028.
3. First deliverable is contradiction/status/classification coverage for all ADRs.
4. Preserve repo taxonomy (`docs/adr`, `docs/ops`, `docs/concepts`, `docs/archive`).
5. Generate indexes/maps from metadata; do not hand-maintain them as source of truth.
6. For Open edX/Tutor process guidance, use official sources first:
   - `https://docs.openedx.org`
   - `https://docs.tutor.edly.io`
7. Exception/workaround ADRs are invalid without expiry and removal conditions.
8. Do not delete overloaded content without extracting to `evidence/` or `docs/runbooks/`.

## Historical Immediate Priorities

- Install ADR manifest/frontmatter/graph tooling.
- Author ADR-028 through ADR-033.
- Resolve contradictions across ADR-003, ADR-017, ADR-019, ADR-021, ADR-024, and ADR README behavior.
- Convert ADR-013 and ADR-022 into time-bounded exception lifecycle.
- Deepen ADR-018 into a decision-grade commerce ADR.
