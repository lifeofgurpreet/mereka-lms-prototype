# LMS/CMS `/metrics` Drift Evidence

Date: 2026-02-27
Environment: prod
Context: gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster

## Findings

1. Deployment `lms` and `cms` still mount hashed settings configmaps with stale marker sets:
   - `settings-lms=openedx-settings-lms-patched-5m749fk9gc`
   - `settings-cms=openedx-settings-cms-9d4948mm2c`

2. Runtime payload inspection:
   - `openedx-settings-lms-patched-5m749fk9gc` contains no `openedx_prometheus` block and no `/metrics` route wiring.
   - `openedx-settings-cms-9d4948mm2c` contains partial `django_prometheus` middleware wiring but no confirmed `_metrics_urlconf` route-marker insertion.

3. Source-of-truth check in repo confirms runtime contract currently includes required Prometheus wiring:
   - `deploy/k8s/base/apps/openedx/settings/lms/production.py` includes explicit `openedx_prometheus` + `ROOT_URLCONF_OVERRIDES` block.
   - `deploy/k8s/base/apps/openedx/settings/cms/production.py` includes equivalent block with `_metrics_urlconf` registration.

4. Runtime probe behavior observed from the same command set that has been driving this review:
   - `curl` against LMS `/metrics` with allowed host may return non-Prometheus payloads (404 / missing exposition).
   - Host rewrite behavior remains fragile in some paths (`DisallowedHost` remains relevant during container-level checks).

## Determination

This is a **render-source drift** condition: live deployments are running older Open edX settings config snapshots, not the latest source revision containing the full LMS/CMS Prometheus route wiring expected by current observability gates.

## Immediate remediation path

1. Reconcile/regen Open edX settings render in the GitOps-sourced release path.
2. Rollout `lms`/`cms` with fresh configmap references and verify `openedx-settings-*` payload in the live namespace contains:
   - `django_prometheus`
   - `openedx_prometheus`
   - `ROOT_URLCONF_OVERRIDES` + `openedx_prometheus.urls`
3. Rerun `run-observability-first-class.sh --mode runtime --strict` and store metrics evidence artifacts.
4. Add automated guardrail for configmap payload markers in runtime evidence.
