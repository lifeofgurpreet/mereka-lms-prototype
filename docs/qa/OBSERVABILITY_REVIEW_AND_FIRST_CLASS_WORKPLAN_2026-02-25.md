# Mereka LMS Observability Review & Work Plan (Reviewer pass, no implementation)

> Status: Archive-candidate (historical context only).
> Use `docs/qa/OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md` and
> `.github/workflows/observability-compliance.yml` as the active execution contract.

Date: 2026-02-25
Author: Codex (review/plan mode)
Scope: Observability for Open edX (Mereka LMS) across local/dev/staging/prod and VPS/BBI boundaries.

## Executive summary
- I reviewed `mereka-lms`, `bbi-infrastructure`, and `vps/infrastructure` and confirmed observability is split across repos:
  - App-level telemetry manifests live in `mereka-lms` and are vendored into `bbi-infrastructure`.
  - Platform/cluster telemetry lives in `bbi-infrastructure/platform/monitoring`.
  - VPS observability is mostly standalone/service-specific and scoped as non-production, not a replacement for BBI Kubernetes monitoring.
- In current state, production and staging overlays are not fully parity-aligned with local/dev in monitored surfaces.
- The main risks are: missing ServiceMonitors/alerts for critical non-LMS services, weak parity in overlay composition, and incomplete platform-to-workload visibility continuity.

## Repo ownership map (what belongs where)

### `mereka-lms`
- Open edX service monitoring manifests:
  - `deploy/k8s/base/monitoring/*`
- Monitoring kustomization that references local monitoring stack assets:
  - `deploy/k8s/base/monitoring/kustomization.yaml`
- App readiness/observability guidance and current gap notes:
  - `docs/qa/OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md`

### `bbi-infrastructure`
- GitOps app source for Mereka LMS (vendored `mereka-lms` base):
  - `apps/mereka-lms/base/kustomization.yaml`
  - `apps/mereka-lms/vendor/mereka-lms/deploy/k8s/base/monitoring/*`
- Environment overlays and profile wiring:
  - `apps/mereka-lms/overlays/local/kustomization.yaml`
  - `apps/mereka-lms/overlays/dev/kustomization.yaml`
  - `apps/mereka-lms/overlays/staging/kustomization.yaml`
  - `apps/mereka-lms/overlays/prod/kustomization.yaml`
  - `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml`
  - `apps/mereka-lms/overlays/profiles/staging/kustomization.yaml`
- Platform monitoring and checklists:
  - `platform/monitoring/*`

### `vps/infrastructure`
- VPS-specific observability scope, specs, and runbooks for standalone/non-Kubernetes services:
  - `observability/*`
- This repo is documented as development-only for VPS standalone workloads; Kubernetes observability ownership remains in BBI.

## What is currently live (as of this review)

### In `mereka-lms`
- Base monitoring for LMS/CMS and DB components exists.
- `slo-burn-rate-rules.yaml` is present in repo base monitoring list.

### In GitOps app rendering (`bbi-infrastructure`)
- Vendored mirror of `mereka-lms` monitoring exists, but the mirror set does not currently include the same `slo-burn-rate-rules.yaml` inclusion in its kustomization path.
- Local overlay contains more detailed exporter resources than staging/prod overlays.
- Staging/prod overlays currently appear to consume `base` directly and do not automatically include `local` monitoring extras unless explicitly wired.
- Dev profile can include local extras via profile indirection, but staging profile composition is inconsistent due direct staging overlay usage.

### In VPS infrastructure
- Observability docs and contracts exist for VPS standalone services, but this does not provide full parity for Kubernetes production workloads.

## Gap analysis (reviewer findings)

### 1) Non-production parity gap (dev/staging vs prod)
- Missing parity contract between local/dev monitoring surfaces and production/staging.
- Dev profile benefits from local monitoring includes; production/staging overlays are narrower and do not include equivalent service export coverage.

### 2) Missing service telemetry coverage
- Existing first-class readiness notes already identify missing monitored services:
  - `caddy`
  - `mfe`
  - `forum`
  - `discovery`
  - `ecommerce`
  - `credentials`
  - `purchase-gateway`
- Likely missing both ServiceMonitor definitions and alert bindings for these services.

