# Stabilization Control Board

> Canonical repo-side board for phase truth, lane status, and anti-false-closure decisions.
> Status date: 2026-03-12

## Current Phase

**Current phase: `Stabilization`**

`Stabilization` remains the active phase because repo-side guardrails are now durable, but
runtime/browser closure is not yet canonically closed in merged repo truth.

## Phase Model

| Phase | Meaning | Current state |
|---|---|---|
| `Stabilization` | Stop false-red repo churn, define operating contracts, remove governance ambiguity | **ACTIVE** |
| `Convergence` | Convert mixed runtime/manual truth into one durable release/evidence model | **BLOCKED** |
| `Architecture Hardening` | Larger infra/runtime hardening wave after convergence truth is durable | **PARKED** |

## Lane Board

| Lane | Scope | Status | Truth | State class | Notes |
|---|---|---|---|---|---|
| `Lane A` | Runtime/build/runtime proof | `ACTIVE` | `PROVISIONAL` | `MANUAL_STATE` | Runtime/browser closure is not canonically closed here. Any local proof from other lanes is not independently reverified by this board. |
| `Lane F` | Repo-only CI stabilization | `COMPLETE` | `CONFIRMED` | `DURABLE` | Repo-side CI false-red prevention and runner-capability guardrails are merged repo truth. See `CI_FALSE_RED_PREVENTION.md`, `ARC_RUNNER_CAPABILITY_CONTRACT.md`, and `REPO_ONLY_CI_BLOCKER_LEDGER.md`. |
| `Lane G` | Retired-root remediation / docs-governance closure | `COMPLETE` | `CONFIRMED` | `DURABLE` | Canonical docs roots and retired-root governance are merged repo truth. See `DOCS_ROOT_AUTHORITY_CONTRACT.md` and `RETIRED_ROOT_REMEDIATION_LEDGER.md`. |
| `Lane H` | Stabilization control board / release truth | `ACTIVE` | `CONFIRMED` | `DURABLE` | This lane defines program control truth and anti-false-closure phase gates. |
| `Enterprise MFE build contract` | Image/build truth contract | `COMPLETE` | `CONFIRMED` | `DURABLE` | Build truth is pinned at the contract layer, but runtime promotion/use is still phase-gated. See `ENTERPRISE_MFE_BUILD_CONTRACT.md`. |
| `Architecture hardening wave` | Post-convergence infra/runtime hardening | `PARKED` | `PARKED` | `TEMPORARY_RUNTIME_MITIGATION` | Not allowed to expand yet. This work stays parked until the convergence gate is satisfied. |

## Truth Classes

| Class | Meaning |
|---|---|
| `CONFIRMED` | Durable repo truth is merged and not contradicted by canonical evidence. |
| `PROVISIONAL` | Evidence exists, but it is incomplete, local-only, or not yet durable enough to close the claim. |
| `CONTRADICTED` | Repo truth and observed/manual/runtime evidence disagree; the issue must stay open. |
| `EXTERNAL_BLOCKER` | The blocker exists outside the lane's repo-owned mutation surface. |
| `PARKED` | Intentionally deferred; not allowed to masquerade as active closure. |

## Durable vs Manual Classes

| Class | Meaning |
|---|---|
| `DURABLE` | Merged repo truth or pinned release evidence that survives actor/session change. |
| `MANUAL_STATE` | Live or operator-held state that is not fully codified in merged truth. |
| `TEMPORARY_RUNTIME_MITIGATION` | Deliberate runtime workaround that reduces immediate pain but is not closure. |

## Current Irreversible Priorities

1. Keep repo-side stabilization truth durable and non-ambiguous.
2. Convert runtime/browser closure claims into canonical, merged, non-contradictory evidence before any phase advance.
3. Prevent manual runtime mitigations or local proof artifacts from being summarized as release closure.

## Current Open Program Truth

| Area | Classification | Why it stays open |
|---|---|---|
| Learner portal end-to-end closure | `PROVISIONAL` | Repo-side contracts are stronger, but durable runtime/browser proof is not yet canonically closed here. |
| Final runtime/browser closure for enterprise learner secondary paths | `PROVISIONAL` | This lane did not independently reverify those paths; no merged canonical closure bundle is cited here. |
| Full convergence of manual runtime state into codified truth | `CONTRADICTED` | Manual runtime mitigations and desired durable release truth are not yet the same thing. |
| Staging proof | `PARKED` | Staging proof is not the current next irreversible step. |
| Architecture hardening / infra patch wave | `PARKED` | Blocked until stabilization exits cleanly and convergence truth is durable. |
| Runner saturation / ARC queue effects | `EXTERNAL_BLOCKER` | Throughput can delay proof/build jobs, but it is not semantic closure. |

## Local Proof Input Handling

Lane H may read local proof files such as `var/proofs/**` as **local proof input** only.
They are:

- external lane evidence
- not independently reverified by this lane
- non-canonical merged repo truth unless promoted into tracked repo artifacts

This board does not treat local proof files as authoritative closure.

## Gate Summary

| Gate | Owner | Status | Why |
|---|---|---|---|
| `Stabilization -> Convergence` | `Lane A` + release-truth owner | `BLOCKED` | Repo-side stabilization is durable, but runtime/browser closure is not yet durable and non-contradictory in merged truth. |
| `Convergence -> Architecture Hardening` | Future hardening owner | `PARKED` | Hardening cannot start while convergence truth is still unresolved. |

## Do Not Broaden Yet

- Do not claim learner runtime closure from local-only or manual evidence.
- Do not treat admin merge, DB writes, or pod-local changes as semantic closure.
- Do not open architecture hardening or infra patch waves before the convergence gate is satisfied.
- Do not import `var/proofs/**` into canonical truth without explicit tracked promotion and classification.

## Canonical Inputs

- `docs/stabilization/EXECUTION_INVARIANTS.md`
- `docs/stabilization/CI_FALSE_RED_PREVENTION.md`
- `docs/stabilization/ARC_RUNNER_CAPABILITY_CONTRACT.md`
- `docs/stabilization/REPO_ONLY_CI_BLOCKER_LEDGER.md`
- `docs/stabilization/ENTERPRISE_MFE_BUILD_CONTRACT.md`
- `docs/stabilization/DOCS_ROOT_AUTHORITY_CONTRACT.md`
- `docs/stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md`
- `docs/stabilization/CONVERGENCE_EVIDENCE_BUNDLE_CONTRACT.md`
- `docs/reviews/DEV_RUNTIME_CONVERGENCE_EVIDENCE.md`
