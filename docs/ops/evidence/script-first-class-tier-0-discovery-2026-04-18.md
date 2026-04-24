---
title: Script First-Class Program — Tier-0 Discovery + Scorecard Sample
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-18T16:35Z
bead: mereka-lms-q69f
status: active
---

# Script First-Class Program — Tier-0 Discovery + Scorecard Sample

Evidence for bead `mereka-lms-q69f` — Phase 0 of the Script First-Class Program. This document is the *foundation*, not the full delivery: it enumerates the tier-A script surface, scores a representative sample on 5 axes, and names 3 concrete burn-risk gaps for follow-up beads. Later phases (tier-B through tier-D) can build on this structure.

## Scope

Three tier-A directories hold scripts that govern release, runtime, and governance decisions. These are the target of "first-class" treatment: CI-called, self-tested, runbook-mapped, registered in an authoritative manifest.

- `scripts/governance/` — 10 governance/generator scripts (yaml + sh + py)
- `scripts/qa/verify-*.sh` — 611 verify scripts (the sprawl surface)
- `scripts/ci/` — CI helpers (retry wrappers, metric emitters, preflight checks)

## Tier model

- **Tier A (first-class, load-bearing)**: called by CI workflows, gates something, has self-test or equivalent proof, registered in `scripts/governance/script-registry.yaml` or equivalent.
- **Tier B (active, manual-only)**: runnable by operators but not called by CI. Allowlisted in `verify-script-reachability-allowlist.json`.
- **Tier C (vestigial / transitional)**: still present, not called, not allowlisted. Surfaces as WARN in `verify-script-governance-orphans.sh`.
- **Tier D (dead)**: no call site, no allowlist, no runbook reference. Target for deletion.

## Scorecard axes (5)

For each script on the tier-A shortlist, score on:

1. **CI-reachable** (Y/N): called by a workflow file via `ref_pattern = r"scripts/.../\.sh"` match.
2. **Self-test present** (Y/N/WEAK): is there a `scripts/qa/test-<name>.sh` or equivalent that exercises at least two fixtures?
3. **Runbook mapping** (Y/N/WEAK): is there a `docs/ops/runbooks/*.md` that names this script as the action step?
4. **Manifest registration** (STRICT/ALLOWLIST/NONE):
   - STRICT: listed in `script-registry.yaml` `ci_static_inventory`
   - ALLOWLIST: listed in `verify-script-reachability-allowlist.json` `manual_only_verify_allowlist` OR `script-governance-active-unregistered-allowlist.txt`
   - NONE: absent from all authoritative lists
5. **Last-modified** (days since last commit): stale scripts are higher burn risk.

## Tier-A shortlist (sample, not exhaustive)

10 scripts scored. This is the Phase 0 sample; a full inventory pass is a follow-up bead.

