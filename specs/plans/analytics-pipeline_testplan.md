---
spec: analytics-pipeline_spec.md
tier: 2
status: draft
last_updated: '2026-02-10'
test_framework: shell_verification + kubectl_check + smoke_test + manual_verification
plan: analytics-pipeline_plan.md
---

# Analytics Pipeline (Aspects/Panorama) -- Test Plan

**Source Spec**: `specs/analytics-pipeline_spec.md`

## Test Framework Context

This project is an infrastructure/deployment repository. There is no application-level test framework (no Vitest, Jest, orpytest for the core system). Testing follows the establishedpattern in `scripts/qa/`:

| Test Type | Tool | Pattern |
|-----------|------|---------|
| `shell_verification` | Bash scripts | `scripts/qa/verify-*.sh`, `scripts/qa/audit-*.sh` |
| `kubectl_check` | kubectl commands | Inline in verificationscripts |
| `smoke_test` | Bash scripts (HTTP checks) | `scripts/qa/smoke-test-analytics.sh` |
| `manual_verification` | Human checklist | Documented inlinebelow |

---

## Test Matrix

### Acceptance Criteria Tests

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-001 | Aspects plugin shows as enabled in `tutor pluginslist` | `shell_verification` | `scripts/qa/verify-analytics-pipeline.sh` | None (runs against live Tutor env) |
| AC-001 | Negative: plugin disabled returns non-zero | `shell_verification` | `scripts/qa/verify-analytics-pipeline.sh` |None |
| AC-002 | xAPI events exist in ClickHouse `xapi_events` table with count > 0 | `kubectl_check` | `kubectl exec deploy/clickhouse -n mereka-lms -- clickhouse-client --query "SELECT count() FROM openedx.xapi_events"` | Requires at least 1 courseactivity after Aspects enabled |
| AC-002 | Events contain expected verb types (registered, enrolled, completed, viewed) | `kubectl_check` | `kubectl execdeploy/clickhouse -n mereka-lms -- clickhouse-client --query"SELECT DISTINCT verb_id FROM openedx.xapi_events"` | Requires test learner activity |
| AC-002 | Negative: empty ClickHouse returns non-zero exit from verification | `shell_verification` | `scripts/qa/verify-analytics-pipeline.sh` | Clean ClickHouse (no events) |
| AC-003 | TTL configured on `xapi_events` table (90-day retention) | `kubectl_check` | `kubectl exec deploy/clickhouse -nmereka-lms -- clickhouse-client --query "SHOW CREATE TABLE openedx.xapi_events" \| grep -i TTL` | None |
| AC-003 | Negative: events older than 90 days are automatically removed | `manual_verification` | Manually insert backdated row, wait for merge cycle, verify deletion | Requires ClickHouse admin access |
| AC-004 | Superset health endpoint returns HTTP 200 | `smoke_test` | `scripts/qa/smoke-test-analytics.sh` | None (runs against live cluster) |
| AC-004 | Superset accessible via ingress URL (analytics.academyv2.mereka.io) | `smoke_test` | `scripts/qa/smoke-test-analytics.sh` | Requires DNS + ingress configured |
| AC-004 | Negative: Superset pod not running detected by verification script | `shell_verification` | `scripts/qa/verify-analytics-pipeline.sh` | Simulate pod down |
| AC-005 | Pre-built dashboards exist in Superset (count >= 5) | `kubectl_check` | `kubectl exec deploy/superset -n mereka-lms -- superset list_dashboards` or API query | Requires dashboard import job completed |
| AC-005 | Dashboards load in under 5 seconds | `manual_verification` | Staff user opens each dashboard, measures load time in browser DevTools | Staff OAuth login required |
| AC-006 | No email addresses in ClickHouse event data | `shell_verification` | `scripts/qa/audit-analytics-pii.sh` | None(queries live ClickHouse) |
| AC-006 | No IP addresses in ClickHouse event data | `shell_verification` | `scripts/qa/audit-analytics-pii.sh` | None |
| AC-006 | Actor IDs are SHA-256 hashes (64 hex chars) | `shell_verification` | `scripts/qa/audit-analytics-pii.sh` | None|
| AC-006 | Negative: injecting PII into events is detected byaudit | `shell_verification` | `scripts/qa/audit-analytics-pii.sh` | Insert test row with email address, verify audit catches it |
| AC-007 | Instructor can view embedded dashboard in LMS course page | `manual_verification` | Staff user logs into LMS, navigates to course with embedded dashboard, verifies iframe loads | Requires Superset embedding configured + LMS course with embed block |
| AC-007 | Non-staff user cannot see embedded dashboard | `manual_verification` | Learner user in LMS course sees placeholder or nothing instead of dashboard | Requires RBAC test |
| AC-008 | User deletion script removes events from all ClickHouse tables | `shell_verification` | `scripts/qa/verify-analytics-pipeline.sh` (calls `scripts/analytics/delete-user-events.sh`) | Insert test user data, run deletion, verify zero rows |
| AC-008 | Deletion verification script confirms zero remaining records | `shell_verification` | `scripts/analytics/verify-user-deletion.sh` | Post-deletion state |
| AC-008 | Negative: deletion of non-existent user returns gracefully | `shell_verification` | `scripts/analytics/delete-user-events.sh` | Non-existent user hash |

### Edge Case Tests

