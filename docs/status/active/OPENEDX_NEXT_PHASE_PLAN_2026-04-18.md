# Open edX Next Phase Plan - 2026-04-18

This plan follows the independent remote audit in `07-INDEPENDENT-REMOTE-AUDIT-2026-04-18.md`.

It now assumes two things are true at the same time:

- the earlier promoted artifact for app commit `102a56a07d3270bb61d7c95b28d6ed0d67919360` was real and evidenced
- the later graduation artifact `d0580feefd53580d378e1d9254d5e38dc5dfe066` reached live web deployment on `rke2-nonprod`

But the conveyor is still not "boring" because of five remaining weaknesses:

1. VPS repo checkouts are not canonical by default.
2. RC-02 evidence is present but not independently reproducible on the VPS.
3. RC-05 worker readiness is still open.
4. The post-deploy workflow mixes a noisy production parked-state gate into the same narrative as runtime/browser truth.
5. Active workflows and docs still encode stale GKE/GCP control-plane assumptions strongly enough to mislead operators.

## Operating Goal

Do not reopen broad source/build work.

The next phase is to turn the current one-line proof into a trustworthy operator surface and remove the known false-green / false-red seams around it.

## Priority Order

Never reorder these five items:

1. make operator truth reproducible
2. close the worker readiness defect
3. separate workflow debt from runtime truth
4. remove stale control-plane assumptions from active operator surfaces
5. harden promotion reliability

## Phase 1 - Canonicalize Operator Truth On The VPS

### Purpose

Make `ssh mereka` a trustworthy operator surface instead of a branch-dependent archaeology site.

### Problems observed

- `mereka-lms` server checkout was on a feature branch, not `main`
- local `main` in `mereka-lms` was stale versus `origin/main`
- local `main` in `bbi-infrastructure` was behind `origin/main`
- `verify-release-object.sh` could not be rerun cleanly because the required `platform-control-plane` schema checkout was not discoverable from the VPS

### Actions

1. Define one canonical checkout policy for:
   - `~/projects/k8s/mereka-lms`
   - `~/projects/bbi-infrastructure`
   - `~/projects/k8s/bbi-infrastructure`

2. Add one short operator preflight note or script that records:
   - current branch
   - local HEAD
   - `origin/main`
   - dirty state

3. Restore or document a discoverable `platform-control-plane` contract root on the VPS.

4. Decide whether the RC-02 verifier should:
   - keep depending on a sibling control-plane checkout, or
   - accept the saved schema inside the evidence packet as a reproducibility path

### Exit criteria

- an operator on `ssh mereka` can tell which checkout is canonical in under 30 seconds
- RC-02 verification can be rerun cleanly from the VPS without hidden workflow-only assumptions

## Phase 2 - Close RC-05 Honestly

### Purpose

Fix the worker probe defect without reopening unrelated runtime surfaces.

### Problems observed

- `lms-worker` is `0/3 Ready`
- `cms-worker` is `0/2 Ready`
- pods are alive and Celery is ready
- current probe uses broker-traversing `celery inspect ping`
- this creates readiness failure without proving worker death

### Actions

1. Replace the current readiness probe with a local-only readiness signal.

Prefer, in order:

- a local process/worker heartbeat check that does not traverse Redis/broker round-trip
- a local task-registration or app bootstrap check
- only if unavoidable, a materially widened timeout as a temporary safety patch

2. Re-run rollout on dev and capture:
   - deployment availability
   - pod readiness
   - whether task processing still works
   - whether Argo becomes `Healthy`

3. Reclassify RC-05 after the fix:
   - closed
   - still open
   - or narrowed to non-blocking residual debt

### Exit criteria

- workers become Ready under the live dev deployment
- RC-05 no longer depends on "alive but NotReady" language
- Argo health is no longer held in `Degraded` or `Progressing` by this defect

## Phase 3 - Split Post-Deploy Workflow Debt From Runtime Truth

### Purpose

Stop the post-deploy signal from confusing production parked-state auth failures with dev runtime/browser truth.

### Problems observed

- failed run `24591547989` did not fail in browser E2E
- it failed in `Verify Production Parked State`
- it failed at `Authenticate to GCP and get GKE credentials`
- the current workflow and runbook still let this read like a generic post-deploy runtime failure

### Actions

1. Split or rename the workflow lanes so these are distinct:
   - production parked-state verification
   - staging or dev browser/runtime proof

2. Ensure status contexts are explicit enough that operators cannot confuse them.

3. Update the runbook so a parked-state auth failure is categorized as:
   - workflow/control-plane debt
   - not app runtime failure

4. Decide whether the automatic parked-state lane should:
   - stay but be renamed and scoped
   - move to a different workflow
   - or be retired if the topology no longer justifies it

### Exit criteria

- a failing prod parked-state auth check cannot be mistaken for a failed dev runtime proof
- RC-05 and RC-06 status is not polluted by this workflow

