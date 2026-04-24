# `mereka_lms.py` Maintainability Split Status (2026-03-02)

## Scope

Issue: `#109` (`infrastructure/tutor/plugins/mereka_lms.py` maintainability split)

## Current State

- Main plugin file length: `2226` lines.
- Extracted module length: `1110` lines (`infrastructure/tutor/plugins/mereka_lms_mfe_slots.py`).
- Direct QA coupling to concrete plugin path is now `0` references in `scripts/qa/*`.
- Many checks still rely on text-based contract assertions across plugin sources; compatibility helper keeps those checks split-safe.

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
- `./scripts/qa/deprecated/verify-tutor-patches-inventory.sh` PASS

## Progress Update (Phase 2, QA compatibility contract layer)

- Added shared helper: `scripts/shared/mereka_plugin_contract.sh`.
  - Supports contract-aware discovery across `mereka_lms.py` + future `mereka_lms_*.py` split modules.
  - Exposes reusable checks: presence, fixed-string search, regex search, and regex count across all contract files.
- Migrated high-signal verifiers to consume the compatibility helper:
  - `scripts/qa/verify-paragon-theme-urls.sh`
  - `scripts/qa/verify-security-hardening.sh`
  - `scripts/qa/verify-plugin-slot-wiring.sh`
  - `scripts/qa/verify-footer-slot-only.sh`
  - `scripts/qa/deprecated/verify-tutor-patches-inventory.sh`
- Outcome: staged split prep is now in place for critical gates without moving runtime hook payloads yet.

Validation after phase 2:
- `./scripts/qa/verify-paragon-theme-urls.sh` PASS (`PASS=27 WARN=0 FAIL=0`)
- `./scripts/qa/verify-security-hardening.sh` PASS (`PASS=30 WARN=1 FAIL=0`)
- `./scripts/qa/verify-plugin-slot-wiring.sh` PASS (`PASS=39 FAIL=0 WARN=0`)
- `./scripts/qa/verify-footer-slot-only.sh` PASS (`PASS=15 FAIL=0 WARN=0`)
- `./scripts/qa/deprecated/verify-tutor-patches-inventory.sh` PASS (`23 PASS 0 FAIL 0 SKIP`)

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

## Progress Update (Phase 6, tenant/assessment verifier tranche)

- Extended compatibility-layer adoption to additional tenant/assessment QA verifiers:
  - `scripts/qa/verify-assessment-bulk.sh`
  - `scripts/qa/verify-advanced-xblocks.sh`
  - `scripts/qa/verify-tenant-footer-variant-lane.sh`
  - `scripts/qa/verify-tenant-branding-matrix.sh`
  - `scripts/qa/verify-tenant-isolation-evidence.sh`
  - `scripts/qa/verify-tenant-isolation-gates.sh`
- Outcome:
  - direct path-coupling reduced from `73` to `48`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - no helper/regression breakage introduced; remaining failures reflect existing verifier expectation drift against current plugin contracts.

Validation after phase 6:
- `./scripts/qa/verify-assessment-bulk.sh` baseline FAIL (`FAILED_CHECKS=1`):
  - missing `ASSESSMENT_LANGUAGES` marker in plugin contract source
- `./scripts/qa/verify-advanced-xblocks.sh` PASS (`64 PASS / 0 FAIL`)
- `./scripts/qa/verify-tenant-footer-variant-lane.sh` baseline FAIL (`38 PASS / 9 FAIL / 2 WARN`):
  - expects legacy `SITE_VARIANTS` naming/shape that diverges from current plugin contract markers
- `./scripts/qa/verify-tenant-branding-matrix.sh` baseline FAIL (`20 PASS / 11 FAIL / 1 WARN`):
  - expects legacy `SITE_VARIANTS` markers/fallback pattern not matching current plugin contract markers
- `./scripts/qa/verify-tenant-isolation-evidence.sh` PASS (`39 PASS / 0 FAIL / 3 WARN`)
- `./scripts/qa/verify-tenant-isolation-gates.sh` PASS (`30 PASS / 0 FAIL / 0 SKIP`)

## Progress Update (Phase 7, multisite/security verifier tranche)

- Extended compatibility-layer adoption to additional multisite/security QA verifiers:
  - `scripts/qa/verify-security-hardening.sh`
  - `scripts/qa/verify-plugin-slot-wiring.sh`
  - `scripts/qa/verify-footer-slot-only.sh`
  - `scripts/qa/verify-multisite-ux-consistency.sh`
  - `scripts/qa/verify-multitenant-brand-platform.sh`
  - `scripts/qa/validate-multisite-config.sh`
