---
title: Hourly Operator Loop Prompt
type: loop-prompt
owner: platform-release
status: reusable
---

# Hourly Operator Loop Prompt

Paste the text below after `/loop 1 hour`.

```text
Systematically work through the current platform queue for the next hour.

You are not operating from this prompt as a frozen snapshot. You are operating
from live sources of truth:

1. `docs/status/active/CURRENT-OPERATOR-STATE.md`
2. the beads tracker (`br`)
3. current repo truth (`git`, `gh`)
4. current platform truth (`kubectl`, Argo, runtime checks)

Primary rule:
- reconcile tracker truth, doc truth, repo truth, and live system truth first
- then execute a meaningful sprint slice
- then update tracker + rolling state doc before the hour ends

Repos in scope:
- `Biji-Biji-Initiative/mereka-lms` (app repo; local checkout varies per operator workstation)
- `Biji-Biji-Initiative/bbi-infrastructure` (infra repo; local checkout varies per operator workstation)

Doc rules:
- `docs/status/active/CURRENT-OPERATOR-STATE.md` is the rolling authority file
- numbered handoff / session docs are historical snapshots unless explicitly
  folded into the rolling file
- do not create new status-doc churn when updating the rolling file is enough
- if a numbered doc is created for a durable reason, fold its useful truth back
  into `CURRENT-OPERATOR-STATE.md` in the same loop

Tracker rules:
- use `br` as the live task graph
- if the bead graph is stale, incomplete, poorly split, or missing follow-up
  work, fix the bead graph first
- if execution reveals new real work, create or split beads immediately
- keep dependencies and priorities honest

Execution rules (governed by docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md):
- work through a sprint slice, not a single tiny task
- push as many bounded, high-leverage items as are truly ready this hour
- merged defects on `main` outrank helper work
- realization-truth / release-safety gaps outrank prose work
- status / README / docs work matters when it reduces operator confusion,
  prevents stale authority, or enables the next loop to run autonomously
- if CI fails, inspect the real failure and fix it
- if an open PR is stale, rebase, narrow, fix, supersede, or close it
- if a merged artifact on `main` is wrong, patch `main` (Rule 2: retractions
  patch source, not margins — if retracting, sweep the term across canonical
  artifacts in the same tranche)
- if shipping a helper, either wire it into its call site in the same PR or
  file a wire-in bead (Rule 4: helpers ship with a call site or wire-in bead)
- if shipping a runbook with status:executable, dry-run it and capture
  evidence in docs/ops/evidence/<name>-YYYY-MM-DD.md (Rule 3: a runbook is
  not executable until it has been run)
- if changing a verifier, coordinate all five layers — workflow +
  policy/config + verifier + self-test + runbook — in the same tranche or
  mark layers N/A explicitly (Rule 5)
- when in doubt, check relevant docs and source before acting
- do not rely on ambient kubectl context for dev checks; use explicit context

Start-of-loop procedure:
1. Read `docs/status/active/CURRENT-OPERATOR-STATE.md`.
2. Refresh repo truth in both repos.
3. Refresh the live platform truth needed for the active queue.
4. Refresh the bead graph.
5. Repair `CURRENT-OPERATOR-STATE.md` if it drifted before implementation
   starts.
6. Choose the highest-leverage ready sprint slice and go.

Expected scope for one hour:
- multiple related fixes / PR updates are allowed
- multiple merges are allowed
- multiple bead updates are allowed
- multiple docs updates are allowed
- the only limit is that the work stays coherent and improves the real queue

Required outputs by the end of the hour:
1. live truth rechecked
2. PR / queue truth rechecked
3. beads updated
4. `CURRENT-OPERATOR-STATE.md` updated
5. exact next move written down there

Definition of success:
- the queue is more accurate than it was at loop start
- the rolling authority doc is current
- at least one high-leverage item is merged, opened cleanly, or materially
  de-risked
- ambiguity is lower
- the next loop can continue autonomously without oral context
```

## Authority

The execution rules above are enforced by the **Truth Repair Doctrine**
(`docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md`). The five rules and
their mechanical enforcement:

| Rule | Claim | Enforcement |
|---|---|---|
| 1 | Canonical = generated or dry-run-verified | `scripts/governance/generate-current-operator-state.sh` (this file's regenerator) |
| 2 | Retractions patch source, not margins | `scripts/governance/verify-retraction-sweep.sh` (bead y69t.2, PR #1825) |
| 3 | A runbook is not executable until run | `scripts/governance/verify-runbook-executable.sh` (bead y69t.1, PR #1824) |
| 4 | Helpers ship with call site or wire-in bead | Social discipline + bead closure convention |
| 5 | Verifier changes update all 5 layers | PR template checkbox |

If a loop iteration ever conflicts with a rule, the doctrine wins. If the
doctrine itself is wrong, patch the doctrine first, then update the
enforcement scripts and this prompt in the same tranche.
