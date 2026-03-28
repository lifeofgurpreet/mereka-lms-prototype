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
  - `#1169` is merged in repo truth and its main build completed successfully on `4a05e894ad0d62423fd6b782e434e9b1d68e168f`
  - `#2168` is merged in infra truth, so the dev-promotion PR creation step is no longer open debt
  - the blocker moved to live runtime availability after promotion:
    - `https://academyv2.mereka.dev/` → `502`
    - `https://biji-biji.academyv2.mereka.dev/` → `502`
    - `https://skillourfuture.academyv2.mereka.dev/` → `502`
    - `https://apps.academyv2.mereka.dev/` → `302 Location: https://academyv2.mereka.dev`
    - `https://apps.biji-biji.academyv2.mereka.dev/` → `302 Location: https://academyv2.mereka.dev`
    - `https://apps.skillourfuture.academyv2.mereka.dev/` → `302 Location: https://academyv2.mereka.dev`
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

The program is no longer queue-bound. The active control point is narrower and more operational:

1. treat post-promotion dev public-host `502` behavior as the immediate runtime blocker
2. rerun tenant-host proof only after dev availability returns and keep `#1164` open until that proof exists
3. keep nonprod MFE-config parity represented truthfully as closed
4. keep prod public-host `502` behavior classified separately from the dev tenant-palette lane
5. keep the tracker downstream of live runtime truth instead of repo-only milestones

## Two-week execution board

### T-01 — Restore or classify dev runtime availability after merged promotion

Priority: `P0`
Owner surfaces: infra/runtime with `mereka-lms` follow-through

Current truth:

- `#1166` is merged in app repo truth.
- `#1169` is merged and its build completed successfully on `4a05e894ad0d62423fd6b782e434e9b1d68e168f`.
- `#2168` is merged in infra truth, so dev promotion creation is complete.
- live dev public hosts are currently failing broadly:
  - `academyv2.mereka.dev` → `502`
  - `biji-biji.academyv2.mereka.dev` → `502`
  - `skillourfuture.academyv2.mereka.dev` → `502`

Done when:

- the dev public-host failure boundary is explicit and stable
- either dev availability is restored or the outage is handed to the correct runtime owner with exact evidence
- the tenant-palette lane is no longer blocked by generic host unavailability

Verification commands:

```bash
for u in \
  https://academyv2.mereka.dev \
  https://biji-biji.academyv2.mereka.dev \
  https://skillourfuture.academyv2.mereka.dev
do
  curl -I -sS "$u" | sed -n '1,8p'
done

gh pr view 2168 --repo Biji-Biji-Initiative/bbi-infrastructure --json state,mergedAt,mergeCommit,url
gh issue view 1164 --repo Biji-Biji-Initiative/mereka-lms --json state,url
```

Notes:

- Do not reopen source work just because runtime is currently down.
- Promotion completion is not the same as runtime closure.

### T-02 — Close `#1164` only with tenant-host runtime proof

Priority: `P0`
Owner surfaces: `mereka-lms` -> `bbi-infrastructure` -> live runtime

Current truth:

- `#1166` is merged in repo truth.
- `#2168` is merged in infra truth.
- `#1164` remains open because the runtime proof on non-default tenant hosts is still blocked by live dev host availability and has not yet passed.

Done when:

- live dev availability is back
- the tenant-host browser/API proof passes on at least one non-default tenant host
- `#1164` closes only after that runtime evidence exists

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

- This lane is no longer blocked by source merge or promotion-PR creation.
- Do not close it from repo truth alone.

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
