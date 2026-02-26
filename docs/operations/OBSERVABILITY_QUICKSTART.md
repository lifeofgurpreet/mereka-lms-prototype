# Observability Quickstart
_Audience: On-call / Operators • Last updated: 2026-02-07_

Use this when you need a fast answer to: "Is Mereka LMS healthy right now?"

## 1) Fast Checks (2-3 minutes)

```bash
# Canonical first-class evidence run (local + runtime)
OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod \
  ./scripts/qa/run-observability-first-class.sh --mode all --strict

# Public surfaces + certs
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod

# Canonical strict branding parity check (prod)
STRICT_MFE_BRANDING_REV=1 ./scripts/branding/run-branding-gates.sh prod

# Monitoring config integrity (repo-local)
./scripts/qa/audit-observability.sh --mode local

# Runtime monitoring objects + synthetic cronjobs (requires cluster + gcloud auth)
OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod \
  ./scripts/qa/run-observability-first-class.sh --mode runtime --strict

# Velero alert pipeline + freshness/recency checks (repo + runtime)
./scripts/qa/audit-velero-alert-pipeline.sh

# Atlas modulestore guard (repo + runtime)
./scripts/qa/verify-atlas-modulestore-path.sh --mode all

# Alert routing verification (runtime policies + channels + optional VPS webhook audit)
CHECK_TIMEOUT_SECONDS=900 ./scripts/qa/verify-alert-routing.sh

# Grafana panel/query coverage contract (required + recommended)
./scripts/qa/audit-grafana-dashboard.sh --strict-required

# DB exporter telemetry contract (repo + optional runtime)
./scripts/qa/audit-db-exporter-telemetry.sh --mode local
# After rollout:
STRICT_RUNTIME=1 ./scripts/qa/audit-db-exporter-telemetry.sh --mode runtime

# Sentry wiring contract (repo + optional runtime)
./scripts/qa/verify-sentry-wiring.sh --mode local
# Sentry CLI/org/project contract
./scripts/qa/verify-sentry-cli-contract.sh
# After SENTRY_DSN + sentry_sdk rollout:
STRICT_RUNTIME=1 ./scripts/qa/verify-sentry-wiring.sh --mode runtime

# Multisite governance gate (site config + org ownership + auth surfaces + hostname drift)
CHECK_TIMEOUT_SECONDS=900 ./scripts/qa/run-multisite-governance-gates.sh --env both

# Consolidated gate (auth + multisite + observability + Velero + Grafana)
./scripts/qa/run-operations-gates.sh --env both
# Optional Sentry gate:
RUN_SENTRY_WIRING_AUDIT=1 SENTRY_AUDIT_MODE=local ./scripts/qa/run-operations-gates.sh --env both
```

`run-operations-gates.sh` now executes observability checks through
`scripts/qa/run-observability-first-class.sh` (runtime strict mode), so CI/manual/runtime evidence contracts stay aligned.

`run-observability-first-class.sh` writes deterministic evidence artifacts into `var/ci/`:
- compliance JSON/Markdown
- runtime verification text/Markdown (runtime/all mode)
- unified evidence index JSON with normalized identity labels

If runtime mode fails while local mode passes, treat it as rollout drift (GitOps/runtime
state has not picked up this repo commit yet), not as a source-contract failure.

If parity fails only because a GCP dashboard is missing, run:

```bash
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply
```

Use plan output as an artifact, then confirm the same parity lane passes.

To include the Grafana-only dashboard artifacts in local parity checks temporarily,
set `OBSERVABILITY_INCLUDE_GRAFANA_DASHBOARDS=1`.

Automated equivalent:
- `.github/workflows/public-health-check.yml` runs strict prod branding parity + dev branding gate and uploads logs.

`run-operations-gates.sh` now enables alert-routing verification by default and writes
per-check logs under `var/operations-gates/`.
Sentry wiring audit is available as an opt-in check
(`RUN_SENTRY_WIRING_AUDIT=1`, `SENTRY_AUDIT_MODE=local|runtime|all`).
It also writes machine/human summaries:
- `summary.json` (structured check results)
- `summary.md` (operator-readable table with status + duration + log path)

`audit-observability --mode runtime` now also verifies that `PrometheusRule/lms-alerts`
contains the reliability alerts:
`OpenEdxCriticalDeploymentUnavailable`, `OpenEdxPodsPendingTooLong`,
`OpenEdxCrashLoopingContainers`, and `OpenEdxSyntheticOrBackupJobFailures`.
It additionally verifies these alert rules are loaded by Prometheus runtime via
`/api/v1/rules` (not just present in Kubernetes objects).

Atlas allowlist drift monitoring posture (VPS):
```bash
./scripts/qa/audit-atlas-allowlist-monitor.sh
STRICT_WEBHOOK=1 ./scripts/qa/audit-atlas-allowlist-monitor.sh
```

DR evidence bundle (monthly or before incident reviews):
```bash
STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar
```

## 2) Core Dashboards

GCP Monitoring dashboards (managed from `infrastructure/monitoring/dashboards/`):
- `Mereka LMS - Public Endpoints`
- `Mereka LMS - Auth`
- `Mereka LMS - GKE`
- `Mereka LMS - Operations Signals`

Primary signals to watch first:
- Uptime dips on LMS/Studio/Apps or microsites
- `operations-signals` spikes for:
  - MySQL/Redis CPU and memory request utilization
  - Stateful storage errors
  - MySQL connection errors
  - Redis connection errors
  - Velero backup verification success/failure and restore-test success/failure
  - Velero backup verification failures
  - Velero restore-test failures
- Prometheus deep telemetry:
  - MySQL connection utilization + slow query spikes
  - Redis rejected connections + key evictions

## 3) Alert Categories

Critical:
- TLS cert expiry
- Stateful storage errors
- Velero restore-test failures
- Velero backup verification failures
- Velero backup verification stale (no success in 30h)
- Velero restore-test stale (enforced by runtime freshness audit, not a long-window GCP alert policy)
- CrashLoopBackOff on any `mereka-lms` workload
- Critical deployment unavailable replicas (`lms`, `cms`, `caddy`, `mfe`, `forum`, `discovery`, `ecommerce`, `credentials`, `notes`, `xqueue`)

Warning:
- Pod restarts
- PVC utilization high
- MySQL saturation high
- Redis saturation high
- MySQL/Redis connection error spikes
- Pods pending too long
- Synthetic/backup job failures (`auth-verify-prod`, `cert-verify-prod`, `backup-verification`, `restore-test`)

## 4) Apply / Update Monitoring

```bash
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply
```

`apply-monitoring-configs.sh` intentionally skips
`velero-restore-test-stale.json` because Cloud Monitoring threshold/absence alert
conditions cannot evaluate 45-day windows.

Legacy-only templates (Cloud SQL) are skipped by default:

```bash
INCLUDE_LEGACY_MONITORING=1 ./scripts/infra/apply-monitoring-configs.sh apply
```

For parity checks, the dashboard scope intentionally excludes
`infrastructure/monitoring/dashboards/video-cost.json` and
`infrastructure/monitoring/dashboards/video-operations.json` (Grafana-only).

## 5) Incident Triage Order

1. Confirm public impact with `public-health-check.sh`.
2. Check Operations Signals dashboard for storage / DB / cache / Velero indicators.
3. Inspect pod restarts and service logs (`kubectl logs -n mereka-lms deployment/<svc>`).
4. If storage or data risk is involved, follow `docs/operations/DISASTER_RECOVERY.md` and `docs/operations/VELERO_BACKUP_AUDIT.md`.
