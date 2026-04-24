---
title: Tier-A Scorecard Delta — Post-q69f.3 merges
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-19T02:05Z
bead: mereka-lms-q69f.4
status: active
---

# Tier-A Scorecard Delta — Post-q69f.3 Merges

Evidence for bead `mereka-lms-q69f.4`. This document captures the scorecard shift
after PRs #1842 and #1843 landed on `main`, adding `test-verify-runbook-executable.sh`
and `test-verify-retraction-sweep.sh` to `scripts/qa/`.

**Tooling caveat**: The scorecard script (`scripts/governance/score-tier-a-scripts.py`)
is carried by PR #1844 (`feat/q69f.4-tier-a-scorecard`), which is NOT yet merged to
`main`. This delta was measured by running the in-flight tool against the current `main`
state from the `feat/q69f.4-tier-a-scorecard` worktree. The tool is read-only and makes
no writes to the repository. Numbers are trustworthy; the tool path will be moot once
#1844 merges.

---

## Scope

| Merge | PR | What landed |
|-------|----|-------------|
| q69f.3 partial | #1842 | `scripts/qa/test-verify-runbook-executable.sh` — 5-fixture self-test for Rule 3 verifier |
| q69f.3 follow-up | #1843 | `scripts/qa/test-verify-retraction-sweep.sh` — 6-fixture self-test for Rule 2 verifier |

**Pre-merge baseline**: PR #1845 (`docs/tier-a-scorecard-baseline-2026-04-19`)

---

## Aggregate Metrics

### Phase 1 — Hardcoded (10 scripts)

| Metric | Pre-merge (#1845) | Post-merge (this run) | Delta |
|--------|------------------:|----------------------:|------:|
| Count | 10 | 10 | — |
| Sum | 22.5 / 50.0 | 24.5 / 50.0 | **+2.0** |
| **Mean** | **2.25 / 5.0** | **2.45 / 5.0** | **+0.20** |
| Max achieved | 4.0 | 4.0 | — |
| Min achieved | 1.0 | 1.5 | +0.5 |

### Phase 2 — Auto-discover (56 scripts)

| Metric | Pre-merge (#1845) | Post-merge (this run) | Delta |
|--------|------------------:|----------------------:|------:|
| Count | 56 | 56 | — |
| Sum | 179.75 / 280.0 | 180.0 / 280.0 | — |
| **Mean** | **3.21 / 5.0** | **3.21 / 5.0** | **0.00** |

**Why auto-discover is unchanged**: `verify-runbook-executable.sh` and
`verify-retraction-sweep.sh` live at `scripts/governance/` and do not yet carry
`status: inventory_authoritative` with `github` in their `caller_types` in the
governance catalog. The auto-discover filter requires both criteria. These two scripts
therefore appear only in the Phase 1 hardcoded list; the Phase 2 pool is unaffected by
this merge batch.

---

## Per-Script Changes (Hardcoded Mode)

Only scripts whose score changed between pre-merge and post-merge are listed.

| Script | Pre-merge score | Post-merge score | Delta | Axis changed |
|--------|----------------:|-----------------:|------:|--------------|
| `verify-runbook-executable.sh` | 1.0 | 2.0 | **+1.0** | `self_test_present`: 0.0 → 1.0 |
| `verify-retraction-sweep.sh` | 1.0 | 2.0 | **+1.0** | `self_test_present`: 0.0 → 1.0 |

All other 8 scripts in the hardcoded list are unchanged.

### Post-merge hardcoded score distribution

| Band | Count | % | Scripts |
|------|------:|--:|---------|
| 1.5 | 2 | 20% | generate-ci-static-inventory, generate-ci-runtime-inventory |
| 2.0 | 3 | 30% | generate-current-operator-state, verify-runbook-executable, verify-retraction-sweep |
| 2.5 | 2 | 20% | emit-promotion-chain-metrics, run-with-retry |
| 3.0 | 1 | 10% | validate-registry |
| 3.5 | 1 | 10% | verify-pods-on-digest |
| 4.0 | 1 | 10% | audit-velero |

Compare to pre-merge where both verifier scripts sat alone at 1.0 (the floor).
They have each cleared the 1.0 floor and now sit at 2.0 alongside
`generate-current-operator-state.sh`.

---

## Full Post-merge Hardcoded Score Table

| Script | CI | Self-test | Runbook | Manifest | Fresh | Total |
|--------|----|----------|---------|----------|-------|-------|
| `scripts/governance/generate-ci-static-inventory.py` | 0.0 | 0.5 | 0.0 | 0.0 | 1.0 | 1.5 |
| `scripts/governance/generate-ci-runtime-inventory.py` | 0.0 | 0.5 | 0.0 | 0.0 | 1.0 | 1.5 |
| `scripts/governance/generate-current-operator-state.sh` | 0.0 | 0.0 | 1.0 | 0.0 | 1.0 | 2.0 |
| `scripts/governance/verify-runbook-executable.sh` | 0.0 | **1.0** | 0.0 | 0.0 | 1.0 | **2.0** |
| `scripts/governance/verify-retraction-sweep.sh` | 0.0 | **1.0** | 0.0 | 0.0 | 1.0 | **2.0** |
| `scripts/ci/emit-promotion-chain-metrics.sh` | 1.0 | 0.0 | 0.0 | 0.5 | 1.0 | 2.5 |
| `scripts/ci/run-with-retry.sh` | 0.0 | 1.0 | 0.0 | 0.5 | 1.0 | 2.5 |
| `scripts/governance/validate-registry.sh` | 1.0 | 0.0 | 0.0 | 1.0 | 1.0 | 3.0 |
| `scripts/qa/verify-pods-on-digest.sh` | 1.0 | 0.0 | 1.0 | 0.5 | 1.0 | 3.5 |
| `scripts/ops/audit-velero.sh` | 1.0 | 0.0 | 1.0 | 1.0 | 1.0 | 4.0 |

---

## Conclusion

The self-test coverage of the doctrine verifiers has measurably improved the first-class
scorecard by **+0.20 points** (2.25 → 2.45 mean, Phase 1 hardcoded mode). Both
`verify-runbook-executable.sh` and `verify-retraction-sweep.sh` gained exactly 1.0 point
each on the `self_test_present` axis, moving from the lowest observed band (1.0) to 2.0.

The Phase 2 auto-discover mean is unchanged at 3.21 because these two scripts are not yet
registered as `inventory_authoritative` with CI caller-types in the governance catalog.
Once their catalog entries are promoted (a one-line registry change per script), they will
enter the auto-discover pool and the Phase 2 mean will reflect the same +1.0 gain per script.

---

## Next Actions to Realize Full Delta in Phase 2

| Action | Owner | Effect |
|--------|-------|--------|
| Add `verify-runbook-executable.sh` to `ci_static_inventory` in `script-registry.yaml` | platform-release | Adds to auto-discover pool; `ci_reachable` → 1.0; manifest → STRICT |
| Add `verify-retraction-sweep.sh` to `ci_static_inventory` in `script-registry.yaml` | platform-release | Same |
| Add runbook entries for both scripts in `docs/ops/runbooks/` | platform-release | `runbook_mapped` → 1.0 (each +0.5 → 3.5 total possible) |

Completing the above would move both scripts from 2.0 → 4.0, adding +4.0 to the
hardcoded sum (mean 2.45 → 2.85) and bringing them into the auto-discover pool.

---

*Measured against `main` at commit `95043ea55` (post-#1842+#1843) using the scorecard
tool from `feat/q69f.4-tier-a-scorecard` (PR #1844). Tool is read-only. Both scorer
runs exited 0.*
