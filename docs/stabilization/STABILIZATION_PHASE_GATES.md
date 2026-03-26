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

**Updated: 2026-03-26**

The program remains in `Stabilization`, but the gate is now `PARTIALLY SATISFIED`.

### What is now satisfied (merged repo truth)

1. Repo-side stabilization contracts: **COMPLETE** (Lanes F, G, H all CONFIRMED/DURABLE)
2. Canonical runtime/browser evidence bundle: **MERGED** (`docs/reviews/STAGING_RUNTIME_CONVERGENCE_EVIDENCE.md`, PR #1061)
3. Evidence bundle classifies paths: **YES** — 28 CONFIRMED, 6 PROVISIONAL, 2 PARKED, no open CONTRADICTED
4. SSO browser proof: **TRACKED** — GitHub Actions run 23584121291, both SSO Canary and smoke-authenticated GREEN on main

### What remains for full gate satisfaction

1. Enterprise service deployment to staging: **PROVISIONAL** — enterprise-catalog, enterprise-access, enterprise-subsidy not fully deployed
2. Image digest pinning: **PROVISIONAL** — staging uses mutable SHA-timestamp tags, not immutable digests
3. Synthetic test fixtures: **PARKED** — not provisioned on staging

### The gate may advance when

- Enterprise services are deployed and verified on staging, OR
- Enterprise paths are explicitly reclassified as out-of-scope for this gate with an owner and reason

Current claim-lineage intake for that gate is tracked in:

- `docs/stabilization/CONVERGENCE_EVIDENCE_BUNDLE_CONTRACT.md`
- `docs/reviews/DEV_RUNTIME_CONVERGENCE_EVIDENCE.md`
- `docs/reviews/STAGING_RUNTIME_CONVERGENCE_EVIDENCE.md`
