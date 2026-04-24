# Convergence Evidence Promotion Handoff

> Date: 2026-03-12
> From: Lane I (convergence evidence bundle)
> To: Reviewer + Lane A (runtime proof)

## What This Pack Does

This pack establishes the canonical repo-side bridge between the stabilization control board (already merged on main) and the runtime/browser evidence being produced by Lane A.

It provides:

1. **A contract** (`CONVERGENCE_EVIDENCE_BUNDLE_CONTRACT.md`) defining how runtime evidence gets classified and promoted into canonical repo truth
2. **A human-readable evidence bundle** (`DEV_RUNTIME_CONVERGENCE_EVIDENCE.md`) with a complete claim lineage table covering all seven evidence domains
3. **A machine-readable manifest** (`dev-runtime-convergence-bundle.v1.yaml`) encoding every claim with its status, durability, and promotion path
4. **A CI verifier** (`verify-convergence-evidence-bundle.sh`) ensuring the pack stays internally consistent
5. **This handoff document** explaining what's canonical, what depends on Lane A, and what's missing

## What This Pack Does NOT Do

- It does NOT perform runtime proof (no kubectl, no browser, no pod access)
- It does NOT claim convergence readiness (the gate is explicitly BLOCKED)
- It does NOT fix any runtime issues
- It does NOT modify Lane A artifacts under `var/proofs/`
- It does NOT smooth over contradictions between earlier and later evidence

## What Is Now Canonical

The following are now merged repo truth (after this PR):

1. **Evidence classification system** — five claim status classes (CONFIRMED, PROVISIONAL, CONTRADICTED, EXTERNAL_BLOCKER, PARKED) and three durability classes (DURABLE, MANUAL_STATE, TEMPORARY_RUNTIME_MITIGATION)
2. **Promotion rules** — explicit criteria for when local proof becomes canonical truth
3. **Contradiction policy** — later evidence supersedes earlier; contradictions recorded, not erased
4. **Current evidence inventory** — 24 promoted claims, 4 provisional claims, 5 contradicted claims, 4 blockers
5. **Required evidence shape** — exactly what Lane A must produce for each remaining blocker

## What Still Depends on Lane A

| Dependency | What Lane A Must Do |
|-----------|-------------------|
| PR #1662 merge | Confirm cookie name sed patch is merged and deployed |
| PR #1673 merge | Confirm enterprise_worker init container is merged and deployed |
| Pod-restart test | Delete pods, verify portals work without manual intervention |
| Browser re-proof | Screenshot all 3 portals after PRs merged and pods restarted |
| Admin data visibility | Screenshot admin portal showing enterprise data (not "No results") |

## What Exact Evidence Is Missing Before Phase Advance

The Stabilization → Convergence gate requires ALL of:

1. **All 4 provisional claims promoted to CONFIRMED** (S4, G3, G4, A3)
2. **All 4 blockers resolved** (BLK-1 through BLK-4)
3. **Post-merge browser re-proof** covering admin portal, learner dashboard, learner search
4. **Pod-restart durability test** proving no manual intervention needed
5. **Evidence submitted as tracked artifact** (not local var/proofs/ file)

Until all five are satisfied, the program remains in Stabilization.

## What Evidence Would Still Be Insufficient

Even if it looks encouraging, the following would NOT satisfy the gate:

- curl-only proof without browser proof
- Browser proof before PRs #1662 and #1673 are merged
- Browser proof without pod-restart test
- Local var/proofs/ file without promotion to tracked repo truth
- Summary document that smooths over the 5 recorded contradictions
- Partial proof covering only learner portal (admin must also be verified)

## Claim Count Summary

| Category | Count |
|----------|-------|
| CONFIRMED + DURABLE (promotable) | 24 |
| PROVISIONAL (awaiting promotion) | 4 |
| CONTRADICTED (must stay open) | 5 |
| EXTERNAL_BLOCKER (parked) | 1 |
| Active blockers | 4 |

## Cross-References

| Document | Purpose |
|---------|---------|
| `docs/stabilization/CONVERGENCE_EVIDENCE_BUNDLE_CONTRACT.md` | Classification and promotion rules |
| `docs/reviews/DEV_RUNTIME_CONVERGENCE_EVIDENCE.md` | Human-readable evidence bundle |
| `docs/stabilization/dev-runtime-convergence-bundle.v1.yaml` | Machine-readable manifest |
| `scripts/qa/verify-convergence-evidence-bundle.sh` | CI verifier |
| `docs/stabilization/STABILIZATION_PHASE_GATES.md` | Phase gate criteria |
| `docs/stabilization/STABILIZATION_CONTROL_BOARD.md` | Control board |
