# Observability Coverage Gap Report — Mereka LMS

Date: 2026-02-25

## Metadata

- last_updated: 2026-02-25
- owner: Mereka LMS platform team
- scope: dev/nonprod/prod ServiceMonitor + PrometheusRule coverage audit via first-class matrix
- canonical_command: `./scripts/qa/build-observability-coverage-matrix.sh`

## Method

- repo coverage: `--mode local` against `deploy/k8s/base/monitoring`
- runtime parity probes:
  - `COVERAGE_ENV_LABEL=dev COVERAGE_DISPATCH_PROFILE=nonprod`
  - `COVERAGE_ENV_LABEL=nonprod COVERAGE_DISPATCH_PROFILE=nonprod`
  - `COVERAGE_ENV_LABEL=prod COVERAGE_DISPATCH_PROFILE=prod`
  - `--mode runtime`
- strict: disabled for this pass (non-runtime contexts not currently enforced in this environment)

## Snapshot (single-source evidence)

### Repository coverage

- local coverage pass count: `pass=53`
- local coverage fail count: `fail=0`
- local coverage skip count: `skip=0`
- local total checks: `53`
- identity in generated artifact: `env=unknown;profile=custom;context=default;app_ns=mereka-lms;monitoring_ns=monitoring`

### Runtime parity coverage (dev / nonprod / prod)

All three parity lanes currently return the same outcome because runtime context is not injected in this analysis pass.

- pass count: `pass=53`
- fail count: `fail=0`
- skip count: `skip=27`
- total checks: `80`

Skipped runtime checks indicate each lane is currently unresolved at runtime object level:

- `service-monitor-live`
  - `lms-metrics`
  - `cms-metrics`
  - `mysql-metrics`
  - `redis-metrics`
  - `enterprise-catalog-metrics`
  - `xqueue-metrics`
  - `mux-delivery-monitor`
  - `caddy-metrics`
  - `mfe-metrics`
  - `forum-metrics`
  - `discovery-metrics`
  - `ecommerce-metrics`
  - `credentials-metrics`
  - `purchase-gateway-metrics`
- `prometheusrule-live`
  - `lms-alerts`
  - `enterprise-alerts`
  - `velero-alerts`
  - `slo-recording-rules`
  - `auth-alerts`
  - `caddy-alerts`
  - `services-alerts`
  - `video-alerts`
  - `email-alerts`
  - `library-alerts`
  - `ora2-operations`
  - `credentials-alerts`

No repo-only required objects are missing:

- all required `servicemonitor-*.yaml` files are present and referenced in kustomization
- all required `prometheusrule-*.yaml` files are present and referenced in kustomization
- extra runtime-irrelevant objects are only informational (`prometheusrule-externalsecrets`, `prometheusrule-tenant-isolation`, `prometheusrule-xqueue`).

## Owner + target date

| Environment | Owner | Gap | Target fix date | Evidence |
|---|---|---|---|---|
| dev | Mereka LMS observability owners | Runtime ServiceMonitor/PrometheusRule verification blocked (all runtime checks skip due missing/implicit context wiring in this pass) | 2026-02-28 | `var/ci/observability-coverage-dev-runtime.md` |
| nonprod | Mereka LMS observability owners | Runtime ServiceMonitor/PrometheusRule verification blocked (all runtime checks skip due missing/implicit context wiring in this pass) | 2026-02-28 | `var/ci/observability-coverage-nonprod-runtime.md` |
| prod | Mereka LMS observability owners | Runtime ServiceMonitor/PrometheusRule verification blocked (all runtime checks skip due missing/implicit context wiring in this pass) | 2026-02-28 | `var/ci/observability-coverage-prod-runtime.md` |

## Required action (immediate)

1. Re-run parity checks with explicit env context values:

```bash
OBSERVABILITY_ENV_LABEL=dev \
OBSERVABILITY_DISPATCH_PROFILE=nonprod \
OBSERVABILITY_K8S_CONTEXT=<dev-context> \
OBSERVABILITY_GCP_PROJECT=<dev-or-shared-project> \
./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

2. Confirm each environment emits no runtime skips and no runtime fails in `observability-coverage-<env>-runtime.json`.

3. Close out parity gap and move `OBS-006` to done once runtime lanes produce concrete present/absent results.

