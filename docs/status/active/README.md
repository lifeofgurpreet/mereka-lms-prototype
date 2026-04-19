# Open edX Planning Packet

This directory is the consolidated planning and review packet for the April
2026 Open edX conveyor and MFE work.

It is not a diary. It is the working packet future operators and implementers
should read to avoid re-litigating the same truths.

## Start Here

### If you are the next agent taking over

Read these first, in this order:

- [`CURRENT-OPERATOR-STATE.md`](CURRENT-OPERATOR-STATE.md)
- [`IMPLEMENTER-MARCHING-ORDERS.md`](IMPLEMENTER-MARCHING-ORDERS.md)
- [`TEAM-BATCH-SEQUENCING-PLAN.md`](TEAM-BATCH-SEQUENCING-PLAN.md)
- [`TEAM-LONG-RUN-HANDOVER-PROMPT.md`](TEAM-LONG-RUN-HANDOVER-PROMPT.md)
- [`HOURLY-OPERATOR-LOOP-PROMPT.md`](HOURLY-OPERATOR-LOOP-PROMPT.md)
- [`TRACKER-HYGIENE-RECOVERY-PLAN.md`](TRACKER-HYGIENE-RECOVERY-PLAN.md)

Use `CURRENT-OPERATOR-STATE.md` as the rolling authority file. Use
`IMPLEMENTER-MARCHING-ORDERS.md` as the durable routing surface. Use
`TEAM-BATCH-SEQUENCING-PLAN.md` for multi-agent / team sequencing. Use
`TEAM-LONG-RUN-HANDOVER-PROMPT.md` when handing the whole tranche to a new team.
Use
`HOURLY-OPERATOR-LOOP-PROMPT.md` as the reusable execution contract. Use the
tracker hygiene plan before doing non-trivial `.beads` mutation while tracker
repair remains open.

Only after that should you dip into timestamped packet docs for background.
Every `-20260418` file below is a snapshot in time; some fields (PR numbers,
S6 subtask status, "open follow-ups") rot within hours.

Explicitly stale / historical (do NOT treat as current authority):

- `22-NEXT-AGENT-HANDOFF-2026-04-18T07Z.md` — listed #1805/#1812 as open
  after both were merged; unqualified `kubectl` in re-prove commands.
- `23-SESSION-CLOSURE-2026-04-18T11Z.md` (if present) — listed S6.1/S6.2/
  S6.5 as "in CI" after closure events had moved past those states.
- any "S6 2/5 merged, 3/5 in CI" summary — aged out.

### Conveyor / release track

1. `00-OPERATING-MODEL.md`
2. `01-MASTER-ROADMAP.md`
3. `02-TRACKER.md`
4. `03-OPERATOR-PLAYBOOK.md`
5. `04-EXECUTION-BOARD.md`
6. `05-EVIDENCE-LEDGER.md`

### Most recent remote-review packet

- `07-INDEPENDENT-REMOTE-AUDIT-2026-04-18.md`
- `08-NEXT-PHASE-PLAN-2026-04-18.md`
- `14-IMPLEMENTER-ANTI-DRIFT-MEMO-2026-04-18.md`
- `15-ACTIVE-CONTROL-PLANE-SURFACE-CLASSIFICATION-2026-04-18.md`

### MFE planning sequence

1. `09-MFE-CONSOLIDATION-PLAN-2026-04-18.md`
2. `10-MFE-SPRINT-A-EXECUTION-PLAN-2026-04-18.md`
3. `11-MFE-SPRINT-B-ENTERPRISE-PARITY-PLAN-2026-04-18.md`
4. `12-MFE-PROGRAM-DECISIONS-2026-04-18.md`
5. `13-MFE-PLUGIN-BACKLOG-CLASSIFICATION-2026-04-18.md`
6. `16-ENTERPRISE-OWNERSHIP-SPLIT-2026-04-18.md`

### Execution aids

- `14-IMPLEMENTER-ANTI-DRIFT-MEMO-2026-04-18.md`
- `15-ACTIVE-CONTROL-PLANE-SURFACE-CLASSIFICATION-2026-04-18.md`
- `17-EXECUTION-GRAPH-2026-04-18.md`
- `18-AGENT-ASSIGNMENT-MAP-2026-04-18.md`
- `19-LANE-KICKOFF-PROMPTS-2026-04-18.md`
- `20-FOUR-WEEK-WORK-PLAN-2026-04-18.md`

### Reviewer / planner pack

- `CURRENT-OPERATOR-STATE.md` — rolling authority file
- `HOURLY-OPERATOR-LOOP-PROMPT.md` — reusable loop prompt
- `IMPLEMENTER-MARCHING-ORDERS.md` — durable “what should I do next?” routing
- `TEAM-BATCH-SEQUENCING-PLAN.md` — batch order, concurrency limits, team sequencing
- `TEAM-LONG-RUN-HANDOVER-PROMPT.md` — ready-to-paste long-run takeover prompt for the next team
- `TRACKER-HYGIENE-RECOVERY-PLAN.md` — tracker repair and safe operating mode
- `REVIEWER-PLANNER-OPERATING-CHARTER.md` — role charter
- `DEBT-BURN-REGISTER.md` — sequenced debt surface
- `SCRIPT-FIRST-CLASS-SCOREBOARD.md` — script hardening program
- `SCRIPT-TIER-A-FIRST-10.md` — first concrete script burn list
- `MFE-ISSUE-MAP.md` — executable MFE issue classes
- `MFE-EXECUTABLE-FRONTIER-QUEUE.md` — first concrete MFE execution lanes
- `NEXT-WEEK-IMPLEMENTER-BURN-QUEUE.md` — medium-horizon execution queue
- `TRACKER-RESTORE-SEED-BEADS.md` — exact candidate beads to create after tracker repair

## Current High-Level Truth

- the web-serving conveyor is proven
- the operator surface is still not fully trustworthy
- worker readiness remains open
- stale workflow/control-plane signal still needs cleanup
- MFE learner productization and enterprise parity are separate future sprints

## Use Pattern

- use the conveyor docs for execution order and truth-layer discipline
- use the MFE docs for planning, sprint boundaries, and product-surface
  sequencing
- do not mix conveyor stabilization and MFE program work into one execution
  packet unless a fresh proof event forces it
