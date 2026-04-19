---
title: Tier-A Scorecard Baseline 2026-04-19
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-19T00:00Z
bead: mereka-lms-q69f.4
status: active
---

# Tier-A Scorecard Baseline 2026-04-19

Evidence for bead `mereka-lms-q69f.4` — Phase 1 and Phase 2 baseline capture of the
Script First-Class Program scorecard introduced in
`docs/ops/evidence/script-first-class-tier-0-discovery-2026-04-18.md`.
This document anchors the Phase 4 threshold decision with observed distribution data.

The scorecard was executed against the branch `feat/q69f.4-tier-a-scorecard` at its
state on 2026-04-19T00:00Z (script path:
`scripts/governance/score-tier-a-scripts.py`).

---

## Scope

Both discovery modes were exercised in the same run:

| Mode | Phase | Discovery method | Scripts scored |
|------|-------|-----------------|---------------|
| Hardcoded | 1 | Fixed shortlist of 10 Tier-A scripts from Phase 0 evidence | 10 |
| Auto-discover | 2 | `generate-script-governance-catalog.py` — `inventory_authoritative` + `github` caller type + governance/verify/ci paths | 56 |

### Scoring axes (max 5.0 total, each axis 0 / 0.5 / 1)

| Axis | Key | 1.0 | 0.5 | 0.0 |
|------|-----|-----|-----|-----|
| CI-reachable | `ci_reachable` | Referenced in `.github/workflows/*.yml` or `ci-scripts-*.txt` | — | Not referenced |
| Self-test present | `self_test_present` | `scripts/qa/test-<name>.sh` exists | Referenced by another test script | Absent |
| Runbook mapped | `runbook_mapped` | Full path in a `docs/ops/runbooks/*.md` | Basename only | Not mentioned |
| Manifest registration | `manifest_registration` | `ci_static_inventory.entries` in `script-registry.yaml` (STRICT) | In allowlist file (ALLOWLIST) | Neither (NONE) |
| Fresh modification | `fresh_modification` | Last commit ≤ 30 days ago | Last commit ≤ 90 days ago | Older than 90 days |

---

## Aggregate Metrics

### Phase 1 — Hardcoded (10 scripts)

| Metric | Value |
|--------|-------|
| Count | 10 |
| Sum | 22.5 / 50.0 |
| **Mean** | **2.25 / 5.0** |
| Max achieved | 4.0 |
| Min achieved | 1.0 |

### Phase 2 — Auto-discover (56 scripts)

| Metric | Value |
|--------|-------|
| Count | 56 |
| Sum | 180.0 / 280.0 |
| **Mean** | **3.21 / 5.0** |
| Max achieved | 4.0 |
| Min achieved | 2.0 |

---

## Top 5 Performers (Phase 2)

| Script | Total | ci | st | rb | mf | fr |
|--------|------:|---:|---:|---:|---:|---:|
| `scripts/qa/verify-a11y-authenticated-routes.sh` | 4.0 | 1.0 | 0.0 | 1.0 | 1.0 | 1.0 |
| `scripts/qa/verify-documentation-standards.sh` | 4.0 | 1.0 | 1.0 | 0.0 | 1.0 | 1.0 |
| `scripts/qa/verify-enterprise-frontend-live-contract.sh` | 4.0 | 1.0 | 1.0 | 0.0 | 1.0 | 1.0 |
| `scripts/qa/verify-footer-variant-matrix.sh` | 4.0 | 1.0 | 0.0 | 1.0 | 1.0 | 1.0 |
| `scripts/qa/verify-observability-pii-filtering.sh` | 4.0 | 1.0 | 0.0 | 1.0 | 1.0 | 1.0 |

Axis key: ci=CI-reachable, st=self-test, rb=runbook-mapped, mf=manifest, fr=fresh-modification.

An additional 9 scripts also scored 4.0 (`verify-oidc-provider-configs.sh`,
`verify-oidc-user-password-state.sh`, `verify-pii-inventory.sh`,
`verify-preview-redirect.sh`, `verify-public-branding.sh`,
`verify-secret-inventory.sh`, `verify-studio-authoring-branding.sh`,
`verify-tenant-branding-runtime.sh`, `verify-tenant-contract-alignment.sh`).
No script in the auto-discover set achieved 5.0 — `self_test_present` or
`runbook_mapped` is the universal gap holding the cluster back from perfect.

---

## Bottom 5 Underperformers (Phase 2)

| Script | Total | Zero axes |
|--------|------:|-----------|
| `scripts/qa/verify-skill-frontmatter-integrity.sh` | 2.0 | ci, st, rb |
| `scripts/qa/verify-release-readiness.sh` | 2.0 | ci, st, rb |
| `scripts/qa/verify-branch-protection-contract.sh` | 2.5 | ci, rb |
| `scripts/qa/verify-tutor-multisite-domains.sh` | 3.0 | st, rb |
| `scripts/qa/verify-tenant-visual-contract.sh` | 3.0 | st, rb |

All five are fully `inventory_authoritative` and `fresh_modification=1.0`.
Their deficit is exclusively in CI wire-in (`ci_reachable`) and ecosystem coverage
(`self_test_present`, `runbook_mapped`) — not age or registration.

### Phase 1 bottom 5 (governance scripts — notably lower mean)

| Script | Total | Zero axes |
|--------|------:|-----------|
| `scripts/governance/verify-retraction-sweep.sh` | 1.0 | ci, st, mf |
| `scripts/governance/verify-runbook-executable.sh` | 1.0 | ci, st, mf |
| `scripts/governance/generate-ci-static-inventory.py` | 1.5 | ci, mf |
| `scripts/governance/generate-ci-runtime-inventory.py` | 1.5 | ci, mf |
| `scripts/governance/generate-current-operator-state.sh` | 2.0 | ci, st, mf |

