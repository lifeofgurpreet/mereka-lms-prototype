# Advanced Assessment Authoring Guide

Use this guide when a course team needs to design or operate beyond basic
multiple-choice problems in Studio.

This is the current companion for advanced assessment authoring on Mereka LMS.
It complements, but does not replace:

- [COURSE_AUTHORING_QUICKSTART.md](COURSE_AUTHORING_QUICKSTART.md)
- [OPENEDX_FOR_TEAM_MEMBERS.md](OPENEDX_FOR_TEAM_MEMBERS.md)
- [../../ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md](../../ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md)
- [../../ops/runbooks/PROCTORING_RUNBOOK.md](../../ops/runbooks/PROCTORING_RUNBOOK.md)
- [../../../specs/advanced-assessment-xqueue_spec.md](../../../specs/advanced-assessment-xqueue_spec.md)

## Current Platform Boundary

As of 2026-04-10:

- ORA2 authoring is a real platform surface.
- Timed exams with the null proctoring backend are a real platform surface.
- The XQueue service is deployed, but external grader workers are not yet a
  production-ready default capability.
- Proctored exam workflows are disabled pending provider selection and contract
  work.
- Bulk assessment operations and analytics are planned work, not a universally
  enabled author workflow.

Do not promise code-grader-backed problems, proctored exam flows, or bulk grade
operations as generally available unless the current lane has explicitly proved
them.

There is intentionally no standalone XQueue grader authoring guide. The
course-team boundary stays here, while runtime and rollback stay in
[../../ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md](../../ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md)
and
[../../ops/runbooks/ASSESSMENT_OPERATIONS_RUNBOOK.md](../../ops/runbooks/ASSESSMENT_OPERATIONS_RUNBOOK.md)
until external grader workers become a real maintained launch surface.

## Before You Start

1. Use [COURSE_AUTHORING_QUICKSTART.md](COURSE_AUTHORING_QUICKSTART.md) to get
   into the correct Studio and course shell.
2. Confirm the tenant and Studio URL from
   [../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md).
3. Confirm whether the course needs:
   - rubric-based open response
   - timed exam behavior
   - code or external grading
   - advanced XBlock problem types
4. If the workflow depends on gated features, escalate before promising it to
   course staff.

## What Course Authors Can Reliably Use

## Assessment Choice Matrix

Use this table before promising an advanced assessment pattern to a course
team.

| Requirement | Current answer | Safe authoring lane | Escalate when |
| --- | --- | --- | --- |
| rubric-based written or portfolio submissions | supported | ORA2 | uploads, grading queue, or rubric workflow behave inconsistently |
| time-limited exam without identity verification | supported | timed exam with null backend | the course asks for browser lockdown, identity checks, or external review |
| code or external grader-backed submissions | gated | coordinated XQueue rollout only | the course launch depends on it at all |
| provider-backed proctored exam | deferred | not a launch-ready authoring promise | always |
| bulk assessment export/import/regrade | gated | coordinated ops lane only | always |
| unusual XBlock assessment type | verification-required | lane-specific proof before promise | the block has not been exercised in the current lane |

### ORA2

Use ORA2 when the course needs:

- free-text or portfolio-style submissions
- rubric-based grading
- peer assessment
- staff assessment through the ORA grading interface

Current expectations:

- ORA2 file uploads are supported through the configured filesystem-backed
  storage path
- rubric and peer-review behavior should be treated as course-level design work
  that needs staff review before launch
- staff grading routes through the ORA grading MFE, not ad-hoc admin actions

#### ORA2 Rubric And Review Design Patterns

Use ORA2 when the rubric can be made explicit and repeatable. The safest
launches share these patterns:

- keep criteria small and observable rather than subjective catch-all buckets
- use a small number of score bands per criterion unless assessors are already
  trained on a richer rubric
- separate “required for pass” criteria from “quality” criteria so staff can
  explain outcomes consistently
- pilot peer-review wording with internal staff before opening it to learners

#### ORA2 Peer Assessment Configuration

Before enabling peer assessment, confirm:

- the course team can recruit enough active reviewers to satisfy the expected
  review count
- the deadline structure leaves time for learner submissions, peer review, and
  fallback staff grading
- the rubric language is stable before the first learner submission
- the course team knows which submissions should be escalated to staff review

If reviewer volume is doubtful, plan for staff-assessment fallback instead of
promising peer review as the only grading path.

#### ORA2 File Upload Best Practices

Treat uploads as part of launch design, not an afterthought:

- publish allowed file types and size expectations in the learner instructions
- keep required deliverables narrow enough that staff can grade them
  consistently
- require stable naming conventions only if the course team can enforce them
  operationally
- test the exact upload path in the launch tenant before promising portfolio or
  attachment-heavy assignments

#### ORA2 Grading Workflow

The current supported grading workflow is:

1. learner submits through ORA2
2. peer review runs when configured and staffed
3. staff grading completes in the ORA grading MFE when staff intervention is
   required
4. final score propagates to the gradebook

If a course team expects spreadsheet-based grading, offline scoring, or mass
override tooling, that is no longer an ORA2-only authoring question. Escalate
it as a governed bulk-operations request.

### Timed Exams

Use timed exams when the requirement is:

- fixed time limit
- automatic timeout/submission behavior
- non-proctored exam deterrence

Current expectations:

- timed exams are supported without a proctoring vendor
- this is not identity verification or browser lockdown
- proctored exam language should not be used unless the proctoring lane is
  explicitly re-enabled

### Standard Advanced Problem Types

Current authoring may include some richer upstream Open edX problem types, but
availability must be verified in the current lane before promising them for a
course launch.

