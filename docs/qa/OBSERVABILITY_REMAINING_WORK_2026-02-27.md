# Observability Remaining Work (Mereka LMS) — 2026-02-27

## Current state (post nonprod checks)

- Live runtime strict verification still fails in the active nonprod lane.
- `AC-OVR-016` remains the top blocker: LMS/CMS `/metrics` are not yet returning Prometheus-safe payloads in strict run evidence.
- Runtime wiring evidence for caddy/mfe/forum/discovery/ecommerce/credentials/purchase-gateway and rules sets is incomplete in live lane snapshots.
- Evidence identity is still only stable when lane env vars are explicitly set for every run.

## What is now confirmed in code

- Runtime checks, coverage matrix, first-class orchestrator, and wiring evidence collection scripts are already present.
- Monitoring resource manifests in `deploy/k8s/base/monitoring` include the required ServiceMonitor and PrometheusRule families.
- App settings/plugin code for `/metrics` routes and Django middleware is implemented in `infrastructure/tutor/plugins/mereka_lms.py` and `infrastructure/tutor/custom-apps/openedx_prometheus/`.

The remaining gap is now primarily **runtime parity and deployment synchronization**, not core script design.

## Top 10 remaining execution tasks (systematic)

1. **Lane hardening**
   - Enforce nonprod/prod lane identity explicitly before every strict run:
     `OBSERVABILITY_ENV_LABEL`, `OBSERVABILITY_DISPATCH_PROFILE`, `OBSERVABILITY_K8S_CONTEXT`, `OBSERVABILITY_GCP_PROJECT`.
   - Generate and archive `observability-first-class-runtime-evidence-index.json`.

2. **Close LMS `/metrics` contract (AC-OVR-016)**
   - Require strict nonprod proof: `status_code: 200`, non-zero `# HELP`, `# TYPE`, numeric samples.
   - Artifact: `var/ci/observability-metrics-lms-runtime.md`.

3. **Close CMS `/metrics` contract (AC-OVR-016)**
   - Same as LMS; artifact: `var/ci/observability-metrics-cms-runtime.md`.

4. **Confirm configmap wiring in runtime deployment**
   - Verify `/var` settings map check for `openedx_prometheus.urls` + middleware markers in the exact rendered map mounted by `lms` and `cms`.

5. **Deploy/verify critical caddy monitoring objects (OBS-053)**
   - Confirm `servicemonitor-caddy.yaml` and `prometheusrule-caddy.yaml` are present and scrapeable.
   - Artifact: `observability-caddy-prometheus-wiring-runtime.md`.

6. **Deploy/verify MFE monitoring objects (OBS-054)**
   - Confirm `servicemonitor-mfe.yaml` and `prometheusrule-services.yaml` appear in targets/rules checks.
   - Artifact: `observability-mfe-prometheus-wiring-runtime.md`.

7. **Deploy/verify shared services (OBS-055)**
   - Confirm forum/discovery/ecommerce/credentials/purchase-gateway monitors are present and in Prometheus target set.
   - Artifacts: corresponding `observability-*-prometheus-wiring-runtime.md` files.

8. **Deploy/verify service rule families (OBS-056)**
   - Confirm `slo-recording-rules`, `video-alerts`, `ora2-operations`, `services-alerts`, and `caddy-alerts` groups are visible in `/api/v1/rules`.

9. **Strict determinism cleanup (AC-OVR-025/029)**
   - Validate strict runs consistently produce machine-parseable JSON and no mixed stdout/stderr failure blob in `observability-compliance-runtime.json`.

10. **Wave release handoff**
    - Close tasks in priority order and attach evidence matrix + exception log before any non-runtime lane claim.

## Hard stop gates

- Do not promote to next wave until AC-OVR-016 passes on LMS and CMS in one nonprod strict run.
- Do not promote coverage gates until per-object wiring evidence files exist and report non-zero target/rule matches.
- Keep `OBSERVABILITY_*` lane variables part of your runbook and CI docs so evidence identity never falls back to `unknown/custom`.