The governance scripts in Phase 1 score 0.97 points below the Phase 2 mean.
Their structural issue: they are not in `ci_static_inventory` (manifest=NONE) and
have no `test-<name>.sh` harness. They are invoked ad-hoc or via wrapper scripts
not yet captured in the allowlist.

---

## Score Distribution Histogram

### Phase 1 (n=10)

| Band | Count | % | Scripts |
|------|------:|--:|---------|
| 1.0 | 2 | 20% | verify-retraction-sweep, verify-runbook-executable |
| 1.5 | 2 | 20% | generate-ci-static-inventory, generate-ci-runtime-inventory |
| 2.0 | 1 | 10% | generate-current-operator-state |
| 2.5 | 2 | 20% | emit-promotion-chain-metrics, run-with-retry |
| 3.0 | 1 | 10% | validate-registry |
| 3.5 | 1 | 10% | verify-pods-on-digest |
| 4.0 | 1 | 10% | audit-velero |

### Phase 2 (n=56)

| Band | Count | % | Notes |
|------|------:|--:|-------|
| 2.0 | 2 | 4% | verify-skill-frontmatter-integrity, verify-release-readiness |
| 2.5 | 1 | 2% | verify-branch-protection-contract |
| 3.0 | 38 | 68% | **Dominant cluster** — CI + manifest + fresh, missing st + rb |
| 3.5 | 1 | 2% | verify-dev-visual-correctness |
| 4.0 | 14 | 25% | Best performers — one axis missing |

The Phase 2 distribution is bimodal in practice: 68% sit at exactly 3.0 and 25%
at exactly 4.0. The 3.0 cluster is homogeneous: all have `ci_reachable=1.0`,
`manifest_registration=1.0`, `fresh_modification=1.0` and both `self_test_present`
and `runbook_mapped` at 0.0. This is a structural pattern, not random scatter.

---

## Threshold Recommendation

### Context

- Phase 2 mean: **3.21 / 5.0**
- 3.0 cluster holds 38/56 scripts (68%)
- The two scripts at 2.0 are registered and fresh but lack CI wire-in + runbook

### Options

| Option | Threshold | Effect at current distribution |
|--------|----------:|---------------------------------|
| Permissive | 2.0 | Gates only scripts below 2.0 (zero failures today) |
| Median-aligned | 2.5 | Gates only the 3 scripts at 2.0 and 2.5 (3/56 = 5%) |
| Conservative | 3.0 | Passes the 68% cluster at exactly 3.0; gates the 3 below (5%) |
| Aspirational | 3.5 | Gates 41 scripts (73%) — immediately breaking |
| Strict | 4.0 | Gates 42 scripts (75%) — immediately breaking |

**Recommendation: threshold = 2.5**

Rationale:

1. A threshold of 2.5 catches scripts that are missing CI wire-in AND have no self-test
   AND are not runbook-mapped — a genuine hygiene gap, not a reasonable one-axis miss.

2. It does not break the 68% majority that sit at 3.0, which already demonstrate
   the three hardest axes (CI, manifest, freshness) and are missing only runbook and
   self-test (two axes with known backlog work).

3. It is achievable by the two 2.0 scripts through a single CI wire-in commit — the
   smallest possible lift to clear the bar.

4. The distribution offers no support for 3.0 as initial enforcement: gating zero
   scripts is not a gate. Gating zero scripts while asserting 3.0 is aspirational
   training-wheels enforcement would be technically correct but misleading.

---

## Phase 4 Acceptance Criteria

Phase 4 adds `--threshold` CI enforcement to the scorecard job.

### Recommended configuration at Phase 4 launch

```yaml
# ci.yml — scorecard-enforcement job
- name: Tier-A scorecard gate
  run: |
    python3 scripts/governance/score-tier-a-scripts.py \
      --auto-discover \
      --threshold 2.5
```

**Pass condition**: Exit 0 — no auto-discovered Tier-A script scores below 2.5.

**Graduation path** (not enforced at Phase 4 launch):

| Milestone | Target threshold | Expected scripts below threshold |
|-----------|----------------:|----------------------------------|
| Phase 4 launch (now) | 2.5 | 3 → must be fixed before or at enforcement |
| Phase 5 (30 days) | 3.0 | 0 at current baseline; 3.0 is already the dominant cluster |
| Phase 6 (60 days) | 3.5 | Requires runbook or self-test for all scripts — ~1 day of work per script |

The jump from 2.5 → 3.0 should happen as soon as the three below-2.5 scripts
are wired into CI. No new structural work is needed; it is exclusively a
`ci-scripts-static.txt` registration for `verify-release-readiness.sh` and
`verify-skill-frontmatter-integrity.sh`.

---

## Captured Artifacts

The raw JSON outputs that produced this analysis were captured during the
scorecard run on the `feat/q69f.4-tier-a-scorecard` branch:

| Artifact | Description |
|----------|-------------|
| Phase 1 JSON | `score-tier-a-scripts.py --json` — 10 hardcoded scripts |
| Phase 2 JSON | `score-tier-a-scripts.py --auto-discover --json` — 56 auto-discovered scripts |

Both runs exited 0 (no `--threshold` flag applied at capture time).
The raw JSON is not committed here; the metrics above are the authoritative
extracted summary.

---

*Captured against branch `feat/q69f.4-tier-a-scorecard` on 2026-04-19T00:00Z.
For Phase 4 enforcement script, see PR #1844.*
