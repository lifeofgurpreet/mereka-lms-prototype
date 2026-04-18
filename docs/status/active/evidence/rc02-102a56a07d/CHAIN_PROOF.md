# RC-03 / RC-04 Single-Chain Image Proof — Artifact 102a56a07d

**Date:** 2026-04-18 (UTC 2026-04-18T01:15Z probe time)

## One Chain, Seven Layers

| # | Layer | Source | openedx | mfe |
|---|---|---|---|---|
| 1 | Git source (mereka-lms) | commit `102a56a07d` on `main` (merge PR #1797) | — | — |
| 2 | Build workflow | run [24590743862](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24590743862) success 2026-04-17T23:14:15Z | — | — |
| 3 | Build artifact (release-bundle.json) | `.images.openedx.digest`, `.images.mfe.digest` | `sha256:d17ae77f…54578` | `sha256:377923c0…b35e1` |
| 4 | Promote workflow input | promote run [24591542962](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/actions/runs/24591542962) success 2026-04-17T23:45:23Z — consumed release-object for `102a56a07d` | `sha256:d17ae77f…54578` | `sha256:377923c0…b35e1` |
| 5 | bbi-infra merge → overlay | commit `506b9337` (PR #3169) writes `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` | `sha256:d17ae77f…54578` | `sha256:377923c0…b35e1` |
| 6 | Argo desired | `Application mereka-lms-dev` → `.spec.source.path = apps/mereka-lms/overlays/profiles/dev` → synced revision `41d3d414` (current `bbi-infrastructure:main` HEAD, matches 506b9337 merged into 41d3d414) | `sha256:d17ae77f…54578` | `sha256:377923c0…b35e1` |
| 7 | Deployment spec | `kubectl -n mereka-lms-dev get deploy -o jsonpath` for lms, cms, lms-worker, cms-worker, mfe | `sha256:d17ae77f…54578` | `sha256:377923c0…b35e1` |
| 8 | Live pod imageID | `kubectl -n mereka-lms-dev get pods -o json` for running containers | `sha256:d17ae77f…54578` | `sha256:377923c0…b35e1` |

## Agreement

All eight layers agree on both digests. No drift. No substitution. No stale intermediate.

## Secondary Image Sets (Not On This Chain)

These have their own lifecycles and are out of scope for this artifact:
- `enterprise-access:main-20260311` (fixed tag, manually promoted)
- `enterprise-admin-portal:ab3112cb950a…`
- `enterprise-learner-portal:ea8651ec8cfd…`
- `credentials:21.0.0`, `discovery:21.0.1`, `notes:21.0.0`, `xqueue:21.0.0` (frozen upstream)

## Verdict

**RC-03 (promotion contract): CLOSED.** Overlay pin matches release-object digests; promotion workflow consumed the release-object successfully.
**RC-04 (promotion realization): CLOSED.** Argo sync operation `Succeeded`; deployment specs carry promoted digests; live pods carry matching `imageID`s.

## Caveat (Non-Blocking)

Argo app status shows `Synced:Progressing` at probe time due to `cms-worker` (1/2 Ready) and `lms-worker` (2/3 Ready) replicas whose readinessProbe (introduced by `bbi-infrastructure#3166` closing bead `q5yz`) cannot complete `celery inspect ping` within the 20s timeout. This is a probe defect (RC-05 runtime scope), **not** an image-chain issue. Traffic is served: at least one replica per deployment is Ready and serving. Filed separately.
