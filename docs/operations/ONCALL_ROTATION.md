# On-Call Rotation & Escalation
_Audience: All Engineers • Owner: Engineering Lead • Last updated: 2026-02-10_

This document defines the on-call rotation structure and escalation procedures for Mereka Academy.

## Roles

| Role | Responsibility | Response Time | Rotation |
|------|---------------|---------------|----------|
| Primary On-Call | First responder; triage and initial remediation | 15 min (P1), 30 min (P2) | Weekly |
| Secondary On-Call | Backup if primary unreachable; escalation point | 30 min (P1), 1 hr (P2) | Weekly (offset) |
| Incident Commander | Coordinates P1/P2 response; owns communication; declares resolution | Engaged for all P1 | Engineering Lead (fixed) |

## Constraints

- No engineer on-call for more than 7 consecutive days
- Primary and secondary must be different engineers each week
- On-call handoff documentation required at each rotation change
- Schedule maintained in Slack (pinned in `#mereka-operations`) and/or PagerDuty

## Schedule Verification

To verify the on-call schedule meets requirements:

1. **Check current week assignment**:
   - Open `#mereka-operations` Slack channel → pinned schedule
   - Or check PagerDuty/Opsgenie if configured
   - Verify both primary and secondary are assigned

2. **Verify no consecutive duty exceeds 7 days**:
   - Review the schedule for the past 30 days
   - No engineer should appear as primary or secondary for more than 7 consecutive days
   - Cross-check with any swap records

3. **Verify handoff documentation exists**:
   - At each rotation boundary, the outgoing on-call should have posted:
     - Open issues/incidents from the previous week
     - Any ongoing monitoring concerns
     - Pending follow-ups

**Acceptance**: Every inspected week has both primary and secondary assigned, no engineer exceeds 7 consecutive days, and handoff documentation exists at rotation boundaries.

## Escalation Matrix

| Tier | Trigger | Escalation Target | Time Limit |
|------|---------|-------------------|------------|
| L1 | Alert fires | Primary on-call | 15 min to acknowledge |
| L2 | Primary does not ack in 15 min OR cannot resolve in 30 min | Secondary on-call | 15 min to acknowledge |
| L3 | Secondary does not ack in 15 min OR issue persists > 1 hr | Incident Commander (engineering lead) | 15 min to acknowledge |
| L4 | Issue persists > 2 hrs OR data loss confirmed | VP/CTO | Immediate |

## Incident Response

### P1 Acknowledgement

A P1 (Critical) incident requires acknowledgement within 15 minutes of alert firing.

**Verification procedure**:

1. **Check Alertmanager/PagerDuty history** for the P1 alert:
   - Note the alert fire timestamp
   - Note the acknowledgement timestamp (Slack reaction, PagerDuty ack, or incident channel response)

2. **Calculate response time**:
   ```
   response_time = ack_timestamp - alert_fire_timestamp
   ```

3. **Verify against SLA**:
   - P1 acknowledgement: must be <= 15 minutes
   - If exceeded, check whether escalation to L2 occurred automatically

4. **For drill/simulation**:
   - Trigger a test alert via Alertmanager silence removal or manual alert
   - Measure time to acknowledgement by on-call engineer
   - Document response time in drill report

**Acceptance**: P1 alerts are acknowledged within 15 minutes. If primary on-call does not respond, automatic escalation to secondary occurs.

### P2 Acknowledgement

- P2 acknowledgement target: 30 minutes
- Same verification procedure as P1 with adjusted threshold

## Escalation

### Auto-Escalation Test

To verify automatic escalation works when primary on-call is unreachable:

1. **Check Alertmanager escalation config**:
   ```bash
   # Verify escalation routes exist in Alertmanager config
   kubectl -n monitoring get secret alertmanager-monitoring-kube-prometheus-alertmanager \
     -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d | grep -A10 'group_wait\|repeat_interval'
   ```

2. **Verify escalation routing**:
   - Primary on-call receives alert first
   - After `group_wait` + `repeat_interval` (configured for 15 min), if not silenced/resolved:
     - Alert re-fires to secondary on-call channel/contact
   - After additional 15 min without resolution:
     - Alert escalates to Incident Commander

3. **Simulated escalation test** (quarterly):
   - Primary on-call deliberately does not acknowledge a test alert
   - Verify secondary receives escalation within 15 minutes
   - Verify Incident Commander is notified if secondary also does not respond
   - Document escalation timing in drill report

4. **Verify automated check** covers Alertmanager config:
   ```bash
   bash scripts/qa/verify-error-budget.sh --check-escalation-config
   ```

**Acceptance**: When primary on-call does not acknowledge a P1 alert within 15 minutes, the alert automatically escalates to secondary on-call. Full end-to-end escalation path verified quarterly.

## Handoff Template

At each rotation change, outgoing on-call posts in `#mereka-operations`:

```
## On-Call Handoff: <DATE>
Outgoing: @<name> | Incoming: @<name>

### Open Issues
- <issue description> (status, next steps)

### Monitoring Notes
- <any degraded signals, known flaky alerts>

### Pending Follow-ups
- <items that need attention this week>
```
