# Observability Readiness Review: Mereka LMS (Dev/Non-prod/Prod)

_Date: 2026-02-25_

## Metadata

- last_updated: 2026-02-25
- owner: Mereka LMS platform team
- canonical_workflow: `.github/workflows/observability-compliance.yml`
- canonical_index: `docs/qa/OBSERVABILITY_CANONICAL_INDEX.md`

## 0) Objective

This review is a planner-level inventory only. It identifies what is live in plans and manifests, what is partially done, and what is still missing before observability can be considered first-class across local/dev (staging-equivalent), non-production, and production.

Canonical index:
- `docs/qa/OBSERVABILITY_CANONICAL_INDEX.md`

## 1) What is already baked into plans

**Specs that define the contract**

- `specs/observability-validation-requirements_spec.md` defines the required ServiceMonitors and PrometheusRules with AC IDs `AC-OVR-001` through `AC-OVR-031` and includes rollout guidance.
- `specs/observability-stack_spec.md` sets baseline stack expectations with `AC-001` through `AC-008`, plus logging/tracing ACs (`AC-LOG-001` through `AC-LOG-008`).
- `specs/slo-sla-service-level-management_spec.md` defines SLO/SLA and alerting gates with AC IDs through `AC-041`, plus emergency/deployment behavior in `AC-044` and availability math in `AC-046`.

**Operational scripts and enforcement points already present**

- `scripts/qa/audit-observability.sh` (live + repo audit entrypoint).
- `scripts/qa/verify-observability-stack.sh` (aggregates stack checks and delegates to audit tooling).
- `scripts/qa/verify-observability-runtime.sh` (runtime contract verification scaffold with AC mapping).
- `scripts/qa/run-observability-first-class.sh` (canonical orchestrator for local/runtime/all evidence runs).
- `.github/workflows/observability-audit.yml` now uses `run-observability-first-class.sh` for runtime/all scheduled runs and preserves `audit-observability.sh` for local-only mode.

## 2) What is live in repo manifests

| Signal | Evidence in repo | Status |
|---|---|---|
| Monitoring base kustomization | `deploy/k8s/base/monitoring/kustomization.yaml` | Active |
| ServiceMonitors included | `servicemonitor-lms`, `servicemonitor-cms`, `servicemonitor-mysql`, `servicemonitor-redis`, `servicemonitor-enterprise`, `servicemonitor-xqueue`, `servicemonitor-mux`, `servicemonitor-caddy`, `servicemonitor-mfe`, `servicemonitor-forum`, `servicemonitor-discovery`, `servicemonitor-ecommerce`, `servicemonitor-credentials`, `servicemonitor-purchase-gateway` | Mostly complete |
| Service-level logs pipeline | `deploy/k8s/base/logging/promtail-*` via `deploy/k8s/base/logging/kustomization.yaml` and forwarded to `https://loki.mereka.dev` | Implemented |
| LMS/CMS `/metrics` app-level signal quality | `/metrics -> HTTP 200` is enforced by `deploy/k8s/base/monitoring/verify.sh`, `scripts/qa/validate-observability-compliance.sh`, and `scripts/qa/verify-observability-runtime.sh` | Enforced |
| Compliance script runtime | `scripts/qa/validate-observability-compliance.sh` is now implemented | Implemented |

## 3) Missing from live monitoring against spec requirements

### 3.1 ServiceMonitor gaps (`AC-OVR-001`, `AC-OVR-002`)

The required table in `specs/observability-validation-requirements_spec.md` includes `caddy-metrics`, `mfe-metrics`, `forum-metrics`, `discovery-metrics`, `ecommerce-metrics`, `credentials-metrics`, and `purchase-gateway-metrics`. These are now present in the deployment graph:
- monitoring resources in `deploy/k8s/base/monitoring/kustomization.yaml`
- purchase gateway service monitor in `services/purchase-gateway/k8s/kustomization.yaml` (included by `deploy/k8s/base/kustomization.yaml`)

### 3.2 PrometheusRule gaps (`AC-OVR-005`, `AC-OVR-008`, `AC-OVR-009`, `AC-OVR-010`)

Spec-required coverage has been implemented for:

