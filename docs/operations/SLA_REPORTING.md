# SLA Reporting
_Audience: Engineering + Enterprise Account Managers • Owner: Engineering Lead • Last updated: 2026-02-10_

This document defines the monthly and quarterly SLA reporting process for Mereka Academy.

## Cadence

| Report | Frequency | Distribution Deadline | Recipients |
|--------|-----------|----------------------|------------|
| Monthly SLA Report | Monthly | Within 5 business days of month end | Enterprise account contacts |
| Quarterly Business Review | Quarterly | Within 10 business days of quarter end | Enterprise account contacts + management |

## Report Generation

### Automated

```bash
# Generate monthly report (dry-run to verify sections)
./scripts/qa/generate-sla-report.sh --dry-run

# Generate for a specific month
./scripts/qa/generate-sla-report.sh --month 2026-01

# Full report with data
./scripts/qa/generate-sla-report.sh --month 2026-01 --output var/sla-reports/2026-01.md

# Validate report contains no internal details
./scripts/qa/verify-sla-report-security.sh var/sla-reports/2026-01.md
```

### Manual Fallback

If the script is not yet available, assemble the report manually using:
1. GCP Cloud Monitoring uptime check results (monthly availability)
2. Grafana SLO dashboard screenshots (latency, error budget)
3. Incident log from Slack `#mereka-operations` or PagerDuty
4. Maintenance log from `var/maintenance-log.csv`

## Report Sections

### Per-Service Availability

For each Tier 1/2/3 service, report:
- Availability percentage for the reporting period
- SLA target vs. actual
- PASS/FAIL compliance status

### Latency Percentiles

For each service tier:
- p50, p95, p99 latency distribution
- Comparison against SLO targets
- Trend vs. previous month

### Error Budget Status

- Remaining error budget per service (as ratio and minutes)
- Burn rate trend over the reporting period
- Any deployment freezes triggered by budget consumption

### Incident Summary

- Count of incidents by severity (P1/P2/P3/P4)
- Mean Time to Resolution (MTTR) by severity
- Root cause categories
- Links to postmortems (P1/P2 only)

### Maintenance Windows

Monthly SLA reports must include all declared maintenance windows:

1. **For each maintenance window**, report:
   - Start time (UTC and local)
   - End time (UTC and local)
   - Scope (which services/features affected)
   - Outcome (completed as planned / overrun / cancelled)
   - Any client impact beyond expected

2. **Verification**:
   - Cross-reference `var/maintenance-log.csv` entries with the reporting month
   - Verify each window was declared at least 72 hours in advance
   - Confirm maintenance duration was excluded from availability calculation

3. **Format in report**:
   ```
   | Date | Time (UTC) | Duration | Scope | Outcome |
   |------|-----------|----------|-------|---------|
   | 2026-01-15 | 02:00-04:30 | 2.5h | K8s upgrade | Completed |
   ```

**Acceptance**: The maintenance windows section appears in the generated SLA report with start time, end time, and scope for every declared window in the reporting period.

### Trend Comparison

- Month-over-month availability trend
- Month-over-month latency trend
- Improvement/degradation highlights

## Security Requirements

Reports distributed to enterprise clients MUST NOT contain:
- Internal IP addresses
- Secret names or values
- K8s namespace/pod names
- Infrastructure hostnames (internal DNS)

Verify with: `./scripts/qa/verify-sla-report-security.sh <report-file>`

## Retention

- SLA reports retained for at least 24 months
- Stored in `var/sla-reports/` (gitignored) and archived to GCS
