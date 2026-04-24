# Assessment Operations Runbook
_Audience: Platform operators and course-launch owners • Owner: Platform Team • Last verified: 2026-04-10 • Status: canonical_

Use this runbook for operator procedures and ownership boundaries around the
assessment lane as a whole.

This is the current assessment-ops companion. It complements, but does not
replace:

- [XQUEUE_HEALTH_RUNBOOK.md](XQUEUE_HEALTH_RUNBOOK.md)
- [PROCTORING_RUNBOOK.md](PROCTORING_RUNBOOK.md)
- [../../guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md](../../guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md)
- [../../../specs/advanced-assessment-xqueue_spec.md](../../../specs/advanced-assessment-xqueue_spec.md)

## Current Platform State

As of 2026-04-10:

- ORA2 is a real supported assessment surface.
- Timed exams with the null backend are a real supported assessment surface.
- XQueue service health is an active runtime concern.
- External grader workers remain planned/gated work rather than a default live
  assessment capability.
- Proctored exams remain disabled pending provider and contract work.
- Bulk assessment operations remain planned/gated rather than universally
  available.

This runbook exists so current operations guidance does not get split across
XQueue-only and proctoring-only documents.

## Use This Runbook When

Use this runbook when you need to:

- classify an assessment incident into the right sub-runbook
- decide whether a requested assessment workflow is live, gated, or deferred
- check launch readiness for ORA2, timed exams, or XQueue-dependent courses
- route operators and course teams to the correct current owner

## Decision Table

| Need | Current state | Primary owner |
| --- | --- | --- |
| ORA2 submissions, rubric flow, ORA grading queue | Supported | this runbook + course authoring guide |
| Timed exam behavior without proctoring | Supported | this runbook + proctoring runbook |
| XQueue service health | Supported runtime surface | [XQUEUE_HEALTH_RUNBOOK.md](XQUEUE_HEALTH_RUNBOOK.md) |
| XQueue external graders | Planned/gated | this runbook + XQueue runbook |
| Proctored exams | Deferred / disabled | [PROCTORING_RUNBOOK.md](PROCTORING_RUNBOOK.md) |
| Bulk export/import/regrade | Planned/gated | this runbook + feature rollout owner |

## Launch Intake Package

Before platform operations should approve an advanced assessment launch, the
request must include:

- course key and launch date
- assessment mode requested
- expected learner volume
- grading owner
- whether uploads, external graders, or timed-exam enforcement are required
- rollback or fallback expectation if the gated feature is not ready

If this package is incomplete, treat the request as planning work, not a
launch-ready escalation.

## Triage Questions

Before changing anything, answer:

1. Is the course using ORA2, timed exams, or both?
2. Is there any dependency on XQueue-backed grading?
3. Is the request actually about proctoring rather than timed exams?
4. Is the problem authoring-side, grading-side, or runtime-side?
5. Is the requested workflow already proved in the current lane, or still only
   described in the spec/plan?

Do not collapse these categories. “Assessment problem” is too vague to operate
on safely.

## Routing Guide

### ORA2 Submission Or Staff-Grading Issues

Use this runbook first, then escalate through the standard LMS/CMS runtime
investigation path if needed.

Common examples:

- submissions fail
- file uploads fail
- grading queue is inconsistent
- staff grading is delayed

If the symptom is actually queue or callback related, move immediately to
[XQUEUE_HEALTH_RUNBOOK.md](XQUEUE_HEALTH_RUNBOOK.md).

#### ORA2 Incident Handling

Work this sequence:

1. confirm whether the symptom is submission, upload, peer review, or staff
   grading
2. capture course key, assignment, learner scope, and launch deadline
3. check whether staff can still complete grading through the ORA grading MFE
4. if uploads or grade propagation are broken, preserve examples before making
   broad config claims
5. if the issue is really queue or callback related, reclassify immediately to
   the XQueue lane

### Timed Exam Issues

Use this runbook for non-proctored timed exam expectations:

- timer enforcement
- timeout behavior
- re-entry expectations
- distinction between timed exams and proctored exams