| Edge Case | Test Case | Type | File / Command | Mocks/Fixtures |
|-----------|-----------|------|----------------|----------------|
| EC-1: Event Backpressure | Verify batch size is configurable (`ASPECTS_EVENT_BATCH_SIZE`) | `shell_verification` | `scripts/qa/verify-analytics-pipeline.sh` | Check Tutor config value |
| EC-2: ClickHouse Disk Space | Alert fires when disk usage exceeds 80% | `kubectl_check` | `kubectl get prometheusrule -nmereka-lms -o yaml \| grep "clickhouse_disk"` | PrometheusRule deployed |
| EC-2: ClickHouse Disk Space | PVC size is adequate (>= 10Gi) | `kubectl_check` | `kubectl get pvc clickhouse-data -n mereka-lms -o jsonpath='{.spec.resources.requests.storage}'` | None |
| EC-3: Superset Query Timeout | Superset timeout is configured (>= 120s) | `kubectl_check` | Check Superset configmap for`SUPERSET_WEBSERVER_TIMEOUT` | None |
| EC-4: PII Leakage | Comprehensive PII scan across all ClickHouse tables | `shell_verification` | `scripts/qa/audit-analytics-pii.sh` | None (full table scan) |
| EC-5: Data Deletion Compliance | Deletion audit log is written | `shell_verification` | `scripts/analytics/delete-user-events.sh` | Check log file after deletion |

### NFR Tests

| NFR | Test Case | Type | File / Command | Mocks/Fixtures |
|-----|-----------|------|----------------|----------------|
| Event lag <= 10 min | Monitoring alert exists for lag > 10min | `kubectl_check` | `kubectl get prometheusrule -n mereka-lms -o yaml \| grep "event_processing_lag"` | PrometheusRuledeployed |
| Query response <= 5s p95 | Dashboard queries complete in under 5s (manual timing) | `manual_verification` | Time dashboard load in browser | Staff login required |
| Write throughput >= 500 events/sec | ClickHouse write metrics show sustained throughput | `manual_verification` | CheckGrafana dashboard during load | Requires synthetic load or production traffic |
| Superset availability >= 99.5% | Superset health endpoint monitored by uptime check | `kubectl_check` | Check probe configuration in deployment | None |
| Storage cost <= $50/month | PVC size + compression yields target cost | `manual_verification` | Calculate from GKE diskpricing * PVC size | GKE pricing data |
| GDPR deletion <= 7 days | Deletion script can complete within minutes (well under 7 days) | `shell_verification` | `scripts/analytics/delete-user-events.sh` + timing | Test user data |

---

## Test Execution Order

Tests should be executed in this order during verification:

1. **Infrastructure checks** (Phase 1): secrets synced, PVC exists, pods running
2. **Pipeline checks** (Phase 2): Aspects enabled, events flowing, schema correct
3. **PII audit** (Phase 2): no PII in event data
4. **Dashboard checks** (Phase 3): Superset accessible, dashboards loaded, RBAC working
5. **Deletion checks** (Phase 4): deletion script works, verification confirms
6. **Observability checks** (Phase 5): ServiceMonitors, PrometheusRules, Grafana dashboard
7. **Smoke tests** (Phase 6): all HTTP endpoints healthy
8. **Manual verifications** (Phase 6): embedding, load times,throughput

---

## Verification Script Inventory

| Script | Purpose | ACs Covered |
|--------|---------|-------------|
| `scripts/qa/verify-analytics-pipeline.sh` | Comprehensive pipeline health check | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006 |
| `scripts/qa/audit-analytics-pii.sh` | PII detection scan across ClickHouse | AC-006 |
| `scripts/qa/smoke-test-analytics.sh` | HTTP health checks for Superset and ClickHouse | AC-004 |
| `scripts/analytics/delete-user-events.sh` | Execute GDPR data deletion | AC-008 |
| `scripts/analytics/verify-user-deletion.sh` | Confirm deletion completeness | AC-008 |

---

## Manual Verification Checklist

For acceptance criteria that require manual verification:

- [ ] **AC-003 (retention)**: Insert a row with `timestamp` older than 90 days. Wait for ClickHouse merge cycle (or forcewith `OPTIMIZE TABLE`). Verify the row no longer exists.
- [ ] **AC-005 (dashboard load time)**: Open each of the 5 pre-built dashboards in Chrome. Use Network tab to verify initial load completes in under 5 seconds.
- [ ] **AC-007 (instructor embedding)**: Log in as a staff user. Navigate to a course page that has a Superset embed block. Verify the iframe loads and displays analytics data.
- [ ] **AC-007 (non-staff blocked)**: Log in as a non-staff learner. Navigate to the same course page. Verify the embeddeddashboard is not visible or shows access denied.
- [ ] **NFR (query response)**: Execute 5 representative dashboard queries in Superset SQL Lab. Record p95 latency. Must be <= 5 seconds.
- [ ] **NFR (write throughput)**: During a period of active learner usage, check the Grafana analytics dashboard for ClickHouse write throughput metric. Should sustain >= 500 events/sec.

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-008) hasat least one test case
- [x] Every edge case from the spec has a negative/verification test
- [x] Test types are appropriate for what is being tested (infra = shell/kubectl, UI = manual)
- [x] Mocks/fixtures specified where external services or test data are required
- [x] Manual verification items have clear instructions and acceptance threshold
- [x] Verification scripts follow existing `scripts/qa/` naming convention
- [x] Source spec linked in header
