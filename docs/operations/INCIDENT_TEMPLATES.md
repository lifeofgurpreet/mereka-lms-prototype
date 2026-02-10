# Incident Communication Templates
_Audience: All Engineers + Account Managers • Owner: Engineering Lead • Last updated: 2026-02-10_

This document provides templates for incident lifecycle communication: declaration, updates, resolution, and postmortems.

## Incident Declaration Template

```
## Incident: <TITLE>
**Severity**: P<N> (<Critical|High|Medium|Low>)
**Declared**: <YYYY-MM-DD HH:MM UTC>
**Incident Commander**: @<name>
**Primary On-Call**: @<name>

### Impact
<What is affected? How many users/clients impacted?>

### Current Status
<What do we know? What is being investigated?>

### Next Update
<Expected time of next status update>
```

## Status Update Template

```
## Update #<N> - <YYYY-MM-DD HH:MM UTC>
**Severity**: P<N> (unchanged|escalated|de-escalated)

### Progress
<What has been done since last update?>

### Current Status
<What is the current state?>

### Next Steps
<What is being done next?>

### Next Update
<Expected time of next update>
```

## Resolution Template

```
## Incident Resolved - <YYYY-MM-DD HH:MM UTC>
**Severity**: P<N>
**Duration**: <X hours Y minutes>
**Incident Commander**: @<name>

### Resolution
<What fixed the issue?>

### Impact Summary
<Total impact: users affected, duration, data implications>

### Follow-up
Postmortem will be published within 5 business days.
```

## Postmortem

### Required Sections Checklist

Every P1/P2 postmortem MUST be published within 5 business days of resolution and MUST contain all of the following sections:

- [ ] **Title and Metadata**: Incident ID, severity, date, duration, Incident Commander, authors
- [ ] **Timeline**: Chronological sequence of events from detection through resolution, with timestamps (UTC)
- [ ] **Root Cause**: Technical explanation of what caused the incident (not blame-oriented)
- [ ] **Impact**: Quantified scope — users affected, requests failed, data implications, SLA impact
- [ ] **Remediation**: What was done to resolve the incident (immediate fix)
- [ ] **Prevention**: Action items to prevent recurrence, each with owner and due date

**Verification procedure**:

1. **Locate the postmortem** in `docs/operations/postmortems/` or the incident tracking system
2. **Check publication date** is within 5 business days of incident resolution
3. **Verify all required sections** are present using the checklist above
4. **Verify action items** have owners and due dates assigned
5. **Verify the postmortem is linked** in the monthly SLA report's incident summary

**Acceptance**: Postmortem is published within 5 business days, contains all required sections (timeline, root cause, impact, remediation, prevention), and action items have assigned owners.

### Postmortem Template

```markdown
# Postmortem: <Incident Title>

| Field | Value |
|-------|-------|
| **Incident ID** | INC-<NNNN> |
| **Severity** | P<N> |
| **Date** | <YYYY-MM-DD> |
| **Duration** | <X hours Y minutes> |
| **Incident Commander** | <name> |
| **Authors** | <names> |

## Timeline

| Time (UTC) | Event |
|------------|-------|
| HH:MM | Alert fired: <description> |
| HH:MM | On-call acknowledged |
| HH:MM | Root cause identified |
| HH:MM | Fix applied |
| HH:MM | Verified healthy |
| HH:MM | Incident resolved |

## Root Cause

<Technical explanation of what caused the incident>

## Impact

- **Users affected**: <count or percentage>
- **Requests failed**: <count or percentage>
- **Data loss**: <none | description>
- **SLA impact**: <minutes of downtime against error budget>
- **Services affected**: <list>

## Remediation

<What was done to fix the immediate issue>

## Prevention

| # | Action Item | Owner | Due Date | Status |
|---|-------------|-------|----------|--------|
| 1 | <action> | @<name> | <date> | Open |
| 2 | <action> | @<name> | <date> | Open |
```

## Filing Location

- Postmortems: `docs/operations/postmortems/<YYYY-MM-DD>-<slug>.md`
- Incident log: maintained in monthly SLA report (sanitized for client visibility)
