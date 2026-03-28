# Two-Week Platform Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-28T06:02:48Z • Status: active_

This is the execution board for the next 14 days. It is intentionally cross-repo and cross-surface: app CI truth, infra promotion truth, live runtime truth, and frontend source-of-truth cleanup all belong here when they are still active and verifiable.

The goal is not to keep a long wish list. The goal is to keep the next two weeks legible for handoff: what is already true, what is still open, who owns each lane, and what exact proof closes it.

## Truth model

- Repo truth: a change is merged on `origin/main`, or a specific PR head is known and its check state is explicit.
- Infra truth: the relevant `bbi-infrastructure` workflow, overlay, or Argo desired state is known.
- Runtime truth: a live API probe, browser proof, or cluster probe shows the expected behavior.
- Closure rule: do not claim a lane is done from repo truth alone when the lane affects runtime.
- Tracker rule: active status docs consume truth. They do not substitute for it.

## Current verified state

- Recently merged in `mereka-lms`:
  - `#1162` `docs(status): refresh platform truth control point` merged `2026-03-28T05:09:15Z`
  - `#1157` `feat(footer): share public footer content source` merged `2026-03-28T04:48:23Z`
  - `#1161` `docs(status): refresh platform truth tracker` merged `2026-03-28T04:51:25Z`
  - `#1160` `test(smoke): require both public MFE config surfaces` merged `2026-03-28T05:27:42Z`
  - `#1148` `test(runtime): add enterprise deep-route browser proof` merged `2026-03-28T01:03:07Z`
  - `#1149` `docs(status): add two-week platform truth tracker` merged `2026-03-28T01:13:14Z`
  - `#1150` `test(runtime): verify LMS and MFE config surfaces stay aligned` merged `2026-03-28T03:13:32Z`
  - `#1151` `fix(ci): repair setup-playwright action manifest` merged `2026-03-28T02:56:30Z`
  - `#1152` `docs(status): refresh platform truth control point` merged `2026-03-28T02:29:33Z`
  - `#1153` `docs(branding): clarify runtime shim ownership` merged `2026-03-28T02:45:35Z`
  - `#1154` `fix(ci): checkout post-deploy gate policy` merged `2026-03-28T03:30:07Z`
  - `#1155` `docs(status): refresh platform truth control point` merged `2026-03-28T03:48:07Z`
- Recently merged in `bbi-infrastructure`:
  - `#2164` `feat(ci): emit dev promotion proof artifact` merged `2026-03-28T05:10:13Z`
  - `#2163` `feat(proof): emit mereka-lms runtime realization json` merged `2026-03-28T04:54:00Z`
  - `#2155` `feat(promotion): infra-owned dev image promotion for mereka-lms` merged `2026-03-27T13:08:26Z`
  - `#2157` `fix(ci): route dev promotion through pull requests` merged `2026-03-27T13:36:43Z`
  - `#2161` `feat(ci): prove impacted mereka-lms runtime realization` merged `2026-03-28T02:56:10Z`
  - `#2162` `fix(ci): harden settings ownership verifier` merged `2026-03-28T03:14:05Z`
- Active issue stack:
  - `#834` is closed as the audit-remediation parent epic; the runtime palette follow-on moved to `#1164`
  - `#842` is closed by `#1148`
  - `#843` is closed by `#1153`
  - `#1164` is the open successor issue for tenant runtime palette injection in the public MFE shell
- Active app PR lanes:
  - `#1158` `docs(branding): align tenant runtime contract`
  - head: `ff25713d06bffad29f9f4ecee04f1091cfb2d58e`
  - current state: branch refreshed on top of current `main`; fresh CI wave is queued/in progress, no failing job
- Closed non-merge app lane:
  - `#1159` `docs(tenant-branding): align palette truth`
  - closed `2026-03-28T04:55:58Z`
  - current state: retired as a separate lane; any still-useful palette-truth deltas must be absorbed deliberately, not merged blindly
- Non-board open PRs:
  - `#1156` Dependabot bump; not part of the platform-truth program
- Live dev runtime is on the current promoted image set:
  - `openedx` deployments use `4aba20f30871938d59594fbf70e2ca99e389da5a@sha256:299bd93755f7e4e93da9f0ef38a725343508a33a862bc97d8dd02f23f1320b8f`
  - `mfe` uses `4aba20f30871938d59594fbf70e2ca99e389da5a@sha256:ddd93e8603d96d3a639f89c281a00785fa822537f1feb3eadd45d69fcfc7449d`
- The LMS/apps MFE-config parity gap is repaired live on nonprod:
  - live `https://academyv2.mereka.dev/api/mfe_config/v1` and `https://apps.academyv2.mereka.dev/api/mfe_config/v1?mfe=authn` both return non-null governed learner/account/profile/login key families
  - `bash scripts/qa/verify-mfe-config-contract.sh --env dev` passes
  - `bash scripts/qa/verify-mfe-config-contract.sh --env staging` passes
