---
spec: observability-stack_spec.md
plan: plans/observability-stack_plan.md
tier: 2
status: draft
owner: engineering
last_updated: "2026-02-10"
test_framework: "shell_verification (bash scripts), kubectl_check (K8s API), smoke_test (HTTP probes), manual_verification(human checklist)"
---

# Test Plan: Observability Stack (Prometheus/Tempo/Loki)

**Source Spec**: `specs/observability-stack_spec.md`

## Test Strategy

This project is infrastructure-as-code with no application-level test framework (no pytest, vitest, etc. for the observability stack itself). Verification uses:

1. **shell_verification**: Bash scripts in `scripts/qa/` thatvalidate configuration files, K8s resource state, and HTTP endpoints
2. **kubectl_check**: Direct `kubectl` commands that verify K8s resource existence and configuration
3. **smoke_test**: HTTP requests to service endpoints that verify functional behavior
4. **manual_verification**: Human-executed checks for UI behavior, alert delivery, and visual dashboard correctness

## Test Matrix

### Acceptance Criteria Tests

| AC # | Test Description | Test Type | Test Location | Priority | Mocks/Fixtures |
|------|------------------|-----------|---------------|----------|----------------|
| AC-001 | Verify ServiceMonitors exist for all workloads (LMS, CMS, MySQL, Redis) | kubectl_check | `scripts/qa/verify-observability-stack.sh` | P1 | None (live cluster) |
| AC-001 | Verify Prometheus targets show all pods as UP | smoke_test | `scripts/qa/verify-observability-stack.sh` | P1 |Requires port-forward to Prometheus |
| AC-001 | Verify scrape interval is <= 30s on all ServiceMonitors | shell_verification | `scripts/qa/verify-observability-stack.sh` | P1 | None (checks YAML files) |
| AC-002 | Verify Grafana is accessible and requires authentication | smoke_test | `scripts/qa/verify-observability-stack.sh` | P1 | None (live HTTP check) |
| AC-002 | Verify Grafana dashboards exist (K8s overview, podresources, LMS/CMS, MySQL, Redis) | kubectl_check | `scripts/qa/audit-grafana-dashboard.sh` | P1 | Dashboard contract JSON |
| AC-002 | Verify dashboard loads in under 3 seconds for 24hquery window | manual_verification | Documented inline (humantimes page load) | P2 | None |
| AC-003 | Verify LMS `/metrics` endpoint returns HTTP 200 with Prometheus text format | smoke_test | `scripts/qa/verify-observability-stack.sh` | P1 | None (live pod exec) |
| AC-003 | Verify `/metrics` contains `http_requests_total` counter | smoke_test | `scripts/qa/verify-observability-stack.sh` | P1 | None (live pod exec) |
| AC-003 | Verify `/metrics` contains `http_request_duration_seconds` histogram | smoke_test | `scripts/qa/verify-observability-stack.sh` | P2 | None (live pod exec) |
| AC-003 | Verify `/metrics` contains all 7 custom metrics from spec | smoke_test | `scripts/qa/verify-observability-stack.sh` | P2 | None (live pod exec) |
| AC-004 | Verify Promtail DaemonSet is running on all nodes| kubectl_check | `scripts/qa/verify-observability-stack.sh`| P1 | None (live cluster) |
| AC-004 | Verify Loki receives logs from mereka-lms namespace | smoke_test | `scripts/qa/verify-observability-stack.sh` |P1 | Requires logcli or HTTP API |
| AC-004 | Verify logs are labeled with namespace, pod, container | smoke_test | `scripts/qa/verify-observability-stack.sh` | P1 | Requires logcli query |
| AC-004 | Verify Loki 7-day retention policy is configured |shell_verification | `scripts/qa/verify-observability-stack.sh` | P2 | None (checks config) |
| AC-005 | Verify Tempo pod is running and healthy | kubectl_check | `scripts/qa/verify-observability-stack.sh` | P2 | None (live cluster) |
| AC-005 | Verify traces are being ingested (query a recent trace) | smoke_test | `scripts/qa/verify-observability-stack.sh` | P2 | Requires generating traffic + Tempo API |
| AC-005 | Verify trace sampling is configured (10% default,100% errors) | shell_verification | `scripts/qa/verify-observability-stack.sh` | P3 | None (checks config) |
| AC-006 | Verify PrometheusRules include OOM/crash-loop/5xx/disk/DB-pool alerts | kubectl_check | `scripts/qa/verify-observability-stack.sh` | P1 | None (live cluster) |
| AC-006 | Verify Alertmanager Slack routing is configured |kubectl_check | `scripts/qa/verify-alert-routing.sh` | P1 | None (checks AM config) |
| AC-006 | Simulate OOM condition and verify alert fires in Slack | manual_verification | Documented inline (requires deliberate pod stress) | P1 | Stress test pod (e.g., `stress-ng`)|
| AC-007 | Verify Grafana Loki datasource has derived fieldsfor trace correlation | kubectl_check | `scripts/qa/verify-observability-stack.sh` | P2 | None (checks datasource config)|
| AC-007 | Click trace ID in Grafana logs panel and verify itopens Tempo trace view | manual_verification | Documented inline (human clicks in Grafana UI) | P2 | Requires correlatedlog+trace |
| AC-008 | Verify Prometheus retention is set to >= 30 days |shell_verification | `scripts/qa/verify-observability-stack.sh` | P1 | None (checks Helm values or Prometheus args) |
| AC-008 | Query metrics older than 7 days to verify data exists | smoke_test | `scripts/qa/verify-observability-stack.sh`| P2 | Requires metrics history |

### Edge Case / Negative Tests

