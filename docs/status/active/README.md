# Active Status Reports
_Audience: Contributors/reviewers · Owner: Platform Team · Status: canonical (status root)_

This root is for current operational state only.

## Start here — canonical operator authority

**If you are an operator, reviewer, or agent picking up work on this platform, start here and nowhere else:**

- [`CURRENT-OPERATOR-STATE.md`](CURRENT-OPERATOR-STATE.md) — **rolling, auto-generated** state of the PR queue, live cluster, tracker, and repo. Regenerate before trusting it: `bash scripts/governance/generate-current-operator-state.sh`. Hand-edits to this file are drafts, not authority.
- [`HOURLY-OPERATOR-LOOP-PROMPT.md`](HOURLY-OPERATOR-LOOP-PROMPT.md) — reusable loop prompt for autonomous operator iteration. Reads live state; carries no frozen claims.

Authority principle: **canonical state is generated, not written**. Numbered/timestamped handoff docs in this directory are historical snapshots and must not be treated as current authority. If the rolling state file and a numbered doc disagree, trust the rolling state file. If the rolling state file and a direct `gh pr view` / `kubectl --context rke2-nonprod ...` command disagree, trust the direct command and regenerate.

The full rule set governing canonical artifacts in this repo is the [Truth Repair Doctrine](../../meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md). Rule 1 ("canonical = generated") is enforced by `scripts/governance/generate-current-operator-state.sh`. Rule 2 ("retractions patch source") by `scripts/governance/verify-retraction-sweep.sh`. Rule 3 ("runbook is not executable until run") by `scripts/governance/verify-runbook-executable.sh`. Read the doctrine before writing or repairing any status doc.

## Primary active boards

- [MASTER_LAUNCH_ROADMAP_2026-04-04.md](MASTER_LAUNCH_ROADMAP_2026-04-04.md)
- [ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md](ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md)
- [ACTIVE_SURFACE_STATUS_BOARD_2026-04-04.md](ACTIVE_SURFACE_STATUS_BOARD_2026-04-04.md)
- [SMOKE_ACCOUNT_REGISTRY_2026-04-04.md](SMOKE_ACCOUNT_REGISTRY_2026-04-04.md)

## Boundary

- `docs/status/active/` = operational state snapshots and execution boards.
- Stable model belongs in `docs/architecture/`.
- Contracts belong in `docs/reference/contracts/`.
- Procedures belong in `docs/reference/operations/` and `docs/ops/runbooks/`.

## Historical handoff / session snapshots (do NOT treat as current authority)

Numbered or timestamped handoff, session-closure, and takeover-brief files in this directory (patterns `NN-NEXT-AGENT-HANDOFF-*.md`, `NN-SESSION-CLOSURE-*.md`, `NN-NEXT-AGENT-TAKEOVER-BRIEF-*.md`, `NN-IMPLEMENTER-*.md`, `NN-MFE-*.md`, `NN-FOUR-WEEK-*.md`) are historical artifacts. They carry frozen state (PR numbers as they stood at the timestamp in the filename, "S6 2/5 merged" summaries, etc.) and rot within hours. Use them only for historical context — never to decide current action.

## Legacy active trackers

Older trackers in this directory are retained for context but should not override the primary active boards listed above, and the rolling state file above overrides everything.
