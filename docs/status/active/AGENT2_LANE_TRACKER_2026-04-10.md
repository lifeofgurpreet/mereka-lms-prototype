# Agent 2 Lane Tracker

_Owner: Agent 2 | Last verified: 2026-04-10T15:17:00Z | Status: active_

## Fresh Re-anchor

| Repo | Remote truth | Local checkout state | Notes |
|---|---|---|---|
| `mereka-lms` | `origin/main` = `e4764d5834b6e24c26069e7edb2a527d05ae3b1d` | current local worktree remains the Agent 2 authority checkout; latest app source now includes `#1541`, `#1543`, `#1546`, and `#1547` | freshest valid app build is push run `24244345117` |
| `bbi-infrastructure` | `origin/main` = `ee4fb7253487b34f07e0989adb319a90119d99e5` | dirty local checkout is **not** authority; read `origin/main` directly for lane truth | current infra `main` now includes merged `#2692`, merged `#2702`, merged `#2708`; source truth carries `e4764d58...` LMS digests |
| `platform-control-plane` | `origin/main` = `fb55cf862ae6050c31d79457372de81e7d4cd997` | local `main` at same SHA | PCP still ahead of active app/infra contract consumption |

## Current Promotion-Lane Conclusion

- Automatic `repository_dispatch` reception is already proved by successful infra runs `24218312468`, `24228818979`, and `24230714536`.
- Organic push-build dispatch is also already proved by app push runs `24226842382` and `24227735786`; both runs generated release bundles and dispatched to infra.
- Automatic dev promotion and Argo realization are now proved for two releases in sequence:
  - older realized line `ro-rb-496b8a3b-20260410T065709Z`
  - current canonical dev line `ro-rb-e4764d58-20260410T142410Z`
