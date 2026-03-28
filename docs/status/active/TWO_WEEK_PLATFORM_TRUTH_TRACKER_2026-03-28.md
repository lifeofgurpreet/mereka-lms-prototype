# Two-Week Platform Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-28T08:51:31Z • Status: active_

This is the execution board for the current 14-day platform-truth window. It is intentionally cross-repo and cross-surface: app CI truth, infra promotion truth, live runtime truth, and status/handoff truth all belong here when they are still active and verifiable.

The board is not a wish list. It is the current control point: what is already closed, what is still open, and what exact proof is required before the next lane can be called done.

## Truth model

- Repo truth: a change is merged on `origin/main`, or a specific PR head is known and its check state is explicit.
- Infra truth: the relevant `bbi-infrastructure` workflow, overlay, PR, or Argo realization is known.
- Runtime truth: a live API probe, browser proof, or cluster probe shows the expected behavior.
- Closure rule: do not claim a runtime lane is done from repo truth alone.
- Tracker rule: active status docs consume truth. They do not substitute for it.

## Current verified state

- Recently merged in `mereka-lms`:
  - `#1169` `fix(ci): bound non-blocking SBOM scans` merged `2026-03-28T07:51:48Z` at `4a05e894ad0d62423fd6b782e434e9b1d68e168f`
  - `#1168` `docs(ci): align build workflow with infra-owned promotion` merged `2026-03-28T07:15:44Z`
  - `#1166` `fix(runtime): bridge tenant palette into public MFE shell` merged `2026-03-28T06:34:31Z` at `21dad0731a07d1b1e1203247ea7d9a54397d454a`
  - `#1165` `docs(status): close audit epic and refresh platform truth` merged `2026-03-28T06:10:36Z`
  - `#1158` `docs(branding): align tenant runtime contract` merged `2026-03-28T06:12:33Z`
  - `#1160` `test(smoke): require both public MFE config surfaces` merged `2026-03-28T05:27:42Z`
  - `#1157` `feat(footer): share public footer content source` merged `2026-03-28T04:48:23Z`
- Recently merged in `bbi-infrastructure`:
  - `#2168` `chore(mereka-lms): promote dev images to 4a05e894ad0d62423fd6b782e434e9b1d68e168f` merged `2026-03-28T08:43:12Z` at `60a49e2490d469398dde54f346db1106917864c8`
  - `#2167` `fix(mereka-lms): set prod MFE host override` merged `2026-03-28T08:46:44Z` at `be096402b4d47c49e69dceb4e628eda3404c543a`
  - `#2165` `fix(mereka-lms): backfill prod mfe config urls` merged `2026-03-28T07:33:40Z`
  - `#2164` `feat(ci): emit dev promotion proof artifact` merged `2026-03-28T05:10:13Z`
  - `#2163` `feat(proof): emit mereka-lms runtime realization json` merged `2026-03-28T04:54:00Z`
  - `#2158` `fix(mereka-lms): backfill MFE config URLs in env overlays` merged `2026-03-28T01:09:58Z`
  - `#2155` `feat(promotion): infra-owned dev image promotion for mereka-lms` merged `2026-03-27T13:08:26Z`
  - `#2157` `fix(ci): route dev promotion through pull requests` merged `2026-03-27T13:36:43Z`
- Active issue stack:
  - `#834` is closed as the audit-remediation parent epic
  - `#842` is closed by `#1148`
  - `#843` is closed by `#1153`
  - `#1164` remains open as the active successor issue for tenant runtime palette proof
- Active open app PRs:
  - `#1156` Dependabot bump; not part of the platform-truth program
