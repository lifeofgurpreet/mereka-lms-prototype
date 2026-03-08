# Maintenance Window Policies
_Audience: Platform Eng + Enterprise Account Managers • Owner: Engineering Lead • Last updated: 2026-02-10_

This document defines maintenance window policies for Mereka Academy (Open edX on GKE). Maintenance windows are excluded from SLA availability calculations per the SLO/SLA spec.

## Constraints

| Policy | Requirement |
|--------|-------------|
| Advance notice | Notify enterprise clients at least 72 hours before scheduled maintenance |
| Preferred window | 02:00-06:00 UTC (10:00-14:00 MYT) weekdays, or weekends |
| Maximum duration | 4 hours per maintenance window |
| Maximum frequency | 2 maintenance windows per calendar month |
| Emergency maintenance | Permitted with less than 72h notice for P1 incidents; immediate notification required |
| SLA exclusion | Declared maintenance window duration excluded from SLA availability calculations |

## Declaration Procedure

1. **Create maintenance record** in the maintenance calendar (Google Calendar: "Mereka Academy Maintenance"):
   - Title: `[Maintenance] <scope> - <date>`
   - Duration: planned start/end in UTC
   - Description: scope of changes, expected impact, rollback plan

2. **Notify enterprise clients** at least 72 hours in advance:
   - Email to enterprise account contacts (template below)
   - Update status page at `https://status.mereka.dev`
   - Post in Slack `#mereka-operations` channel

3. **Log the window** for SLA reporting:
   ```bash
   # Record in maintenance log (append to CSV)
   echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),<end-time>,<scope>,<outcome>" >> var/maintenance-log.csv
   ```

## Notification Template

```
Subject: [Mereka Academy] Scheduled Maintenance - <DATE>

Dear <Client>,

We are writing to inform you of a scheduled maintenance window for Mereka Academy:

  Date: <DATE>
  Time: <START> - <END> UTC (<START_MYT> - <END_MYT> MYT)
  Duration: <N> hours (maximum)
  Scope: <description of changes>
  Expected Impact: <brief description>

During this window, the platform may be temporarily unavailable. This maintenance
is excluded from SLA availability calculations per our service agreement.

If you have questions, please contact your account manager.

Best regards,
Mereka Academy Platform Team
```

## Execution Checklist

- [ ] Maintenance record created in calendar (72h+ in advance)
- [ ] Enterprise client notification sent
- [ ] Status page updated to "Under Maintenance"
- [ ] Pre-maintenance backup created (`velero backup create pre-op-...`)
- [ ] Changes applied within declared window
- [ ] Post-maintenance health check (`./scripts/qa/public-health-check.sh prod`)
- [ ] Status page updated to "Operational"
- [ ] Maintenance log entry recorded with outcome

## Verification

### SLA Exclusion Test

To verify maintenance windows are excluded from SLA availability calculations:

1. **Check maintenance log** exists and contains the window:
   ```bash
   cat var/maintenance-log.csv
   # Should show: start_time,end_time,scope,outcome
   ```

2. **Generate SLA report for the maintenance period**:
   ```bash
   ./scripts/qa/generate-sla-report.sh --month <YYYY-MM> --dry-run
   ```

3. **Verify exclusion** in the report output:
   - The "Maintenance Windows" section lists the declared window
   - Availability percentage calculation excludes the window duration from both numerator and denominator
   - SLA compliance status reflects availability without maintenance downtime

4. **Cross-reference with monitoring data**:
   - Check GCP uptime check results for the maintenance period
   - Verify any downtime during the window is annotated as "maintenance" in Grafana
   - Confirm the downtime does NOT count against error budget

**Acceptance**: The monthly SLA report correctly excludes declared maintenance windows, and the availability percentage matches expectations when maintenance downtime is removed from the calculation.

## Overrun Handling

If maintenance exceeds the declared window:
1. Alert fires at 75% of declared duration (3h for a 4h window)
2. Overage beyond declared duration counts against SLA availability
3. Log overrun with root cause in maintenance record
4. Send additional client notification explaining the delay
