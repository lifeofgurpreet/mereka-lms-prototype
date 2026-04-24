# Release Identity Chain Map

_Owner: Agent 2 | Last verified: 2026-04-12T22:10:52Z | Status: active_

## Current Chain

```text
build-tutor-images.yml
  -> Generate Release Bundle
     bundle_id = rb-<sha8>-<timestamp>
     release_id = ro-rb-<sha8>-<timestamp>
  -> app release-binding path
     writes production image refs into app repo truth
  -> infra prod promotion path
     writes realized image refs into GitOps overlay truth
  -> ArgoCD realization
     moves desired revision into prod cluster
  -> runtime proof lane
     proves public surfaces against the same release line
```

## Where Identity Is Born

| Identity | Writer | Current shape |
|---|---|---|
| `bundle_id` | `Generate Release Bundle` in `build-tutor-images.yml` | `rb-<sha8>-<timestamp>` |
| `release_id` | release-object generator in the same build lane | `ro-rb-<sha8>-<timestamp>` |

## Where Identity Is Carried

| Hop | Carrier | Current state |
|---|---|---|
| build artifact | release-bundle job output | proved |
| app repo production binding | merged app PR | proved |
| infra prod promotion | merged infra PR | proved |
| post-realization cleanup | merged infra cleanup PR | proved |
| Argo desired revision | `mereka-lms-prod` Application status | proved |
| live deployment images | prod `Deployment.spec.template.spec.containers[].image` | proved |
| runtime proof | current smoke verifier on clean app `origin/main` | proved |

## Current Realized Example: `ro-rb-d6e9f14f-20260411T224043Z`

| Link | Evidence |
|---|---|
| build run | [`24292565290`](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24292565290) emitted bundle `rb-d6e9f14f-20260411T224043Z` and release object `ro-rb-d6e9f14f-20260411T224043Z` |
| app binding | merged [#1588](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1588) wrote the same release line into app production binding truth (`e57b9d766dcf6fa0338c201eb16ddf65a9336ddc`) |
| prod promotion | merged [#2768](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2768) realized the same line into prod GitOps (`aebcf5a2eff13d807f0c65827deaa2f81223f890`) |
| post-realization cleanup | merged [#2770](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2770) removed one-shot job drift without changing the realized release digests (`e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9`) |
| deployed revision | Argo now reports `mereka-lms-prod` `sync=Synced`, `phase=Succeeded`, `revision=e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9` |
| live Open edX digest | `sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f` on `lms/cms/lms-worker/cms-worker` |
| live MFE digest | `sha256:5e68fd69af068e7c36f0945f12cfcbe970dfcbd18a92ff5ea2c61d871fcdef08` on `mfe` |
| runtime proof | `bash scripts/qa/verify-post-deploy-smoke.sh --env prod` from clean app `origin/main` `8b22aa7a94ef4f01ab490ec42ea147b5f1b4aa9d` returned `PASS=17 FAIL=0 WARN=6 SKIP=0` |
| residual gap | top-level Argo app health still reports `Degraded` even though child-resource diff and health are clean after hard refresh |

## Where Identity Still Downgrades

| Edge | Current problem |
|---|---|
| build result -> realized prod deployment | the build workflow still does not itself complete the full production promotion chain |
| release object -> PCP authority | release-object truth is still repo-local rather than PCP-owned |
| runtime smoke -> cluster-scoped readiness/image subchecks | the smoke script's `kubectl` checks still depend on ambient context, so warnings can appear even when explicit `rke2-prod` proof is clean |
| Argo desired state -> top-level app health | controller rollup can stay stale even when no child resources are unsynced or unhealthy |

## What Moves Next To PCP

1. Release-object contract authority.
2. Dispatch / promotion payload authority.
3. Promotion-record schema so release identity stays machine-readable across build, promotion, and runtime proof.
4. Governance for the exact PCP contract ref used by each emitted artifact.