If the request is about live vendor-backed proctoring, move immediately to
[PROCTORING_RUNBOOK.md](PROCTORING_RUNBOOK.md) and treat it as deferred unless
the provider lane has been explicitly enabled.

#### Timed Exam Response Procedure

For timed exam incidents, establish:

- whether the timer started correctly
- whether timeout/submission behavior matched the learner expectation
- whether the issue is isolated to one learner, one subsection, or the full
  course
- whether the course team accidentally described a proctoring requirement as a
  timed-exam requirement

Do not promise browser lockdown, identity verification, or reviewer oversight
as a timed-exam fix. Those belong to a different lane.

### XQueue Issues

Use [XQUEUE_HEALTH_RUNBOOK.md](XQUEUE_HEALTH_RUNBOOK.md) for:

- pod/runtime health
- queue backlog
- consumer failures
- grader rollout work
- LMS callback failures

Do not describe XQueue-backed grader authoring as live unless the grader worker
deployment and end-to-end proof exist in the current lane.

### Bulk Assessment Operations

Bulk export, import, regrade, or override requests are still a governed rollout
surface, not a default instructor self-serve capability.

Before approving bulk work, confirm:

- the exact operation requested
- the affected course and learner scope
- the source of truth for the target grades or metadata
- rollback or recovery path if the operation misapplies data
- whether the current lane has already proved the operation type

#### Bulk Operation Recovery

If a bulk operation misapplies data or stalls:

1. stop additional operator actions until the authoritative input set is
   preserved
2. capture the exact operation type, submission/learner scope, and source file
3. record which grades or metadata were changed and which were only queued
4. restore from the approved rollback source if one exists
5. do not rerun the operation until the failure mode is classified and the
   operator handoff is updated

## Launch-Readiness Boundary

For an assessment workflow to be called launch-ready, the current lane must
prove all of the following:

- authoring path is available in the correct Studio
- learner submission path works
- grading path works
- grade/result visibility works
- operator recovery path is documented

If one of those is missing, the feature is not launch-ready even if part of the
infrastructure exists.

## Evidence Expectations

For any gated advanced-assessment launch, capture:

- the request owner and launch date
- the lane-specific verification artifact
- the current runtime dependency, if any
- the fallback plan if the feature must be disabled or reverted
- the operator handoff entry showing who accepted the risk

## Alert Response Procedures

When assessment alerts or launch blockers fire:

- classify whether the incident belongs to ORA2, timed exams, XQueue runtime,
  or deferred proctoring
- route queue/runtime symptoms into
  [XQUEUE_HEALTH_RUNBOOK.md](XQUEUE_HEALTH_RUNBOOK.md)
- route vendor readiness questions into
  [PROCTORING_RUNBOOK.md](PROCTORING_RUNBOOK.md)
- treat provider staffing and SLA decisions as deferred owner-gap work until a
  provider-backed proctoring lane is actually live
- preserve launch-impact evidence before making feature-availability claims

## XQueue Rollback Boundary

If grader-backed assessment was trialed and must be backed out:

- stop calling the grader lane “available”
- scale down or disable the grader rollout path
- preserve queue depth, grader failure, and callback evidence
- move the course back to a proved non-grader assessment mode where possible
- require a new verified rollout before reopening the lane

## Current Escalation Boundaries

Escalate when:

- a course depends on XQueue-backed graders
- a course depends on bulk regrade/export/import
- a course launch assumes proctored exams
- the current lane cannot prove the required advanced assessment type
- reviewer staffing or proctoring-SLA questions arise

Reviewer staffing does not have a separate current-owner companion on this
rebased branch. Do not invent a staffing model in local course-launch docs;
keep that boundary with the current vendor/readiness surfaces until the
provider-backed lane is real.

## Related Canonical Docs

- course-team side:
  [../../guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md](../../guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md)
- XQueue runtime side:
  [XQUEUE_HEALTH_RUNBOOK.md](XQUEUE_HEALTH_RUNBOOK.md)
- proctoring boundary:
  [PROCTORING_RUNBOOK.md](PROCTORING_RUNBOOK.md)
- current capability snapshot:
  [../../reference/operations/CAPABILITY_MATRIX.md](../../reference/operations/CAPABILITY_MATRIX.md)
