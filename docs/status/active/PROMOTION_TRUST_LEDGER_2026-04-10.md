# Promotion Trust Ledger

_Owner: Agent 2 | Last verified: 2026-04-10T14:08:00Z | Status: active_

## Current Automated Chain

| Step | Canonical source | Current status | Proof artifact | Blocker | Owner | Next move |
|---|---|---|---|---|---|---|
| 1. Push build fires | `mereka-lms/.github/workflows/build-tutor-images.yml` | proved | push runs `24226842382`, `24227735786` | none | app repo | keep |
| 2. OpenEdX image builds | same workflow, `Build OpenEdX Image` | proved | both push runs completed the OpenEdX build job | none | app repo | keep |
| 3. MFE image builds | same workflow, `Build MFE Image` | proved for push, optional/skipped for partial manual runs | both push runs completed MFE build; manual run `24229142921` skipped MFE and therefore skipped bundle generation | workflow success does not imply promotion candidate | app repo | keep push proof separate from manual proof |
| 4. Release bundle + release object emit | same workflow, `Generate Release Bundle` job | proved | run `24226842382` job `70735675252`; run `24227735786` job `70741458312` | contract authority still split | app repo | bind to PCP authority |
| 5. Truth ledger emits | `scripts/release/generate_truth_ledger.py` inside bundle job | proved | same bundle jobs completed `Generate truth ledger` step | runtime plane still empty in CI-produced ledger | app repo | consume only as build/release-plane proof until runtime is attached |
| 6. Dispatch to infra fires | `Dispatch dev promotion to infra repo` step | proved | same bundle jobs completed dispatch step | no PCP dispatch contract | app repo | add PCP-backed contract validation |
| 7. Infra receiver accepts and validates | `bbi-infrastructure/.github/workflows/promote-dev-image.yml` | proved | repository_dispatch runs `24218312468`, `24228818979`, `24230714536` | none | infra repo | keep |
| 8. Dev overlay mutation PR opens | same infra workflow | proved | infra PR [#2645](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2645) merged; [#2640](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2640) closed as superseded | none | infra repo | keep |
| 9. Argo realizes promoted digest | ArgoCD + overlay merge | proved | `mereka-lms-dev` application is `Synced` + `Healthy`; live `lms/cms` images match `sha256:0ce0538...`; live `mfe` image matches `sha256:fd8e06c...`; desired profile still carries `496b8a3...` digests from `#2645` | runtime-consumable proof still absent | infra/runtime | hand realized release ID to Agent 1 |
| 10. Release ID binds to runtime proof | runtime verifier lane | unproved | build bundle `rb-496b8a3b-20260410T065709Z`, release object `ro-rb-496b8a3b-20260410T065709Z`, infra dev promotion record, and live digests now align; no runtime/user-path proof yet | waits on Agent 1 runtime proof | Agent 1 + Agent 2 | attach runtime evidence to the same release ID |

## Dispatch Truth

- Automatic reception is real, not hypothetical.
- The latest successful repository-dispatch dev promotion is infra run `24230714536` on `2026-04-10T06:57:20Z`.
- That run validated the incoming release object, wrote the sidecar, updated the dev overlay, created the PR, generated dev promotion evidence, and uploaded the artifact.
- The promoted dev overlay PR `#2645` is now merged, and the follow-on verifier repair PR `#2675` is also merged on infra `main`; current infra `origin/main` is `8b325d5bf5e7fd465f7656b2b4ec5c3206565f54`.
- `Post-Merge Release Proof` run `24240983372` succeeded, but that artifact is static contract proof only; it does not by itself prove live realization.
- Live realization is separately proved: Argo reports `mereka-lms-dev` as `Synced` + `Healthy`, and live deployment images match the exact `openedx` / `mfe` digests carried by app run `24227735786`, infra run `24230714536`, and merged PR `#2645`.

## Remaining WS4 Work

1. Runtime release binding: consume release `ro-rb-496b8a3b-20260410T065709Z` in Agent 1 runtime/user-path proof.
2. Authority cleanup: make PCP, not paired workflow code, the source of the sender/receiver contract.
3. Promotion semantics cleanup: merge app PR `#1539` so a red overall build cannot mutate GitOps.
4. Writer cleanup: retire the ad hoc `dev_promotion_record` once dev emits canonical PCP promotion evidence.
