# Two-Week Platform Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-28T06:44:09Z • Status: active_

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
  - `#2158` `fix(mereka-lms): backfill MFE config URLs in env overlays` merged `2026-03-28T01:09:58Z`
  - `#2164` `feat(ci): emit dev promotion proof artifact` merged `2026-03-28T05:10:13Z`
  - `#2163` `feat(proof): emit mereka-lms runtime realization json` merged `2026-03-28T04:54:00Z`
  - `#2155` `feat(promotion): infra-owned dev image promotion for mereka-lms` merged `2026-03-27T13:08:26Z`
  - `#2157` `fix(ci): route dev promotion through pull requests` merged `2026-03-27T13:36:43Z`
  - `#2161` `feat(ci): prove impacted mereka-lms runtime realization` merged `2026-03-28T02:56:10Z`
  - `#2162` `fix(ci): harden settings ownership verifier` merged `2026-03-28T03:14:05Z`
- Active issue stack:
  - `#834` is closed as the audit-remediation parent epic
  - `#842` is closed by `#1148`
  - `#843` is closed by `#1153`
  - `#1164` remains open as the active successor issue for tenant runtime palette injection in the public MFE shell
- Recently merged active-lane closeouts:
  - `#1166` `fix(runtime): bridge tenant palette into public MFE shell` merged `2026-03-28T06:34:31Z` at `21dad0731a07d1b1e1203247ea7d9a54397d454a`
  - `#1158` `docs(branding): align tenant runtime contract` merged `2026-03-28T06:12:33Z` at `fa2243ad4ed29012120b342c2b13b4f26be7ad8b`
  - `#1165` `docs(status): close audit epic and refresh platform truth` merged `2026-03-28T06:10:36Z` at `be93d49c0ffff13e03bed3513b40cf68d43ef009`
- Closed non-merge app lane:
  - `#1159` `docs(tenant-branding): align palette truth`
  - closed `2026-03-28T04:55:58Z`
  - current state: retired as a separate lane; any still-useful palette-truth deltas must be absorbed deliberately, not merged blindly
- Active control-plane doc lane:
  - `#1167` `docs(status): refresh two-week platform truth tracker`
  - current state: open doc refresh lane; read live PR metadata for the exact head and keep the merged `#1166` state plus the still-open `#1164` runtime boundary accurate
- Non-board open PRs:
  - `#1156` Dependabot bump; not part of the platform-truth program
- Live dev runtime is on the current promoted image set:
  - `openedx` deployments use `4aba20f30871938d59594fbf70e2ca99e389da5a@sha256:299bd93755f7e4e93da9f0ef38a725343508a33a862bc97d8dd02f23f1320b8f`
  - `mfe` uses `4aba20f30871938d59594fbf70e2ca99e389da5a@sha256:ddd93e8603d96d3a639f89c281a00785fa822537f1feb3eadd45d69fcfc7449d`
- The LMS/apps MFE-config parity gap is repaired live on nonprod:
  - infra owner proof landed in `bbi-infrastructure#2158`
  - live `https://academyv2.mereka.dev/api/mfe_config/v1` and `https://apps.academyv2.mereka.dev/api/mfe_config/v1?mfe=authn` both return non-null governed learner/account/profile/login key families
  - `bash scripts/qa/verify-mfe-config-contract.sh --env dev` passes
  - `bash scripts/qa/verify-mfe-config-contract.sh --env staging` passes
  - current production host behavior from this workstation is a separate availability anomaly (`502` on LMS and apps hosts), not the earlier nonprod null-key defect
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

The system is no longer blocked by stale queue debt or unclear runner ownership. `#1158`, `#1165`, and `#1166` are merged, `#834` is closed, and the active runtime boundary is now post-merge realization plus live tenant-host proof for `#1164`.

The remaining risk is concentrated in four places:

1. get `#1166` fully through post-merge `main` and image-build follow-through
2. run the new live tenant-host/browser proof after deployment on a real non-default tenant host
3. keep the repaired MFE-config parity lane represented truthfully as closed on nonprod
4. keep `#1164` open until runtime proof is actually complete
5. separate any prod availability anomaly from the already-fixed nonprod config-completeness bug

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

