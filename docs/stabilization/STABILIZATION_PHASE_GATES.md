# Stabilization Phase Gates

> Explicit phase transitions for anti-false-closure program control.

## Gate: `Stabilization -> Convergence`

**Owner:** `Lane A` + release-truth owner  
**Current status:** `BLOCKED`

### Required evidence

1. Repo-side stabilization contracts are merged and current:
   - execution invariants
   - runner capability contract
   - CI false-red prevention
   - retired-root remediation
   - enterprise MFE build contract
2. One canonical runtime/browser evidence bundle is merged in tracked repo truth.
3. The runtime/browser bundle explicitly classifies primary and secondary learner paths as:
   - `CONFIRMED`
   - `PROVISIONAL`
   - `CONTRADICTED`
   and does not summarize contradictions away.
4. Manual runtime mitigations are either removed or explicitly recorded as non-durable.
5. The next release truth is pinned to immutable refs, not convenience aliases.

### Disallowed shortcuts

- local-only `var/proofs/**` treated as canonical closure
- admin merge treated as runtime proof
- curl-only proof treated as full user-visible closure
- pod-local hot-patch treated as architecture closure
- manual DB writes treated as durable convergence

### What counts as durable truth

- merged repo artifacts
- pinned image refs and digests
- tracked evidence bundles with named owners and timestamps
- release truth that survives actor/session change

### What does not count as closure

- ephemeral runner success
- manual runtime mitigation with no durable codification
- partial browser proof with unresolved contradictory paths
- external queue relief without semantic proof

## Gate: `Convergence -> Architecture Hardening`

**Owner:** future hardening owner  
**Current status:** `PARKED`

### Required evidence

1. The `Stabilization -> Convergence` gate is fully satisfied.
2. Release truth is pinned and reviewable under the release-evidence contract.
3. Runtime/manual divergences are either codified durably or kept explicitly open as blockers.
4. The planned hardening wave has a bounded owner, scope, and rollback-aware execution contract.
5. Staging or equivalent pre-hardening proof is present if hardening depends on it.

### Disallowed shortcuts

- using architecture hardening to "clean up later" unresolved runtime contradictions
- treating infra patching as proof that the current release is semantically closed
- broadening into new hardening waves while convergence still depends on manual state

### What counts as durable truth

- pinned release bundle
- merged evidence of convergence
- tracked hardening plan with owner and approval fields

### What does not count as closure

- manual operator memory
- informal Slack/PR comments without tracked contracts
- unpinned image aliases such as `latest`

## Current Gate Decision

The program remains in `Stabilization`.

It may move to `Convergence` only when runtime/browser closure is recorded as durable,
non-contradictory merged repo truth rather than local proof, manual mitigation, or
temporary operational state.