Treat the following as verification-required rather than assumed baseline:

- drag-and-drop variants
- math expression input
- chemical or image-annotation style blocks
- other non-default XBlocks

If a course depends on one of these, require a lane-specific verification pass
before the authoring commitment is finalized.

There is intentionally no separate advanced-XBlock guide. Keep authoring
promise boundaries here, and keep capability verdicts in
[../../ops/runbooks/ASSESSMENT_OPERATIONS_RUNBOOK.md](../../ops/runbooks/ASSESSMENT_OPERATIONS_RUNBOOK.md),
so the repo does not split one uncertain lane across multiple thin docs.

## Advanced Question Type Availability

Use this table before a launch commitment:

| Assessment type | Current posture | Authoring note |
| --- | --- | --- |
| ORA2 | supported | real current lane, with grading workflow and uploads |
| Timed exam | supported | null backend only; not vendor proctoring |
| Drag-and-drop and similar richer core problem types | verification-required | verify in the current lane before promise |
| Math and specialized symbolic input | verification-required | verify exact course use case before promise |
| Problem Builder or pip-installed advanced XBlocks | gated | treat as rollout work, not baseline authoring |
| XQueue-backed code or external grading | gated | coordinated platform rollout only |

Known limitations:

- support can differ between “present in upstream Redwood” and “proved in this
  tenant and launch lane”
- accessibility, gradebook behavior, and export/import expectations must be
  checked on the exact block type, not assumed from a neighboring feature
- any pip-installed XBlock remains higher-risk than core platform problem types

## Authoring Intake Package

Before the platform team should accept an advanced-assessment escalation, the
course team should hand over:

- course key and target launch date
- assessment type being requested
- learner volume estimate
- grading owner and expected turnaround
- whether uploads, peer review, timed exam enforcement, or external grading are
  required
- any bilingual rubric or accessibility constraints

If that package is incomplete, treat the request as exploratory rather than
launch-ready.

## What Is Not Yet General-Availability Authoring

### XQueue-Backed Problems

The XQueue service exists, but that does not mean course authors can safely
launch code-grader-backed problems on demand.

At present:

- the queue service and consumer are deployed
- external grader workers are still a gated rollout item
- any course depending on code-submission grading needs explicit platform
  coordination and proof

Do not treat “XQueue is deployed” as equivalent to “XQueue-backed authoring is
ready for course teams.”

#### XQueue Grader Authoring Guidance

If a course insists on code- or service-backed grading, the authoring contract
is still coordinated and gated:

- define the expected learner payload clearly before authoring begins
- specify the grader input schema, expected score/result payload, and callback
  behavior with the platform team
- require a lane-specific local or staging proof before course launch
- do not promise self-serve grader onboarding in Studio

The safe current interpretation is “possible with coordinated rollout,” not
“supported by default for any course team.”

### Bulk Assessment Operations

Instructor-facing bulk export/import/regrade workflows are still planned work.
If a course launch depends on them:

- capture that dependency early
- escalate to platform operations
- do not promise a self-serve author workflow yet

#### Bulk Operations Guidance

If instructors ask for bulk assessment operations, gather these details before
accepting the request:

- exact operation type: export, import, override, or regrade
- target course, subsection, and learner scope
- authoritative source for replacement grades or metadata
- progress visibility expectations during the run
- rollback expectation if the operation must be stopped or reverted

Treat bulk work as a platform-coordinated change window, not a routine
authoring action.

## Course-Team Training Checklist

Before a course team should be considered ready for advanced-assessment launch,
walk them through:

- ORA2 authoring and staff-grading expectations
- timed exam boundary versus true proctoring
- the gated status of XQueue-backed problems
- which advanced question types are proved versus only theoretically available
- what bulk operations do and do not mean in the current platform
- who owns escalation when grading, uploads, timers, or queue behavior drift

## Authoring Checklist

Before an advanced assessment goes live, confirm:

- assessment type chosen matches the actual requirement
- grading ownership is explicit
- due dates and learner expectations are written down
- accessibility and language needs are known
- the course team understands whether the feature is live, gated, or deferred
- the escalation owner is named if the course depends on a gated lane
- learner-facing instructions match the actual platform behavior
- the course team has completed a pre-launch drill for the chosen assessment
  mode

If the answer to any of those is unclear, stop and escalate before content is
published.

## Escalate When

Escalate to platform operators when:

- the course needs XQueue-backed grading
- the course needs bulk grade export/import/regrade
- the course depends on a specific advanced XBlock that has not been verified
  in the current lane
- the course team asks for proctored exams
- the ORA grading interface, uploads, or timed-exam behavior are inconsistent
  with expected current behavior

## Canonical Operator Companions

- assessment operations and incident handling:
  [../../ops/runbooks/ASSESSMENT_OPERATIONS_RUNBOOK.md](../../ops/runbooks/ASSESSMENT_OPERATIONS_RUNBOOK.md)
- XQueue operational health:
  [../../ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md](../../ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md)
- proctoring enable/disable boundary:
  [../../ops/runbooks/PROCTORING_RUNBOOK.md](../../ops/runbooks/PROCTORING_RUNBOOK.md)

## No-Promise Rules

Do not tell a course team that the platform supports:

- provider-backed proctoring
- self-serve code grader onboarding
- bulk assessment administration
- arbitrary advanced XBlock assessment types

unless the current lane has explicit proof for that exact workflow.

## Metadata

- Owner: Platform Team
- Last reviewed: 2026-04-10
- Applies to: course teams, instructors, and platform staff preparing advanced
  assessments in Mereka LMS