- The promotion boundary is materially stronger than it was 24 hours ago:
  - `bbi-infrastructure/.github/workflows/promote-dev-image.yml` is merged
  - `bbi-infrastructure/.github/workflows/promote-image.yml` already exists as the broader governed promotion surface
  - app-repo CI no longer needs to mutate infra git state directly
- Current post-merge follow-through boundaries:
  - `mereka-lms` `main` carries the `#1154` merge commit `2f3eba2b3b13afbe13e3b4d9b0ef77f856ec0c56`
  - `#1154` post-merge `main` is already clean:
    - `CI` success
    - `CodeQL` success
    - `WIF Readiness Check` success
    - `IaC Security Scan` success
  - `#1150` post-merge `main` is already clean:
    - `CI` success
    - `CodeQL` success
    - `IaC Security Scan` success
  - `bbi-infrastructure` main is already clean for `#2162`:
    - `Auth Verification` success
    - `Policy Guards` success

## What we achieved already

- Drained the stale app PR queue and got it back to truthful heads.
- Restored CodeQL on ARC heavy and closed the runner/image truth gap that was blocking `#1016`.
- Fixed learner-home handoff truth for `/dashboard` and moved it into canonical seed/reconcile paths.
- Added authenticated DOM/browser proof for learner dashboard surfaces and merged it into `main`.
- Repaired live dev/staging public MFE-config parity and merged the verifier lane that now guards it.
- Landed the infra-owned dev-promotion path and fixed its protected-branch behavior so it opens PRs instead of pushing to `main`.
- Proved app-scoped post-merge runtime realization and merged the shell-hardening follow-up for its first verifier false negative.

## Current control point

The system is no longer blocked by stale queue debt or unclear runner ownership. `#1157`, `#1160`, `#1161`, `#1162`, `#2163`, and `#2164` are merged, live LMS/apps MFE-config parity is repaired, `#834`, `#842`, and `#843` are closed, and the active queue is down to one app-repo rerun lane: `#1158`.

The remaining risk is concentrated in four places:

1. land `#1158` so the tenant-branding docs/schema/verifier stop over-claiming current runtime behavior
2. keep the now-merged `#1160` browser smoke lane represented truthfully in the control-plane docs
3. keep the now-merged `#2164` dev-promotion artifact lane represented truthfully in the control-plane docs
4. keep `#834` closed as the audit-remediation parent epic and leave `#1164` as the explicit successor for runtime palette injection

## Two-week execution board

### T-01 — Keep the shared footer source landed and retired unless it regresses

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- `#1157` merged at `2026-03-28T04:48:23Z`.
- The footer source of truth is now shared across LMS and MFE public footer content.
- This is no longer an active implementation lane unless fresh evidence shows regression.

Done when:

- current `main` keeps the shared footer content source intact
- current footer DOM/classnames remain compatible with existing CSS/verifiers

Verification commands:

```bash
bash scripts/qa/verify-footer-parity.sh --source-only
bash scripts/qa/verify-footer-variant-matrix.sh
bash scripts/qa/verify-footer-slot-only.sh
pytest -q tests/test_mfe_slot_ownership_patch.py
git diff --check
```

Notes:

- Do not reopen this lane without new source/runtime evidence.

### T-02 — Land `#1158` and retire `#1159` as a separate lane

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- `#1158` is the active truthful repair for the tenant-branding runtime contract.
- `#1159` is closed and should not be treated as an independent active lane anymore.
- the repo had conflicting canonical claims:
  - `docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md` said `palette.*` maps directly to plugin-injected runtime CSS variables and `font_source_url` is injected into the MFE head
  - other repo truth already said tenant-specific runtime colour/token injection is not implemented as a live guarantee
  - `scripts/qa/verify-tenant-branding-runtime.sh` treated missing brand-color tokens as informational only
- that means the first repair is contract alignment, not pretending the runtime injector already exists

Done when:

- `#1158` merges on a truthful head
- any still-useful palette-truth refinements are absorbed deliberately instead of reviving `#1159` wholesale
- the docs/schema/verifier all describe the same current tenant-branding runtime model
- the next runtime injector lane can start from a truthful baseline instead of contradictory docs

Verification commands:

```bash
bash scripts/qa/verify-multitenant-brand-platform.sh
bash scripts/qa/verify-tenant-branding-contract.sh
bash scripts/qa/verify-tenant-token-switching.sh
git diff --check
```

Notes:

- This lane does not implement the runtime injector yet.
- Its purpose is to stop lying about what current runtime tenant theming does.

### T-03 — Keep the repaired MFE-config parity explicit and verifier-backed

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- `#1158` is still the contract-truth first move.
- `#1160` is merged and now part of the maintained proof baseline.
- `#2164` is merged and already hardens dev promotion evidence.
- current governed runtime still does not prove live per-tenant `palette.*` -> `--mereka-color-*` injection; that future implementation is tracked in `#1164`.

Done when:

- `#1158` is merged
- the tracker reflects the repaired MFE-config parity baseline truth
- the successor runtime injector lane stays explicit in `#1164`

Verification commands:

