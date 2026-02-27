# Observability First-Class Repair Plan (rke2-nonprod) — 2026-02-27

## Status
- Completed in repo: forward correlation headers on all direct Caddy admin/login reverse-proxy paths.
- Last runtime strict run still fails with 6 active blockers (details below).

## Latest evidence
- `var/ci/observability-first-class-runtime-step-results.md`
- `var/ci/observability-runtime-verify-runtime.txt`
- `var/ci/observability-coverage-runtime.json`
- `var/ci/observability-logging-pipeline-runtime.txt`
- `var/ci/observability-correlation-headers-runtime.txt`

## Remaining Blockers (priority order)

1. **Reconcile Argo app sync on nonprod app and monitoring stack**
   - `mereka-lms-dev` is `OutOfSync`/`Progressing` with source `apps/mereka-lms/overlays/profiles/dev` in `bbi-infrastructure`.
   - Action: complete syncs and dependency ordering so base kustomize outputs from this repo are fully applied.

2. **Restore LMS/CMS `/metrics` contract (AC-OVR-016)**
   - Runtime check still reports `LMS /metrics returned 000` and patched settings maps without prometheus markers.
   - Action: ensure `openedx-settings-lms-patched` and `openedx-settings-cms-patched` retain/merge `django_prometheus` + `openedx_prometheus` wiring before pod rollout.

3. **ServiceMonitor runtime coverage for non-core services**
   - Missing in runtime for: `caddy-metrics`, `mfe-metrics`, `forum-metrics`, `discovery-metrics`, `ecommerce-metrics`, `credentials-metrics`, `purchase-gateway-metrics`.
   - Action: ensure these resources are deployed to the nonprod cluster and discoverable by Prometheus.

4. **Promtail/Loki logging pipeline**
   - `promtail` DS/pods are absent under `monitoring`; structured/log filtering checks fail.
   - Action: reconcile logging app stack in nonprod to include `promtail` and matching `Loki` endpoint/config.

5. **Tracing/data-plane readiness continuity**
   - Correlation header fix landed in Caddy; validate trace-header propagation across authn/admin routes in nonprod after next deploy.

6. **Dashboard/routing parity evidence refresh**
   - Re-run strict runtime observability runner and update evidence artifacts once the above are fixed.

7. **Open tracing/AC evidence consistency**
   - Keep `verify-observability-first-class` evidence artifacts versioned with UTC identities and include run identity in handoff notes.

8. **Nonprod monitoring app dependencies**
   - Confirm whether monitoring namespace is shared across apps (`monitoring-dev-rke2`) and whether this app should register to shared Grafana/Prometheus datasource or deploy local sources.

9. **Cross-repo validation of `bbi-infrastructure` source path**
   - Validate if nonprod overlay profile in infra points at the expected App-of-apps source (`apps/mereka-lms/overlays/profiles/dev`) and that path includes monitoring/logging artifacts required by spec gates.

10. **Post-fix revalidation workflow**
   - Re-run:
     - `run-observability-first-class.sh --mode runtime --strict`
     - `run-observability-first-class.sh --mode local`
     - `build-observability-parity-delta.sh --env nonprod`

## Note
- The last failed correlation evidence (`var/ci/observability-correlation-headers-runtime.txt`) was generated before the latest `Caddyfile` header patch was applied and is stale; it should be regenerated with the next full runtime run.
