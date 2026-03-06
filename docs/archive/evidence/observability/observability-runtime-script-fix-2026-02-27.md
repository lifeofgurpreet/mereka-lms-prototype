# Observability Runtime Script Fix and Remaining Gaps

- Date: 2026-02-27
- Context: `rke2-nonprod` (`VERIFY_OBS_K8S_CONTEXT=rke2-nonprod`)
- Evidence identity: `env=nonprod;profile=nonprod;context=rke2-nonprod;project=mereka-lms`
- Executed by: `scripts/qa/verify-observability-runtime.sh`
- Result: `PASS 8 / FAIL 29 / SKIP 2`

## What was fixed

1. Removed `timeout` + shell-function call bug in `scripts/qa/verify-observability-runtime.sh`.
   - Before: `timeout "$VERIFY_CMD_TIMEOUT" kubectl_cmd ...` bypassed `kubectl_cmd` shell function.
   - After: added `kubectl_cmd_with_timeout()` and migrated timeout-wrapped call sites.
   - Verification: runtime script now executes and produces runtime wiring evidence instead of failing at command-resolution stage.

2. Fixed syntax regressions caused by the refactor.
   - Verified with `bash -n scripts/qa/verify-observability-runtime.sh`.

3. Added explicit timeout-safe command path for Prometheus/metrics reads so `/metrics` and wiring checks are now observable in one runtime execution.

4. Added namespace-agnostic runtime wiring resilience in `check_prometheus_runtime_wiring`.
   - ServiceMonitor lookup now validates both `VERIFY_MONITORING_NAMESPACE` and `VERIFY_APP_NAMESPACE` to avoid false negative `not found` failures in environments where monitoring objects are namespace-scoped to the app namespace.
   - Prometheus pod resolution now checks both `VERIFY_MONITORING_NAMESPACE` and `VERIFY_APP_NAMESPACE`, so runtime wiring checks can execute when the stack colocates Prometheus in the app namespace.
   - ServiceMonitor target evidence now records the resolved namespace for each check.
5. Hardened ServiceMonitor discovery path in `resolve_service_monitor()`.
   - Added all-namespace fallback when known namespaces (`${VERIFY_MONITORING_NAMESPACE}` and `${VERIFY_APP_NAMESPACE}`) do not contain the target.
   - Added explicit duplicate-match detection when the same ServiceMonitor name exists in multiple namespaces, returning a hard fail with evidence of candidate namespaces instead of silently selecting one.
6. Hardened PrometheusRule discovery in the runtime wiring check.
   - Added analogous `resolve_prometheus_rule()` lookup for expected `PrometheusRule` objects.
   - Rule checks now check both known namespaces first and fallback all namespaces deterministically.
   - Added deterministic ambiguity handling for duplicated rule names across namespaces and evidence of resolved/ambiguous rule namespace candidates.

## Current observed runtime state (post-fix)

- `AC-OVR-016`: Prometheus recording rule check passes.
- `AC-OVR-016` LMS/CMS `/metrics`: still returning `000` (payload missing).
- `AC-OVR-018/019/020`: remaining GCP monitoring/control plane gaps.
- `AC-OVR-021/023`: skipped in this run due missing Grafana/API inputs.
- `AC-OVR-025`: still failing because `verify-observability-compliance.sh --json` still fails under current runtime environment.
- `AC-OVR-029`: still failing (`validate-observability-compliance.sh` not currently gating monitoring-path changes as strict in CI path).
- `AC-OVR-031`: checks passed (query syntax health is clean).
- `Runtime wiring`: many `ServiceMonitor` and `PrometheusRule` presence failures across `caddy-metrics`, `mfe-metrics`, `forum/discovery/ecommerce/credentials/purchase-gateway-metrics`, and `caddy-alerts/slo-recording-rules/video-alerts/ora2-operations`.

## Immediate high-priority backlog (next large tasks)

1. Fix LMS/CMS `/metrics` reachability in nonprod/dev/prod runtime lane (`deploy/lms`, `deploy/cms` should expose valid Prometheus exposition at container-level).
2. Deploy missing monitoring objects from `OBS-053 .. OBS-057` in parity order:
   - `caddy-metrics` + `caddy-alerts`
   - `mfe-metrics` + `services-alerts`
   - `forum/discovery/ecommerce/credentials/purchase-gateway-metrics`
   - `slo-recording-rules` + `video-alerts` + `ora2-operations`
3. Re-run strict runtime pass in lane with the updated script to confirm namespace-aware checks now reduce false negatives before continuing object-by-object closure.
4. Re-check `run-observability-first-class.sh --mode runtime --strict` after each monitoring wave.
5. Resolve `AC-OVR-025` by inspecting `validate-observability-compliance.sh --json` output path in this environment and ensuring JSON compatibility under strict mode.
6. Resolve `AC-OVR-029` by updating strict workflow gating for monitoring-path changes.