```bash
rg -n "TenantConfig\\.palette|palette\\.(primary|secondary|accent|background|text)|--mereka-color-primary|--mereka-color-secondary|--mereka-color-accent|--mereka-color-background|--mereka-color-text" infrastructure deploy scripts tests -S
bash scripts/qa/verify-token-drift.sh
bash scripts/qa/verify-branding-css.sh
git diff --check
```

Notes:

- Do not claim the runtime contract is real until the runtime path exists.

### T-04 — Keep the successor runtime palette lane explicit

Priority: `P1`
Owner surfaces: split between `mereka-lms` and `bbi-infrastructure`

Current truth:

- live dev and staging LMS/apps MFE-config parity is repaired
- current `main` already checks both public surfaces in `scripts/qa/verify-mfe-config-contract.sh`
- `#2163` is merged and emits machine-readable runtime realization JSON
- `#2164` is merged and emits the dev-promotion proof artifact
- the broader promotion boundary is materially stronger after `#2155`, `#2157`, `#2161`, `#2162`, and `#2163`
- the remaining value is not another redesign; it is keeping the proof chain explicit on the next real promotion and using `#1164` for the runtime palette follow-on

Done when:

- the repaired MFE-config lane stays guarded without being misclassified as still broken
- the tracker and follow-on proof notes treat `#2164` as merged reality rather than an open lane
- the next promotion proof bundle names each step explicitly:
  - built digest
  - infra PR / overlay mutation
  - Argo desired-state move
  - live deployment image move
  - runtime verifier pass

Verification commands:

```bash
bash scripts/qa/verify-mfe-config-contract.sh --env dev
bash scripts/qa/verify-mfe-config-contract.sh --env staging
gh pr view 2155 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
gh pr view 2157 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
gh pr view 2161 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
gh pr view 2162 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
kubectl get deploy -n mereka-lms-dev lms cms lms-worker cms-worker mfe -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

Notes:

- Keep this lane in maintenance/proof mode unless fresh evidence reopens a runtime defect.

### T-05 — Keep trackers and retired lanes truthful

Priority: `P1`
Owner surfaces: `mereka-lms`

Current truth:

- `#1148` is merged and `#842` is closed.
- `#843` is closed.
- `#1157` is merged.
- `#1160` is merged.
- `#1162` is merged.
- `#2164` is merged.
- `#834` is closed as the audit-remediation parent epic, with runtime palette follow-on tracked in `#1164`.
- the MFE-config parity lane is repaired and verifier-backed on current `main`.
- the tracker in `main` drifts quickly because the queue is now small and merges are happening faster than doc-only refresh cadence.

Done when:

- the tracker stops treating closed or merged lanes as if they were still open
- retired lanes reopen only if fresh runtime or source-of-truth evidence appears

Verification commands:

```bash
bash scripts/qa/verify-token-drift.sh
bash scripts/qa/verify-branding-css.sh
gh issue view 842 --repo Biji-Biji-Initiative/mereka-lms --json state,url
gh issue view 843 --repo Biji-Biji-Initiative/mereka-lms --json state,url
git diff --check
```

Notes:

- Do not pull closed lanes back into the control point without new evidence.

## Longer-horizon workstreams after the two-week window

These are real, but they should not displace the two-week critical path above.

| Workstream | Why it matters | Why it is not first |
|---|---|---|
| Tenant runtime palette injection `#1164` | multi-tenant palette/runtime token layering is still incomplete | the current tenant/runtime path works well enough for one active tenant family, and the implementation now has a focused follow-on lane instead of a vague umbrella |
| Full retirement of `head-extra.html` | removes an emergency override surface entirely | requires a separate bounded cleanup lane after the already-closed ownership/docs work |
| More aggressive generated-artifact automation | reduces future catalog/inventory drift friction | useful, but the current blocker is one concrete workflow repair and two post-merge proof tails |
| Staging/prod post-promotion runtime packs | makes release proof even more machine-checkable | dev/runtime truth and the next governed promotion path should be stabilized first |

## Ownership boundary

- `mereka-lms` owns app behavior, tests, browser proof, runtime contract expectations, docs, and frontend source-of-truth cleanup.
- `bbi-infrastructure` owns overlay mutation, promotion workflows, Argo realization, and post-promotion operational proof.
- Trackers in `docs/status/active/**` must describe those boundaries, not blur them.

## Do not claim this program closed unless all of these are true

- `#1148` is merged and `#842` is no longer open debt
- live dev and staging LMS/apps public MFE-config surfaces stay aligned for the governed learner/account/profile/login keys, and `#1150` keeps that parity durable in repo truth
- `#1154` is merged and its post-merge `main` runs close cleanly
- the `#2161` false-negative is closed by `#2162` and its merge-commit follow-through is clean
- `#1157` is the active footer-source lane and is described as a single-source repair rather than a vague drift warning
- `#1158` is explicitly tracked as the contract-truth first move for tenant runtime theming
- `#1164` is the explicit successor for tenant runtime palette implementation
- `#834` is closed as the audit-remediation parent epic or explicitly re-scoped to exclude the runtime palette follow-on
- `#843` remains closed unless new frontend ownership drift appears
- the active trackers still match the actual repo, infra, and runtime state
