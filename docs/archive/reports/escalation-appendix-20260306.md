# Escalation Appendix 2026-03-06
_Audience: Docs Lead + Domain Owners + Reviewers • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Purpose
Define deterministic routing for blockers and policy conflicts under `GOV-02`.

## Decision Rights Routing
| Trigger | First Escalation Target | Final Decision Authority | Target Response Time |
|---|---|---|---|
| Canonical conflict across docs in same topic | Domain Owner | Docs Lead | 1 business day |
| Policy conflict with remediation playbook | Docs Lead | Docs Lead | 1 business day |
| Evidence archive uncertainty (risk of active doc archival) | Domain Owner + Docs Lead | Docs Lead | 1 business day |
| Compliance/security concern in docs instructions | Security/Compliance Reviewer | Docs Lead + Security/Compliance Reviewer | same day |
| Broken-link regression after structural move | Reviewer | Docs Lead | same day |

## Escalation Rules
1. Mark tracker task `BLOCKED` with concrete reason and file paths.
2. Open/append a note in weekly scorecard under `Risks and Blocks`.
3. Do not perform canonical reassignment without domain owner acknowledgement.
4. Do not archive evidence by age-only criteria; apply lifecycle matrix + owner approval.
5. Resume blocked task only after escalation decision is recorded.

## Communication Contract
- Required fields for escalation message:
  - task ID
  - affected path(s)
  - conflict type (`canonical-conflict|policy-conflict|compliance|link-breakage|archive-risk`)
  - proposed safe action
- A decision must be recorded in one of:
  - `docs/archive/reports/docs-program-scorecard-YYYYMMDD.md`
  - `docs/archive/reports/governance-approval-note-YYYYMMDD.md`

## Blocking Examples
- Two canonical docs with contradictory procedures for the same runbook trigger.
- A superseded stub missing replacement pointer in first 10 lines.
- A proposed evidence move based only on file age without role/status checks.
