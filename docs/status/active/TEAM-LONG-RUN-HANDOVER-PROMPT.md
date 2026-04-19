---
title: Team Long-Run Handover Prompt
type: team-handover-prompt
owner: platform-review
status: active
observed_at: 2026-04-18T14:00Z
---

# Team Long-Run Handover Prompt

Use the prompt below when handing the work to the next team or long-running
multi-agent session.

## Paste This

```text
You are the next team taking over long-running execution on the Mereka LMS /
operator-surface / MFE frontier program.

You are not inheriting a frozen snapshot. You are inheriting a living system.
Your job is to keep the truth surfaces aligned, keep the queue moving, and keep
the team working in the same active tranche instead of fragmenting into
unrelated work.

Start from these authority surfaces, in this exact order:

1. `docs/status/active/CURRENT-OPERATOR-STATE.md`
2. `docs/status/active/IMPLEMENTER-MARCHING-ORDERS.md`
3. `docs/status/active/TEAM-BATCH-SEQUENCING-PLAN.md`
4. `docs/status/active/HOURLY-OPERATOR-LOOP-PROMPT.md`
5. `docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md` if tracker repair is still open
6. `docs/status/active/NEXT-WEEK-IMPLEMENTER-BURN-QUEUE.md`

Do not treat older numbered handoff/session docs as current authority unless
their durable truth has already been folded into the rolling state file.

Your primary operating rule:

- `CURRENT-OPERATOR-STATE.md` answers what is true now
- `IMPLEMENTER-MARCHING-ORDERS.md` answers what one implementer should do next
- `TEAM-BATCH-SEQUENCING-PLAN.md` answers how the team should sequence work in
  batches

If those disagree:
- rolling state wins on current truth
- marching orders win on routing
- team batch plan wins on concurrency and sequencing

Core mission:

1. keep live truth, repo truth, tracker truth, and next-move truth aligned
2. clear the highest-leverage in-flight queue first
3. patch merged defects on `main` instead of narrating around them
4. then move the team through the next durable batch in order
5. leave the system easier for the next shift than you found it

Team operating model:

- 1 reviewer/planner owns:
  - `CURRENT-OPERATOR-STATE.md`
  - batch choice
  - queue/tracker shaping
  - deciding when a batch exits
- 2 implementers own bounded slices inside the current batch
- 1 flex implementer, if available, handles:
  - CI/rebase support
  - proof/evidence slices
  - bounded debt burn

Do not let each person pick a different strategic program.

Batch discipline:

- at most one queue-clearing batch
- at most one foundation batch
- at most one frontier batch

Do not run five strategic programs at once.

The allowed batch order is:

Batch 0 — Queue clearing / truth stabilization
Batch 1 — Foundation closure
Batch 2 — Release-safety / operational proof
Batch 3 — Script first-class burn
Batch 4 — MFE proof and closure frontier
Batch 5 — Debt burn / expansion

Default sequencing:

Phase A:
- Batch 0
- Batch 1

Phase B:
- Batch 2
- Batch 3

Phase C:
- Batch 4
- Batch 5

Do not skip ahead because a later batch feels more interesting.

Start-of-takeover procedure:

1. Read the six authority files listed above.
2. Refresh current repo truth in both repos.
3. Compare the current checkout branch to `origin/main` before claiming a
   script, doc, or surface is missing.
4. Refresh current PR truth.
5. Refresh live platform truth with explicit context-pinned commands.
6. Refresh tracker truth (`br`) carefully.
7. Update `CURRENT-OPERATOR-STATE.md` immediately if it drifted.
8. Identify the current active batch.
9. Split the batch into bounded slices and assign them.
10. Start execution.

Tracker rules:

- tracker reads are useful
- tracker mutation is only allowed if the tracker lane is healthy enough or the
  active assignment is explicitly tracker repair
- if tracker hygiene is degraded, follow
  `docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md`
- do not turn a full team shift into tracker archaeology unless tracker
  reliability is the active batch

Queue rules:

- raw open-PR lists are not the work plan
- the active tranche in `CURRENT-OPERATOR-STATE.md` is the real queue
- if a PR is important and in flight, clear it before opening new strategic
  fronts
- if `main` is known wrong, patch `main` before helper work

Docs rules:

- keep `CURRENT-OPERATOR-STATE.md` current throughout the run
- do not create status-doc churn when the rolling state file is enough
- if you create any numbered artifact for a durable reason, fold its durable
  truth back into the rolling state file in the same working window
- `README.md` in `docs/status/active/` must keep pointing newcomers at the
  right authority surfaces

Implementer rules:

- each implementer should always have one bounded slice
- a bounded slice should aim to end in one of:
  - merged change
  - clean PR
  - decisive proof artifact
  - precise blocker with evidence
- do not spend a shift mostly polling
- if CI fails, inspect the real cause and fix it
- if a PR is behind, rebase it
- if a merged artifact on `main` is wrong, patch it

Reviewer/planner rules:

- keep the bead graph honest
- split oversized work
- add missing dependencies
- discover debt, but do not distract the team with unrelated new lanes while a
  higher-leverage active batch is still open
- shape the next batch before the current one exits

Default routing inside batches:

If Batch 0 is active:
- rebase/fix/land the highest-value in-flight PRs
- kill stale assumptions
- make `CURRENT-OPERATOR-STATE.md` match reality

If Batch 1 is active:
- finish governance/doctrine closure
- or tracker reliability if explicitly assigned
- or top Tier A script scaffolding

If Batch 2 is active:
- produce operational proof:
  - rollback drill evidence
  - DR proof
  - realization-truth proof

If Batch 3 is active:
- use `SCRIPT-TIER-A-FIRST-10.md`
- take the top unchecked Tier A item
- define/verify contract, exit behavior, tests, and next burn

If Batch 4 is active:
- use `MFE-EXECUTABLE-FRONTIER-QUEUE.md`
- start with browser proof or semantic closure, not broad MFE polish

If Batch 5 is active:
- burn debt that reduces future operator confusion first:
  - stale status files
  - merged-but-wrong follow-ups
  - orphan allowlist cleanup

Daily rhythm:

Beginning of day / takeover:
- re-prove truth
- set active batch
- assign bounded slices

Midday:
- check whether the current batch should continue or exit
- do not pivot just because a later batch is more exciting

End of day / handoff:
- re-check live truth
- re-check queue truth
- update beads if safe
- update `CURRENT-OPERATOR-STATE.md`
- write the next exact move there
- record whether the active batch is still active or has exited

Definition of success:

- every team member can name the current active batch
- every implementer has one bounded slice
- the rolling state file matches reality
- important in-flight work is getting cleared
- batch exits are explicit
- no one needs oral context to know what to do next

Anti-patterns:

- one person doing tracker archaeology while everyone else starts unrelated new programs
- broad MFE work before foundation/proof lanes are stable
- using raw PR lists as the work plan
- creating new status docs instead of updating the rolling state file
- calling progress “good” when CI truth or live truth has not been rechecked

If you finish a slice and are unsure what to do next:

1. read `CURRENT-OPERATOR-STATE.md`
2. confirm the active batch
3. use `IMPLEMENTER-MARCHING-ORDERS.md` to pick the next bounded slice inside
   that batch
4. if the batch is exhausted, use `TEAM-BATCH-SEQUENCING-PLAN.md` to decide
   whether the batch exits and what comes next
5. update the rolling state file so the next person does not have to guess
```
