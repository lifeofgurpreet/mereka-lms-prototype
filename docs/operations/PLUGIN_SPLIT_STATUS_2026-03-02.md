# `mereka_lms.py` Maintainability Split Status (2026-03-02)

## Scope

Issue: `#109` (`infrastructure/tutor/plugins/mereka_lms.py` maintainability split)

## Current State

- Plugin file length: `3460` lines.
- Direct QA coupling: `96` references inside `scripts/qa/*` to the concrete file path `infrastructure/tutor/plugins/mereka_lms.py`.
- Many checks currently rely on direct `grep` against the monolithic file for contract assertions (slots, token keys, theme URLs, tenant wiring, analytics guardrails).

## Why Full Split Is Blocked Right Now

A hard split (moving major hook payload strings into separate files/modules) will immediately invalidate path-sensitive and text-sensitive QA gates unless those gates are migrated in the same change set. Doing that safely is a broad refactor and conflicts with the current priority: runtime stabilization and deterministic frontend evidence closure.

## Decision (2026-03-02)

- `#109` is **explicitly blocked / staged** pending runtime stabilization completion.
- No broad plugin decomposition is performed in this lane.
- Runtime-facing work remains prioritized (`#105`, `#107`, `#108`, `#106`, `#111` decisioning).

## Safe Staged Plan (post-stability)

1. Add a compatibility contract layer for QA checks (allow `mereka_lms.py` + split modules).
2. Move one section at a time (e.g., footer/component slot definitions first), preserving exported symbols and behavior.
3. Run targeted gates after each section move (`verify-plugin-slot-wiring.sh`, `verify-paragon-theme-urls.sh`, `verify-analytics-hardening.sh`, etc.).
4. Keep one logical move per commit; avoid mixed runtime changes in split commits.

## Evidence Commands

```bash
wc -l infrastructure/tutor/plugins/mereka_lms.py
rg -n "infrastructure/tutor/plugins/mereka_lms.py" scripts/qa | wc -l
```
