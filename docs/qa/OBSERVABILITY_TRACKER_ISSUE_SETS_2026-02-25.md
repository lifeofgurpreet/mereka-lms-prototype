# Observability Tracker Issue Sets (Mereka LMS)

> Status: Archive-candidate for current execution flow.
> This file is retained for historical tracker context only.
> Active execution source of truth is `docs/qa/OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md`
> and `.github/workflows/observability-compliance.yml`.

Date: 2026-02-25  
Scope: Tracker-ready issue sets for first-class observability execution

## 1) Parent issue

Title: `OBS-COMPLIANCE-01: First-class observability parity for Mereka LMS`

Description:
- Establish strict observability parity across `local`, `rke2-nonprod`, and `production`.
- Close all open observability validation AC gaps with runtime evidence.
- Track dependencies across monitor coverage, alert rule load, app metrics readiness, and CI/runtime compliance gates.

Acceptance Criteria:
- `AC-OBS-001`: Parent has linked child issues `OBS-A` through `OBS-F`.
- `AC-OBS-002`: All child issues include explicit AC mappings and done criteria.
- `AC-OBS-003`: Parent is not closed until all child issues are closed with evidence artifacts.

## 2) Child issue sets

### OBS-A
Title: `OBS-A: Runtime scrape parity validation for required ServiceMonitors`
- Status in repo: manifests implemented.
- Scope now: runtime evidence only.
- AC mapping: `AC-OVR-001`, `AC-OVR-002`, `AC-OVR-003`, `AC-OVR-004`.
- Done when:
- `audit-observability --mode runtime` confirms required services are scraped in nonprod + production.
- Evidence artifact is attached with successful checks for `caddy`, `mfe`, `forum`, `discovery`, `ecommerce`, `credentials`, `purchase-gateway`.

### OBS-B
Title: `OBS-B: Runtime rule-load parity for caddy/services alert rules`
- Status in repo: manifests implemented.
- Scope now: runtime evidence only.
- AC mapping: `AC-OVR-005`, `AC-OVR-008`, `AC-OVR-009`, `AC-OVR-010`.
- Done when:
- Prometheus runtime rules API confirms required caddy + service rules are loaded in nonprod + production.
- Alert rule names and severities match repo manifests.

### OBS-C
Title: `OBS-C: Deterministic compliance gate evidence package`
- Scope: make strict compliance script deterministic and evidence-producing in local/runtime modes.
- AC mapping: `AC-OVR-024`, `AC-OVR-025`, `AC-OVR-026`, `AC-OVR-027`, `AC-OVR-028`, `AC-OVR-029`.
- Done when:
- `scripts/qa/validate-observability-compliance.sh` returns deterministic pass/fail with JSON evidence.
- No hangs under unavailable cluster conditions.
- Negative-control AC checks fail as expected with clear diagnostics.

### OBS-D
Title: `OBS-D: LMS/CMS app metrics reliability closure`
- Scope: resolve LMS/CMS `/metrics` reliability so SLI queries are production-usable.
- AC mapping: `AC-OVR-012`, `AC-OVR-013`, `AC-OVR-014`, `AC-OVR-015`.
- Done when:
- LMS/CMS expose stable app metrics.
- SLI queries are non-empty and usable for alert/SLO policy.

### OBS-E
Title: `OBS-E: CI strict gate for observability compliance`
- Scope: enforce observability compliance workflow as release-readiness guard.
- AC mapping: `AC-OVR-024` through `AC-OVR-031` (relevant implemented checks).
- Done when:
- CI fails on mandatory compliance gaps.
- CI artifacts include actionable failure diagnostics.

### OBS-F
Title: `OBS-F: Parity policy codification and operator handoff`
- Scope: codify non-prod parity semantics and execution ownership in docs and tracker.
- AC mapping: process control.
- Done when:
- `local` vs `rke2-nonprod` vs `production` parity policy is explicit in observability ownership docs.
- On-call and release-readiness docs reference same parity contract.

## 3) Suggested dependency graph

1. `OBS-A` and `OBS-B` can run in parallel.
2. `OBS-C` depends on baseline script stability and can start in parallel with `OBS-A/B`.
3. `OBS-D` depends on app metrics implementation and should start after `OBS-C` baseline is stable.
4. `OBS-E` depends on `OBS-C` and at least one runtime evidence pass from `OBS-A/B`.
5. `OBS-F` can start early but must complete before parent closure.

## 4) `br` command batch (copy/paste once tracker runtime is healthy)

```bash
br create "OBS-COMPLIANCE-01: First-class observability parity for Mereka LMS" -t epic -p 1 -d "Parent issue for observability parity execution across local/rke2-nonprod/production with strict AC-based closure."
br create "OBS-A: Runtime scrape parity validation for required ServiceMonitors" -t task -p 1 -d "Runtime evidence for required ServiceMonitors. @covers AC-OVR-001 AC-OVR-002 AC-OVR-003 AC-OVR-004"
br create "OBS-B: Runtime rule-load parity for caddy/services alert rules" -t task -p 1 -d "Runtime evidence for alert rule load and parity. @covers AC-OVR-005 AC-OVR-008 AC-OVR-009 AC-OVR-010"
br create "OBS-C: Deterministic compliance gate evidence package" -t task -p 1 -d "Deterministic local/runtime validation + JSON evidence. @covers AC-OVR-024 AC-OVR-025 AC-OVR-026 AC-OVR-027 AC-OVR-028 AC-OVR-029"
br create "OBS-D: LMS/CMS app metrics reliability closure" -t task -p 1 -d "Make LMS/CMS metrics reliable for SLI use. @covers AC-OVR-012 AC-OVR-013 AC-OVR-014 AC-OVR-015"
br create "OBS-E: CI strict gate for observability compliance" -t task -p 1 -d "Enforce observability compliance in CI/runtime workflows. @covers AC-OVR-024 AC-OVR-025 AC-OVR-026 AC-OVR-027 AC-OVR-028 AC-OVR-029 AC-OVR-030 AC-OVR-031"
br create "OBS-F: Parity policy codification and operator handoff" -t docs -p 2 -d "Document and enforce observability parity ownership and handoff policy."
```

## 5) Evidence file convention

Use:
- `docs/archive/evidence/observability/<issue-id>-<UTC_TIMESTAMP>.md`

Recommended command:
```bash
ts="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
mkdir -p docs/archive/evidence/observability
touch "docs/archive/evidence/observability/OBS-COMPLIANCE-01-${ts}.md"
```