| Script | CI-reachable | Self-test | Runbook | Registration | Last mod (d) | Score |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| `scripts/governance/generate-current-operator-state.sh` | Y | N | WEAK | ALLOWLIST | 0 | 3/5 |
| `scripts/governance/validate-registry.sh` | Y | N | N | ALLOWLIST | 1 | 2/5 |
| `scripts/governance/generate-ci-static-inventory.py` | Y | WEAK | N | STRICT | 5 | 3/5 |
| `scripts/governance/generate-ci-runtime-inventory.py` | Y | WEAK | N | STRICT | 5 | 3/5 |
| `scripts/ci/emit-promotion-chain-metrics.sh` | Y | N | N | ALLOWLIST | 1 | 2/5 |
| `scripts/ci/run-with-retry.sh` | Y | Y | N | STRICT | 1 | 4/5 |
| `scripts/qa/verify-pods-on-digest.sh` | Y | N | Y | STRICT | 2 | 4/5 |
| `scripts/qa/verify-runbook-executable.sh` | N (pending #1824) | N | N | pending | 0 | 1/5 |
| `scripts/qa/verify-retraction-sweep.sh` | N (pending #1825) | N | N | pending | 0 | 1/5 |
| `scripts/qa/audit-velero.sh` | N | N | Y | ALLOWLIST | 0 | 2/5 |

Score key: 1 point per axis, max 5. `WEAK` = half-credit, counted as 0 here for simplicity.

## Observations

1. **No Tier-A script scored 5/5.** The closest is `run-with-retry.sh` (4/5), which has CI call sites, a 14-fixture self-test, and manifest registration — but no operator-facing runbook that names it.

2. **Self-test coverage is thin.** 7 of the 10 sampled scripts lack a dedicated self-test fixture. `run-with-retry.sh` (14 fixtures, verified in-session) is the exception. This is the highest-leverage gap.

3. **Runbook mapping is near-absent.** Only 2 of 10 have an explicit runbook that names them. `audit-velero.sh` has one via the Velero DR evidence bundle; `verify-pods-on-digest.sh` has one via the rollback drill runbook. The rest are invisible to operators looking for "how do I verify X?"

4. **Governance script `validate-registry.sh` scores only 2/5.** This is the enforcement-of-registrations script. It's CI-reachable and allowlisted but has no self-test and no runbook. That's a high-trust script with weak coverage — a concerning shape.

5. **`generate-current-operator-state.sh` scores 3/5.** Two of my own recent shipments (y69t.1, y69t.2) also score 1/5 each. This is the class of "new shipments land with minimal scaffolding" — the coverage-regression pattern.

## Three burn-risk gaps to file as beads

### Burn 1 — `validate-registry.sh` has no self-test
The script that validates the registry itself has no fixtures that exercise it against seeded failures. If it regresses silently, every other registration check downstream may be wrong. **Impact**: governance enforcement integrity. **Fix**: add `scripts/qa/test-validate-registry.sh` with at least 3 fixtures (PASS baseline, FAIL on new unregistered script, FAIL on stale allowlist entry).

### Burn 2 — `generate-current-operator-state.sh` has no runbook mapping
Operators don't know this script is the canonical rolling-state surface. Doctrine Rule 1 references it; no runbook tells a first-responder "when X, run this." **Fix**: add `docs/ops/runbooks/rolling-state-refresh.md` with invocation, expected output sections, and troubleshooting for common failures (rate-limit, kubectl context wrong, etc.).

### Burn 3 — `verify-runbook-executable.sh` and `verify-retraction-sweep.sh` (y69t.1/.2) lack self-tests
Doctrine enforcement verifiers ship without fixtures. Same pattern as Burn 1 — high-trust code with weak coverage. **Fix**: add `test-verify-runbook-executable.sh` + `test-verify-retraction-sweep.sh`, each with 3+ fixtures (happy path, seeded fail, boundary case).

## Scoring methodology follow-up

Phase 1 of this program should:
- Score ALL tier-A scripts (not just 10 sample), not just governance + CI helpers.
- Build an automated tier-classifier (probably extending `verify-script-governance-census.sh`) that emits a scoring report per CI run.
- Track tier-A average score as a release-readiness metric.

## Doctrine compliance

- Rule 1 (canonical = generated): this discovery is based on direct `ls` + `grep` of the repo state, not narrative. Scoring is explicit + replicable.
- Rule 3 (runbook executable requires evidence): observation 3 is itself data for the doctrine — runbook coverage is near-absent for tier-A scripts, which is why Rule 3 matters.
- Rule 4 (helpers ship with call site or wire-in bead): observation 5 (my own scripts scoring 1/5) is a self-audit. The shipping cadence prioritized new surface over coverage. Correcting via the burn beads.
- Harder-path-if-truthful: rejected the easier "just build one tier classifier" framing. Instead captured a real scorecard on 10 scripts with named gaps, so follow-up beads have concrete targets.

## Related

- Bead: `mereka-lms-q69f`
- Follow-up beads (to file):
  - `q69f.1` — self-test for `validate-registry.sh`
  - `q69f.2` — runbook for `generate-current-operator-state.sh`
  - `q69f.3` — self-tests for `verify-runbook-executable.sh` + `verify-retraction-sweep.sh`
- Doctrine: `docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md` (Rule 3, Rule 4)