### T-02 — Carry merged `#1166` through deployment and close `#1164` only on real runtime proof

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- `#1158` is merged and removed the contradictory tenant-branding runtime claims.
- `#1159` is closed and should stay retired as a separate lane.
- `#1166` merged at `2026-03-28T06:34:31Z` as `21dad0731a07d1b1e1203247ea7d9a54397d454a`.
- staging non-default tenant hosts exist and are reachable:
  - `https://staging.academy.biji-biji.com`
  - `https://apps.staging.academy.biji-biji.com`
  - `https://staging.skillourfuture.academy.mereka.io`
  - `https://apps.staging.skillourfuture.academy.mereka.io`
- pre-merge staging baseline proved the runtime gap was real on those tenant hosts:
  - `SITE_NAME` is correct on the non-default tenant hosts
  - `PRIMARY_COLOR`, `SECONDARY_COLOR`, `ACCENT_COLOR`, and `TEXT_ON_PRIMARY` are still `None`
- post-merge runtime proof is not yet recorded, so `#1164` must stay open

Done when:

- `#1166` post-merge `main` is clean
- any required image/promotion steps for the merged commit are explicit
- post-merge deployment carries the branch into a real tenant-host environment
- the targeted browser proof passes on at least one non-default tenant host
- `#1164` is closed only after that runtime proof exists

Verification commands:

```bash
cd tests/e2e && npx playwright test tests/tenant-palette-bridge.spec.ts --list
BASE_URL=https://staging.academy.biji-biji.com EXPECTED_SITE_NAME='Biji-Biji Academy' \
  npx playwright test tests/tenant-palette-bridge.spec.ts --reporter=line
gh run list --repo Biji-Biji-Initiative/mereka-lms --branch main --limit 20
git diff --check
```

Notes:

- This lane is merged in repo truth.
- The remaining boundary is deployment + live tenant-host proof.

### T-03 — Keep the repaired MFE-config parity explicit and verifier-backed

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- `#1158` is merged and now part of the maintained contract baseline.
- `#1160` is merged and now part of the maintained proof baseline.
- `#2158` is merged and is the evidence-backed infra repair for the old nonprod LMS-host null-key bug.
- `#2164` is merged and already hardens dev promotion evidence.
- current governed runtime still does not prove live per-tenant `palette.*` -> `--mereka-*` / `--pgn-*` injection until `#1166` is deployed and proven.

Done when:

- `#1166` is merged and runtime-proven
- the tracker reflects the repaired MFE-config parity baseline truth
- the successor runtime injector lane closes cleanly only after the live proof exists

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
- the remaining value is not another redesign; it is keeping the proof chain explicit on the next real promotion and using merged `#1166` plus the still-open `#1164` runtime proof boundary for the tenant palette follow-on

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
gh pr view 2158 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
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

- `#1158` is merged.
- `#1165` is merged.
- `#1166` is the active runtime lane.
- `#1164` remains open until live tenant-host proof is complete.
- `#834` is closed as the audit-remediation parent epic.
- the tracker in `main` drifts quickly because the queue is now small and merges are happening faster than doc-only refresh cadence.

Done when:

- the tracker stops treating closed or merged lanes as if they were still open
- retired lanes reopen only if fresh runtime or source-of-truth evidence appears
- `#1164` is not closed until live tenant-host runtime proof is recorded

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
| Full retirement of `head-extra.html` | removes an emergency override surface entirely | requires a separate bounded cleanup lane after the already-closed ownership/docs work |
| More aggressive generated-artifact automation | reduces future catalog/inventory drift friction | useful, but the current blocker is one concrete workflow repair and two post-merge proof tails |
| Staging/prod post-promotion runtime packs | makes release proof even more machine-checkable | dev/runtime truth and the next governed promotion path should be stabilized first |
| Broader token/override cleanup after `#1166` | keeps the tenant runtime bridge and its follow-ons explicit | the bridge itself is the active lane; cleanup belongs after live proof |

## Ownership boundary

- `mereka-lms` owns app behavior, tests, browser proof, runtime contract expectations, docs, and frontend source-of-truth cleanup.
- `bbi-infrastructure` owns overlay mutation, promotion workflows, Argo realization, and post-promotion operational proof.
- Trackers in `docs/status/active/**` must describe those boundaries, not blur them.

## Do not claim this program closed unless all of these are true

- `#1158` is merged and `#1165` is merged
- `#1166` is merged and runtime-proven
- `#1164` is only closed after live tenant-host runtime proof exists
- `#834` is closed as the audit-remediation parent epic
- the active trackers still match the actual repo, infra, and runtime state