- `prometheusrule-caddy.yaml` for `CaddyHighErrorRate`, `CaddyHighLatency`, `CaddyDown`.
- `prometheusrule-services.yaml` for `ForumPodDown`, `DiscoveryPodDown`, `EcommercePodDown`, `CredentialsPodDown`, `MFEPodDown`, and purchase gateway alerts.

Remaining gaps in this tier:

- `prometheusrule-lms.yaml` still needs `HighPVCUtilization`.
- `prometheusrule-slo.yaml` still needs `LatencyRegressionSpike`, `LatencyRegressionDrift`, `ErrorRateSpike`.

Implemented in this pass:

- `prometheusrule-lms.yaml` now includes `HighPVCUtilization`.
- `prometheusrule-slo.yaml` now includes `LatencyRegressionSpike`, `LatencyRegressionDrift`, `ErrorRateSpike`.

### 3.3 Compliance runtime gate incompleteness (`AC-OVR-024` through `AC-OVR-031`)

`scripts/qa/validate-observability-compliance.sh` has now been implemented, including local/runtime orchestration and optional JSON output.

Runtime validation is now fully concrete: `verify-observability-runtime.sh` now runs negative-control coverage for `AC-OVR-026` instead of a TODO/manual blocker. `AC-OVR-026` is validated by invoking `verify-observability-validation.sh` against a temporary manifest set missing a required ServiceMonitor entry and asserting failure with expected diagnostic output.

### 3.4 Service parity across environments

`deploy/k8s/overlays/staging/kustomization.yaml` is explicitly flagged as deprecated in-file. Active non-production parity lane is effectively `deploy/k8s/overlays/rke2-nonprod`. If parity is defined as dev/staging, the canonical pair becomes:

- local: developer/dev-like fast feedback, intentionally reduced service set and replicas
- nonprod: `rke2-nonprod` with closer service parity
- production: `production`

A dedicated active `staging` overlay is not currently the canonical target.

## 4) What this means for “is it live in all environments?”

- Observability as a framework is live in repo and has automation hooks.
- Core telemetry is significantly expanded and includes caddy/mfe/forum/discovery/ecommerce/credentials/purchase-gateway service scrape + alert coverage.
- App-level SLI path remains high risk because LMS/CMS `/metrics` is still historically high-variance (`HTTP 400` observed in legacy status notes).
- CI strictness is improving, and strict merge-blocking checks now run through the new `observability-compliance.yml` workflow.

## 5) Tracker-ready issue sets (for implementer handoff)

### Issue set A — Foundation parity for required surfaces (implemented in this pass)

Title: `OBS-FOUNDATION-01: Add required ServiceMonitors for caddy, mfe, forum, discovery, ecommerce, credentials, purchase-gateway`

Scope: add YAML files and include in `deploy/k8s/base/monitoring/kustomization.yaml`.

Status: completed in this pass.

Acceptance basis: `AC-OVR-001`, `AC-OVR-002`, `AC-OVR-003`, `AC-OVR-004`

### Issue set B — Foundation parity for required alert rules (implemented in this pass)

Title: `OBS-FOUNDATION-02: Add prometheusrule-caddy.yaml and prometheusrule-services.yaml with required alerts`

Scope: add missing PrometheusRule resources and include them in base monitoring kustomization.

Status: implemented in this pass.

Acceptance basis: `AC-OVR-005`, `AC-OVR-008`, `AC-OVR-009`, `AC-OVR-010`

Done when required alert names are present with severity/component labels and summary/description annotations.

### Issue set C — Extend existing LMS/SLO alerting

Title: `OBS-SLO-03: Add HighPVCUtilization and SLO regression alerts`

Scope: `prometheusrule-lms.yaml`, `prometheusrule-slo.yaml`, plus required labels/annotations.

Acceptance basis: `AC-OVR-008`, `AC-OVR-010`, `AC-OVR-011`

Done when `HighPVCUtilization`, `LatencyRegressionSpike`, `LatencyRegressionDrift`, and `ErrorRateSpike` are present and load in Prometheus.
Status: implemented.

### Issue set D — Complete validation gate implementation and CI enforcement

Title: `OBS-GATE-04: Implement validate-observability-compliance.sh and wire PR/runtime enforcement`

Scope: implement full local/runtime modes, structured JSON output, strict mode behavior, and CI workflow gate.

Acceptance basis: `AC-OVR-024`, `AC-OVR-025`, `AC-OVR-026`, `AC-OVR-027`, `AC-OVR-028`, `AC-OVR-029`