- Current source truth, deployed truth, and live truth for LMS now align on the newer `e4764d58...` release line across infra `origin/main`, Argo revision `ee4fb725...`, and live `lms/cms/lms-worker/cms-worker/mfe` deployment specs.
- The earlier `#1546` candidate is no longer ambiguous: push run `24243667953` did fire `Build Tutor Images`, but `Post-push MFE Scan` failed before producing any scan artifacts because the job lost `github.com` DNS resolution and `git` exited 128. That is an environment/bootstrap failure, not a release-quality failure in the image itself.
- Fresh promotion artifact [#2702](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2702) was real and source-merged, but it is no longer the canonical dev truth target; it was superseded by the newer valid artifact [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708).
- Current app head `#1543` did produce a newer valid promotion candidate. Push run `24244345117` completed both image builds, both post-push scans, provenance, and `Generate Release Bundle`, then dispatched dev promotion and opened [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708).
- Canonical realization target decision:
  - `#2702` = realized intermediate artifact for `4edae4e...`
  - `#2708` = freshest valid artifact and current dev truth
- `#2708` is now merged, infra `origin/main` carries `e4764d58...` LMS digests, Argo is `Synced` / `Healthy` on `ee4fb725...`, and live deployment specs match those same digests.
- What remains unproved is runtime-consumable release-ID proof in Agent 1’s lane, not promotion-lane realization.
- The infra runtime-verifier truthfulness fix is now merged in [#2711](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2711): proof reads the synced Git revision Argo reports instead of a dirty local checkout.
- The highest-risk ambiguity is now contract lineage: app and infra still speak a working legacy `release-object/v1` contract, but PCP is not yet the active enforcement authority for that contract.
- One local duplicate writer is now retired in source: stale app-side `config/release-object-schema.yaml` has been removed, and app verifiers/workflows now point at the real JSON schema projection instead.

## Relevant PRs In This Lane

| Repo | PR | State | Why it matters now |
|---|---|---|---|
| `mereka-lms` | [#1541](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1541) | merged | passed writer app installation IDs into gitops callers |
| `mereka-lms` | [#1543](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1543) | merged | synced Mereka MFE theme assets into the Tutor build context and triggered fresh push run `24244345117` |
| `mereka-lms` | [#1546](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1546) | merged | removed PAT fallback from gitops callers on app `main` |
| `mereka-lms` | [#1547](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1547) | merged | required app auth in gitops verifiers on app `main` |
| `mereka-lms` | [#1539](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1539) | merged | prevents future red overall builds from auto-promoting |
| `mereka-lms` | [#1529](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1529) | closed | superseded by `#1541/#1546/#1547` |
| `bbi-infrastructure` | [#2640](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2640) | closed | superseded dev promotion PR from app push run `24226842382` |
| `bbi-infrastructure` | [#2645](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2645) | merged | dev promotion PR from app push run `24227735786`; merge commit `a06fdf33a3ecc619c0558ad31d2c831796ad54f1` |
| `bbi-infrastructure` | [#2675](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2675) | merged | realigned stale verifier and contract surfaces so current infra `main` can validate the realized promotion path |
| `bbi-infrastructure` | [#2702](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2702) | merged | fresh LMS dev promotion PR for `4edae4e...`; merged at `2026-04-10T14:17:07Z` and fully realized, but later superseded by `#2708` |
| `bbi-infrastructure` | [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708) | merged | freshest valid LMS dev promotion PR for `e4764d58...`; merged at `2026-04-10T14:36:00Z` after exact artifact review/approval |
| `bbi-infrastructure` | [#2700](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2700) | merged | moved the general image updater to app auth on infra `main`, but did not absorb the reusable dev-tag installation-ID fix from `#2692` |
| `bbi-infrastructure` | [#2692](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2692) | merged | merged at `2026-04-10T13:31:56Z`; infra `main` now contains required installation-ID enforcement for `reusable-update-dev-tag.yml` |
| `bbi-infrastructure` | [#2636](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2636) | closed | superseded by newer writer-auth work on current `main` |

## WS4 Status

| Step | Status | Evidence |
|---|---|---|
| Dispatch auth | proved | app build job step `Generate GitHub App token...` + successful `repository_dispatch` infra runs |
| Sender/receiver payload works | proved, not PCP-governed | push runs `24226842382`, `24227735786`; infra run `24230714536` validated release object and created PR |
| Infra reception | proved | `promote-dev-image.yml` repository_dispatch runs succeed |
| Dev promotion PR creation | proved | infra PR [#2645](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2645) merged; [#2702](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2702) merged; [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708) merged as freshest valid artifact |
| Argo realization | proved | `mereka-lms-dev` Argo application is `Synced` + `Healthy` at `ee4fb7253487b34f07e0989adb319a90119d99e5` while live `lms/cms/lms-worker/cms-worker` run `openedx:e4764d58...@sha256:2eed29db...` and live `mfe` runs `mfe:e4764d58...@sha256:9fff8d03...` |
| Fresh post-gate promotion from current workflow-bearing app source | proved through live realization | app run `24244345117` emitted release bundle `rb-e4764d58-20260410T142410Z`, release object `ro-rb-e4764d58-20260410T142410Z`, dispatched infra PR [#2708](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2708), and the merged overlay now realizes live in dev |
| Newest current-head promotion candidate | proved and chosen | app head `e4764d58...` from `#1543` produced the freshest valid LMS artifact; `#2708` explicitly superseded `#2702` as canonical dev truth |
| Runtime release-ID consumption | unproved | digest continuity and live realization are proved for `ro-rb-e4764d58-20260410T142410Z`, but Agent 1 runtime proof lane has not yet consumed this release ID in user-path/runtime evidence |
| Durable chain | unproved | manual bridge still exists; PCP contract authority not yet active |

## Current Blockers

| Severity | Blocker | Why it blocks closure |
|---|---|---|
| High | Runtime-consumable release-ID proof still missing | Agent 2 has now proved build -> dispatch -> GitOps -> Argo -> live digests for `ro-rb-e4764d58-20260410T142410Z`, but Agent 1 runtime/user-path evidence has not yet attached to that release |
| High | Release-object authority still split | app YAML schema, app JSON schema, generator, and infra workflow checks are all separate writers |
| Medium | Stale app-side release-object shadow authority is now removed, but PCP is still not active | the app repo now has one fewer false contract surface, but app and infra still validate a repo-local JSON projection instead of PCP-owned authority |
| Medium | PCP contract ref governance is still implicit | the live promotion lane is realized and the runtime verifier is now truthful, but PCP selection/consumption is still repo-local rather than governed |
| Medium | PCP authority migration still not active | merged `#2692` closed the reusable dev-tag installation-ID gap, but release-object and dispatch contract authority are still repo-local rather than PCP-governed |

## Next Moves

1. Hand the realized release bundle for `ro-rb-e4764d58-20260410T142410Z` to Agent 1 with exact digests and Argo revision.
2. Move dispatch/release-object authority into PCP now that the reusable writer-auth gap is closed on infra `main` and verifier truthfulness is merged.
