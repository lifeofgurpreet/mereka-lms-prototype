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
2. `docs/status/active/IMPLEMENTER-MARCHING-ORDERS.md`
3. `docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md` when tracker repair is open
4. the beads tracker (`br`)
5. current repo truth (`git`, `gh`)
6. current platform truth (`kubectl`, Argo, runtime checks)

Primary rule:
- reconcile tracker truth, doc truth, repo truth, and live system truth first
- then execute a meaningful sprint slice
- then update tracker + rolling state doc before the hour ends
- if repo inventory matters, compare the current checkout to `origin/main`
  before claiming a script/doc/surface is missing

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
- if tracker hygiene is degraded, follow `TRACKER-HYGIENE-RECOVERY-PLAN.md`
  before doing non-trivial mutation
- if the bead graph is stale, incomplete, poorly split, or missing follow-up
  work, fix the bead graph first
- if execution reveals new real work, create or split beads immediately
- keep dependencies and priorities honest

Execution rules:
- work through a sprint slice, not a single tiny task
- push as many bounded, high-leverage items as are truly ready this hour
- merged defects on `main` outrank helper work
- realization-truth / release-safety gaps outrank prose work
- status / README / docs work matters when it reduces operator confusion,
  prevents stale authority, or enables the next loop to run autonomously
- if CI fails, inspect the real failure and fix it
- if an open PR is stale, rebase, narrow, fix, supersede, or close it
- if a merged artifact on `main` is wrong, patch `main`
- when in doubt, check relevant docs and source before acting
- do not rely on ambient kubectl context for dev checks; use explicit context

Start-of-loop procedure:
1. Read `docs/status/active/CURRENT-OPERATOR-STATE.md`.
2. Read `docs/status/active/IMPLEMENTER-MARCHING-ORDERS.md`.
3. Refresh repo truth in both repos.
4. Compare current checkout branch truth to `origin/main` when the task depends
   on repo inventory or landed files.
5. Refresh the live platform truth needed for the active queue.
6. Refresh the bead graph.
7. Repair `CURRENT-OPERATOR-STATE.md` if it drifted before implementation
   starts.
8. Choose the lane using `IMPLEMENTER-MARCHING-ORDERS.md`, then take the
   highest-leverage ready sprint slice inside that lane.

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
