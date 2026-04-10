# Promotion Trust Ledger

_Owner: Agent 2 | Last verified: 2026-04-10T15:17:00Z | Status: active_

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
| 8. Dev overlay mutation PR opens | same infra workflow | proved for the freshest valid release | infra PR [#2645](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2645) merged for `496b8a3...`; infra PR [#2702](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2702) merged for `4edae4e...`; infra PR [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708) merged for `e4764d58...` with release bundle `rb-e4764d58-20260410T142410Z` / release object `ro-rb-e4764d58-20260410T142410Z` | none at PR level | infra repo | keep milestone-only tracking |
| 9. Argo realizes promoted digest | ArgoCD + overlay merge | proved for the freshest valid release | current infra `origin/main` carries `e4764d58...` digests and Argo reports `mereka-lms-dev` `Synced` / `Healthy` on revision `ee4fb7253487b34f07e0989adb319a90119d99e5`; live `lms/cms/lms-worker/cms-worker/mfe` deployment specs all match `e4764d58...` digests | none for current dev target | infra/runtime | hand exact realized bundle to Agent 1 |
| 10. Release ID binds to runtime proof | runtime verifier lane | partially proved | build bundle `rb-e4764d58-20260410T142410Z`, release object `ro-rb-e4764d58-20260410T142410Z`, infra PR [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708), Argo revision `ee4fb725...`, and live digests now align; runtime/user-path proof still open | waits on Agent 1 runtime proof | Agent 1 + Agent 2 | attach runtime evidence to the same release ID |

## Dispatch Truth

- Automatic reception is real, not hypothetical.
- The latest successful repository-dispatch dev promotion is infra run `24230714536` on `2026-04-10T06:57:20Z`.
- That run validated the incoming release object, wrote the sidecar, updated the dev overlay, created the PR, generated dev promotion evidence, and uploaded the artifact.
- The promoted dev overlay PR `#2645` is now merged, and infra `origin/main` has advanced again to `ee4fb7253487b34f07e0989adb319a90119d99e5`.
- Fresh automated dev promotion `#2702` existed for `4edae4e...` and was fully realized, but it is no longer the canonical dev truth because the newer valid artifact `#2708` superseded it.
- Current canonical dev promotion truth:
  - app run `24244345117`
  - release bundle `rb-e4764d58-20260410T142410Z`
  - release object `ro-rb-e4764d58-20260410T142410Z`
  - infra PR [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708), merged at `2026-04-10T14:36:00Z`
  - Argo revision `ee4fb7253487b34f07e0989adb319a90119d99e5`
  - live `openedx` digest `sha256:2eed29dbd0cf5df5ddb55f4075d23cdeb4bb3c48704d20b540f7746379dd4ea4`
  - live `mfe` digest `sha256:9fff8d031b00feed62f1103baf21d2127c5f5721be064c6158aac018b3a15347`
- Source truth has moved: infra `origin/main` now carries LMS dev `openedx` / `mfe` digests for `e4764d58...` (`sha256:2eed29db...` / `sha256:9fff8d03...`).
- Argo truth has moved: `mereka-lms-dev` is `Synced` / `Healthy` on revision `ee4fb725...`.
- Live deployment-spec truth has moved: `lms`, `cms`, `lms-worker`, `cms-worker`, and `mfe` all now show `e4764d58...` digests.
- The promotion lane therefore has one explicit supersession rule recorded in practice:
  - if a newer valid LMS promotion PR exists and is green, it supersedes the older realized intermediate release as the canonical current dev truth
  - `#2708` superseded `#2702`
- `Post-Merge Release Proof` run `24240983372` succeeded, but that artifact is static contract proof only; it does not by itself prove live realization.
- Live realization is separately proved: live deployment images still match the exact `openedx` / `mfe` digests carried by app run `24227735786`, infra run `24230714536`, and merged PR `#2645`.
- The earlier fresh app-side candidate from `#1546` is now concrete: push run `24243667953` did fire `Build Tutor Images`, but `Post-push MFE Scan` failed before producing any scan artifacts because the job lost `github.com` resolution and `git` exited 128. That failure is environmental/bootstrap drift, not a vulnerability or contract verdict.
- Current app `origin/main` `e4764d5834b6e24c26069e7edb2a527d05ae3b1d` via `#1543` did supersede `#2702`: run `24244345117` completed green enough to emit the newer release bundle, dispatched infra promotion, and opened merged PR [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708).
- A proof-surface correctness bug was also found and is now source-fixed: [#2711](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2711) changed `scripts/qa/verify-mereka-lms-runtime-realization.sh` to read the synced Git revision from Argo instead of the local filesystem.

## Remaining WS4 Work

1. Runtime release binding: consume release `ro-rb-e4764d58-20260410T142410Z` in Agent 1 runtime/user-path proof.
2. Authority cleanup: make PCP, not paired workflow code, the source of the sender/receiver contract.
3. Writer cleanup: merged infra PR `#2692` now puts installation-ID-scoped app auth on infra `main`; retire the remaining duplicate writer auth semantics that still exist outside the reusable updater.
4. Local authority cleanup: app repo stale `config/release-object-schema.yaml` is retired; remaining release-object authority work is now explicitly the local JSON projection vs PCP contract split.
