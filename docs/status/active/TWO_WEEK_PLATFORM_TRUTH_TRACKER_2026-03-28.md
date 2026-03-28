# Two-Week Platform Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-28T03:45:19Z • Status: active_

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
  - `#1148` `test(runtime): add enterprise deep-route browser proof` merged `2026-03-28T01:03:07Z`
  - `#1149` `docs(status): add two-week platform truth tracker` merged `2026-03-28T01:13:14Z`
  - `#1150` `test(runtime): verify LMS and MFE config surfaces stay aligned` merged `2026-03-28T03:13:32Z`
  - `#1151` `fix(ci): repair setup-playwright action manifest` merged `2026-03-28T02:56:30Z`
  - `#1152` `docs(status): refresh platform truth control point` merged `2026-03-28T02:29:33Z`
  - `#1153` `docs(branding): clarify runtime shim ownership` merged `2026-03-28T02:45:35Z`
  - `#1154` `fix(ci): checkout post-deploy gate policy` merged `2026-03-28T03:30:07Z`
- Recently merged in `bbi-infrastructure`:
  - `#2155` `feat(promotion): infra-owned dev image promotion for mereka-lms` merged `2026-03-27T13:08:26Z`
  - `#2157` `fix(ci): route dev promotion through pull requests` merged `2026-03-27T13:36:43Z`
  - `#2161` `feat(ci): prove impacted mereka-lms runtime realization` merged `2026-03-28T02:56:10Z`
  - `#2162` `fix(ci): harden settings ownership verifier` merged `2026-03-28T03:14:05Z`
- Active issue stack:
  - `#834` remains the parent epic for audit remediation and proof hardening
  - `#842` is closed by `#1148`
  - `#843` is closed by `#1153`
- Active app PR lanes:
  - none on the platform-truth board
- Active docs PR lane:
  - `#1155` `docs(status): refresh platform truth control point`
  - only open PR in `mereka-lms`
- Active infra PR lanes:
  - none on the platform-truth board; `#2162` is already merged
- Live dev runtime is on the current promoted image set:
  - `openedx` deployments use `4aba20f30871938d59594fbf70e2ca99e389da5a@sha256:299bd93755f7e4e93da9f0ef38a725343508a33a862bc97d8dd02f23f1320b8f`
  - `mfe` uses `4aba20f30871938d59594fbf70e2ca99e389da5a@sha256:ddd93e8603d96d3a639f89c281a00785fa822537f1feb3eadd45d69fcfc7449d`
- The LMS-host/apps-host MFE-config parity gap is repaired live on nonprod:
  - `bash scripts/qa/verify-mfe-config-contract.sh --env dev` passes
  - `bash scripts/qa/verify-mfe-config-contract.sh --env staging` passes
  - live dev and staging LMS-host/apps-host public surfaces now return non-null values for the governed learner/account/profile/login key family
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

The system is no longer blocked by stale queue debt or unclear runner ownership. The remaining risk is concentrated in four places:

1. merge `mereka-lms#1155` so the active-status docs stop lagging behind reality
2. open the next real implementation lane: shared footer content source across LMS and MFE surfaces
3. open the MFE-config contract truth lane so the live parity repair is backed by an explicit contract and verifier
4. leave the already-closed enterprise/frontend ownership lanes retired unless fresh evidence reopens them

## Two-week execution board

### T-01 — Merge `#1155` and refresh the control-plane docs to current reality

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- `#1154` is merged and the post-merge `main` runs are clean.
- `#1155` is the remaining open docs lane in `mereka-lms`.
- the tracker is one control point behind unless it absorbs the latest queue state.

Done when:

- `#1155` is rebased onto current `main`
- the tracker names `#1154` as merged, not open
- the tracker points at the next actual implementation lanes rather than stale queue repair

Verification commands:

```bash
gh pr list --repo Biji-Biji-Initiative/mereka-lms --state open --limit 10
gh pr view 1155 --repo Biji-Biji-Initiative/mereka-lms --json headRefOid,mergeStateStatus,statusCheckRollup,url
git diff --check
```

Notes:

- Docs stay downstream of reality.
- The tracker should now reflect a drained app queue, not a still-open repair queue.

