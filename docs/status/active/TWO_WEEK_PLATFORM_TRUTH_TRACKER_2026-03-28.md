# Two-Week Platform Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-28T02:18:30Z • Status: active_

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
  - `#1144` `fix(ci): restore CodeQL to ARC heavy runners` merged `2026-03-27T16:49:37Z`
  - `#1145` `fix(multisite): seed learner-home MFE gate` merged `2026-03-27T18:02:05Z`
  - `#1147` `[codex] add authenticated learner DOM audit mode` merged `2026-03-27T19:45:13Z`
  - `#1148` `test(runtime): add enterprise deep-route browser proof` merged `2026-03-28T01:03:07Z`
  - `#1149` `docs(status): add two-week platform truth tracker` merged `2026-03-28T01:13:14Z`
- Recently merged in `bbi-infrastructure`:
  - `#2155` `feat(promotion): infra-owned dev image promotion for mereka-lms` merged `2026-03-27T13:08:26Z`
  - `#2157` `fix(ci): route dev promotion through pull requests` merged `2026-03-27T13:36:43Z`
  - `#2158` `fix(mereka-lms): backfill MFE config URLs in env overlays` merged `2026-03-28T01:09:58Z`
  - `#2159` `fix(ci): refresh impacted apps before post-merge audit` merged `2026-03-28T01:42:26Z`
  - `#2160` `fix(ci): self-validate post-merge proof workflows` merged `2026-03-28T01:55:55Z`
  - merge commit: `a4382673979a236b5e8b9660d78d6befe9a5eadd`
  - proof status on the merge commit:
    - `Post-Merge Release Proof`: success
    - `Post-Merge Cluster Validation`: failure
  - lane classification: `repo_complete`, not `runtime_validated`
- The app PR queue is no longer blocked on enterprise browser proof:
  - `#1148` merged at commit `9a1d9cc5e274239627bc294c634b47d037cefe99`
  - the last known blocking diff was catalog drift in `verification/catalogs/verification_catalog.json`
  - that drift was fixed on PR head `5de82adcfc10cd7074a8af348ababb655a85da14` before merge
- The active issue stack is now concentrated:
  - `#834` parent epic: audit remediation, frontend parity, docs truth, migration proof hardening
  - `#842` is now closed by `#1148`
  - `#843` is the next frontend debt lane after the runtime contract lane
- Active app PR lanes relevant to the board:
  - `#1150` `test(runtime): verify LMS and MFE config surfaces stay aligned`
  - `#1152` `docs(status): refresh platform truth control point`
  - `#1153` `docs(branding): clarify runtime shim ownership`
- Live dev runtime is on the current promoted image set:
  - `openedx` deployments use `4aba20f30871938d59594fbf70e2ca99e389da5a@sha256:299bd93755f7e4e93da9f0ef38a725343508a33a862bc97d8dd02f23f1320b8f`
  - `mfe` uses `4aba20f30871938d59594fbf70e2ca99e389da5a@sha256:ddd93e8603d96d3a639f89c281a00785fa822537f1feb3eadd45d69fcfc7449d`
- The broad LMS-host/apps-host MFE config null-key defect is repaired on nonprod, but parity is not fully closed:
  - live dev LMS-host and apps-host endpoints both return non-null values for:
    - `LEARNER_HOME_MICROFRONTEND_URL`
    - `ACCOUNT_MICROFRONTEND_URL`
    - `DISCUSSIONS_MICROFRONTEND_URL`
  - live staging LMS-host and apps-host endpoints return the same key family non-null
  - remaining live parity gaps still reproduced on `2026-03-28T02:18:30Z`:
    - dev LMS-host omits `ACCOUNT_SETTINGS_URL`, `PROFILE_MICROFRONTEND_URL`, and `LOGIN_REDIRECT_URL`
    - dev `ACCOUNT_PROFILE_URL` differs across surfaces (`/profile` on LMS-host vs `/u/` on apps-host)
    - staging LMS-host and apps-host both omit `ACCOUNT_SETTINGS_URL`, `PROFILE_MICROFRONTEND_URL`, and `LOGIN_REDIRECT_URL`
