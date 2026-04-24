# Mereka LMS Observability Review & Implementation Blueprint (Execution Ready)

> Status: Archive-candidate (historical context only).
> Use `docs/status/readiness/OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md` and
> `.github/workflows/observability-compliance.yml` as the active execution contract.

Date: 2026-02-25
Scope: `mereka-lms` repository only, with downstream vendoring impact noted.

## 1) Where we are today

### 1.1 Live / already baked in

- Monitoring stack and automation are defined in repo.
  - `deploy/k8s/base/monitoring/*`
  - `deploy/k8s/base/monitoring/kustomization.yaml`
  - `scripts/qa/audit-observability.sh`
  - `scripts/qa/verify-observability-stack.sh`
  - `scripts/qa/verify-observability-runtime.sh`
- Existing live service telemetry scope includes:
  - `servicemonitor-lms`
  - `servicemonitor-cms`
  - `servicemonitor-mysql`
  - `servicemonitor-redis`
  - `servicemonitor-enterprise`
  - `servicemonitor-xqueue`
  - `servicemonitor-mux`
  - `servicemonitor-caddy`
  - `servicemonitor-mfe`
  - `servicemonitor-forum`
  - `servicemonitor-discovery`
  - `servicemonitor-ecommerce`
  - `servicemonitor-credentials`
  - `servicemonitor-purchase-gateway`
- Existing live alert scope includes:
  - `prometheusrule-lms`
  - `prometheusrule-velero`
  - `prometheusrule-slo`
  - `prometheusrule-xqueue`
  - `prometheusrule-ora2`
  - `prometheusrule-auth`
  - `prometheusrule-email`
  - `prometheusrule-video`
  - `prometheusrule-libraries`
  - `prometheusrule-externalsecrets`
  - `prometheusrule-tenant-isolation`
  - `prometheusrule-caddy`
  - `prometheusrule-services`
- SLO burn-rate reference exists as `slo-burn-rate-rules.yaml`.

### 1.2 What is not live / incomplete

- Runtime proof is still incomplete for strict first-class observability sign-off (manifest presence is not enough).
- `LMS/CMS /metrics` readiness remains a known reliability concern in existing status notes (`HTTP 400` observed in `IMPLEMENTATION_STATUS.md`).
- Tracker ownership is still missing for observability-specific AC closure (`AC-OVR-*`) in current open/in-progress work.
- `br` tracker CLI is currently unstable in this environment, so issue creation requires either manual import or a repaired tracker runtime.

## 2) Live by environment mapping (Mereka LMS repo perspective)

- `deploy/k8s/base/monitoring` is authoritative for monitor/alerts.
- All environment overlays in this repo inherit base unless they explicitly override or remove items.
- Therefore, if a monitor/alert is missing from base, it is missing across environments.
- Current practical parity interpretation from existing repo guidance:
  - local: fast feedback surface.
  - nonprod/staging-equivalent (`rke2-nonprod`): should include full parity baseline.
  - production: should follow same base with environment-safe deltas only.

## 3) What this means operationally

- The observability framework is live.
- Coverage is still partial and not first-class yet.
- We are in “contract-ready foundation + missing service/parity surfaces” state.
- The first release blocker is service coverage + alert closure, not base tooling availability.

## 4) Tracker-ready AC plan for implementation

### OBS-FOUNDATION-A
Title: ServiceMonitor surface closure for non-LMS services
- Status: implemented in manifests.
- Scope delivered: `servicemonitor-caddy`, `servicemonitor-mfe`, `servicemonitor-forum`, `servicemonitor-discovery`, `servicemonitor-ecommerce`, `servicemonitor-credentials`, and purchase gateway service monitor wiring through `services/purchase-gateway/k8s/kustomization.yaml`.
- AC mapping: `AC-OVR-001`, `AC-OVR-002`, `AC-OVR-003`, `AC-OVR-004`.
- Remaining action: runtime scrape verification evidence in nonprod + production lanes.

### OBS-FOUNDATION-B
Title: Service alert-rule closure for edge and supporting services
- Status: implemented in manifests.
- Scope delivered: `prometheusrule-caddy.yaml`, `prometheusrule-services.yaml`, and supporting required rule coverage in base monitoring kustomization.
- AC mapping: `AC-OVR-005`, `AC-OVR-008`, `AC-OVR-009`, `AC-OVR-010`.
- Remaining action: confirm Prometheus loads active rules in runtime (`/api/v1/rules`) for both parity lanes.

### OBS-FOUNDATION-C
Title: Runtime proof package for observability parity
- Scope: execute strict local/runtime validation and collect evidence for nonprod + production.
- Files: `scripts/qa/validate-observability-compliance.sh`, `scripts/qa/verify-observability-runtime.sh`, `docs/qa/`.
- AC mapping: `AC-OVR-024`, `AC-OVR-025`, `AC-OVR-026`, `AC-OVR-027`, `AC-OVR-028`, `AC-OVR-029`.
- Done criteria: strict gates pass or fail with deterministic evidence artifacts (no hangs, no manual TODO exceptions).

### OBS-FOUNDATION-D
Title: Close app-level SLI gap (LMS/CMS /metrics quality)
- Scope: make app metrics endpoint reliable and SLI-safe for Prometheus queries.
- Files: OpenedX image/settings and relevant monitoring wiring.
- AC mapping: `AC-OVR-012`, `AC-OVR-013`, `AC-OVR-014`, `AC-OVR-015`.
- Done criteria: `/metrics` returns stable high-signal series for LMS/CMS.
 - Status: pending implementation.

### OBS-GATE-E (mandatory before release claim)
Title: Implement observability compliance script and strict gate path
- Scope: finalize runtime behavior and CI strictness for `scripts/qa/validate-observability-compliance.sh`; complete runtime/local checks and strict fail mode.
- Files: `scripts/qa/validate-observability-compliance.sh`
- AC mapping: `AC-OVR-024` through `AC-OVR-031` where relevant.
- Done criteria: no TODO bypasses, structured evidence output, strict mode blocks missing mandatory items.
 - Status: implementation landed; runtime/CI hardening still pending final sign-off.

### OBS-PROCESS-F
Title: Create canonical tracker and execution dependencies
- Scope: create one parent issue for all observability implementation with child issues A-E.
- AC mapping: process-only control, no direct AC ID.
- Done criteria: all children assigned, dependency graph created, no ambiguous ownership.
 - Status: pending (blocked by `br` CLI instability in current environment).

## 5) Implementation order (strict)

1. OBS-FOUNDATION-A
2. OBS-FOUNDATION-B
3. OBS-FOUNDATION-C
4. OBS-GATE-E
5. OBS-FOUNDATION-D
6. OBS-PROCESS-F

## 6) Evidence required before handoff

- Manifest diff summary showing added/removed/retained monitoring resources.
- Runtime check results from `scripts/qa/run-observability-first-class.sh --mode runtime`.
- Metric scrape proof for newly added ServiceMonitors.
- Alert presence proof from Prometheus rules endpoint or rule selector queries.
- `/metrics` validation evidence from LMS and CMS.
- Tracker status snapshot with child dependencies closed only when done criteria pass.
