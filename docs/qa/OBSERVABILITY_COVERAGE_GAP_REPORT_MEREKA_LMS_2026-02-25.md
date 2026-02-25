# Observability Coverage Gap Report — Mereka LMS

Date: 2026-02-25

## Metadata

- last_updated: 2026-02-25
- owner: Mereka LMS platform team
- scope: dev/staging/prod ServiceMonitor + PrometheusRule coverage audit via first-class matrix
- canonical_command: `./scripts/qa/build-observability-coverage-matrix.sh`

## Method

- repo coverage: `--mode local` against `deploy/k8s/base/monitoring`
- runtime parity probes:
  - `COVERAGE_ENV_LABEL=dev COVERAGE_DISPATCH_PROFILE=nonprod COVERAGE_K8S_CONTEXT=kind-dev`
  - `COVERAGE_ENV_LABEL=staging COVERAGE_DISPATCH_PROFILE=nonprod COVERAGE_K8S_CONTEXT=rke2-staging`
  - `COVERAGE_ENV_LABEL=prod COVERAGE_DISPATCH_PROFILE=prod COVERAGE_K8S_CONTEXT=gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`
  - `--mode runtime`
- strict: enabled for these strict runtime passes.

## Snapshot (single-source evidence)

### Repository coverage

- local coverage pass count: `pass=53`
- local coverage fail count: `fail=0`
- local coverage skip count: `skip=0`
- local total checks: `53`
- identity in generated artifact: `env=unknown;profile=custom;context=default;app_ns=mereka-lms;monitoring_ns=monitoring`

### Runtime parity coverage (dev / staging / prod)

Recent strict runtime passes with explicit contexts show:

- staging (`rke2-staging`): pass=70 fail=9 skip=0 total=79
- dev (`kind-dev`): pass=64 fail=15 skip=0 total=79
- prod (`gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`): pass=68 fail=11 skip=0 total=79

`kind-dev` missing runtime objects:

- ServiceMonitors:
  - `xqueue-metrics`
  - `mux-delivery-monitor`
  - `mfe-metrics`
  - `forum-metrics`
  - `discovery-metrics`
  - `ecommerce-metrics`
  - `credentials-metrics`
  - `purchase-gateway-metrics`
- PrometheusRules:
  - `caddy-alerts`
  - `services-alerts`
  - `video-alerts`
  - `email-alerts`
  - `library-alerts`
  - `ora2-operations`
  - `credentials-alerts`

`staging` missing runtime objects:

- ServiceMonitors:
  - `forum-metrics`
  - `discovery-metrics`
  - `ecommerce-metrics`
  - `purchase-gateway-metrics`
- PrometheusRules:
  - `slo-recording-rules`
  - `services-alerts`
  - `video-alerts`
  - `library-alerts`
  - `ora2-operations`

`prod` missing runtime objects:

- ServiceMonitors:
  - `caddy-metrics`
  - `mfe-metrics`
  - `forum-metrics`
  - `discovery-metrics`
  - `ecommerce-metrics`
  - `credentials-metrics`
  - `purchase-gateway-metrics`
- PrometheusRules:
  - `caddy-alerts`
  - `services-alerts`
  - `ora2-operations`
  - `credentials-alerts`

No repo-only required objects are missing:

- all required `servicemonitor-*.yaml` files are present and referenced in kustomization
- all required `prometheusrule-*.yaml` files are present and referenced in kustomization
- extra runtime-irrelevant objects are only informational (`prometheusrule-externalsecrets`, `prometheusrule-tenant-isolation`, `prometheusrule-xqueue`).

## Owner + target date

| Environment | Owner | Gap | Target fix date | Evidence |
|---|---|---|---|---|
| dev | Mereka LMS observability owners | Runtime parity checks are generated for `kind-dev` with 15 missing runtime monitors/rules | 2026-02-28 | `var/ci/observability-coverage-dev-runtime.md` |
| staging | Mereka LMS observability owners | Runtime parity checks on `rke2-staging` show 9 missing runtime monitors/rules | 2026-02-28 | `var/ci/observability-coverage-staging-runtime.md` |
| prod | Mereka LMS observability owners | Runtime parity checks are generated for GKE with 11 missing runtime monitors/rules | 2026-02-28 | `var/ci/observability-coverage-prod-runtime.md` |

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

3. Close out parity gap and move `OBS-006` / `OBS-007` to done once runtime lanes produce concrete present/absent results and strict mode can pass in all environments.
