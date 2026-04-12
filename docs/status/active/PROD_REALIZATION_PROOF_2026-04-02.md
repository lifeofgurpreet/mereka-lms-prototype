# Prod Domain Realization — Final Proof Bundle

_Captured: 2026-04-12T22:10:52Z | Cluster: `rke2-prod` | Verdict: **`runtime_validated`**_

## Final Verdict

**`runtime_validated`** for release object `ro-rb-d6e9f14f-20260411T224043Z`.

This lane is **not fully `operationally_closed`** only because Argo still reports
top-level app health `Degraded` even though:

- `sync = Synced`
- `operationState.phase = Succeeded`
- `unsynced resources = none`
- `non-healthy child resources = none`
- hard refresh did not move `health.lastTransitionTime` from `2026-04-09T15:48:33Z`

That residual red is currently classified as **stale controller rollup debt**,
not release drift.

## Repo Truth

| Plane | Current truth |
|---|---|
| app repo | `origin/main = 8b22aa7a94ef4f01ab490ec42ea147b5f1b4aa9d` |
| app binding merge | [#1588](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1588) → `e57b9d766dcf6fa0338c201eb16ddf65a9336ddc` |
| smoke-verifier fix | [#1589](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1589) → `8b22aa7a94ef4f01ab490ec42ea147b5f1b4aa9d` |
| infra repo | `origin/main = e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9` |
| prod promotion merge | [#2768](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2768) → `aebcf5a2eff13d807f0c65827deaa2f81223f890` |
| prod cleanup merge | [#2770](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2770) → `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9` |

## Release Truth

| Field | Value |
|---|---|
| build run | [`24292565290`](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24292565290) |
| build head | `d6e9f14f623d26256ed55c0ef174a3fea19eada5` |
| release bundle | `rb-d6e9f14f-20260411T224043Z` |
| release object | `ro-rb-d6e9f14f-20260411T224043Z` |

## Deployed Truth

| Field | Value |
|---|---|
| Argo app | `mereka-lms-prod` |
| revision | `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9` |
| sync | `Synced` |
| operationState.phase | `Succeeded` |
| top-level health | `Degraded` |
| unsynced resources | `none` |
| non-healthy child resources | `none` |

## Live Image Proof

| Workload | Image |
|---|---|
| `lms` | `ghcr.io/biji-biji-initiative/mereka-lms/openedx:d6e9f14f623d26256ed55c0ef174a3fea19eada5@sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f` |
| `cms` | `ghcr.io/biji-biji-initiative/mereka-lms/openedx:d6e9f14f623d26256ed55c0ef174a3fea19eada5@sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f` |
| `lms-worker` | `ghcr.io/biji-biji-initiative/mereka-lms/openedx:d6e9f14f623d26256ed55c0ef174a3fea19eada5@sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f` |
| `cms-worker` | `ghcr.io/biji-biji-initiative/mereka-lms/openedx:d6e9f14f623d26256ed55c0ef174a3fea19eada5@sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f` |
| `mfe` | `ghcr.io/biji-biji-initiative/mereka-lms/mfe:d6e9f14f623d26256ed55c0ef174a3fea19eada5@sha256:5e68fd69af068e7c36f0945f12cfcbe970dfcbd18a92ff5ea2c61d871fcdef08` |

## Runtime Proof

Fresh smoke proof from clean app `origin/main` (`8b22aa7a94ef4f01ab490ec42ea147b5f1b4aa9d`):

```bash
bash scripts/qa/verify-post-deploy-smoke.sh --env prod
```

Result:

- `PASS=17`
- `FAIL=0`
- `WARN=6`
- `SKIP=0`

Key public-surface passes:

- LMS homepage `200`
- LMS heartbeat `200`
- Studio homepage `302`
- Studio heartbeat `200`
- Authn login `200`
- Authn register `200`
- Learner dashboard `200`
- Account settings `200`
- Profile `200`
- Course About `200`
- Discussions `200`
- `academy.biji-biji.com` LMS `200`
- `skillourfuture.academy.mereka.io` LMS `200`

`WARN=6` comes only from the script's ambient-context `kubectl` readiness/image
subchecks. Those warnings do not contradict the explicit `rke2-prod`
deployment-image reads above.

## Why Argo Still Looks Red

The remaining top-level `Degraded` bit does **not** currently correspond to a
real child-resource problem:

- no `status.conditions`
- no unsynced resources
- no child resources with `health.status != Healthy`
- hard refresh (`argocd.argoproj.io/refresh=hard`) re-reconciled the app but did
  not move the health transition timestamp

This should be handled as controller-state debt unless a future read shows a
real child-resource regression.

## Done When

This release lane should be treated as complete unless one of the following
becomes false:

1. live prod images drift from the digests above
2. runtime smoke stops passing on current `main`
3. Argo child resources become unsynced or non-healthy

If only the top-level app health bit remains `Degraded` with clean child
evidence, do **not** reopen the release lane as a runtime regression.
