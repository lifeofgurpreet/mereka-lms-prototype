# Dev Runtime Convergence Evidence

> Human-readable convergence bundle for current dev runtime truth promotion.
> Lane I status date: 2026-03-12

## Executive Classification

**Current dev runtime state: `PROVISIONAL` with `CONTRADICTED` learner-secondary-path claims.**

What can be trusted now:

- repo-side stabilization contracts are durable
- build truth is durably pinned at the contract layer
- later local Lane A evidence narrows the learner-secondary-path blocker away from cookie/JWT propagation and toward MFE handling of JSON 404s

What cannot yet be claimed:

- durable learner portal closure
- convergence readiness
- durable live image/GitOps/data-layer truth from this lane

## Source Handling

This bundle uses the following as **external lane evidence / local proof input / not independently reverified by this lane**:

- `var/proofs/lane-a-runtime-closure.md`
- screenshots under `assets/screenshots-of-issues/lane-a-phase2-proof/`
- screenshots under `assets/screenshots-of-issues/lane-a-phase3-bff-closure/`

These inputs are not canonical truth by default.

## Claim Lineage

| Claim | Source artifact | Current status | State class | Contradicted by what | Can/cannot promote |
|---|---|---|---|---|---|
| Repo-only stabilization guardrails are merged and active | `docs/stabilization/STABILIZATION_CONTROL_BOARD.md`, `STABILIZATION_PHASE_GATES.md`, `EXECUTION_INVARIANTS.md` | `CONFIRMED` | `DURABLE` | — | Can promote |
| Enterprise MFE build truth uses immutable source-tag rules, not `latest` | `docs/stabilization/ENTERPRISE_MFE_BUILD_CONTRACT.md` | `CONFIRMED` | `DURABLE` | — | Can promote |
| Admin portal user-visible success exists in dev | `var/proofs/lane-a-runtime-closure.md`, phase 2 screenshots | `PROVISIONAL` | `MANUAL_STATE` | Not contradicted, but not canonically promoted | Cannot promote yet |
| Learner primary-path dashboard shows enterprise banner after login | `var/proofs/lane-a-runtime-closure.md`, phase 2 and phase 3 screenshots | `PROVISIONAL` | `MANUAL_STATE` | Not contradicted, but still local proof input only | Cannot promote yet |
| Learner secondary-path blocker is BFF 401 / JWT cookie propagation | Earlier section of `var/proofs/lane-a-runtime-closure.md` | `CONTRADICTED` | `MANUAL_STATE` | Later section of the same proof shows BFF 200 and root cause reclassified to JSON 404 / MFE handling | Cannot promote |
| Learner portal browser proof passes with synthetic learner identity | Phase 2 acceptance table in `var/proofs/lane-a-runtime-closure.md` | `CONTRADICTED` | `MANUAL_STATE` | Phase 3 proof still shows learner shell plus React error boundary on JSON 404 | Cannot promote |
| HTML 404 proxy behavior was the remaining learner-secondary-path blocker | Mid-phase 3 local proof | `PROVISIONAL` | `TEMPORARY_RUNTIME_MITIGATION` | Post-fix phase 3 proof shows HTML -> JSON 404 conversion is fixed, but user-visible failure remains | Cannot promote as closure |
| Remaining learner-secondary-path blocker is MFE error boundary on JSON 404 from optional endpoints | Later phase 3 section of `var/proofs/lane-a-runtime-closure.md` | `PROVISIONAL` | `MANUAL_STATE` | Not contradicted by later evidence in this worktree | Cannot promote yet |
| Live image tags/digests listed in the local proof are the tested runtime truth | `var/proofs/lane-a-runtime-closure.md` | `PROVISIONAL` | `MANUAL_STATE` | Depends on external runtime/GitOps state not promoted into tracked repo evidence here | Cannot promote yet |
| Waffle-flag or DB/manual state contributes to the runtime slice | `var/proofs/lane-a-runtime-closure.md` | `PROVISIONAL` | `MANUAL_STATE` | No contradiction, but manual state is not durable closure | Cannot promote |

## Durable Truths Already Promotable

1. The program remains in `Stabilization`.
2. The `Stabilization -> Convergence` gate is blocked until runtime/browser evidence is durable and non-contradictory.
3. Build truth must be pinned to immutable refs and cannot depend on `latest`.
4. Local proof files and screenshots are non-canonical unless promoted into tracked artifacts.

## Provisional Truths Still Awaiting Promotion

1. Admin portal appears healthy in dev local proof.
2. Learner primary-path dashboard appears healthy in dev local proof.
3. The later learner-secondary-path root-cause analysis is more credible than the earlier BFF-401 theory.
4. The proxy-side HTML -> JSON 404 conversion appears fixed in local proof.

## Contradicted Truths That Must Stay Open

1. The learner-secondary-path issue is not credibly classifiable as a JWT cookie propagation failure anymore.
2. The learner portal cannot be described as browser-closed just because the shell renders.
3. A proxy-only fix is not sufficient closure when the MFE still throws an error boundary on JSON 404.

## Exact Blockers Preventing `Stabilization -> Convergence`

| Blocker | Owner | Classification | Why it blocks convergence |
|---|---|---|---|
| No canonical merged runtime/browser bundle | Lane A | `PROVISIONAL` | Current runtime evidence is still local proof input, not durable tracked truth. |
| Learner secondary path still fails at the user-visible layer | Lane A | `CONTRADICTED` | Later evidence still shows the error boundary after the proxy fix. |
| Live image/GitOps/runtime mapping is not promoted into tracked convergence evidence | Lane A + external infra surface | `PROVISIONAL` | The local proof names live refs, but this lane cannot canonize external runtime state by itself. |
| Manual DB/runtime state remains in the story | Lane A | `MANUAL_STATE` | Manual flags or data assumptions are not durable convergence closure. |
| Runner throughput and queue effects can delay proof refresh | External platform capacity | `EXTERNAL_BLOCKER` | Throughput affects evidence freshness, but does not change semantic closure. |

## Exact Evidence Lane A Must Produce Next

Lane A must produce one tracked, contradiction-aware runtime bundle that includes:

1. Admin portal browser proof on the promoted runtime slice.
2. Learner portal primary-path browser proof on the same promoted runtime slice.
3. Learner portal secondary-path browser proof on the same promoted runtime slice.
4. A secondary-endpoint request matrix showing:
   - required endpoints
   - optional endpoints
   - acceptable non-fatal responses
   - unacceptable fatal responses
5. Proof that optional endpoint 404s no longer trigger an error boundary.
6. Pinned image/build truth for the tested runtime.
7. Explicit labeling of any remaining manual DB/runtime state and why it is not closure.
8. A supersession note that explicitly retires the earlier BFF-401 root-cause claim.

## What Not To Claim Yet

- Do not claim learner portal closure.
- Do not claim secondary-path closure from screenshots alone.
- Do not claim convergence readiness from a merged PR or proxy fix alone.
- Do not claim live image/GitOps/data-layer closure from local proof notes alone.
- Do not summarize the current learner runtime state as “basically fixed”.