- The promotion boundary is materially stronger than it was 24 hours ago:
  - `bbi-infrastructure/.github/workflows/promote-dev-image.yml` is merged
  - `bbi-infrastructure/.github/workflows/promote-image.yml` already exists as the broader governed promotion surface
  - app-repo CI no longer needs to mutate infra git state directly
- Current app-repo regression:
  - `mereka-lms` `main` head `d1b633b4bccf6f1b63a325f729e24d1763cff15b` has a failed `CI` run
  - failure boundary: `Static Validation Precheck` -> `Verify verification catalog is generated and current`
  - immediate fix path: regenerate `verification/catalogs/verification_catalog.json` in a follow-up app PR

## What we achieved already

- Drained the stale app PR queue and got it back to truthful heads.
- Restored CodeQL on ARC heavy and closed the runner/image truth gap that was blocking `#1016`.
- Fixed learner-home handoff truth for `/dashboard` and moved it into canonical seed/reconcile paths.
- Added authenticated DOM/browser proof for learner dashboard surfaces and merged it into `main`.
- Landed the infra-owned dev-promotion path and fixed its protected-branch behavior so it opens PRs instead of pushing to `main`.
- Verified live dev runtime on the promoted image set instead of stopping at GHCR or repo-level overlay claims.

## Current control point

The system is no longer blocked by stale queue debt or unclear runner ownership. The remaining risk is concentrated in four places:

1. restore `mereka-lms` `main` to green after `#1149` by merging a catalog-refreshing follow-up PR
2. classify and follow through the `#2160` post-merge proof result instead of treating the lane as operationally closed
3. merge `mereka-lms#1150` so the partially repaired MFE-config lane stays contract-honest across both LMS-host and apps-host surfaces
4. merge `mereka-lms#1153` to advance `#843` with explicit runtime-shim ownership and verifier guardrails

## Two-week execution board

### T-01 — Confirm enterprise deep-route proof stayed merged and close the lane cleanly

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- `#1148` is merged at `9a1d9cc5e274239627bc294c634b47d037cefe99`.
- `#842` is closed.
- Post-merge `CI` on that merge commit succeeded; the later cancellation on `CodeQL` happened only because `main` advanced to `#1149`.
- The remaining work on this lane is post-merge truth, not PR repair.

Done when:

- post-merge `main` runs are green for the affected checks
- no regression reopens the enterprise/browser proof surface
- the tracker no longer describes this as an open PR lane

Verification commands:

```bash
gh pr view 1148 --json state,mergedAt,mergeCommit,url
gh issue view 842 --json state,closedAt,url
gh run list --repo Biji-Biji-Initiative/mereka-lms --branch main --limit 10
```

Notes:

- This lane is no longer the active implementation bottleneck.
- Do not reopen it unless fresh evidence shows regression.

### T-01b — Restore app main to green after the tracker merge

Priority: `P0`
Owner surfaces: `mereka-lms`

Current truth:

- `#1149` merged documentation updates but did not regenerate `verification/catalogs/verification_catalog.json`
- current `main` head `d1b633b4bccf6f1b63a325f729e24d1763cff15b` is failing `CI`
- failure boundary is narrow and reproducible:
  - `Static Validation Precheck`
  - `Verify verification catalog is generated and current`
- follow-up app PRs now carry the minimal governed fix path:
  - `#1152` tracker refresh plus catalog update
  - `#1153` runtime-shim ownership docs plus catalog update

Done when:

- a follow-up app PR with the regenerated catalog merges
- `mereka-lms` `main` returns to green
- the tracker no longer treats this as an active regression

Verification commands:

```bash
python3 scripts/qa/generate-verification-catalog.py
bash scripts/qa/verify-verification-catalog.sh
gh run view 23674117290 --repo Biji-Biji-Initiative/mereka-lms --log-failed
git diff -- verification/catalogs/verification_catalog.json
```

Notes:

- This is a regression repair, not a new product lane.
- Keep the fix minimal unless reality changed elsewhere in the same truth surface.

### T-02 — Keep the repaired MFE config contract lane honest

Priority: `P0`
Owner surfaces: `mereka-lms`, then `bbi-infrastructure` only if the evidence proves the owner boundary lives there

Current truth:

