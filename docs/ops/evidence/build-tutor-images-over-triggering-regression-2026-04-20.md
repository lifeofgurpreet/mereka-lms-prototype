---
title: "Build Tutor Images — over-triggering regression + duration drift (2026-04-20 slice 77)"
type: evidence-bundle
status: active
observed_at: 2026-04-20T01:55Z
owner: platform-release
severity: P2 (wastes ~1 build-hour per non-image PR; blocks real fix PRs via concurrency group)
triggered_by: user question "why are we not just doing it on fastlane? is mereka lms fastlane full?" + follow-up on whether build was necessary
---

# Build Tutor Images — over-triggering regression + duration drift

User pushed back on slice-77 "45 min cold MFE" timing estimate. Deeper investigation revealed two separate, compound problems, and caught one real self-inflicted waste.

## Problem 1 — `resolve-build-scope.sh` over-triggers on non-image changes

`scripts/infra/resolve-build-scope.sh` classifies each changed path as:
- OpenEdX-owned (narrow allowlist)
- MFE-owned (narrow allowlist)
- **anything else → `mark_shared` → builds BOTH images**

The default-to-both behavior is conservative but WRONG for large classes of changes:

- `deploy/k8s/base/*.yaml` (kustomize manifests — consumed by GitOps, not image builds)
- `scripts/qa/*.sh` (CI verifiers — don't affect image content)
- `scripts/infra/verify-*.sh`, `scripts/infra/release-*.sh` (release tooling — separate from image pipeline)
- `docs/*`, `*.md` (documentation — obviously not image input)
- `.github/workflows/*.yml` (CI config)
- `scripts/governance/*.yaml` (catalog/registry)

**Real example**: PR #1901 (slice 73 pin-required restore) touched:
- `deploy/k8s/base/kustomization.yaml`
- `scripts/infra/release-openedx-gitops.sh`
- `scripts/infra/verify-release-preflight.sh`

None of these are image source. They fell through to `mark_shared`, resulting in:
- `build_openedx=true build_mfe=true`
- Run `24639215635` started 22:30Z on `mereka-k8s-heavy-builders`
- OpenEdX built in 17 min (cache hit)
- **MFE was still in_progress 1h 20min+ later** on a commit that didn't touch any MFE source

This MFE build was cancelled at 01:55Z by the operator (me) after recognizing the waste.

## Problem 2 — MFE build duration regressed recently

Recent `Build Tutor Images` run durations (most recent → older):

| Run | Duration | Conclusion | SHA | Notes |
|-----|----------|------------|-----|-------|
| 24639215635 | 100+ min (cancelled) | - | 71438656 | Slice 73 config PR — should not have built MFE at all |
| 24637920856 | 146 min | **failure** | 12c34683 | Slice 71 #1897 |
| 24631285760 | 68 min | success | d083c235 | #1743 Tutor 21.0.2→21.0.3 bump — legitimate cache invalidation |
| 24630631333 | **22 min** | success | 60d07115 | Slice 69 state doc update |
| 24628623317 | 33 min | success | e7bfe2e0 | Pre-Tutor-bump |
| 24595035890 | 28 min | success | 9211c547 | Pre-Tutor-bump |
| 24594709469 | 27 min | success | d0580fee | Pre-Tutor-bump |

**Pattern**: pre-Tutor-bump baseline was 22-33 min. Post-Tutor-bump one warm rebuild was 68 min (acceptable, reseeds cache). Subsequent runs regressed further: 146 min failure, then 100+ min cancelled.

**Hypothesis** (not confirmed): either:
- Cache seed from Tutor-bump rebuild didn't populate correctly → every subsequent run is cold
- MFE webpack is hanging (stuck job, no output, not actually compiling)
- ARC heavy-builder resource pressure (3 pods 28/21/9 min old, MAXIMUM 8, not expanded)

Diagnostic needed: pull the MFE build log after the next completed run and grep for `CACHED` lines + total webpack compile time.

## Problem 3 — Concurrency group serializes long builds

`.github/workflows/build-tutor-images.yml` uses:
```yaml
concurrency:
  group: build-tutor-images-main
  cancel-in-progress: false
```

When one build hangs for 100+ min, every subsequent push-to-main is blocked. PR #1906 (P0 Authn MFE login crash fix) was queued 31 min (now 2h 40min) waiting for #1901's wasteful build to release the lock.

## Problem 4 — Fastlane available but disabled

Repo variables:
- `CI_FASTLANE_BUILD_LABEL=mereka-lms-vps-fastlane-build` ← SET
- `CI_FASTLANE_BUILD_ENABLED` ← UNSET

Without `CI_FASTLANE_BUILD_ENABLED=true`, `select-build-lane` action defaults to `mereka-k8s-heavy-builders`. This is an opportunity cost, not a correctness defect.

## Recommended fixes (in order of impact)

### Fix A — tighten `resolve-build-scope.sh` (HIGH-LEVERAGE)

Add explicit "skip-build" classification for:
- `docs/**`, `*.md`
- `scripts/qa/**`, `scripts/governance/**`
- `scripts/infra/verify-*.sh`
- `scripts/infra/release-*.sh`
- `deploy/k8s/base/kustomization.yaml` (manifest-only)
- `.github/workflows/*.yml` (CI config)
- `.beads/**`, `tests/**` that don't feed Dockerfiles

If ALL changed paths classify as skip-build → set `build_openedx=false build_mfe=false`. Workflow then skips the build stages entirely (the `if: ...` conditions on build-openedx and build-mfe jobs already gate on these outputs).

### Fix B — add `paths-ignore` to workflow trigger (belt-and-braces)

Same path list, enforced at the workflow-trigger level. Even if resolve-build-scope is buggy in the future, docs-only pushes never trigger the workflow.

### Fix C — investigate MFE duration regression

Pull logs from next completed run, grep for:
- `CACHED` vs `NOT CACHED` layer counts
- `webpack ... in Nms` timing
- Step-by-step elapsed time to find where the 68→146→100+ min came from

### Fix D — enable `CI_FASTLANE_BUILD_ENABLED=true`

Small repo-variable change. Future builds use fastlane when it's online; falls back to heavy-builders otherwise. Does not retroactively unblock current queue.

### Fix E — consider `concurrency.cancel-in-progress: true` for non-main branches, keep false for main

Current config cancels-in-progress=false for all branches. For main this is correct (don't cancel a promotion build). For PRs it's wasteful — newer force-pushes should cancel predecessors.

## What I already did this slice

- **Cancelled run `24639215635`** (the 100+ min wasteful MFE build from slice-73 #1901). Rationale: the rebuild produced zero value (no MFE source changed), and it was blocking #1906's P0 rebuild.
- Filed this evidence doc instead of a bead (tracker still corrupted per slice-77 #1908 follow-ups).

## What I explicitly did NOT do

- Did not ship Fix A (resolve-build-scope tightening) inline. That needs its own PR with test fixtures ensuring the new deny-list matches intent.
- Did not flip `CI_FASTLANE_BUILD_ENABLED`. Want user approval before changing repo-level CI config.
- Did not investigate MFE hang from the cancelled run. Logs remain queryable after completion; deferred to follow-up.

## Related

- PR #1906 (queued — P0 Authn MFE login fix)
- PR #1901 (inadvertently triggered the wasteful build)
- PR #1743 (likely Tutor-bump cache-invalidation root cause)
- Slice 70 MemPalace: `reference-fastlane-speed-measurements` drawer — pre-regression timing data (OpenEdX cache-hit 71s, MFE warm 5-8 min, MFE cold 44 min)

## Next slice priorities adjusted

1. Watch for #1906 rebuild to kick off now that the wasteful predecessor is cancelled
2. Admin-merge bbi-infra promotion PR when it opens
3. Browser-verify Authn MFE login post-rollout
4. File a proper bead for Fix A (resolve-build-scope tightening) once tracker is repaired
5. Consider Fix D config PR once user green-lights