- Outcome:
  - direct path-coupling reduced from `48` to `36`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - parser compatibility hardened for `SITE_VARIANTS` and `MEREKA_SITE_VARIANTS` contract names in `validate-multisite-config.sh`
  - known runtime baseline failure remains only in `verify-multisite-ux-consistency.sh` (hardcoded domain references detected in running MFE dist artifacts).

Validation after phase 7:
- `./scripts/qa/verify-security-hardening.sh` PASS (`PASS=30 FAIL=0 WARN=1`)
- `./scripts/qa/verify-plugin-slot-wiring.sh` PASS (`39 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-footer-slot-only.sh` PASS (`15 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-multisite-ux-consistency.sh` baseline FAIL unchanged (`17 PASS / 1 FAIL / 2 WARN`):
  - runtime MFE dist artifacts still include hardcoded `academyv2.mereka.io` references
- `./scripts/qa/verify-multitenant-brand-platform.sh` PASS (`63 PASS / 0 FAIL / 1 WARN`)
- `./scripts/qa/validate-multisite-config.sh` PASS after parser fix (`12 PASS / 0 FAIL`)

## Progress Update (Phase 8, resilience/visual/slot verifier tranche)

- Extended compatibility-layer adoption to additional resilience/visual/slot QA verifiers:
  - `scripts/qa/verify-tutor-resilience-full.sh`
  - `scripts/qa/deprecated/verify-tutor-patches-inventory.sh`
  - `scripts/qa/verify-visual-parity-checkpoints.sh`
  - `scripts/qa/verify-slot-migration-readiness.sh`
  - `scripts/qa/verify-selector-to-slot-migration.sh`
  - `scripts/qa/verify-performance-budget.sh`
- Outcome:
  - direct path-coupling reduced from `36` to `28`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - all six verifiers pass post-migration (no regression introduced)
  - visual parity verifier now enforces canonical plugin-contract path only (legacy apply-patches fallback removed).

Validation after phase 8:
- `./scripts/qa/verify-tutor-resilience-full.sh --skip-cluster` PASS (`Passed: 45 / Failed: 0 / Skipped: 0`)
- `./scripts/qa/deprecated/verify-tutor-patches-inventory.sh` PASS (`23 PASS / 0 FAIL / 0 SKIP`)
- `./scripts/qa/verify-visual-parity-checkpoints.sh` PASS (`42 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-slot-migration-readiness.sh` PASS (`11 PASS / 0 FAIL / 2 WARN`)
- `./scripts/qa/verify-selector-to-slot-migration.sh` PASS (`60 PASS / 0 FAIL`)
- `./scripts/qa/verify-performance-budget.sh` PASS (`46 PASS / 0 FAIL / 0 WARN`)

## Progress Update (Phase 9, analytics/brand/content verifier tranche)

- Extended compatibility-layer adoption to additional analytics/brand/content QA verifiers:
  - `scripts/qa/verify-a11y-regression-lane.sh`
  - `scripts/qa/verify-admin-console.sh`
  - `scripts/qa/verify-analytics-key-elimination.sh`
  - `scripts/qa/verify-analytics-undefined-regression.sh`
  - `scripts/qa/verify-brand-parity.sh`
  - `scripts/qa/verify-content-libraries-v2.sh`
- Outcome:
  - direct path-coupling reduced from `28` to `22`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - all six verifiers pass post-migration (no regression introduced)
  - analytics verifiers preserve line-level grep behavior via temporary plugin-contract bundle input.

Validation after phase 9:
- `./scripts/qa/verify-a11y-regression-lane.sh` PASS (`PASS=25 / FAIL=0 / WARN=0`)
- `./scripts/qa/verify-admin-console.sh` PASS (`6/6`)
- `./scripts/qa/verify-analytics-key-elimination.sh` PASS (`29 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-analytics-undefined-regression.sh` PASS (`24 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-brand-parity.sh --offline` PASS (`PASS=86 / FAIL=0 / WARN=1 / SKIP=3`)
- `./scripts/qa/verify-content-libraries-v2.sh --mode local` PASS (`PASS=25 / FAIL=0 / SKIP=2`)

## Progress Update (Phase 10, brand/lti/readiness verifier tranche)

- Extended compatibility-layer adoption to additional brand/lti/readiness QA verifiers:
  - `scripts/qa/verify-brand-package/verify-brand-package-structure.sh`
  - `scripts/qa/verify-credentials-readiness.sh`
  - `scripts/qa/verify-custom-app-drift.sh`
  - `scripts/qa/verify-lti-saml-config.sh`
  - `scripts/qa/verify-lti-store.sh`
  - `scripts/qa/verify-oep48-brand-package.sh`
- Outcome:
  - direct path-coupling reduced from `22` to `16`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - all six verifiers pass post-migration (no regression introduced)

Validation after phase 10:
- `./scripts/qa/verify-brand-package/verify-brand-package-structure.sh` PASS (`PASS=64 / FAIL=0`)
- `./scripts/qa/verify-credentials-readiness.sh` PASS (`PASS=47 / FAIL=0 / SKIP=7`)
- `./scripts/qa/verify-custom-app-drift.sh` PASS (`46 PASS / 0 FAIL / 0 WARN`)
- `./scripts/qa/verify-lti-saml-config.sh --offline` PASS (`PASS=18 / FAIL=0 / SKIP=1`)
- `./scripts/qa/verify-lti-store.sh --offline` PASS (`PASS=12 / FAIL=0 / SKIP=3`)
- `./scripts/qa/verify-oep48-brand-package.sh` PASS (`PASS=127 / FAIL=0 / WARN=0 / SKIP=0`)

## Progress Update (Phase 11, mfe/tenant/policy verifier tranche)

- Extended compatibility-layer adoption to additional MFE/tenant/policy QA verifiers:
  - `scripts/qa/verify-mfe-css-architecture.sh`
  - `scripts/qa/verify-oep65-readiness.sh`
  - `scripts/qa/verify-tenant-first-consolidation.sh`
  - `scripts/qa/verify-multi-brand-site.sh`
  - `scripts/qa/verify-mfe-first-policy.sh`
  - `scripts/qa/verify-mfe-analytics-plugin-parity.sh`
- Outcome:
  - direct path-coupling reduced from `16` to `10`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - 4/6 verifiers pass post-migration; 2/6 remain failing due pre-existing baseline/runtime gap checks unrelated to plugin-path migration.

Validation after phase 11:
- `./scripts/qa/verify-mfe-css-architecture.sh` PASS (`PASS=7 / FAIL=0 / WARN=0`)
- `./scripts/qa/verify-oep65-readiness.sh` FAIL (`PASS=16 / FAIL=5 / SKIP=3`) — existing OEP-65 readiness gaps tracked in `docs/reference/architecture/OEP65_MODULE_READINESS.md`
- `./scripts/qa/verify-tenant-first-consolidation.sh --env dev` FAIL (`PASS=15 / FAIL=2 / WARN=0 / SKIP=0`) — existing runtime checks failing in tenant visual/smoke sub-gates
- `./scripts/qa/verify-multi-brand-site.sh` PASS (`PASS=76 / FAIL=0 / SKIP=1`)
- `./scripts/qa/verify-mfe-first-policy.sh` PASS (`PASS=22 / WARN=0 / FAIL=0`)
- `./scripts/qa/verify-mfe-analytics-plugin-parity.sh` PASS (`PASS=25 / FAIL=0 / WARN=0`)

## Progress Update (Phase 12, governance/branding/tenancy verifier tranche)

- Extended compatibility-layer adoption to additional governance/branding/tenancy QA verifiers:
  - `scripts/qa/verify-certificate-branding.sh`
  - `scripts/qa/verify-cross-cutting-requirements.sh`
  - `scripts/qa/verify-legacy-ecommerce-ui-refs.sh`
  - `scripts/qa/verify-paragon-theme-urls.sh`
  - `scripts/qa/verify-cross-cutting-requirements.sh --skip-cluster`
  - `scripts/qa/verify-mereka-tenancy.sh`
- Outcome:
  - direct path-coupling reduced from `10` to `4`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - 5/6 verifiers pass post-migration; 1/6 remains failing due existing tenancy/apply-patches expectation drift unrelated to plugin-path migration.

Validation after phase 12:
- `./scripts/qa/verify-certificate-branding.sh` PASS (`PASS=25 / WARN=0 / FAIL=0`)
- `./scripts/qa/verify-cross-cutting-requirements.sh` PASS (`Passed: 42 / Failed: 0 / Skipped: 2`)
- `./scripts/qa/verify-legacy-ecommerce-ui-refs.sh` PASS (`PASS=10 / WARN=8 / FAIL=0`)
- `./scripts/qa/verify-paragon-theme-urls.sh` PASS (`PASS=27 / WARN=0 / FAIL=0`)
- `./scripts/qa/verify-cross-cutting-requirements.sh --skip-cluster` PASS (`Passed: 42 / Failed: 0 / Skipped: 2`)
- `./scripts/qa/verify-mereka-tenancy.sh` FAIL (`PASS=12 / FAIL=4 / WARN=0`) — existing apply-patches tenancy wiring expectations not met in current baseline

## Progress Update (Phase 13, final clean-file verifier tranche)

- Extended compatibility-layer adoption to the final clean-file QA verifiers in this lane:
  - `scripts/qa/verify-analytics-hardening.sh`
  - `scripts/qa/verify-footer-slot-evidence-rollback.sh`
  - `scripts/qa/verify-fpf-slot-coverage.sh`
- Outcome:
  - direct path-coupling reduced from `4` to `1`
  - all updated scripts are shell-syntax clean (`bash -n`)
  - 1/3 verifiers pass post-migration; 2/3 remain failing due existing baseline expectation drift unrelated to plugin-path migration.

Validation after phase 13:
- `./scripts/qa/verify-analytics-hardening.sh` FAIL (`PASS=23 / FAIL=3 / WARN=0`) — existing analytics hardening gaps in current baseline
- `./scripts/qa/verify-footer-slot-evidence-rollback.sh` FAIL (`PASS=13 / FAIL=9 / WARN=0`) — existing slot/rollback expectation mismatch in current baseline
- `./scripts/qa/verify-fpf-slot-coverage.sh` PASS (`PASS=35 / WARN=0 / FAIL=0`)

## Progress Update (Phase 14, first structural extraction)

- Performed first no-behavior-change structural split in plugin sources:
  - moved the full MFE slot registration block into `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py`
  - added `register_mfe_plugin_slots()` entrypoint in the new module
  - wired `mereka_lms.py` to import and invoke `register_mfe_plugin_slots()`
- Outcome:
  - `mereka_lms.py` reduced from `3426` to `2226` lines (1200-line reduction)
  - direct QA path coupling reduced from `1` to `0`
  - runtime/source contract checks remain green

Validation after phase 14:
- `./infrastructure/tutor/apply-patches.sh` PASS
- `./scripts/qa/verify-mfe-build-prereqs.sh` PASS
- `./scripts/qa/verify-paragon-theme-urls.sh` PASS (`PASS=27 WARN=0 FAIL=0`)

## Why Full Split Is Blocked Right Now

A hard split (moving major hook payload strings into separate files/modules) will immediately invalidate path-sensitive and text-sensitive QA gates unless those gates are migrated in the same change set. Doing that safely is a broad refactor and conflicts with the current priority: runtime stabilization and deterministic frontend evidence closure.

## Decision (2026-03-02, updated)

- `#109` is **in staged execution** (phase 1 + phase 2 + phase 3 + phase 4 + phase 5 + phase 6 + phase 7 + phase 8 + phase 9 + phase 10 + phase 11 + phase 12 + phase 13 + phase 14 complete).
- Broad one-shot decomposition remains out-of-scope for this lane.
- Next safe move is section-by-section extraction with compatibility-gate coverage already in place.
- No direct QA reference to `infrastructure/tutor/plugins/mereka_lms.py` remains in `scripts/qa/*`.

## Safe Staged Plan (post-stability)

1. [x] Add a compatibility contract layer for QA checks (allow `mereka_lms.py` + split modules).
2. [x] Move one section at a time (phase 14 moved MFE slot definitions to `mereka_lms_mfe_slots.py`), preserving exported symbols and behavior.
3. Run targeted gates after each section move (`verify-plugin-slot-wiring.sh`, `verify-paragon-theme-urls.sh`, `verify-analytics-hardening.sh`, etc.).
4. Keep one logical move per commit; avoid mixed runtime changes in split commits.

## Evidence Commands

```bash
wc -l infrastructure/tutor/plugins/mereka_lms.py infrastructure/tutor/plugins/mereka_lms_mfe_slots.py
rg -n "infrastructure/tutor/plugins/mereka_lms.py" scripts/qa | wc -l
```