- Active merged-follow-through lane:
  - `#1166` is merged in repo truth
  - `#1172` is merged in repo truth
  - `#2168` and `#2171` are merged in infra truth, so the dev-promotion creation step and the invalid dev Cilium policy blocker are no longer open debt
  - the tenant proof path itself is still reachable:
    - `https://apps.academyv2.mereka.dev/authn/login` → `200`
    - `https://apps.biji-biji.academyv2.mereka.dev/authn/login` → `200`
    - `https://apps.skillourfuture.academyv2.mereka.dev/authn/login` → `200`
    - tenant LMS-host and apps-host `/api/mfe_config/v1` surfaces return `200`
  - current desired GKE source now includes the non-default tenant hosts in dev ingress/Caddy config, but live `mereka-lms-dev` has not realized that source yet
  - the public tenant hosts resolve to the documented RKE2/nonprod worker IPs rather than the stale GKE ingress address, so public `200` responses do not by themselves prove the GKE namespace has realized current source
  - `#1164` remains blocked by unchanged tenant branding payloads on non-default tenant hosts:
    - `SITE_NAME='Mereka Academy'`
    - `PRIMARY_COLOR=None`
    - `SECONDARY_COLOR=None`
    - `ACCENT_COLOR=None`
    - `TEXT_ON_PRIMARY=None`
    - `PARAGON_THEME=None`
  - a manual sync of `mereka-lms-dev` is not a truthful closure shortcut:
    - the app ignores `/spec/replicas` drift for `lms` and `cms`
    - both workloads are currently at replica `0`
    - their HPAs show `ScalingDisabled`
    - so sync alone would not bring the core LMS/CMS runtime back
- Nonprod MFE-config parity is closed in runtime truth:
  - `bash scripts/qa/verify-mfe-config-contract.sh --env dev` passes
  - `bash scripts/qa/verify-mfe-config-contract.sh --env staging` passes
  - dev and staging both return non-null governed learner/account/discussions/profile/login key families on LMS-host and apps-host surfaces
- Current production behavior is a separate availability anomaly:
  - `https://academyv2.mereka.io/` → `502`
  - `https://academyv2.mereka.io/api/mfe_config/v1` → `502`
  - `https://apps.academyv2.mereka.io/` → `502`
  - `https://apps.academyv2.mereka.io/api/mfe_config/v1?mfe=authn` → `502`
  - `https://studio.academyv2.mereka.io/` → `502`
  - `https://preview.academyv2.mereka.io/` → `502`
  - that is broader than an MFE-config handler bug and currently points to prod public-host availability on the shared ingress/Caddy/app path

## What we achieved already

- Drained the stale app PR queue and got it back to truthful heads.
- Restored CodeQL on ARC heavy and closed the runner/image truth gap that was blocking `#1016`.
- Fixed learner-home handoff truth for `/dashboard` and moved it into canonical seed/reconcile paths.
- Added authenticated DOM/browser proof for learner dashboard surfaces and merged it into `main`.
- Added enterprise deep-route browser proof and closed `#842`.
- Clarified and retired the hotfix/token-ownership debt lane by closing `#843`.
- Repaired live dev/staging LMS/apps MFE-config parity and merged the verifier lane that now guards it.
- Landed the infra-owned dev-promotion path and its proof artifact so app CI no longer mutates infra git state directly.
- Merged the tenant-palette runtime bridge in source truth and merged the prod overlay source-parity backfill for MFE config URLs.

## Current control point

The program is no longer queue-bound. The active control point is narrower and more architectural:

1. keep `#1164` open until tenant branding payloads become tenant-specific and the browser proof passes on the runtime plane that actually serves the public tenant hosts
2. stop conflating the GKE `mereka-lms-dev` build/promotion path with the public RKE2/nonprod tenant-host runtime plane
3. keep nonprod MFE-config parity represented truthfully as closed
4. keep prod public-host `502` behavior classified separately from the dev tenant-palette lane
5. keep the tracker downstream of live runtime truth instead of repo-only milestones

## Two-week execution board

### T-01 — Close `#1164` only with tenant-host runtime proof on the correct plane

Priority: `P0`
Owner surfaces: `mereka-lms` -> `bbi-infrastructure` -> live runtime

Current truth:

- `#1166` and `#1172` are merged in app repo truth.
- `#2168` and `#2171` are merged in infra truth.
- the tenant proof path is executable and semantically failing:
  - tenant LMS-host and apps-host `/api/mfe_config/v1` endpoints return `200`
  - the tenant payloads still return default/null branding values
  - the targeted Playwright proof still fails on `SITE_NAME='Mereka Academy'`
- desired GKE source now contains the non-default tenant hosts in dev ingress/Caddy config
- live GKE `mereka-lms-dev` has not realized that source yet:
  - the live ingresses still expose only `academyv2.mereka.dev` and `apps.academyv2.mereka.dev`
  - the mounted dev Caddy config does not contain the tenant host rules
