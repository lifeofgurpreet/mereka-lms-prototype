# Wave 4 Review Handoff

_Audience: Reviewers and coding agents • Owner: Platform Team • Last verified: 2026-03-09 • Status: historical review handoff snapshot_

This is a historical handoff for the completed Wave 4 review packet. It does
not define the current docs-program handoff surface.

For current execution and review routing, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

Retain this document only as historical review-handoff context for the
completed Wave 4 packet.

## Historical Start Here

- `docs/meta/docs-program/WAVE4_CLOSEOUT.md`
- `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md`
- `docs/meta/docs-program/WAVE4_REVIEWER_CHECKLIST.md`
- `docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md`

## Historical Generated Surfaces

- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`
- `docs/catalog.json`
- `specs/catalog.json`

## Historical Packet Commits

- `57958869f261d5d945f2750ad80daafdf9909a75` `docs: bootstrap wave 4 knowledge control plane`
- `78cf929af9f15d57c1f74089417f20ddf88472d2` `docs: add unified knowledge catalog`
- `554d4392cf39bf5173afaf29ce652d8676b43cdb` `docs: add unified knowledge graph and review front door`
- `70d8bbb5caf5124089a14b1cf0e467b061a557de` `docs: add wrapper retirement ledger`
- `10b4162a4471b41002c5bdc304631619af153367` `docs: add wave 4 merge-time governance`
- `b3e5e41de1e301824400b930fddf9bfded0076e2` `docs: wire knowledge gate into docs policy CI`

## Historical Reviewer Focus

- Confirm the unified control plane improves visibility without collapsing `docs/` and `specs/`.
- Confirm generated surfaces are derived through generators and remain drift-checked.
- Confirm compatibility wrappers are inventoried rather than silently tolerated.
- Confirm CI now protects the knowledge control plane for docs/spec changes.