### T-02 — Open the shared footer content source lane

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- there is still real duplicate footer content ownership between LMS Mako and the MFE footer implementation
- current public MFE footer content lives in `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`
- current LMS footer content lives independently in `infrastructure/tutor/themes/mereka/lms/templates/footer.html`
- both surfaces render correctly today, but future copy/legal/nav changes still require multiple edits
- the smallest credible repair is a shared footer payload exposed on the existing Django↔MFE config bridge while keeping the current DOM/class names stable

Done when:

- one canonical public-footer payload exists for both LMS and MFE surfaces
- the current LMS footer and `MerekaFooter` render from the same content source
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

- Keep CMS/Studio and enterprise footer surfaces out of the first repair unless they can consume the same payload with no extra routing/build work.
- This is now the clearest remaining implementation lane after the queue repair work.

### T-03 — Open the MFE-config contract truth lane

Priority: `P1`
Owner surfaces: `mereka-lms`

Current truth:

- live dev/staging parity for the governed learner/account/profile/login key family is repaired
- the remaining work is to make the contract explicit, stable, and verifier-backed
- `scripts/qa/verify-mfe-config-contract.sh` is the right lane boundary for this work
- the public API should not regress back to implicit or half-populated key exposure

Done when:

- the canonical contract for learner/account/discussions-facing MFE config keys is explicit
- the verifier hard-fails if the governed keys regress
- the live API stays truthful on dev and staging for the approved key family

Verification commands:

```bash
bash scripts/qa/verify-mfe-config-contract.sh --env dev
bash scripts/qa/verify-mfe-config-contract.sh --env staging
bash scripts/qa/verify-multisite-config.sh dev --context rke2-nonprod --namespace mereka-lms-dev
git diff --check
```

Notes:

- Treat this as a runtime contract lane, not a docs lane.
- Do not assume ownership until the diff proves where the missing values belong.

### T-04 — Keep the closed enterprise/frontend ownership lanes retired unless they regress

Priority: `P1`
Owner surfaces: `mereka-lms`

Current truth:

- `#1148` is merged and `#842` is closed.
- `#1153` is merged and `#843` is closed.
- no active implementation PR is currently needed on either lane.

Done when:

- the tracker stops treating these as active queue items
- they reopen only if fresh runtime or source-of-truth evidence appears

Verification commands:

```bash
bash scripts/qa/verify-token-drift.sh
bash scripts/qa/verify-branding-css.sh
gh issue view 842 --repo Biji-Biji-Initiative/mereka-lms --json state,url
gh issue view 843 --repo Biji-Biji-Initiative/mereka-lms --json state,url
```

Notes:

- Do not pull closed lanes back into the control point without new evidence.

## Longer-horizon workstreams after the two-week window

These are real, but they should not displace the two-week critical path above.

| Workstream | Why it matters | Why it is not first |
|---|---|---|
| Tenant CSS runtime injection | multi-tenant palette/runtime token layering is still incomplete | the current tenant/runtime path works well enough for one active tenant family, and footer duplication is the clearer immediate ownership repair |
| Full retirement of `head-extra.html` | removes an emergency override surface entirely | requires a separate bounded cleanup lane after the already-closed ownership/docs work |
| More aggressive generated-artifact automation | reduces future catalog/inventory drift friction | useful, but the current blocker is one concrete workflow repair and two post-merge proof tails |
| Staging/prod post-promotion runtime packs | makes release proof even more machine-checkable | dev/runtime truth and the next governed promotion path should be stabilized first |

## Ownership boundary

- `mereka-lms` owns app behavior, tests, browser proof, runtime contract expectations, docs, and frontend source-of-truth cleanup.
- `bbi-infrastructure` owns overlay mutation, promotion workflows, Argo realization, and post-promotion operational proof.
- Trackers in `docs/status/active/**` must describe those boundaries, not blur them.

## Do not claim this program closed unless all of these are true

- `#1148` is merged and `#842` is no longer open debt
- live dev and staging LMS-host/apps-host public MFE-config surfaces stay aligned for the governed learner/account/profile/login keys, and `#1150` keeps that parity durable in repo truth
- `#1154` is merged and its post-merge `main` runs close cleanly
- the `#2161` false-negative is closed by `#2162` and its merge-commit follow-through is clean
- the shared footer content source lane is opened and described as a single-source repair rather than a vague drift warning
- `#843` remains closed unless new frontend ownership drift appears
- the active trackers still match the actual repo, infra, and runtime state