- the public proof hosts are not backed by the GKE `mereka-lms-dev` namespace being watched for build/promotion:
  - public host DNS resolves to the documented RKE2/nonprod worker IPs
  - GKE `mereka-lms-dev` ingress advertises `34.177.83.168`, has no non-default tenant ingress rules, and its `caddy` / `lms` / `mfe` endpoints are empty
- therefore the GKE build -> promotion -> Argo path can advance source truth, but it does not by itself prove the public tenant hosts moved

Done when:

- the runtime plane serving the public tenant hosts is explicitly identified and observable
- tenant LMS-host and apps-host config payloads become tenant-specific on that plane
- the targeted Playwright proof passes on at least one non-default tenant host on that plane
- `#1164` closes with runtime evidence, not just merged source or GKE promotion progress

Verification commands:

```bash
python3 - <<'PY'
import json, urllib.request
for label, url in [
    ('biji-biji-lms', 'https://biji-biji.academyv2.mereka.dev/api/mfe_config/v1'),
    ('biji-biji-apps', 'https://apps.biji-biji.academyv2.mereka.dev/api/mfe_config/v1?mfe=authn'),
    ('skillourfuture-lms', 'https://skillourfuture.academyv2.mereka.dev/api/mfe_config/v1'),
    ('skillourfuture-apps', 'https://apps.skillourfuture.academyv2.mereka.dev/api/mfe_config/v1?mfe=authn'),
]:
    payload = json.load(urllib.request.urlopen(url))
    print(label, {k: payload.get(k) for k in ['SITE_NAME','PRIMARY_COLOR','SECONDARY_COLOR','ACCENT_COLOR','TEXT_ON_PRIMARY','PARAGON_THEME']})
PY

cd tests/e2e
BASE_URL=https://biji-biji.academyv2.mereka.dev EXPECTED_SITE_NAME='Biji-Biji Academy (Dev)' \
  npx playwright test tests/tenant-palette-bridge.spec.ts --project chromium
BASE_URL=https://skillourfuture.academyv2.mereka.dev EXPECTED_SITE_NAME='Skill Our Future (Dev)' \
  npx playwright test tests/tenant-palette-bridge.spec.ts --project chromium
```

Notes:

- The current blocker is not generic availability; it is wrong tenant runtime data on a different realized plane than the GKE namespace we have been watching.
- Do not close this lane because the app/infra source changes are merged or because the GKE build/promotion chain completes.
- Do not treat manual Argo sync as a closure shortcut while `lms` and `cms` remain intentionally zero-scaled.

### T-02 — Identify the public tenant-host runtime plane and its realization path

Priority: `P0`
Owner surfaces: infra/runtime operations

Current truth:

- live DNS for the public dev hosts points at the documented RKE2/nonprod worker IPs, not the GKE ingress address
- GKE `mereka-lms-dev` does not currently own the non-default tenant hosts at ingress or endpoint level
- desired GKE source now contains the tenant hosts, but live GKE state has not realized that desired ingress/Caddy surface yet
- a separate older `mereka-lms` namespace still exists on GKE with a live `caddy` endpoint, but it does not fully explain the tenant `.academyv2.mereka.dev` host set either
- that means the public runtime proof for `#1164` is currently happening on a different control plane than the GKE namespace/build chain under active observation

Done when:

- the actual public-host serving plane is explicitly named and owned
- the promotion/realization path from merged source to those hosts is explicit
- the `#1164` proof pack is pointed at the plane that actually serves the tenant hosts
- the tracker no longer implies that GKE `mereka-lms-dev` alone can close the public-host proof lane

Verification commands:

```bash
python3 - <<'PY'
import socket
for host in [
    'academyv2.mereka.dev',
    'biji-biji.academyv2.mereka.dev',
    'skillourfuture.academyv2.mereka.dev',
    'apps.academyv2.mereka.dev',
]:
    print(host, socket.gethostbyname(host))
PY

KUBECONFIG=~/.kube/config.backup-20260217-110428 \
kubectl get ingress -n mereka-lms-dev openedx-lms openedx-mfe -o wide

KUBECONFIG=~/.kube/config.backup-20260217-110428 \
kubectl get svc,endpoints -n mereka-lms-dev caddy lms mfe -o wide
```

Notes:

- This lane is now a prerequisite for closing the tenant-palette proof honestly.
- It also explains why forcing sync on the GKE app is not enough: the core LMS/CMS workloads remain replica-zero by separate policy.

