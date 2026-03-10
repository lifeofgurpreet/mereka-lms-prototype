# Analytics Pipeline Runbook
_Audience: Platform Eng + Data Team • Owner: Engineering Lead • Last updated: 2026-02-13_

This runbook covers operational procedures for the analytics pipeline.

> **DEPLOYMENT STATUS**: Aspects/Superset NOT DEPLOYED - This runbook documents target-state procedures
>
> **Current state**:
> - Aspects plugin installed locally but not deployed to production
> - Superset dashboards not available
> - Learning analytics pipeline not active
>
> **Infrastructure monitoring** (Prometheus/Grafana): OPERATIONAL - but this is separate from learning analytics
>
> **To deploy Aspects**: Follow `docs/concepts/analytics/ASPECTS_TARGET_STATE.md`
>
> **Spec**: `specs/analytics-pipeline_spec.md`
> **Testmap**: `specs/testmaps/analytics-pipeline_spec.testmap.yml`
>
> <!-- Last deployment status check: 2026-02-13 (docs audit) -->

## Prerequisites

- Access to production GKE cluster
- Access to Grafana dashboards
- ClickHouse client (if direct access needed)

---

## ClickHouse Disk Space

### Procedure
1. Check ClickHouse disk usage:
   ```bash
   kubectl exec -n mereka-lms deploy/clickhouse -- clickhouse-client \
     --query "SELECT formatReadableSize(sum(bytes_on_disk)) FROM system.parts"
   ```
2. Verify TTL-based deletion is working:
   ```bash
   kubectl exec -n mereka-lms deploy/clickhouse -- clickhouse-client \
     --query "SELECT table, partition, rows, formatReadableSize(bytes_on_disk) FROM system.parts WHERE active ORDER BY modification_time DESC LIMIT 20"
   ```
3. Check available disk space on the PV:
   ```bash
   kubectl exec -n mereka-lms deploy/clickhouse -- df -h /var/lib/clickhouse
   ```

### Acceptance
- Disk usage < 80% of allocated PV
- TTL-based deletion is removing data older than retention period
- No "disk full" errors in ClickHouse logs

---

## Dashboard Verification

### Procedure
1. Access Grafana analytics dashboard
2. Verify dashboard loads within 5 seconds
3. Check all panels show data:
   - Active users (daily/weekly/monthly)
   - Course enrollment trends
   - Completion rates
   - Revenue metrics (if applicable)
4. Verify date range picker works correctly
5. Test drill-down from summary to detail views

### Acceptance
- Dashboard loads in < 5 seconds
- All panels show data for the selected date range
- No "No data" panels for periods with known activity
- Visual elements render correctly (charts, tables, numbers)

---

## Dashboard Embedding Verification

### Procedure
1. Log in to LMS as an admin/instructor
2. Navigate to a course with embedded analytics dashboard
3. Verify iframe loads the Grafana dashboard within the LMS page
4. Verify authentication pass-through works (no separate Grafana login)
5. Verify dashboard respects course-level data isolation

### Acceptance
- Embedded dashboard renders within LMS iframe
- No authentication prompt within the iframe
- Dashboard shows only data for the current course
- Iframe is responsive and renders on mobile viewports