## Phase 4 - De-GKE The Active Operator Surface

### Purpose

Remove or relabel the active workflow, script, and doc surfaces that still teach the wrong system model.

### Problems observed

- active workflows still call a composite action named around GCP/GKE auth
- step names still say `Authenticate to GCP and get GKE credentials`
- some active docs still describe production as GKE
- some bootstrap/operator scripts still treat a legacy GKE context as part of normal operations

### Actions

1. Inventory all active GKE/GCP-touching surfaces into three buckets:
   - stale but harmless
   - stale and actively misleading
   - still truly required because they interact with surviving GCP services

2. For actively misleading surfaces:
   - rename steps and job contexts to reflect reality
   - split legacy/prod-parked checks from runtime checks
   - add explicit comments where a surviving GCP dependency remains but cluster runtime is RKE2

3. For active docs:
   - fix team topology and capability matrix language
   - clearly mark historical GKE material as archival, not current operations doctrine

4. For scripts:
   - stop requiring or advertising legacy GKE context presence during bootstrap
   - rename or quarantine obviously stale helpers that still emit GKE-era operational language

### Exit criteria

- an operator reading active workflows and active docs would conclude "RKE2 is the runtime substrate" without ambiguity
- stale GKE/GCP language survives only in historical docs or explicitly legacy-labeled paths

## Phase 5 - Promotion Reliability Hardening

### Purpose

Address the promote failure pattern only after truth layers above are cleanly separated.

### Problems observed

- recent `promote-dev-image.yml` history still shows repeated failures
- the saved audit/bead trail already points to multiple failure classes
- this is governance and reliability debt, not proof the current artifact failed

### Actions

1. Use the existing bead and audit material as the starting inventory:
   - `mereka-lms-1kd9`
   - `OG-03-PROMOTE-AUDIT.md`

2. Validate each claimed failure class against a sample of actual runs.

3. Prioritize fixes by operator leverage:
   - permissions/auth problems first
   - empty-log or opaque failures second
   - schema-evolution coordination third
   - retry/backoff and transient fetch resilience after that

### Exit criteria

- top failure class is verified, not inferred
- one highest-ROI reliability fix is selected and scoped

## Phase 6 - Remove Stale Second-Authority Debt

### Purpose

Clean the known harmless-but-dangerous stale overlay only after the live authority path is stable.

### Problem observed

- `apps/mereka-lms/overlays/dev/kustomization.yaml` still carries stale image pins
- `profiles/dev` overrides them today
- this did not break the current deployment, but it remains needless ambiguity

### Actions

1. Confirm no active workflow ships from `overlays/dev` directly.
2. Remove the stale `images:` block from the parent overlay or replace it with an explicit "must be overridden" contract.

### Exit criteria

- there is one obvious dev image authority path
- no stale parent overlay can silently mislead operators

## What Must Stay Frozen

Do not reopen these until Phases 1 through 5 are materially done:

- broad Build Authority Phase 2 expansion
- deterministic Open edX build cleanup
- MFE aggregate redesign
- Indigo retirement
- broad observability cleanup
- tenant runtime rewrites unrelated to the RC-05 worker probe defect

## Next-Weeks Calendar

Use this as the default execution shape unless the evidence forces a reorder.

### Week 1

- Canonicalize VPS operator truth
- make RC-02 reproducible from `ssh mereka`
- patch the worker readiness probe and re-close RC-05 if the evidence supports it

### Week 2

- split the post-deploy workflow and status contexts
- remove actively misleading GKE/GCP language from active workflows, scripts, and operator docs
- re-run one clean dev promotion after the workflow changes to confirm signal quality improved

### Week 3

- convert promotion reliability findings into one or two concrete fixes
- remove stale `overlays/dev` image authority if still proven non-authoritative
- refresh the operator packet and evidence ledger after the new steady-state run

## Implementer Feedback

Before starting, hold these boundaries:

- treat web-surface graduation as real, not as a license to declare the whole system finished
- treat worker readiness, operator truth, and workflow signal quality as separate problems
- do not reopen source/build architecture unless operator truth work proves a real upstream blocker
- do not "grep-fix" every GKE/GCP string; classify first, then edit only active and misleading surfaces
- keep one written packet of evidence as you go, so the operator surface gets better while the work lands

## Recommended Ownership Split

If this work is split across agents, split by owner layer:

- Agent A: VPS canonicalization + RC-02 reproducibility
- Agent B: RC-05 worker readiness fix
- Agent C: post-deploy workflow/runbook split
- Agent D: promotion reliability audit-to-fix conversion

If one strong agent owns the whole thing, keep the same order and do not parallelize by guesswork.

## Bottom Line

The current web-serving artifact path is good enough to trust.

The current operator surface is not.

The next phase should harden operator truth, runtime readiness, and control-plane signal quality around the already-live artifacts, not start another wave of source-side change.