### 3) Alert and SLO coverage inconsistency
- Incomplete alerting contract across non-core services.
- Potential rule drift in BBI mirror due kustomization delta (notably SLO burn rate include omission).

### 4) Environment model clarity
- `vps/infrastructure` and `bbi-infrastructure` roles need clearer explicit split in tracker/docs:
  - VPS docs should be clearly scoped as `dev/dev-like` or standalone workloads.
  - Kubernetes service visibility and production-like parity should be owned and gated in `bbi-infrastructure` + `mereka-lms`.

### 5) Readiness evidence/contract gap
- Current checks should be normalized so that the following are run by environment:
  - local/deployed manifest-level observability checks
  - runtime check for ServiceMonitors, PrometheusRules, alert-routing, and metrics endpoints
  - parity assertion that `staging` includes all non-optional dev monitoring surfaces required by policy.

## Ready-to-implement issue plan (for implementer)

### Epic: Mereka LMS Observability Parity & First-Class Coverage

#### AC-OBS-001 (Environment parity)
- [ ] Define and codify production/staging/dev parity matrix in code and docs.
- [ ] Ensure staging and production overlays consume equivalent monitoring baseline required for parity checks.
- [ ] Acceptance: non-prod parity check passes with identical mandatory service-monitoring coverage against policy matrix.

#### AC-OBS-002 (Service coverage)
- [ ] Add ServiceMonitors for caddy, mfe, forum, discovery, ecommerce, credentials, and purchase-gateway in app repo and BBI mirror path.
- [ ] Ensure scraping endpoints and pod/port targets are stable and tested.
- [ ] Acceptance: `run-observability-first-class.sh --mode runtime` (or equivalent) shows services present and scraped.

#### AC-OBS-003 (Alerting coverage)
- [ ] Add service-specific alert rules for missing surfaces and wire into reliability/routing policy.
- [ ] Ensure critical/urgent alert routing includes these surfaces.
- [ ] Acceptance: `verify-alert-routing.sh` and Prometheus rule load checks include new series.

#### AC-OBS-004 (Vendored mirror integrity)
- [ ] Align `apps/mereka-lms/vendor/mereka-lms/deploy/k8s/base/monitoring/kustomization.yaml` with `mereka-lms` monitoring source list.
- [ ] Acceptance: mirrored manifest render has no missing includes from source base.

#### AC-OBS-005 (Caddy + exporters)
- [ ] Resolve commented/partial caddy monitoring items where deliberate suppression is no longer needed.
- [ ] Add exporter or metrics path verification for caddy and ensure dashboards consume those metrics.
- [ ] Acceptance: runtime caddy metrics endpoint and associated alertability verified.

#### AC-OBS-006 (VPS boundary + docs)
- [ ] Update docs to explicitly state observability ownership split:
- BBI: Kubernetes app + platform observability for Mereka LMS.
  - VPS infra: standalone services only.
- [ ] Acceptance: no duplicate responsibility ambiguity in runbooks.

#### AC-OBS-007 (Tracker hygiene)
- [ ] Create or update canonical tracker entries in `.beads` for each AC above.
- [ ] Add blockers/dependencies (e.g., observability scripts, dashboards, alert routes).
- [ ] Acceptance: all above ACs appear as open, owner-assigned, and dependency-linked tasks.

## Suggested implementation order for the implementer
1. Lock environment parity baseline (AC-OBS-001).
2. Fix mirror drift and service monitor coverage (AC-OBS-004, AC-OBS-002, AC-OBS-005).
3. Add alerting and routing coverage (AC-OBS-003).
4. Add explicit boundary docs and tracker hygiene (AC-OBS-006, AC-OBS-007).
5. Run staged evidence bundle:
   - manifest lint + generated resources
   - runtime smoke (critical alerts, service endpoints, queryable metrics)
   - parity report artifact attached to implementation PR.

## Direct repository-level action map

- `mereka-lms`: author/update monitoring manifests and app-level docs.
- `bbi-infrastructure`: overlay wiring for env parity + platform monitoring cross-checks.
- `vps/infrastructure`: keep observability docs and runbooks focused on standalone VPS scope only.

## Status to report to implementer
- AC status today is still planning/gap analysis; no implementation work done.
- Coverage is incomplete in three dimensions: overlay parity, non-core service telemetry, and alert wiring for those services.
