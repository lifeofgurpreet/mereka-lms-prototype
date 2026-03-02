# `mereka_lms.py` Maintainability Split Status (2026-03-02)

## Scope

Issue: `#109` (`infrastructure/tutor/plugins/mereka_lms.py` maintainability split)

## Current State

- Plugin file length: `3426` lines.
- Direct QA coupling remains high but improved: `73` references inside `scripts/qa/*` to the concrete file path `infrastructure/tutor/plugins/mereka_lms.py`.
- Many checks currently rely on direct `grep` against the monolithic file for contract assertions (slots, token keys, theme URLs, tenant wiring, analytics guardrails).

## Progress Update (Phase 1, no-behavior-change)

- Introduced shared snippet constants in `mereka_lms.py` for duplicated ENV patch payloads:
  - Redwood optional apps asset wiring
  - `safe_join` monkeypatch block
  - CMS Prometheus metrics/settings block
- Reused these snippets across LMS/CMS asset patches and CMS production/development settings patches.
- This reduced duplication without changing runtime behavior or moving contract markers out of the canonical plugin file.

Validation after refactor:
- `python3 -m py_compile infrastructure/tutor/plugins/mereka_lms.py` PASS
- `./scripts/qa/verify-paragon-theme-urls.sh` PASS
- `./scripts/qa/verify-tutor-patches-inventory.sh` PASS

## Progress Update (Phase 2, QA compatibility contract layer)

- Added shared helper: `scripts/shared/mereka_plugin_contract.sh`.
  - Supports contract-aware discovery across `mereka_lms.py` + future `mereka_lms_*.py` split modules.
  - Exposes reusable checks: presence, fixed-string search, regex search, and regex count across all contract files.
- Migrated high-signal verifiers to consume the compatibility helper:
  - `scripts/qa/verify-paragon-theme-urls.sh`
  - `scripts/qa/verify-security-hardening.sh`
  - `scripts/qa/verify-plugin-slot-wiring.sh`
  - `scripts/qa/verify-footer-slot-only.sh`
  - `scripts/qa/verify-tutor-patches-inventory.sh`
- Outcome: staged split prep is now in place for critical gates without moving runtime hook payloads yet.

Validation after phase 2:
- `./scripts/qa/verify-paragon-theme-urls.sh` PASS (`PASS=27 WARN=0 FAIL=0`)
- `./scripts/qa/verify-security-hardening.sh` PASS (`PASS=30 WARN=1 FAIL=0`)
- `./scripts/qa/verify-plugin-slot-wiring.sh` PASS (`PASS=39 FAIL=0 WARN=0`)
- `./scripts/qa/verify-footer-slot-only.sh` PASS (`PASS=15 FAIL=0 WARN=0`)
- `./scripts/qa/verify-tutor-patches-inventory.sh` PASS (`23 PASS 0 FAIL 0 SKIP`)

## Progress Update (Phase 3, wider verifier adoption)

- Extended compatibility-layer adoption to additional QA verifiers:
  - `scripts/qa/verify-paragon-runtime.sh`
  - `scripts/qa/verify-certificate-branding.sh`
  - `scripts/qa/verify-analytics-key.sh`
  - `scripts/qa/verify-frontend-version-truth.sh`
  - `scripts/qa/verify-analytics-hardening.sh` (uses plugin-contract bundle source)
- Outcome:
  - direct path-coupling reduced from `98` to `92`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - existing pass/fail semantics preserved for known analytics-hardening baseline failures.

