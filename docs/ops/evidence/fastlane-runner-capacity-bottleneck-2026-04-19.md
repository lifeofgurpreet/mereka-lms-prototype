---
title: Fastlane runner capacity bottleneck — topology+CPU scheduling deadlock
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-19T06:20Z
lane: bbi-infrastructure (fix target)
bead_candidate: open new; no matching open bead at observation time
status: active
---

# Fastlane runner capacity bottleneck

Observed during slice 51 of the operator loop on 2026-04-19. 17
auto-merge-armed PRs (mereka-lms `#1845-#1863`) were all BLOCKED for
2+ hours because their CI jobs could not acquire a `mereka-k8s-runners`
fastlane pod. Root cause lives in `bbi-infrastructure`; capturing
evidence here so the right lane can act.

## Symptom chain

1. `gh pr view <id>` → `BLOCKED` with pending `Static Validation *` jobs.
2. `gh run view <id> --json jobs` → multiple `queued` jobs.
3. `kubectl --context rke2-nonprod -n arc-runners get
   autoscalingrunnersets`:

   ```
   mereka-k8s-runners: current=23 desired=null running=10 pending=13 idle=null
   ```

   13 ephemeral runner pods could not schedule.

4. `kubectl describe pod <pending-runner>` shows:

   > 0/7 nodes are available: 2 Insufficient cpu, 2 node(s) didn't match
   > pod topology spread constraints, 3 node(s) didn't match Pod's node
   > affinity/selector.

## Root cause

Runner pod template has a hard topology spread constraint:

```yaml
nodeSelector:
  node-role.kubernetes.io/worker: "true"
topologySpreadConstraints:
  - labelSelector:
      matchLabels:
        actions.github.com/scale-set-name: mereka-k8s-runners
        app.kubernetes.io/component: runner
    maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
```

There are 4 worker nodes on `rke2-nonprod`:

| Node | CPU alloc | CPU req | Mem req | State |
|------|-----------|---------|---------|-------|
| `mereka-np-k8s-wk-01-sin1` | 8 | 7687m (96%) | 65% | saturated |
| `mereka-np-k8s-wk-02-sin1` | 8 | 7987m (99%) | 82% | saturated |
| `mereka-np-k8s-wk-03-sin1` | 8 | 6687m (83%) | 59% | high |
| `mereka-np-k8s-wk-04-sin1` | 16 | 14127m (88%) | 51% | high |

Each runner pod requests `cpu: 1000m`. With 10 runners already running,
they are distributed across all 4 hosts (topology spread maxSkew=1 holds
today). The next runner must land on a host with the lowest current
count — but those hosts are exactly the ones with the highest CPU
pressure, because running workloads + running runners stack together.

`whenUnsatisfiable: DoNotSchedule` makes the constraint HARD. The
scheduler cannot relax it even when the alternative is an indefinite
pending queue. Result: **13 pending runners, CI backpressure for every
PR in the queue for 2+ hours**.

## Invariant

**Runner scheduling is a two-variable optimization — topology spread
AND node CPU budget — and both constraints must be soft (or one of
them), or the cluster will deadlock the fastlane under any CPU-pressure
spike.**

## Impact today

- 17 open mereka-lms PRs stuck in `BLOCKED` for 2+ hours.
- Auto-merge armed → they'll cascade once runners free, but operator
  inference on "is the queue stuck?" is noisy.
- Every PR push triggers ~8 fastlane jobs → every new PR amplifies the
  backlog.

## Recommended remediations (all bbi-infrastructure territory)

1. **Soft topology spread** — change `whenUnsatisfiable: DoNotSchedule`
   → `ScheduleAnyway`. Scheduler prefers spread but won't block.
2. **Raise `maxSkew`** — from 1 to 2 or 3, allowing modest concentration
   before the spread kicks in.
3. **Worker scaling** — another `wk-0N-sin1` node would relieve CPU
   pressure at the fleet level. `wk-04-sin1` is 16 CPU (2x the others);
   a twin would double fastlane capacity.
4. **Runner-pod CPU request shrink** — runner pods request 1000m but
   most jobs spike briefly. Reducing to 500m with the same 3-CPU limit
   would double effective capacity per node, at the cost of noisier
   neighbor contention.

**Least-risk quick fix: option 1 (soft topology spread).** Change one
line in the AutoscalingRunnerSet values file. Does not grow the cluster.
Does not change runner resource profile. Restores capacity immediately.

## Source paths (bbi-infrastructure, not this repo)

The AutoscalingRunnerSet is deployed via the `arc-runners-standard`
ArgoCD app (tracking-id
`arc-runners-standard:actions.github.com/AutoscalingRunnerSet:arc-runners/mereka-k8s-runners`).
ArgoCD cannot be kubectl-patched per
`docs/rules/gitops-enforcement.md`; the fix must land in
`bbi-infrastructure` via PR.

## Do NOT

- Do not `kubectl patch` the AutoscalingRunnerSet on `rke2-nonprod`.
  ArgoCD will revert and a patch loop can ensue.
- Do not retry failing jobs faster; they'll just re-queue.
- Do not rebase every PR on main hoping to clear — the queue isn't
  draining because of drift, it's draining because runners cannot
  schedule.

## Observation note

Verified the mereka-k8s-heavy-builders pool is not affected (2 running,
0 pending). Only `mereka-k8s-runners` is wedged. The heavy-builders set
has different resource shapes and is under-used relative to the light
fastlane.

## Related

- Operator state: `docs/status/active/CURRENT-OPERATOR-STATE.md` slice 51
- CI lane plan: `docs/status/active/CI-OPTIMIZATION-LANE-HANDOVER-2026-04-19.md`
  (parked — this capacity issue is narrower than the full plan)
- ARC deployment docs: `docs/ops/ci-cd/CI_CD_RUNNERS.md`
