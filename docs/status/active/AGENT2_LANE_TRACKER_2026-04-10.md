# Agent 2 Lane Tracker

_Owner: Agent 2 | Last verified: 2026-04-12T22:10:52Z | Status: active_

## Fresh Re-anchor

| Repo | Remote truth | Notes |
|---|---|---|
| `mereka-lms` | `origin/main` = `8b22aa7a94ef4f01ab490ec42ea147b5f1b4aa9d` | includes merged [#1588](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1588) release binding and merged [#1589](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1589) smoke-verifier truth fix |
| `bbi-infrastructure` | `origin/main` = `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9` | includes merged [#2768](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2768) prod promotion and merged [#2770](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2770) one-shot job cleanup |
| `platform-control-plane` | not exercised in this closure tranche | PCP remains an authority-migration follow-up, not the blocking lane for this realized prod release |

## Current Verified State

### Repo truth

- Build run [`24292565290`](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24292565290) on head `d6e9f14f623d26256ed55c0ef174a3fea19eada5` completed successfully through both image builds, both post-push scans, provenance, and `Generate Release Bundle`.
- Exact release bundle: `rb-d6e9f14f-20260411T224043Z`
- Exact release object: `ro-rb-d6e9f14f-20260411T224043Z`
- App release-binding PR [#1588](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1588) merged at `2026-04-12T04:10:24Z` with merge commit `e57b9d766dcf6fa0338c201eb16ddf65a9336ddc`.
- Smoke-verifier truthfulness fix [#1589](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1589) merged at `2026-04-12T21:54:58Z` with merge commit `8b22aa7a94ef4f01ab490ec42ea147b5f1b4aa9d`.
- Infra prod promotion PR [#2768](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2768) merged at `2026-04-12T03:57:23Z` with merge commit `aebcf5a2eff13d807f0c65827deaa2f81223f890`.
- Infra cleanup PR [#2770](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2770) merged at `2026-04-12T21:55:19Z` with merge commit `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9`.

### Deployed truth

- Argo app `mereka-lms-prod` is on revision `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9`.
- Current Argo state:
  - `sync = Synced`
  - `operationState.phase = Succeeded`
  - `unsynced resources = none`
  - `non-healthy child resources = none`
- A bounded hard refresh (`argocd.argoproj.io/refresh=hard`) did not change top-level app health; it remains `Degraded`.

### Runtime truth

- Live prod deployment images match the realized release object exactly:
  - `lms`, `cms`, `lms-worker`, `cms-worker` → `ghcr.io/biji-biji-initiative/mereka-lms/openedx:d6e9f14f623d26256ed55c0ef174a3fea19eada5@sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f`
  - `mfe` → `ghcr.io/biji-biji-initiative/mereka-lms/mfe:d6e9f14f623d26256ed55c0ef174a3fea19eada5@sha256:5e68fd69af068e7c36f0945f12cfcbe970dfcbd18a92ff5ea2c61d871fcdef08`
- Fresh runtime verifier run from clean app `origin/main` (`8b22aa7a94ef4f01ab490ec42ea147b5f1b4aa9d`) passed:
  - command: `bash scripts/qa/verify-post-deploy-smoke.sh --env prod`
  - result: `PASS=17 FAIL=0 WARN=6 SKIP=0`
- The `WARN=6` items are only the script's unscoped `kubectl` readiness/image subchecks. They do not contradict the explicit `rke2-prod` deployment-image proof above.

## Exact Release Chain

| Link | Evidence |
|---|---|
| Build run | [`24292565290`](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24292565290) `success` |
| Bundle identity | `rb-d6e9f14f-20260411T224043Z` |
| Release identity | `ro-rb-d6e9f14f-20260411T224043Z` |
| App release binding | [#1588](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1588) → `e57b9d766dcf6fa0338c201eb16ddf65a9336ddc` |
| Infra prod promotion | [#2768](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2768) → `aebcf5a2eff13d807f0c65827deaa2f81223f890` |
| Post-realization cleanup | [#2770](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2770) → `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9` |
| Argo desired revision | `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9` |
| Live Open edX digest | `sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f` |
| Live MFE digest | `sha256:5e68fd69af068e7c36f0945f12cfcbe970dfcbd18a92ff5ea2c61d871fcdef08` |

## Lane Verdict

- **`runtime_validated`** for release `ro-rb-d6e9f14f-20260411T224043Z`.
- **Not fully `operationally_closed`** only because Argo's top-level app health rollup remains `Degraded`.
- This remaining red is currently classified as **stale controller rollup debt**, not runtime drift, because:
  - `sync = Synced`
  - `phase = Succeeded`
  - `unsynced resources = none`
  - `non-healthy child resources = none`
  - hard refresh left `health.lastTransitionTime = 2026-04-09T15:48:33Z`

## Residuals

| Severity | Residual | Why it is not the release blocker now |
|---|---|---|
| Medium | Argo top-level `Degraded` rollup | no unhealthy child resources remain after hard refresh; live release and smoke proof are clean |
| Medium | Runner-policy drift between workflow preference and heavy-builder contract | the release lane required sanctioned fallback dispatch, but the realized prod artifact is already built and live |
| Medium | Promotion/authority manual joins still exist outside PCP | the release object was realized correctly, but the control-plane consolidation tranche is still ahead |

## Next Moves

1. Keep this lane closed on real proof unless a child resource flips non-healthy or live digests drift.
2. Track the top-level Argo `Degraded` bit as controller-state debt, not as a release rollback signal.
3. Move to the next tranche:
   - authority matrix freeze
   - duplicate-writer retirement
   - PCP-owned dispatch/release contract migration