### T-03 — Keep nonprod MFE-config parity explicitly closed

Priority: `P0`
Owner surfaces: `mereka-lms`, `bbi-infrastructure`

Current truth:

- `#1150`, `#2158`, and `#2165` repaired and guarded the MFE-config contract surface.
- dev and staging both pass the governed verifier on LMS-host and apps-host surfaces.
- the old “nonprod LMS-host null-key” defect is no longer the active bug.

Done when:

- tracker and handoff material continue to describe the nonprod parity lane as closed
- verifier coverage stays in `main`
- any new runtime issue is classified separately instead of reopening the old defect by habit

Verification commands:

```bash
bash scripts/qa/verify-mfe-config-contract.sh --env dev
bash scripts/qa/verify-mfe-config-contract.sh --env staging
gh pr view 2158 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
gh pr view 2165 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
git diff --check
```

Notes:

- “Prod is down” is not evidence that nonprod parity regressed.

### T-04 — Track prod public-host availability as its own outage lane

Priority: `P1`
Owner surfaces: infra/runtime operations

Current truth:

- prod public hosts are returning broad empty `502`s
- staging equivalent hosts are healthy
- current source truth already includes the prod MFE-config backfill, so the active prod blocker is not the missing-key contract

Done when:

- the outage is owned as availability work, not config-contract work
- the precise runtime failure boundary is recorded and preserved in handoff
- prod recovers or is explicitly handed to the correct infra/runtime owner

Verification commands:

```bash
python3 - <<'PY'
import urllib.request, urllib.error
for url in [
    'https://academyv2.mereka.io/',
    'https://academyv2.mereka.io/api/mfe_config/v1',
    'https://apps.academyv2.mereka.io/',
    'https://apps.academyv2.mereka.io/api/mfe_config/v1?mfe=authn',
    'https://studio.academyv2.mereka.io/',
    'https://preview.academyv2.mereka.io/',
]:
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            print(url, r.status)
    except urllib.error.HTTPError as e:
        print(url, e.code)
PY

gh pr view 2165 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,url
git diff --check
```

Notes:

- Do not describe this as an `/api/mfe_config/v1` bug unless the broad `502` surface disappears and a narrower boundary remains.

### T-05 — Keep the board and handoff downstream of reality

Priority: `P1`
Owner surfaces: `mereka-lms` status docs

Current truth:

- the old tracker snapshots are already obsolete fast enough to create narrative drift
- the remaining risk is not missing documentation; it is documentation claiming the wrong active lane

Done when:

- active tracker text matches the current control point
- takeover prompts tell the next agent what to verify first, not what to believe
- closed lanes stay retired unless new evidence reopens them

Verification commands:

```bash
rg -n "Current control point|Current verified state|Done when|Do not" docs/status/active -S
git diff --check
```

## Longer-horizon workstreams after the current control point

These are real, but they are not first in line while the lanes above are still open.

| Workstream | Why it matters | Why it is not first |
|---|---|---|
| Deeper automated tenant-host proof packs | strengthens future multi-tenant runtime assurance | `#1166` still needs one honest end-to-end realization first |
| Full retirement of runtime shim surfaces | reduces future frontend drift | `#843` is already closed at the current governance level |
| More generated-artifact automation | reduces future catalog/verifier friction | current friction is bounded to specific lanes, not systemic failure |
| Prod-host availability hardening | turns current outage diagnosis into boring operations | must be owned as runtime/infra work, not conflated with the now-closed nonprod config lane |

## Ownership boundary

- `mereka-lms` owns app behavior, workflow contracts, browser proof, runtime contract expectations, and status/handoff truth.
- `bbi-infrastructure` owns overlay mutation, promotion workflows, Argo realization, and operational proof artifacts.
- runtime outage classification belongs to the plane where the failure boundary lives, not to whichever repo was touched most recently.

## Do not claim this program closed unless all of these are true

- `#1169` is merged and post-merge `main` build truth is complete
- merged `#1166` has crossed build -> promotion -> live runtime realization
- `#1164` is closed only after tenant-host runtime proof exists
- nonprod MFE-config parity remains represented as closed and guarded
- current dev and prod public-host availability blockers are either resolved or explicitly handed off as separate runtime lanes
- active trackers still match the actual repo, infra, and runtime state
