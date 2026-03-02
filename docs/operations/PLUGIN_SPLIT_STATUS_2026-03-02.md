# `mereka_lms.py` Maintainability Split Status (2026-03-02)

## Scope

Issue: `#109` (`infrastructure/tutor/plugins/mereka_lms.py` maintainability split)

## Current State

- Plugin file length: `3426` lines.
- Direct QA coupling remains high: `98` references inside `scripts/qa/*` to the concrete file path `infrastructure/tutor/plugins/mereka_lms.py`.
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

## Why Full Split Is Blocked Right Now

A hard split (moving major hook payload strings into separate files/modules) will immediately invalidate path-sensitive and text-sensitive QA gates unless those gates are migrated in the same change set. Doing that safely is a broad refactor and conflicts with the current priority: runtime stabilization and deterministic frontend evidence closure.

## Decision (2026-03-02, updated)

- `#109` is **in staged execution** (phase 1 + phase 2 complete).
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