- `bbi-infrastructure#2158` is merged at `efb84a0d72a045e03f11a5f2ea1adf32643f7a6f`
- that merged fix repaired the old null-key defect for the main learner/account/discussions URL family
- live dev LMS-host and apps-host endpoints both return non-null values for:
  - `LEARNER_HOME_MICROFRONTEND_URL`
  - `ACCOUNT_MICROFRONTEND_URL`
  - `DISCUSSIONS_MICROFRONTEND_URL`
- live staging LMS-host and apps-host endpoints return the same key family non-null
- the runtime contract is still incomplete on the public surfaces:
  - `ACCOUNT_SETTINGS_URL` is missing on dev LMS-host, staging LMS-host, and staging apps-host
  - `PROFILE_MICROFRONTEND_URL` is missing on dev LMS-host, staging LMS-host, and staging apps-host
  - `LOGIN_REDIRECT_URL` is missing on dev LMS-host, staging LMS-host, and staging apps-host
  - `ACCOUNT_PROFILE_URL` still mismatches across dev LMS-host/apps-host
- `#1150` is the governed verifier lane that turns this from anecdotal runtime evidence into an explicit contract failure

Done when:

- `#1150` merges on a truthful head
- the strengthened verifier passes on both dev and staging
- LMS-host and apps-host public surfaces agree on the governed account/profile/login keys, not just the three earlier URL keys
- any future regression reopens from runtime truth, not from stale assumptions

Verification commands:

```bash
python3 - <<'PY'
import json, urllib.request
for url in [
    'https://academyv2.mereka.dev/api/mfe_config/v1',
    'https://apps.academyv2.mereka.dev/api/mfe_config/v1?mfe=authn',
    'https://staging.academyv2.mereka.io/api/mfe_config/v1',
    'https://staging.apps.academyv2.mereka.io/api/mfe_config/v1?mfe=authn',
]:
    payload = json.load(urllib.request.urlopen(url))
    print(url)
    for key in [
        'LEARNER_HOME_MICROFRONTEND_URL',
        'ACCOUNT_MICROFRONTEND_URL',
        'DISCUSSIONS_MICROFRONTEND_URL',
        'ACCOUNT_SETTINGS_URL',
        'ACCOUNT_PROFILE_URL',
        'PROFILE_MICROFRONTEND_URL',
        'LEARNING_BASE_URL',
        'LOGIN_REDIRECT_URL',
    ]:
        print(f"  {key}={payload.get(key)!r}")
PY

bash scripts/qa/verify-mfe-config-contract.sh --env dev
bash scripts/qa/verify-multisite-config.sh dev --context rke2-nonprod --namespace mereka-lms-dev
kubectl exec -n mereka-lms-dev deploy/lms -- sh -lc "grep -n 'LEARNER_HOME_MICROFRONTEND_URL\\|ACCOUNT_MICROFRONTEND_URL\\|DISCUSSIONS_MICROFRONTEND_URL\\|FEATURES\\['\\''MFE_CONFIG'\\''\\] = MFE_CONFIG' /openedx/edx-platform/lms/envs/tutor/production.py"
```

Notes:

- Ownership for the original null-key repair was proven by the realized infra settings copies in the live LMS pod.
- The remaining parity gap is narrower and may be split between env defaults and per-site `SiteConfiguration.MFE_CONFIG` state; do not guess the owner from one surface alone.
- Do not call this lane closed from repo truth alone; close it only when the governed runtime verifier passes.

### T-03 — Turn the merged post-merge proof lane into an honest operational verdict

Priority: `P0`
Owner surfaces: `bbi-infrastructure` consuming `mereka-lms` build truth

Current truth:

- dev promotion is now infra-owned
- protected-branch behavior is corrected
- broader governed promotion already exists via `promote-image.yml`
- `bbi-infrastructure#2159` is merged and improved impacted-app realization discipline
- `bbi-infrastructure#2160` is merged and did prove the targeted behavior:
  - `Post-Merge Release Proof` self-triggered and passed on the merge commit
  - `Post-Merge Cluster Validation` self-triggered and failed on real dev-board findings
- the remaining gap is no longer workflow pathing; it is honest operational follow-through on the failed cluster audit

Done when:

