# Postmortems

This directory contains postmortem reports for production incidents affecting Mereka Academy.

## Purpose

Postmortems are blameless technical analyses written after incidents to:
- Document what happened and why
- Identify systemic improvements to prevent recurrence
- Share knowledge across the team
- Build organizational resilience

## When to Write a Postmortem

**Required** for all P1 and P2 incidents (severity definitions in [INCIDENT_TEMPLATES.md](../INCIDENT_TEMPLATES.md))

**Optional but recommended** for P3 incidents with interesting technical lessons

## Timeline

Postmortems MUST be published within **5 business days** of incident resolution.

## Required Sections

Every postmortem must contain:

1. **Title and Metadata**: Incident ID, severity, date, duration, Incident Commander, authors
2. **Timeline**: Chronological sequence of events with UTC timestamps
3. **Root Cause**: Technical explanation (not blame-oriented)
4. **Impact**: Quantified scope - users affected, requests failed, data implications, SLA impact
5. **Remediation**: What was done to resolve the incident (immediate fix)
6. **Prevention**: Action items with owners and due dates

## Template

See the full template in [INCIDENT_TEMPLATES.md](../INCIDENT_TEMPLATES.md#postmortem-template).

Quick template:

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

<Technical explanation>

## Impact

- **Users affected**: <count or percentage>
- **Requests failed**: <count or percentage>
- **Data loss**: <none | description>
- **SLA impact**: <minutes of downtime>
- **Services affected**: <list>

## Remediation

<What was done to fix the immediate issue>

## Prevention

| # | Action Item | Owner | Due Date | Status |
|---|-------------|-------|----------|--------|
| 1 | <action> | @<name> | <date> | Open |
| 2 | <action> | @<name> | <date> | Open |
```

## Filing Naming Convention

Postmortems should be named: `<YYYY-MM-DD>-<slug>.md`

Example: `2026-02-15-mysql-connection-pool-exhaustion.md`

## Verification

Before publishing, ensure:

- [ ] All required sections are present
- [ ] Action items have assigned owners
- [ ] Action items have due dates
- [ ] Timeline uses UTC timestamps
- [ ] Impact is quantified (not "some users" but "~500 users")
- [ ] Root cause is technical and blameless
- [ ] Postmortem is linked in monthly SLA report

## Review Process

1. Incident Commander drafts the postmortem
2. Key participants review and add context
3. Engineering Lead approves before publication
4. Postmortem is shared with the team and added to this directory

## Questions?

See [INCIDENT_TEMPLATES.md](../INCIDENT_TEMPLATES.md) for the full postmortem specification.
