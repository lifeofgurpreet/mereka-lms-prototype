# Promotion Trust Ledger

_Owner: Agent 2 | Last verified: 2026-04-12T22:10:52Z | Status: active_

## Current Canonical Prod Chain

| Step | Canonical source | Current status | Proof artifact | Blocker | Owner | Next move |
|---|---|---|---|---|---|---|
| 1. Tutor image build fires | `mereka-lms/.github/workflows/build-tutor-images.yml` | proved | [`24292565290`](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24292565290) `success` | none | app repo | keep |
| 2. Open edX + MFE images build and scan | same workflow | proved | run `24292565290` jobs `Build OpenEdX Image`, `Build MFE Image`, `Post-push OpenEdX Scan`, `Post-push MFE Scan`, `SLSA Provenance & Attestation` all `success` | none | app repo | keep |
| 3. Release bundle + release object emit | same workflow, `Generate Release Bundle` | proved | bundle `rb-d6e9f14f-20260411T224043Z`, release object `ro-rb-d6e9f14f-20260411T224043Z` | authority still repo-local, not PCP-owned | app repo | migrate authority later |
| 4. Production release binding lands in app repo | `scripts/infra/release-openedx-gitops.sh` / governed release-binding path | proved | merged [#1588](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1588) → `e57b9d766dcf6fa0338c201eb16ddf65a9336ddc` | none | app repo | keep |
| 5. Prod overlay mutation lands in infra repo | `bbi-infrastructure` prod promotion path | proved | merged [#2768](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2768) → `aebcf5a2eff13d807f0c65827deaa2f81223f890` | none | infra repo | keep |
| 6. Post-realization one-shot job drift cleanup lands | infra cleanup path | proved | merged [#2770](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2770) → `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9` | none | infra repo | keep |
| 7. Argo realizes desired state | ArgoCD prod app `mereka-lms-prod` | proved | revision `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9`, `sync=Synced`, `phase=Succeeded` | top-level health rollup stale | infra/runtime | treat as controller debt |
| 8. Live digests match release object | explicit cluster read | proved | Open edX `sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f`; MFE `sha256:5e68fd69af068e7c36f0945f12cfcbe970dfcbd18a92ff5ea2c61d871fcdef08` | none | runtime | keep |
| 9. Runtime/browser proof consumes the realized release | `scripts/qa/verify-post-deploy-smoke.sh` from clean app `origin/main` | proved | `8b22aa7a94ef4f01ab490ec42ea147b5f1b4aa9d` run → `PASS=17 FAIL=0 WARN=6 SKIP=0` | warnings only from unscoped `kubectl` subchecks | app repo + runtime | tighten kube-context handling later |
| 10. Controller rollup closes | Argo top-level health | unproved | app still reports `health=Degraded` after hard refresh even though no unhealthy children remain | stale controller rollup | infra/controller | classify separately from release proof |

## Exact Current Prod Truth

- Build origin run: [`24292565290`](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24292565290)
- Build origin head: `d6e9f14f623d26256ed55c0ef174a3fea19eada5`
- Release bundle: `rb-d6e9f14f-20260411T224043Z`
- Release object: `ro-rb-d6e9f14f-20260411T224043Z`
- App binding merge: `e57b9d766dcf6fa0338c201eb16ddf65a9336ddc`
- Infra prod-promotion merge: `aebcf5a2eff13d807f0c65827deaa2f81223f890`
- Infra cleanup merge: `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9`
- Deployed Argo revision: `e91cba9b8a821c11c29481bb05b4d6e92d5a2ef9`
- Live Open edX digest: `sha256:b08fbb6223faceb4ccc49e89869dcfe3b9752aca4226a9dc153c74f8760b311f`
- Live MFE digest: `sha256:5e68fd69af068e7c36f0945f12cfcbe970dfcbd18a92ff5ea2c61d871fcdef08`

## Trust Boundary Notes

- The release lane is now proved through **build -> bundle -> release object -> app binding -> infra promotion -> Argo realization -> live digests -> runtime smoke** for the same production release line.
- `Manual GitOps Bridge` remained skipped in the build workflow; the production promotion still required the governed follow-on promotion path.
- The release lane should therefore be called **realized and runtime-validated**, not "fully automated end-to-end".
- Top-level Argo app health is the only remaining red bit, and it is not currently supported by child-resource evidence.

## Remaining Work After Release Closure

1. Record controller-rollup debt separately from release proof so later agents do not reopen the production lane by mistake.
2. Eliminate remaining manual joins in the promotion chain.
3. Move release-object and dispatch contract authority into PCP-owned surfaces instead of repo-local projections.
4. Align runner selection policy with the documented heavy-builder contract so release-critical builds do not require operator fallback dispatch.
