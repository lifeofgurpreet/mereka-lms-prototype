# Wave 1 — Multisite Canonicalization

Date: 2026-03-16

## Contradiction Resolved

The prior lane reported production.py with "diff_lines=30" but later
claimed "in sync." The contradiction was caused by a dirty local
bbi-infrastructure checkout with merge conflicts.

**Clean evidence from origin/main:**

| File | App Lines | Infra Lines | Diff | Status |
|------|-----------|-------------|------|--------|
| lms/production.py | 1887 | 1887 | 0 | IN SYNC |
| cms/production.py | 730 | 730 | 0 | IN SYNC |
| lms/mereka_multisite.py | 414 | 199 | 240 | DIVERGED → SYNCED |
| cms/mereka_multisite.py | 235 | 214 | 36 | DIVERGED → SYNCED |

## Canonical Owner Decision

All 4 files: **mereka-lms (app repo)** is canonical. Infra vendored
copies must match byte-for-byte.

## Files Changed

### App repo (mereka-lms)
- `scripts/qa/verify-vendored-settings-drift.sh` — drift guardrail
- `docs/architecture/SETTINGS-OWNERSHIP-CONSOLIDATION.md` — ADR
- `.github/ci-scripts-static.txt` — registered drift checker
- `docs/archive/WAVE1-MULTISITE-CANONICALIZATION.md` — this artifact

### Infra repo (bbi-infrastructure)
- PR #1854: vendor-sync lms/mereka_multisite.py (240 diff → 0)
- PR #1854: vendor-sync cms/mereka_multisite.py (36 diff → 0)

## Drift Checker Status

Registered in `.github/ci-scripts-static.txt`. In CI, it SKIPs
when bbi-infrastructure is not available (expected). Locally, it
detects divergence and exits non-zero.

After PR #1854 merges, expected result: 9 PASS, 0 FAIL, 0 SKIP.

## Remaining Structural Debt

| Item | Scope | Wave |
|------|-------|------|
| 4 overlay Python forks (3500+ lines) | dev/staging/prod overlays | Wave 2 |
| 12 plugin/service settings files | satellite services | Wave 3 |
| ADR-027 execution | structural cleanup | Wave 4 |

## Wave 2 Scope (Recommended)

Decompose `production-staging.py` (1069 lines) into:
1. Thin env-values layer (hostnames, URLs) — stays in infra
2. App-behavior imports from base — consumed from app repo

Start with the dev LMS overlay as the pilot. Validate that
the decomposed version renders the same kustomize output.