Status: implemented, with `AC-OVR-026` now validated as part of automated negative-control coverage.

### Issue set E — Make LMS/CMS app metrics actionable

Title: `OBS-APP-05: Make `/metrics` app-level telemetry production-usable`

Scope: implement django-prometheus rollout or approved equivalent and verify endpoint and SLI recordings.

Acceptance basis: `AC-OVR-012`, `AC-OVR-013`, `AC-OVR-014`, `AC-OVR-015`, `AC-003`, `AC-009`, `AC-026`, `AC-027`

Done when LMS/CMS metrics return rich app indicators and SLI queries return stable non-NaN values.

### Issue set F — Codify non-prod parity policy in tracker/docs

Title: `OBS-PARITY-06: Define and enforce canonical non-prod parity policy`

Scope: formalize local vs `rke2-nonprod` vs production parity expectations and explicit intentional differences for staging-like work.

Acceptance basis: release readiness semantics captured in tracker and documented in `docs/operations/OBSERVABILITY_OWNERSHIP.md`.

Done when parity policy is explicit, reviewed, and referenced in handoff checks.

## 6) Suggested execution order

1. Complete issue set E to make LMS/CMS metrics reliable for SLO computation.
2. Complete issue set F with environment/process updates in the same sprint.

## 7) Non-production parity baseline for observability today

### Canonical lanes to treat as parity set

- `deploy/k8s/overlays/local`: fast-feedback dev with reduced service set and locally loaded image strategy.
- `deploy/k8s/overlays/rke2-nonprod`: staging-equivalent lane (authentically called out as `rke2-nonprod` in repository comments).
- `deploy/k8s/overlays/production`: production-like lane used by Argo/CD.

### What is already shared by all three

- `deploy/k8s/base` is common and includes `monitoring`.
- `deploy/k8s/base/monitoring` is therefore the authoritative source for scrape/alert behavior.
- `kustomization.yaml` in local/rke2-nonprod/production does not independently fork monitoring resources.

### What this means for “live in local/dev/non-prod/prod” claims

- If monitoring is incomplete in `deploy/k8s/base/monitoring`, all overlays inherit that same incompleteness.
- Staging parity claims should be made against `rke2-nonprod`, not the archived `staging` overlay (which is explicitly deprecated in-file).
- Observability readiness claims for local/dev/non-prod/prod are therefore synchronized by design but can diverge only by service enablement and replica counts.

## 8) Tracker status and what is currently owned

I checked the tracker source (`.beads/issues.jsonl`) and the currently open/in-progress set is not observability-labeled and not scoped to this gap:

- Open/in progress IDs: `mereka-lms-1bdm`, `mereka-lms-1jsy`, `mereka-lms-1kwf`, `mereka-lms-1kwf.1`, `mereka-lms-288f`, `mereka-lms-2s47`, `mereka-lms-3bm2`, `mereka-lms-3st7`, `mereka-lms-5ngf`, `mereka-lms-5ngf.2`, `mereka-lms-aza7`, `mereka-lms-bims`, `mereka-lms-i8lo`, `mereka-lms-mci9`.

None of these currently declares dedicated ownership for observability AC closure.

### Recommended tracker structure (no repo implementation required now)

1. Create one parent tracker issue for observability compliance completion.
2. Split into exactly the existing issue sets A–F as children.
3. Add dependencies from parity/readiness parents (`aza7`, `3bm2`, `5ngf`, `3st7`, `288f`) to this new parent where overlap exists.

Suggested parent title:

- `OBS-COMPLIANCE-01: Make observability first-class and AC-complete across non-prod + prod`

Suggested policy gate:

- Mark parent as blocked until child issue sets A, B, and D are green.

## 9) Additional finding: hidden partial implementation and non-included assets

- Required monitoring manifests in the current review window are now included in
  `deploy/k8s/base/monitoring/kustomization.yaml`.
- Remaining non-required assets in this directory are intentional and documented:
  - `cronjob-library-export.yaml`
  - `cronjob-tenant-isolation.yaml`
  - `hpa-enterprise.yaml`
  - `mux-exporter.yaml`
- These non-required assets should be re-reviewed once before merge to keep
  `kustomization.yaml` intentionally scoped and avoid accidental coupling.