- `#2160` merges on a truthful head
- the `#2160` merge commit triggers `Post-Merge Cluster Validation` and `Post-Merge Release Proof`
- those post-merge workflows complete and leave an explicit success or failure boundary tied to the merge commit
- the promotion path continues to show an explicit proof chain:
  - built digest
  - overlay change
  - Argo desired state move
  - live deployment image move
  - runtime verifier pass
- no app-repo workflow reaches into infra git directly

Verification commands:

```bash
gh pr view 2155 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
gh pr view 2157 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
gh pr view 2159 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,headRefOid,statusCheckRollup,url
gh workflow view promote-dev-image.yml --repo Biji-Biji-Initiative/bbi-infrastructure
gh workflow view promote-image.yml --repo Biji-Biji-Initiative/bbi-infrastructure
kubectl get deploy -n mereka-lms-dev lms cms lms-worker cms-worker mfe -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

Notes:

- The main architectural boundary is established.
- `#2159` is a realization-discipline step, not another promotion redesign.

### T-04 — Close the frontend ownership/drift debt in `#843`

Priority: `P1`
Owner surfaces: `mereka-lms`

Current truth:

- the high-value runtime and CI truth lanes were repaired first
- the remaining frontend debt is now the canonical-source question:
  - what `head-extra.html` still owns
  - what token generation owns
  - what runtime override CSS owns
- `#1153` is the first narrow slice on this lane
- `#1153` currently required a governed catalog refresh, not a redesign of the theming stack

Done when:

- `head-extra.html` is no longer an unbounded hotfix layer
- token vs override ownership is explicit in docs/comments/verifiers
- future contributors can answer "which file is canonical for what?" without guesswork
- `#1153` merges cleanly and post-merge `main` stays green

Verification commands:

```bash
bash scripts/qa/verify-token-drift.sh
bash scripts/qa/verify-branding-css.sh
git diff --check
```

Notes:

- This lane matters, but it follows T-02.
- Do not treat style cleanup as higher priority than runtime contract truth.

### T-05 — Keep trackers and evidence downstream of reality

Priority: `P1`
Owner surfaces: mixed, but primarily `mereka-lms` status/evidence maintainers

Current truth:

- most of the dangerous stale queue debt is gone
- the remaining risk is narrative drift: docs claiming closure before runtime or infra proof exists

Done when:

- active trackers point only at current lanes
- each tracker names its truth boundary explicitly
- takeover prompts tell the next agent what to verify first, not what to believe

Verification commands:

```bash
rg -n "Last verified|Status: active|Do not claim|Current truth|Done when" docs/status/active -S
git diff --check
```

## Longer-horizon workstreams after the two-week window

These are real, but they should not displace the two-week critical path above.

| Workstream | Why it matters | Why it is not first |
|---|---|---|
| Shared footer content source | Django and React footer content still risks future drift | both surfaces currently render; runtime contract truth is higher priority |
| Tenant CSS runtime injection | multi-tenant palette/runtime token layering is still incomplete | the current tenant/runtime path works well enough for one active tenant family |
| Full retirement of `head-extra.html` | removes an emergency override surface entirely | requires the token/override ownership lane to land first |
| More aggressive generated-artifact automation | reduces future catalog/inventory drift friction | useful, but the current blocker is one concrete catalog diff, not system-wide generation failure |
| Staging/prod post-promotion runtime packs | makes release proof even more machine-checkable | dev/runtime truth and the next governed promotion path should be stabilized first |

## Ownership boundary

- `mereka-lms` owns app behavior, tests, browser proof, runtime contract expectations, docs, and frontend source-of-truth cleanup.
- `bbi-infrastructure` owns overlay mutation, promotion workflows, Argo realization, and post-promotion operational proof.
- Trackers in `docs/status/active/**` must describe those boundaries, not blur them.

## Do not claim this program closed unless all of these are true

- `#1148` is merged and `#842` is no longer open debt
- live dev LMS-host `api/mfe_config/v1` returns complete learner/account/discussions MFE URLs or the team explicitly narrows the supported contract surface and updates the verifiers/docs to match
- the next promotion path is proven from built digest to live runtime without app-repo git mutation
- `#843` leaves behind explicit canonical ownership for token/override/hotfix layers
- the active trackers still match the actual repo, infra, and runtime state
