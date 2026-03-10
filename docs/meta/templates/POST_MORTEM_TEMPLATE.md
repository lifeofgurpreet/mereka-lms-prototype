<!-- @spec: cross-cutting-requirements_spec.md -->
# Post-Mortem Template

_Copy this file to `docs/status/incidents/YYYY-MM-DD-<slug>.md` and fill it in._

**Requirements**: See [postmortems/README.md](postmortems/README.md) for publishing guidelines.
**Full communication templates**: [INCIDENT_TEMPLATES.md](INCIDENT_TEMPLATES.md)

---

# Postmortem: <!-- Incident Title -->

| Field | Value |
|-------|-------|
| **Incident ID** | INC-NNNN |
| **Severity** | P<!-- 1/2/3 --> |
| **Date** | YYYY-MM-DD |
| **Duration** | X hours Y minutes |
| **Incident Commander** | @name |
| **Authors** | @name, @name |
| **Services Affected** | LMS / Studio / MFE / Forum / ... |
| **Postmortem Published** | YYYY-MM-DD |

---

## Summary

<!-- 2-3 sentences. What happened, how many users were affected, and how it was resolved. -->

---

## Timeline

_All times UTC._

| Time (UTC) | Event |
|------------|-------|
| HH:MM | Alert fired: _description_ |
| HH:MM | On-call acknowledged |
| HH:MM | Initial investigation started |
| HH:MM | Root cause identified: _description_ |
| HH:MM | Fix applied: _description_ |
| HH:MM | Service verified healthy |
| HH:MM | Incident declared resolved |

---

## Root Cause

<!-- Technical explanation. What failed and why. No blame — focus on systemic factors.

Example:
After the LMS deployment rolled out, the Kubernetes service selector still referenced the old
pod template labels. Newly-created pods had updated labels but the Service was not updated,
causing endpoints to show <none> and all traffic to fail.
-->

---

## Impact

| Metric | Value |
|--------|-------|
| Users affected | _count or percentage_ |
| Requests failed | _count or percentage_ |
| Data loss | None / _description_ |
| SLA downtime | _X minutes_ |
| Services affected | _list_ |
| Geographic scope | Global / APAC / ... |

---

## What Went Well

<!-- Things that helped contain or resolve the incident faster. -->

- The 5-command diagnostic pinpointed empty endpoints within 2 minutes.
- _Add more..._

---

## What Didn't Go Well

<!-- Things that slowed diagnosis or resolution. Be specific, not blame-oriented. -->

- Alert did not fire until 10 minutes after the outage began because threshold was too high.
- _Add more..._

---

## Root Cause Analysis

### Why did this happen?

<!-- Use 5-whys or fishbone if helpful. -->

1. **Why** did the site go down? → _answer_
2. **Why** did _that_ happen? → _answer_
3. **Why** did _that_ happen? → _answer_

### Contributing Factors

- _Factor 1_
- _Factor 2_

---

## Action Items

| # | Action Item | Owner | Due Date | Status |
|---|-------------|-------|----------|--------|
| 1 | _Description_ | @name | YYYY-MM-DD | Open |
| 2 | _Description_ | @name | YYYY-MM-DD | Open |
| 3 | _Description_ | @name | YYYY-MM-DD | Open |

---

## Lessons Learned

<!-- Key takeaways for the team. Will these be added to CLAUDE.md or runbooks? -->

- _Lesson 1_
- _Lesson 2_

---

## References

- Alert: _link to Alertmanager or Prometheus query_
- Incident thread: _link to #mereka-incidents Slack thread_
- Fix commit: _git SHA or PR link_
- Related runbook: _link_