## 10) Open questions before implementation

- Is purchase gateway in the next release scope or intentionally deferred with a documented waiver?
- Is `rke2-nonprod` the only canonical staging-equivalent lane for now?
- Should Tempo tracing be in-scope in this phase, given current status of tracing deployment in this repo?

## 11) Execution updates in this pass (2026-02-25)

- Fixed LMS/CMS metrics host rewrite bug in forwarded-header middleware:
  - `deploy/k8s/base/apps/openedx/settings/lms/mereka_forwarded_headers.py`
  - `deploy/k8s/base/apps/openedx/settings/cms/mereka_forwarded_headers.py`
- Added regression guard in `scripts/qa/verify-observability-validation.sh` to fail if the broken pod-IP regex reappears.
- Upgraded `deploy/k8s/base/monitoring/verify.sh` to enforce runtime contract (`/metrics` must return `HTTP 200` for LMS and CMS).
- Upgraded `scripts/qa/verify-observability-runtime.sh` to fail `AC-OVR-016` when LMS/CMS `/metrics` do not return `HTTP 200`, and added Prometheus payload-shape checks (`# HELP`/`# TYPE` markers plus numeric sample lines) to ensure observed data is scrape-safe.
- Upgraded `scripts/qa/validate-observability-compliance.sh --mode runtime` to record explicit `AC-OVR-016` pass/fail for LMS/CMS `/metrics` endpoint health.
- Removed stale documentation language that treated `/metrics -> 400` as expected behavior.

### Runtime evidence commands (nonprod/prod)

Use namespace-aware runtime checks with first-class evidence output:

```bash
OBSERVABILITY_ENV_LABEL=nonprod \
OBSERVABILITY_DISPATCH_PROFILE=nonprod \
OBSERVABILITY_APP_NAMESPACE=mereka-lms \
OBSERVABILITY_MONITORING_NAMESPACE=monitoring \
OBSERVABILITY_EVIDENCE_DIR="docs/evidence/observability/nonprod-$(date -u +%Y-%m-%dT%H-%M-%SZ)" \
./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

Manual CI runtime path is now available in `.github/workflows/observability-compliance.yml`:
- `workflow_dispatch` with `run_runtime=true`
- `app_namespace` and `monitoring_namespace` inputs
- optional `k8s_context` input to pin kubectl to a target cluster context
- optional `require_k8s_context` input (`true|false`) to hard-fail preflight if context is omitted
- `gcp_project` input to pin runtime gcloud checks to the intended project
- optional `require_gcp_project` input (`true|false`) to hard-fail preflight if project input is empty
- Runtime artifacts uploaded as `observability-compliance-runtime`
- Workflow step summary now includes runtime compliance and verifier markdown evidence
- Runtime preflight now records selected namespace/context/project into both summary and artifact (`var/ci/observability-runtime-preflight.md`)
- Runtime preflight also records derived `dispatch_profile` (`prod`/`nonprod`/`custom`) with `profile_note` to classify artifacts quickly.
- Runtime dispatch supports `expected_dispatch_profile` (`any|prod|nonprod|custom`) and preflight fails when derived profile does not match expectation.
- Runtime dispatch includes `environment_label` (`dev|nonprod|prod|custom`) and this label is written into preflight/compliance/runtime evidence files for cross-run comparison.
- All generated evidence markdown now includes a normalized `evidence_identity` line:
  `env=<label>;profile=<dispatch_profile>;context=<k8s_context>;project=<gcp_project>`.
- CI now generates machine-readable evidence index artifacts for ingestion:
  - `var/ci/observability-first-class-local-evidence-index.json`
  - `var/ci/observability-first-class-runtime-evidence-index.json`
- CI now validates both evidence index files with `jq` schema checks and fails if required fields are missing.
- CI now validates evidence bundle integrity by verifying every path listed in each index file exists before artifact upload.
- Runtime CI now enforces identity consistency: preflight/compliance/runtime-verifier `evidence_identity` values must match.
- Local CI now enforces identity consistency between local evidence index and compliance markdown `evidence_identity`.
- Local CI now enforces canonical observability doc metadata keys (`last_updated`, `owner`, `canonical_workflow`, and cross-links) in the two canonical docs.
- Observability CI evidence artifacts (`local` and `runtime`) now set `retention-days: 30` in upload policy.
- Retention policy is centralized in workflow env as `EVIDENCE_RETENTION_DAYS` and reused by both upload steps.
- Workflow preflight now enforces `EVIDENCE_RETENTION_DAYS` to be numeric and within `1..90` before evidence generation/upload.
- Added `scripts/qa/run-observability-first-class.sh` as the canonical gate runner for local/runtime/all execution with deterministic evidence index output.
- `.github/workflows/observability-compliance.yml` now executes the canonical runner in both local and runtime jobs to keep operator and CI execution paths aligned.

## 12) Parity execution status (2026-02-25)

- Added canonical parity matrix: `docs/operations/OBSERVABILITY_PARITY_MATRIX.md`.
- CI now enforces active operations docs to use canonical runtime observability commands (fails on `audit-observability.sh --mode runtime|all` drift).
- Runtime preflight now enforces parity mapping from `environment_label` to `dispatch_profile`:
  - `dev|nonprod -> nonprod`
  - `prod -> prod`
  - `custom -> custom`
- Canonical runtime identity and parity model are now wired through:
  - `docs/qa/OBSERVABILITY_CANONICAL_INDEX.md`
  - `docs/operations/MONITORING.md`
  - `.github/workflows/observability-compliance.yml`

## 13) Parity gap register (2026-02-25)

### Open gaps

| Gap ID | Environment | Gap | Impact | Owner | Target |
|---|---|---|---|---|---|
| PAR-001 | dev | Scheduled parity workflow is implemented but remains pending env wiring and sustained cadence proof. Closure requires 3 consecutive scheduled rollups with no skipped environments. | Drift can go undetected until env wiring is completed. | Mereka LMS platform team | 2026-03-05 |
| PAR-002 | nonprod | Parity delta/review/rollup artifacts are implemented but require sustained nonprod runtime execution. Closure requires 3 consecutive scheduled rollups with no parity delta failures. | Operators may miss trend-level parity regressions without weekly review discipline. | Mereka LMS platform team | 2026-03-07 |

### Closed gaps

| Gap ID | Environment | Closure | Owner | Closed date |
|---|---|---|---|---|
| PAR-C001 | all | Canonical runtime observability gate established via `scripts/qa/run-observability-first-class.sh` and wired into primary workflows/gates. | Mereka LMS platform team | 2026-02-25 |
| PAR-C002 | all | Runtime evidence identity normalization and consistency checks enforced in CI/runtime and DR evidence generation paths. | Mereka LMS platform team | 2026-02-25 |
| PAR-C003 | all | Active operations docs migrated to canonical runtime/all command contract; non-canonical drift now fails in observability compliance CI. | Mereka LMS platform team | 2026-02-25 |
| PAR-C004 | all | Environment-targeted parity automation + parity delta artifacts implemented: `.github/workflows/observability-parity-runtime.yml` + `scripts/qa/build-observability-parity-delta.sh`. | Mereka LMS platform team | 2026-02-25 |
| PAR-C005 | prod | Production parity workflow lane now fails fast when `OBS_PARITY_PROD_K8S_CONTEXT` is missing (no silent prod skip). | Mereka LMS platform team | 2026-02-25 |
| PAR-C006 | all | Weekly parity review artifact is now auto-generated per env run (`observability-parity-review.md`) via `scripts/qa/build-observability-parity-review.sh`. | Mereka LMS platform team | 2026-02-25 |
| PAR-C007 | all | Matrix runs now publish a consolidated rollup artifact (`observability-parity-rollup.md/.json`) for single-view weekly parity review. | Mereka LMS platform team | 2026-02-25 |
| PAR-C008 | all | Alert-noise baseline is codified as an enforceable gate threshold (`infrastructure/monitoring/alert-noise-baseline.json`) and wired into `run-operations-gates.sh` via `audit-alert-noise-baseline.sh`. | Mereka LMS platform team | 2026-02-25 |
| PAR-003 | prod | Runtime alert-noise sample is now generated in `.github/workflows/operations-gates-runtime.yml` via `scripts/qa/build-alert-noise-runtime-sample.sh` and passed to `run-operations-gates.sh` as `ALERT_NOISE_RUNTIME_SOURCE` in strict runtime mode. | Mereka LMS platform team | 2026-02-25 |
