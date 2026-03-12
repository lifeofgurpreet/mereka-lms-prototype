# Convergence Evidence Bundle Contract

> Canonical repo-side contract for promoting runtime/browser evidence into convergence truth.

## Purpose

This contract defines what runtime evidence can be promoted into canonical repo truth, what
must stay provisional/manual/external, and what exact evidence shape is required before the
program may move from `Stabilization` to `Convergence`.

## Canonical classes

### Truth classes

| Class | Meaning |
|---|---|
| `CONFIRMED` | Durable tracked evidence is merged and not contradicted by later canonical evidence. |
| `PROVISIONAL` | Evidence exists, but it is local-only, partial, or not durable enough for promotion. |
| `CONTRADICTED` | A later artifact overturns an earlier claim; the claim must remain open. |
| `EXTERNAL_BLOCKER` | A blocker exists outside this repo-owned mutation surface. |
| `PARKED` | Intentionally deferred; not valid for current phase closure. |

### State classes

| Class | Meaning |
|---|---|
| `DURABLE` | Merged repo truth or pinned release evidence that survives session/operator change. |
| `MANUAL_STATE` | Live runtime, browser, DB, or operator-held state that is not fully codified in tracked truth. |
| `TEMPORARY_RUNTIME_MITIGATION` | A mitigation that reduces symptoms but is not convergence closure. |

## Promotion rules

Runtime/browser evidence may be promoted into canonical repo truth only when all of the
following are true:

1. the evidence is tracked in merged repo artifacts
2. the claim has a named owner and timestamp
3. the claim is scoped to a concrete path or surface
4. later evidence does not contradict it
5. manual runtime state is either absent or explicitly labeled

## Non-canonical local proof input

The following are not canonical truth by default:

- `var/proofs/**`
- screenshots under `assets/screenshots-of-issues/**`
- local notes or browser observations
- live console output not promoted into tracked artifacts

These must be labeled as:

- external lane evidence
- local proof input
- not independently reverified by this lane

## Required evidence surfaces for convergence

### Admin portal

Required to close:

- browser proof on the promoted path
- pinned image truth for the rendered portal
- release or deployment identity for the tested runtime
- contradiction-free claim that the user-visible path succeeds

Insufficient alone:

- screenshot without tracked claim lineage
- shell/curl success without browser proof

### Learner portal primary path

Required to close:

- browser proof for authenticated learner entry and dashboard path
- tracked identity/scope of the test
- pinned image or release identity
- no later contradiction from the same promoted runtime slice

Insufficient alone:

- login redirect proof without the main user-visible screen
- screenshot set with no release identity

### Learner portal secondary path

Required to close:

- browser proof for the secondary learner path
- request/response evidence for the optional or secondary endpoints used by the page
- explicit rule for what 404s are acceptable and why they are non-fatal
- proof that the UI degrades gracefully instead of throwing an error boundary

Insufficient alone:

- “shell renders” without stable user-visible success
- proxy-only fix notes when the MFE still fails on JSON 404
- screenshot of the shell plus an error boundary

### Build truth

Required to close:

- immutable image refs
- source tag or digest lineage
- build contract compatibility with the tested runtime

### GitOps truth

Required to close:

- pinned desired state identity
- deployment mapping to the tested runtime

Note: GitOps truth outside this repo remains external unless promoted into tracked repo evidence.

### Image truth

Required to close:

- immutable tags or digests
- proof that the tested runtime actually used those refs

### Data-layer truth

Required to close:

- tracked description of required data assumptions
- explicit labeling of any DB/manual state that remains outside durable source control

DB or flag changes alone are `MANUAL_STATE`, not convergence closure.

## Contradiction policy

A claim is `CONTRADICTED` when:

- a later artifact disproves the stated root cause
- a later artifact shows the user-visible path still fails
- a claim of closure relies on a mitigation that later evidence shows is insufficient

Example:

- Earlier claim: learner blocker is BFF 401 / JWT cookie propagation.
- Later evidence: BFF returns 200 and the remaining blocker is the MFE error boundary on JSON 404.
- Result: the earlier root-cause claim becomes `CONTRADICTED`.

## Superseded evidence

Evidence is superseded when a later artifact covers the same scope more precisely and changes the
classification or root cause. Superseded evidence must stay visible in claim lineage; it must not
be deleted from the history narrative.

## What cannot be promoted

- screenshots alone
- merged PR state alone
- admin merge alone
- live DB writes alone
- pod-local behavior alone
- “looks fixed” language with unresolved contradiction

## Exact next evidence shape required from Lane A

Lane A must next produce one tracked, contradiction-aware runtime bundle that includes:

1. admin portal browser proof
2. learner portal primary-path browser proof
3. learner portal secondary-path browser proof
4. explicit request matrix for secondary endpoints, including which 404s are expected and non-fatal
5. proof that the UI does not throw an error boundary on those non-fatal responses
6. pinned image/build truth for the tested runtime
7. explicit labeling of any remaining manual DB/runtime state

Without that shape, `Stabilization -> Convergence` remains blocked.
