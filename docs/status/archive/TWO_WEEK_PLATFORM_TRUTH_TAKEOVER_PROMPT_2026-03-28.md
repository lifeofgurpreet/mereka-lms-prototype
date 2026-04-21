# Two-Week Platform Truth Takeover Prompt

You are taking over the active `mereka-lms` platform-truth lane.

Start by reading:

1. `docs/status/active/TWO_WEEK_PLATFORM_TRUTH_TRACKER_2026-03-28.md`
2. `docs/status/active/README.md`
3. `scripts/qa/verify-build-workflow-contract.sh`
4. `scripts/qa/test-verify-build-workflow-contract.sh`
5. `scripts/qa/verify-mfe-config-contract.sh`
6. `tests/e2e/tests/tenant-palette-bridge.spec.ts`

Read the relevant PRs/issues directly:

7. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1169`
8. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1166`
9. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/1164`
10. `https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2168`
11. `https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2167`
12. `https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2165`

## Mission

Keep the remaining platform work truthful across all three planes:

- app repo truth
- infra/promotion truth
- live runtime truth

The objective is not to keep opening new lanes. The objective is to close the current control point in the right order and leave evidence that survives handoff.

## Clean worktrees

Do not use the dirty root worktree.

Use only:

- `/tmp/mereka-tenant-palette-bridge` for `#1166` follow-through and tenant-host runtime proof
- `/tmp/mereka-two-week-tracker` for tracker refreshes

## Current control point

The active work is now:

1. keep `#1164` open until tenant runtime branding data becomes tenant-specific and the browser proof passes on the runtime plane that actually serves the public tenant hosts
2. identify and verify the runtime plane that actually serves those public tenant hosts
3. keep nonprod MFE-config parity represented as closed
4. keep the prod `502` behavior classified as availability/outage work, not as a reopened MFE-config contract bug

## Immediate first tasks

### First lane: close `#1164` only with tenant-host proof on the correct plane

Work in `/tmp/mereka-tenant-palette-bridge` unless the evidence forces an infra/runtime handoff.

Run:

1. prove which runtime plane actually serves `biji-biji.academyv2.mereka.dev`, `skillourfuture.academyv2.mereka.dev`, and their `apps.*` hosts
2. probe tenant LMS-host and apps-host config payloads directly on that plane
3. run the targeted Playwright proof against that same plane
4. treat default/null tenant branding data as the current blocker until the proof passes
5. do not let merged GKE source/promotion work become a false closure claim for this issue

### Second lane: runtime-plane ownership for public tenant hosts

Current verified truth:

- public tenant hosts resolve to RKE2/nonprod worker IPs, not to the GKE ingress address
- GKE `mereka-lms-dev` has no ingress rules or live endpoints for the non-default tenant hosts
- desired GKE source now includes those tenant hosts, but the live GKE app has not realized that ingress/Caddy state yet
- a manual sync is not a truthful closure shortcut while `lms` and `cms` remain replica-zero and their HPAs are `ScalingDisabled`
- therefore the public proof surface for `#1164` is not currently the same thing as the GKE namespace/build chain being monitored

Do not move forward until that ownership boundary is explicit.

### Third lane: tenant-host proof commands

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

### Fourth lane: prod anomaly

Treat prod as a separate availability lane.

The current verified boundary is broad public-host failure:

- `https://academyv2.mereka.io/` → `502`
- `https://academyv2.mereka.io/api/mfe_config/v1` → `502`
- `https://apps.academyv2.mereka.io/` → `502`
- `https://apps.academyv2.mereka.io/api/mfe_config/v1?mfe=authn` → `502`
- `https://studio.academyv2.mereka.io/` → `502`
- `https://preview.academyv2.mereka.io/` → `502`

Do not reopen the old nonprod MFE-config parity bug because of this.

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not close `#1164` because `#1166`, `#1172`, `#2168`, or `#2171` are merged.
- Do not rediscover already-closed queue debt unless fresh evidence proves regression.
- Do not reopen `#1169`; it is merged.
- Do not claim the GKE `mereka-lms-dev` app is the public tenant-host runtime plane unless the routing proof says so.
- Do not treat manual Argo sync as a runtime proof substitute while `lms` and `cms` remain intentionally zero-scaled.
- Do not describe the prod outage as an `/api/mfe_config/v1` bug unless the broad `502` surface disappears and a narrower boundary remains.
- Do not widen `#1169` into general CI cleanup.
- Do not widen merged `#1166` into a new source-implementation lane unless runtime proof shows the merge was insufficient.
- Do not leave the tracker ahead of reality.

## Required proof discipline

Every report must name its plane:

- `repo_truth`
- `pr_truth`
- `infra_truth`
- `runtime_truth`

Every handoff note must include:

1. exact current head or merged commit
2. exact commands run
3. exact remaining blocker
4. exact done criteria still missing

## Minimum acceptable success for this handoff

- `#1169` remains closed
- merged `#1166` has crossed into a visible build/promotion/runtime path and the current runtime blocker is explicit
- `#1164` remains open until tenant-host runtime proof exists
- nonprod MFE-config parity remains represented as closed
- the prod outage remains correctly classified as availability work
- the active tracker still matches the actual system state
