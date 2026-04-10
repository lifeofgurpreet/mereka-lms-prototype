# Agent 2 Lane Tracker

_Owner: Agent 2 | Last verified: 2026-04-10T14:08:00Z | Status: active_

## Fresh Re-anchor

| Repo | Remote truth | Local checkout state | Notes |
|---|---|---|---|
| `mereka-lms` | `origin/main` = `4d0df1a32e150d1acfc21706e1e3734f9456f4fa` | clean Agent 2 worktree at same SHA with pending promotion-lane fixes | source truth for this lane |
| `bbi-infrastructure` | `origin/main` = `8b325d5bf5e7fd465f7656b2b4ec5c3206565f54` | current source truth after verifier realignment `#2675` and control-plane auth follow-up `#2677` | do not use older dirty infra checkout as authority |
| `platform-control-plane` | `origin/main` = `194e6001c924902e8bf3dafefdc37fc842c56653` | local `main` at same SHA, clean | PCP truth is ahead of the older ref previously hardcoded in app generators |

## Current Promotion-Lane Conclusion

- Automatic `repository_dispatch` reception is already proved by successful infra runs `24218312468`, `24228818979`, and `24230714536`.
- Organic push-build dispatch is also already proved by app push runs `24226842382` and `24227735786`; both runs generated release bundles and dispatched to infra.
- Automatic dev promotion and Argo realization are now proved for release `ro-rb-496b8a3b-20260410T065709Z`.
- What remains unproved is runtime-consumable release-ID proof, not dispatch or GitOps realization.
- The highest-risk ambiguity is now contract lineage: app and infra still speak a working legacy `release-object/v1` contract, but PCP is not yet the active enforcement authority for that contract.

## Relevant Open PRs In This Lane

| Repo | PR | State | Why it matters now |
|---|---|---|---|
| `mereka-lms` | [#1529](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1529) | open | GitOps writer app credential migration on app side; no live cutover yet |
| `mereka-lms` | [#1461](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1461) | open | historical WS4 test PR; no longer the only proof source |
| `mereka-lms` | [#1441](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1441) | open | CI/verifier hardening work, but still failing static validation |
| `bbi-infrastructure` | [#2636](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2636) | open | shared GitOps writer app migration; still blocked by install/secret cutover |
| `bbi-infrastructure` | [#2640](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2640) | closed | superseded dev promotion PR from app push run `24226842382` |
| `bbi-infrastructure` | [#2645](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2645) | merged | dev promotion PR from app push run `24227735786`; merge commit `a06fdf33a3ecc619c0558ad31d2c831796ad54f1` |
| `bbi-infrastructure` | [#2675](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2675) | merged | realigned stale verifier and contract surfaces so current infra `main` can validate the realized promotion path |

## WS4 Status

| Step | Status | Evidence |
|---|---|---|
| Dispatch auth | proved | app build job step `Generate GitHub App token...` + successful `repository_dispatch` infra runs |
| Sender/receiver payload works | proved, not PCP-governed | push runs `24226842382`, `24227735786`; infra run `24230714536` validated release object and created PR |
| Infra reception | proved | `promote-dev-image.yml` repository_dispatch runs succeed |
| Dev promotion PR creation | proved | infra PR [#2645](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2645) merged; [#2640](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2640) closed as superseded |
| Argo realization | proved | `mereka-lms-dev` Argo application is `Synced` + `Healthy`; live `lms/cms` run `openedx:496b8a3...@sha256:0ce0538...` and live `mfe` runs `mfe:496b8a3...@sha256:fd8e06c...`, matching infra promotion PR [#2645](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2645) and app release object `ro-rb-496b8a3b-20260410T065709Z` |
| Runtime release-ID consumption | unproved | digest continuity is proved through GitOps realization, but Agent 1 runtime proof lane has not yet consumed this release ID in user-path/runtime evidence |
| Durable chain | unproved | manual bridge still exists; PCP contract authority not yet active |

## Current Blockers

| Severity | Blocker | Why it blocks closure |
|---|---|---|
| High | Runtime-consumable release-ID proof still missing | Agent 2 has proved build -> dispatch -> GitOps -> live digests, but Agent 1 runtime/user-path evidence has not yet attached to `ro-rb-496b8a3b-20260410T065709Z` |
| High | Overall failed app push builds can still promote until app PR [#1539](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1539) lands | runs `24226842382` and `24227735786` failed overall at `SLSA Provenance & Attestation -> Install cosign`, yet still emitted bundles and dispatched |
| High | Release-object authority still split | app YAML schema, app JSON schema, generator, and infra workflow checks are all separate writers |
| Medium | PCP contract ref governance is still implicit | core generators/proof scripts are fixed locally to `platform-control-plane@194e6001...`, but the repo still lacks a governed policy for which PCP ref promotion evidence should claim |
| Medium | GitOps writer app migration incomplete | [#1529](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1529) and [#2636](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2636) are not cut over |

## Next Moves

1. Merge app PR [#1539](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1539) so future red overall builds cannot dispatch automatic promotions.
2. Hand realized release `ro-rb-496b8a3b-20260410T065709Z` to Agent 1 for runtime consumption proof.
3. Decide whether `Post-Merge Cluster Validation` run `24240983325` is a runner-capacity issue or a stale workflow queue artifact; it is no longer needed to establish GitOps realization for this release.
4. Move dispatch payload and release-object authority to PCP or consume PCP contracts directly instead of hardcoding both sides.
5. Retire the manual `update-gitops` bridge after the automated path is realized and runtime-bound.