Validation after phase 3:
- `./scripts/qa/verify-paragon-runtime.sh` PASS (`PASS=10 WARN=2 FAIL=0`)
- `./scripts/qa/verify-certificate-branding.sh` PASS (`PASS=25 WARN=0 FAIL=0`)
- `./scripts/qa/verify-analytics-key.sh` PASS (`PASS=6 FAIL=0 SKIP=0`)
- `./scripts/qa/verify-frontend-version-truth.sh` PASS (`29 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-analytics-hardening.sh` unchanged baseline FAIL (`23 PASS / 3 FAIL / 0 WARN`):
  - `SEGMENT_KEY` expected-in-hook assertion
  - footer runtime sentinel guard assertion
  - CI workflow wiring assertion

## Progress Update (Phase 4, additional verifier adoption)

- Extended compatibility-layer adoption to another tranche of QA verifiers:
  - `scripts/qa/verify-paragon-token-coverage.sh`
  - `scripts/qa/verify-theme-consistency.sh`
  - `scripts/qa/verify-mfe-plugin-slots.sh`
  - `scripts/qa/verify-mfe-slot-source-alignment.sh`
  - `scripts/qa/verify-mfe-footer-slot.sh`
  - `scripts/qa/verify-mfe-footer-plugin-slot.sh`
- Outcome:
  - direct path-coupling reduced from `92` to `86`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - existing pass/skip semantics preserved (including expected optional `tutormfe.hooks` import skip when unavailable).

Validation after phase 4:
- `./scripts/qa/verify-paragon-token-coverage.sh` PASS (`PASS=52 WARN=0 FAIL=0`)
- `./scripts/qa/verify-theme-consistency.sh` PASS (`16 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-mfe-plugin-slots.sh` PASS (`PASS=152 WARN=0 FAIL=0`)
- `./scripts/qa/verify-mfe-slot-source-alignment.sh` PASS (`PASS=78 WARN=0 FAIL=0`)
- `./scripts/qa/verify-mfe-footer-slot.sh` PASS (`29 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-mfe-footer-plugin-slot.sh` PASS (`9 PASS / 0 FAIL / 1 SKIP`)

## Progress Update (Phase 5, footer verifier tranche)

- Extended compatibility-layer adoption to additional footer-focused QA verifiers:
  - `scripts/qa/verify-footer-parity.sh`
  - `scripts/qa/verify-footer-slot-migration.sh`
  - `scripts/qa/verify-footer-variant-matrix.sh`
  - `scripts/qa/verify-legacy-footer-removal.sh`
  - `scripts/qa/verify-mfe-footer-slot-migration.sh`
  - `scripts/qa/verify-mfe-footer-fallbacks.sh`
- Outcome:
  - direct path-coupling reduced from `86` to `73`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - pass/fail behavior preserved; one known baseline failure set in legacy-footer-removal remains unchanged and non-regression.

Validation after phase 5:
- `./scripts/qa/verify-footer-parity.sh` PASS (`PASS=77 FAIL=0 WARN=1 SKIP=1`)
- `./scripts/qa/verify-footer-slot-migration.sh` PASS (`PASS=30 FAIL=0 WARN=1`)
- `./scripts/qa/verify-footer-variant-matrix.sh` PASS (`29 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-legacy-footer-removal.sh` baseline FAIL unchanged (`PASS=26 FAIL=3 WARN=3`):
  - expects literal `"footer_slot"` marker that is not present in canonical plugin source
  - expects literal `"DIRECT_PLUGIN"` marker that is not present in canonical plugin source
  - expects legacy apply-patches component marker that current plugin-first path no longer uses
- `./scripts/qa/verify-mfe-footer-slot-migration.sh` PASS (`PASS=53 FAIL=0 WARN=0`)
- `./scripts/qa/verify-mfe-footer-fallbacks.sh` PASS (`PASS=14 FAIL=0 WARN=2 SKIP=0`)

## Why Full Split Is Blocked Right Now

A hard split (moving major hook payload strings into separate files/modules) will immediately invalidate path-sensitive and text-sensitive QA gates unless those gates are migrated in the same change set. Doing that safely is a broad refactor and conflicts with the current priority: runtime stabilization and deterministic frontend evidence closure.

## Decision (2026-03-02, updated)

- `#109` is **in staged execution** (phase 1 + phase 2 + phase 3 + phase 4 + phase 5 complete).
- Broad one-shot decomposition remains out-of-scope for this lane.
- Next safe move is section-by-section extraction with compatibility-gate coverage already in place.

## Safe Staged Plan (post-stability)

1. [x] Add a compatibility contract layer for QA checks (allow `mereka_lms.py` + split modules).
2. [ ] Move one section at a time (e.g., footer/component slot definitions first), preserving exported symbols and behavior.
3. Run targeted gates after each section move (`verify-plugin-slot-wiring.sh`, `verify-paragon-theme-urls.sh`, `verify-analytics-hardening.sh`, etc.).
4. Keep one logical move per commit; avoid mixed runtime changes in split commits.

## Evidence Commands

```bash
wc -l infrastructure/tutor/plugins/mereka_lms.py
rg -n "infrastructure/tutor/plugins/mereka_lms.py" scripts/qa | wc -l
```