| Edge Case | Test Description | Test Type | Test Location |Priority |
|-----------|------------------|-----------|---------------|----------|
| EC-1: High cardinality metrics | Verify metric_relabel_configs drop high-cardinality labels (user_id, session_id) | shell_verification | `scripts/qa/verify-observability-stack.sh` |P2 |
| EC-2: Log volume spike | Verify Loki rate-limit config exists to prevent ingestion overload | shell_verification | `scripts/qa/verify-observability-stack.sh` | P2 |
| EC-3: Trace sampling miss | Verify error traces (5xx) are always sampled regardless of rate | smoke_test | `scripts/qa/verify-observability-stack.sh` | P3 |
| EC-4: Alertmanager notification failure | Verify Alertmanager has fallback notification (email) if Slack fails | shell_verification | `scripts/qa/verify-alert-routing.sh` | P2 |
| EC-5: Prometheus scrape failure | Verify "target down" alert fires when a pod stops exposing /metrics | manual_verification | Documented inline (scale down, wait for alert) | P2 |
| EC-6: Resource exhaustion | Verify observability stack resource limits are set (< 20% CPU, < 25% memory) | kubectl_check| `scripts/qa/verify-observability-stack.sh` | P1 |
| EC-7: Grafana unauthenticated access | Verify anonymous Grafana access returns 401/redirect | smoke_test | `scripts/qa/verify-observability-stack.sh` | P1 |
| EC-8: Prometheus data loss on restart | Verify Prometheus uses PersistentVolume (not emptyDir) | kubectl_check | `scripts/qa/verify-observability-stack.sh` | P1 |
| EC-9: Concurrent Grafana viewers | Verify Grafana pod has sufficient resources for 10 concurrent viewers | shell_verification | `scripts/qa/verify-observability-stack.sh` | P3 |

### NFR Tests

| NFR | Test Description | Test Type | Test Location | Priority |
|-----|------------------|-----------|---------------|----------|
| Scrape interval <= 30s | Grep all ServiceMonitor YAMLs for`interval:` field | shell_verification | `scripts/qa/verify-observability-stack.sh` | P1 |
| Alert latency <= 2 min | Verify `for:` durations in PrometheusRules are <= 5m (2min fire + margin) | shell_verification| `scripts/qa/verify-observability-stack.sh` | P1 |
| Dashboard load <= 3s | Time a standard Grafana dashboard query over 24h window | manual_verification | Documented inline| P2 |
| LogQL response <= 5s | Time a 1-hour Loki query via API | smoke_test | `scripts/qa/verify-observability-stack.sh` | P2 |
| 50k active time series | Check Prometheus TSDB stats for headSeries count | smoke_test | `scripts/qa/verify-observability-stack.sh` | P3 |
| Loki 500 KB/s ingest | Check Loki distributor_bytes_received_total rate | smoke_test | `scripts/qa/verify-observability-stack.sh` | P3 |
| Resource limit 20% CPU / 25% mem | Sum resource requests across observability pods vs cluster capacity | kubectl_check |`scripts/qa/verify-observability-stack.sh` | P1 |
| PV for Prometheus | Check Prometheus StatefulSet uses PVC not emptyDir | kubectl_check | `scripts/qa/verify-observability-stack.sh` | P1 |
| Auth on all endpoints | HTTP check Grafana, Prometheus UI without auth | smoke_test | `scripts/qa/verify-observability-stack.sh` | P1 |

## Verification Script Structure

The primary verification script `scripts/qa/verify-observability-stack.sh` will follow this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Section 1: ServiceMonitor checks (AC-001)
# Section 2: Grafana access and dashboard checks (AC-002)
# Section 3: /metrics endpoint checks (AC-003)
# Section 4: Loki log ingestion checks (AC-004)
# Section 5: Tempo trace checks (AC-005)
# Section 6: Alert rule and routing checks (AC-006)
# Section 7: Log-trace correlation checks (AC-007)
# Section 8: Retention and NFR checks (AC-008)
# Section 9: Edge case checks (EC-1 through EC-9)
# Section 10: Summary (PASS/FAIL with counts)
```

Modes:
- `--mode local` : Validates YAML files and configuration without cluster access
- `--mode runtime` : Validates live cluster state (requires kubectl access to GKE)

## Manual Verification Checklist

These tests require human execution and cannot be fully automated:

- [ ] **MV-1** (AC-002): Open `https://grafana.mereka.io`, verify login page appears, login, verify dashboards load in under 3 seconds
- [ ] **MV-2** (AC-006): Run `kubectl exec -n mereka-lms deploy/lms -- bash -c 'stress-ng --vm 1 --vm-bytes 2G --timeout 10m'` to trigger OOM, verify alert appears in Slack within 2 minutes
- [ ] **MV-3** (AC-007): In Grafana Explore, query Loki for alog entry with a trace_id, click the trace_id link, verify it navigates to the corresponding trace in Tempo
- [ ] **MV-4** (EC-5): Scale LMS to 0 replicas, wait 5 minutes, verify LMSPodDown alert fires in Alertmanager and reachesSlack
- [ ] **MV-5** (NFR): Open Grafana with 10 browser tabs simultaneously, verify dashboards continue loading without errorsor significant slowdown

## Test Dependencies

| Test | Requires |
|------|----------|
| AC-001 runtime tests | kubectl access to GKE cluster |
| AC-003 smoke tests | django-prometheus installed in LMS image (Task 1.1-1.3) |
| AC-004 log tests | Promtail running, Loki accessible (existing infrastructure) |
| AC-005 trace tests | Tempo deployed (Task 3.1), OTel instrumented (Task 3.2) |
| AC-006 alert tests | Alertmanager Slack webhook configured(Task 2.2) |
| AC-007 correlation tests | Both Tempo (Task 3.2) and Loki log trace_id injection working |
| AC-008 retention tests | Prometheus running for >7 days with data |
