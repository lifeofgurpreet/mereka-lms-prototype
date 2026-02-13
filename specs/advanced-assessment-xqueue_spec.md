---
title: "Advanced Assessment & XQueue Integration (Non-Proctored)"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on:
  - "specs/enterprise-microservices_spec.md"
  - "specs/multi-tenancy-architecture_spec.md"
  - "specs/k8s-deployment_spec.md"
links:
  related_docs:
    - "docs/operations/TROUBLESHOOTING.md"
    - "docs/operations/DEPLOYMENT_RUNBOOK.md"
    - "docs/operations/OBSERVABILITY_QUICKSTART.md"
  related_specs:
    - "specs/proctoring-integration_spec.md"
    - "specs/enterprise-microservices_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/analytics-pipeline_spec.md"
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/badges-credentials-enterprise_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A comprehensive advanced assessment system for Mereka Academy's Open edX platform that enables course authoring teams to create, configure, manage, and analyze rich assessment experiences using only free, built-in, and self-hosted tools. No paid proctoring subscriptions or third-party SaaS assessment services are required.

The system covers five major capabilities:

1. **Open Response Assessment (ORA2)** -- Full configuration and operationalization of the ORA2 framework already present in the Open edX Ulmo release. This includes peer assessment workflows (students grade each other using rubrics), self-assessment, staff assessment, and AI-assisted assessment grading using the ORA2 pipeline. File upload support (images, PDFs, code files) for portfolio-style submissions. The ORA Grading MFE (already configured at `apps.academyv2.mereka.io/ora-grading`) provides the staff grading interface.

2. **XQueue External Grading** -- The XQueue service is already deployed (K8s service `xqueue` on port 8000, MySQL database provisioned, secrets in Infisical) but has no configured external graders. This spec defines how to connect self-hosted grading backends (CodeJail sandboxed Python execution, custom grading scripts, containerized graders) to the XQueue framework for automated assessment of code submissions, mathematical proofs, and structured data problems.

3. **Advanced Question Types** -- Configuration and enablement of advanced XBlock-based problem types that ship with Open edX or are available as free open-source packages: drag-and-drop v2, math expression input (MathJax-based), chemical equation input, circuit simulation, image annotation, and conditional/randomized problem sets.

4. **Timed Exams and Time-Limited Access** -- The built-in Open edX timed exam subsystem (non-proctored) for high-stakes assessments with configurable time limits, grace periods, and submission enforcement. This uses the native `edx-proctoring` "no-op" backend for timed-only exams without any proctoring provider integration.

5. **Assessment Management at Scale** -- Bulk assessment operations for enterprise courses: bulk rubric application, bulk grade override, assessment analytics dashboards, grade passbook integration with the LMS gradebook, student feedback workflows, and multi-language assessment support.

## Why it matters

Mereka Academy's enterprise clients need assessment capabilities beyond basic multiple-choice quizzes to deliver meaningful professional development, compliance training, and skills certification. Open Response Assessment enables subjective evaluation (writing, design, analysis) that cannot be auto-graded. XQueue enables automated grading of code submissions and complex problem types critical for technical training programs. Timed exams provide exam integrity for high-stakes assessments without requiring proctoring subscriptions. Advanced question types (drag-and-drop, math, circuits) serve STEM and technical audiences. Together, these capabilities elevate Mereka Academy from a content delivery platform to a genuine assessment and certification platform.

All components are either already deployed (ORA2, XQueue service, timed exams subsystem) or available as free open-source XBlocks. The investment is in configuration, integration, testing, and operationalization rather than building from scratch. This makes the cost-to-value ratio exceptionally favorable.

Enterprise clients in regulated industries (finance, healthcare, engineering) have specifically requested peer review workflows, code submission grading, and timed exam capabilities as prerequisites for using the platform for certification programs. Without these capabilities, those clients default to competitors with established assessment ecosystems.

## Success looks like

- A course author can create an ORA2 assignment with a rubric, peer assessment step, and staff grading step in Studio within 15 minutes without engineering assistance
- Peer assessment workflows complete successfully: students submit, receive peer reviews from the configured number of peers, and receive a final grade that flows into the gradebook
- ORA2 file uploads (images, PDFs up to 10 MB) work reliably with the filesystem storage backend already configured
- At least one self-hosted XQueue grader is operational, accepting code submissions and returning grading results within 30 seconds at p95
- Timed exams enforce time limits accurately: a student exceeding the time limit has their exam auto-submitted
- Drag-and-drop v2, math expression input, and at least two other advanced question types are available in Studio's problem editor
- Assessment analytics (submission rates, average scores, rubric dimension breakdowns) are accessible to course authors and enterprise admins
- Grade passbook integration works: all assessment types (ORA2, XQueue-graded, timed exams, advanced question types) correctly report grades to the Open edX gradebook
- Bulk grade operations (override, export, regrade) work for courses with 500+ enrolled students without timeouts
- Multi-language rubrics can be created for assessments serving bilingual (English/Malay) enterprise audiences
- The entire system operates without any paid subscriptions, proctoring providers, or external SaaS dependencies

---

# Agent Contract

## Scope

- In scope:
  - ORA2 configuration and operationalization for peer, self, staff, and AI-assisted assessment
  - ORA2 file upload configuration (filesystem backend already set to `/openedx/data/ora2`)
  - ORA2 rubric design patterns and best practices for course authors
  - ORA Grading MFE operationalization (already configured at `apps.academyv2.mereka.io/ora-grading`)
  - XQueue external grader integration with self-hosted containerized graders
  - XQueue grader deployment on GKE (containerized grading workers in the `mereka-lms` namespace)
  - CodeJail sandboxed execution as an XQueue grader backend (requires enabling codejail, currently disabled)
  - Timed exam configuration using the built-in Open edX timed exam subsystem (non-proctored)
  - Advanced XBlock problem types: drag-and-drop v2, math expression input, chemical equation, image annotation, conditional problems
  - Problem Builder XBlock for multi-step guided assessment sequences
  - Rubric-based assessment design for ORA2 and staff grading workflows
  - Peer review workflow configuration (number of peers, grading deadlines, calibration)
  - Multi-language assessment support (rubrics, instructions, feedback in English and Malay)
  - Accessibility compliance (WCAG 2.1 AA) for all assessment interfaces
  - Assessment analytics: submission rates, score distributions, rubric dimension breakdowns, peer agreement metrics
  - Grade passbook integration: all assessment types reporting grades to the Open edX gradebook
  - Bulk assessment management: bulk grade override, bulk regrade, grade export for enterprise courses
  - Student feedback workflows: assessment result notifications, feedback display, grade dispute process
  - Assessment security features available without proctoring (randomized question pools, one-at-a-time display, answer shuffling, time limits)
  - Observability: logging, metrics, alerts for ORA2, XQueue, and assessment pipeline operations

- Out of scope:
  - **Proctoring integration** (explicitly deferred to 2027; see `specs/proctoring-integration_spec.md` which has status `deferred`)
  - Paid proctoring provider subscriptions (Examity, Respondus, ProctorTrack, Proctorio)
  - Browser lockdown software integration
  - Student identity verification for exams
  - Screen recording or webcam monitoring during assessments
  - AI-powered plagiarism detection SaaS (Turnitin, Copyleaks)
  - Custom exam authoring interfaces beyond Studio's built-in editor
  - Mobile-specific assessment interfaces (mobile web uses responsive design; no native assessment SDK)
  - LTI-based external assessment tools from commercial providers
  - Adaptive learning or AI-driven question sequencing
  - Building custom XBlocks from scratch (we use existing open-source XBlocks)

---

### Proctoring Integration (Deferred)

Proctoring features referenced in this spec are defined in `specs/proctoring-integration_spec.md` (Tier 8, status: `deferred`). Assessment features MUST function without proctoring enabled. Proctoring-dependent features MUST be gated behind the `ENABLE_PROCTORED_EXAMS` feature flag.

**Proctoring-related features not included in this spec**:
- Student identity verification (photo ID capture, facial recognition)
- Browser lockdown enforcement (Respondus LockDown Browser, Proctorio)
- Session recording (webcam, screen, audio)
- Live proctoring or AI-based integrity monitoring
- Proctor review workflows

**Timed exams** (included in this spec) use the built-in Open edX timed exam subsystem with the "no-op" proctoring backend, which provides timer enforcement without any proctoring provider integration. Timed exams do NOT require the `ENABLE_PROCTORED_EXAMS` feature flag.

**Exam security features** (included in this spec) such as randomized question order, answer shuffling, one-at-a-time display, and time limits are available without proctoring integration. These provide deterrence and basic integrity controls but do not verify student identity or detect cheating behavior.

## Non-goals

- Replacing Studio's problem editor with a custom assessment authoring tool (Studio is the authoring tool; we configure and extend it)
- Building a proprietary code grading engine (we use containerized graders behind XQueue's standard interface)
- Achieving proctored exam integrity without proctoring (timed exams with platform-level security features provide deterrence, not guarantee)
- Supporting real-time collaborative assessment (students assess independently, not simultaneously)
- Building a question bank marketplace or cross-tenant question sharing system
- Automated AI essay grading for ORA2 (AI-assisted grading provides suggestions to human graders, not autonomous scoring)
- Supporting assessment types that require browser plugins or desktop software installation

## Assumptions

- The Open edX LMS is running Tutor 21.0.0 (Ulmo) with ORA2 (`openassessment`) included in the base image
- The XQueue service is deployed as a K8s service (`xqueue`) with MySQL database (`xqueue`) and secrets provisioned via ExternalSecrets
- The ORA Grading MFE is deployed and accessible at `apps.academyv2.mereka.io/ora-grading`
- ORA2 file upload is configured with filesystem backend at `/openedx/data/ora2` with Redis cache `ora2-storage`
- CodeJail is currently disabled (configured to use `nonexistingpythonbinary`); enabling it requires deploying an AppArmor-secured sandbox
- The existing GKE infrastructure can accommodate 2-4 additional pods for XQueue grader workers
- The existing observability stack (Prometheus, Loki, Tempo) can ingest assessment-related metrics and logs
- Course authors have Studio access and basic familiarity with Open edX problem types
- Enterprise clients will use the platform's built-in English and Malay language support for bilingual assessments
- The `edx-proctoring` package's "no-op" backend supports timed-only exams without any proctoring provider

---

## Requirements

### Functional

#### ORA2 Configuration and Peer Assessment

- The system MUST support creating Open Response Assessment (ORA2) components in Studio with the following assessment steps configurable per assignment:
  - **Self-assessment**: student evaluates their own submission against the rubric
  - **Peer assessment**: configured number of peers evaluate the submission
  - **Staff assessment**: course staff or designated graders evaluate via the ORA Grading MFE
  - **AI-assisted assessment** (training mode): if enabled, the system uses previously staff-graded examples to suggest scores that staff reviewers can accept or override
- The system MUST support configuring peer assessment parameters:
  - `must_grade`: minimum number of peer submissions each student MUST grade (default: 5, range: 1-20)
  - `must_be_graded_by`: minimum number of peer reviews each submission MUST receive (default: 3, range: 1-10)
  - `peer_grading_deadline`: ISO 8601 datetime after which peer grading is no longer accepted
  - `submission_deadline`: ISO 8601 datetime after which new submissions are not accepted
  - `peer_grading_grace_period_hours`: additional hours after `peer_grading_deadline` before grades finalize (default: 24)
- The system MUST support rubric-based grading with the following rubric structure:
  - Each rubric MUST have 1-10 criteria (dimensions)
  - Each criterion MUST have a label (up to 100 characters), a prompt (up to 500 characters), and 2-5 options
  - Each option MUST have a label, an explanation, and a point value (0 to 100)
  - The total rubric score MUST be the sum of selected option point values across all criteria
- The system MUST enforce that rubrics are immutable after the first student submission for that assignment (preventing mid-assessment rubric changes that invalidate existing grades)
- The system MUST support ORA2 file uploads with the following constraints:
  - Allowed file types MUST be configurable per assignment (default: `.pdf`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.doc`, `.docx`)
  - Maximum file size MUST be configurable per assignment (default: 10 MB, maximum: 50 MB)
  - Maximum number of files per submission MUST be configurable (default: 5, maximum: 20)
  - Files MUST be stored at the configured `ORA2_FILEUPLOAD_ROOT` path (`/openedx/data/ora2`)
- The system MUST display peer assessment results to students only after their submission has received the required number of peer reviews AND the peer grading deadline (plus grace period) has passed
- The system SHOULD support a peer calibration step where students practice grading sample submissions (pre-graded by staff) before they can grade real peer submissions
- The system SHOULD support anonymous peer review (default: enabled; students do not see the names of their peer reviewers)

#### ORA Grading MFE Integration

- The ORA Grading MFE at `apps.academyv2.mereka.io/ora-grading` MUST be accessible to users with `staff` or `instructor` roles for courses containing ORA2 assignments
- The MFE MUST display a grading queue showing submissions awaiting staff assessment, ordered by submission time (oldest first)
- The MFE MUST support filtering the grading queue by course, assignment, and grading status (ungraded, in-progress, graded)
- The MFE MUST render the student's text response and any uploaded files inline for the grader
- The MFE MUST present the rubric with selectable options for each criterion and a free-text feedback field
- The MFE MUST support saving draft grades (in-progress) and submitting final grades
- The system MUST propagate staff-assessed grades to the gradebook within 5 minutes of submission

#### Timed Exams (Non-Proctored)

- The system MUST support configuring a course subsection as a timed exam with the following settings:
  - `exam_type`: `timed` (explicitly NOT `proctored`, NOT `practice_proctored`, NOT `onboarding`)
  - `time_limit_minutes`: integer, the allowed exam duration (minimum: 5, maximum: 480)
  - `hide_after_due`: boolean, whether the exam content is hidden after the due date
  - `show_timer`: boolean, whether the countdown timer is visible to the student (default: true)
- The system MUST use the `edx-proctoring` package's built-in "no-op" backend for timed exams, providing timer enforcement without any proctoring provider interaction
- Timed exam state transitions MUST follow the standard exam attempt lifecycle:
  - `created` -> `ready_to_start` -> `started` -> `ready_to_submit` -> `submitted`
  - `started` -> `timed_out` (when timer expires)
- When the timer reaches zero, the system MUST auto-submit the exam with whatever answers the student has provided up to that point
- The system MUST display a warning to the student when 5 minutes and 1 minute remain on the timer
- The system MUST support per-student time extensions (accommodations) configurable by instructors via the instructor dashboard
- Timed exam grades MUST be released to the gradebook immediately upon submission (no proctoring review hold)
- The system MUST NOT require any browser extension, desktop software, webcam, or microphone for timed exams
- The system MUST prevent students from re-entering a timed exam after submission (no re-take unless the instructor resets the attempt)
- The system SHOULD support configurable grace periods (default: 0 minutes) that extend the timer for network latency but do not extend the exam window

#### XQueue External Grading Integration

- The XQueue service MUST accept submission payloads from the LMS via its REST API at `http://xqueue:8000`
- The XQueue service MUST authenticate LMS requests using the credentials stored in ExternalSecrets (`XQUEUE_LMS_PASSWORD`)
- The system MUST support registering external grader workers that poll the XQueue `openedx` queue for submissions
- Each grader worker MUST implement the XQueue grader protocol:
  - Poll `GET /xqueue/get_submission/` to retrieve the next submission
  - Process the submission (execute code, evaluate answer, compute score)
  - Submit results via `PUT /xqueue/put_result/` with a JSON payload containing `correct` (boolean), `score` (float 0.0-1.0), and `msg` (HTML feedback string)
- The system MUST support deploying grader workers as K8s Deployments in the `mereka-lms` namespace
- The system MUST support at least two grader worker types:
  - **Python code grader**: Executes student-submitted Python code in a sandboxed environment and validates output against expected results
  - **Generic script grader**: Executes a course-author-provided grading script (any language) that receives student input via stdin and outputs a JSON grading result
- Grader workers MUST execute student code in a sandboxed environment with:
  - No network access
  - No filesystem write access outside a temporary directory
  - CPU time limit (configurable, default: 10 seconds per submission)
  - Memory limit (configurable, default: 256 MB per submission)
  - Process count limit (configurable, default: 50 processes)
- The system MUST support a configurable timeout for grader workers (default: 30 seconds per submission); if a grader exceeds the timeout, the submission MUST be returned to the queue for retry
- The system SHOULD support CodeJail as an alternative sandboxed execution backend by enabling the `codejail` configuration with an AppArmor profile (currently disabled with `nonexistingpythonbinary`)
- XQueue-graded submissions MUST report grades to the LMS gradebook via the standard XQueue callback mechanism
- The system MUST handle grader worker failures gracefully: if a worker crashes, its in-flight submission MUST be returned to the queue after a configurable visibility timeout (default: 60 seconds)

#### Advanced Question Types (XBlocks)

- The system MUST support the following advanced problem types in Studio's component library:
  - **Drag-and-Drop v2** (`xblock-drag-and-drop-v2`): Interactive drag-and-drop problems with zones, items, and scoring rules
  - **Math Expression Input**: Problems accepting LaTeX-formatted mathematical expressions evaluated by the SymPy-based grader
  - **Chemical Equation Input**: Problems accepting chemical formulas and equations with balanced-equation checking
  - **Image Annotation**: Problems where students annotate regions of an image with labels
  - **Numerical Input with Tolerance**: Problems accepting numeric answers within a configurable tolerance range
  - **Custom JavaScript Problem** (`jsinput`): Problems with custom JavaScript interaction that submit a JSON answer for server-side grading
- The system SHOULD support the following additional XBlocks if available as stable packages for the Ulmo release:
  - **Problem Builder** (`xblock-problem-builder`): Multi-step guided assessment with branching logic
  - **Circuit Schematic Builder**: Interactive circuit design and simulation problems
  - **Peer Instruction** (`ubcpi`): Two-phase assessment where students answer individually, see peer responses, and may revise
- Advanced XBlocks MUST be installable via Tutor plugins or pip packages without requiring a custom LMS image build (preferred: Tutor plugin; fallback: image rebuild with additional pip packages)
- All advanced question types MUST integrate with the Open edX gradebook (correct answers contribute to the course grade)
- All advanced question types MUST be exportable and importable via the OLX course format
- The system MUST support randomized problem selection: course authors MUST be able to create a library of problems and configure a subsection to randomly select N problems from the library for each student

#### Assessment Security (Without Proctoring)

- The system MUST support the following platform-level assessment security features:
  - **Randomized question order**: Questions within an exam subsection are displayed in a different order for each student
  - **Randomized answer order**: Multiple-choice answer options are shuffled per student
  - **One-at-a-time question display**: Students see one question at a time and cannot navigate back to previous questions (configurable per subsection)
  - **Randomized problem pools**: Each student receives a different subset of problems from a configured library
  - **Time limits**: Enforced countdown timer with auto-submission (see Timed Exams section)
  - **Single active attempt**: Only one exam attempt per student is active at any time
  - **IP-based logging**: The student's IP address is logged with each submission for audit purposes
- The system MUST support configuring maximum attempts per problem (default: unlimited for practice, 1-3 for graded assessments)
- The system MUST support configuring whether students can see correct answers after submission (`show_correctness` setting: `always`, `past_due`, `never`)
- The system SHOULD support configurable answer reveal delay: correct answers are shown only after the exam due date, not immediately after submission
- The system MUST log all submission events (answer submitted, attempt started, attempt completed) with user ID, course ID, problem ID, timestamp, and IP address hash

#### Grade Passbook and Gradebook Integration

- All assessment types (ORA2, XQueue-graded, timed exams, standard problems, advanced XBlock problems) MUST report grades to the Open edX gradebook using the standard grading pipeline
- The gradebook MUST accurately reflect:
  - ORA2 grades: weighted combination of peer, self, and staff assessment scores per the rubric
  - XQueue grades: the `score` field (0.0-1.0) returned by the grader worker, scaled to the problem's maximum points
  - Timed exam grades: sum of individual problem scores within the timed subsection
  - Advanced question type grades: the score returned by the XBlock's `check` or `submit` handler
- The system MUST support grade override by instructors for any assessment type via the instructor dashboard
- Grade overrides MUST be logged with instructor user ID, original grade, new grade, reason, and timestamp
- The system MUST support bulk grade export (CSV) for a course section, including assessment type, student identifier, score, maximum score, submission timestamp, and grading source (auto, peer, staff, xqueue)
- The system MUST support bulk grade import (CSV) for instructor-uploaded manual grades
- The system SHOULD support a grade dispute workflow: a student can flag a grade for review, the instructor receives a notification, and the instructor can confirm or override the grade

#### Bulk Assessment Management

- The system MUST support the following bulk operations for enterprise courses with 500+ enrollments:
  - **Bulk regrade**: Regrade all submissions for a specific problem or assignment (e.g., after a grading rubric correction)
  - **Bulk grade override**: Override grades for a list of students (CSV upload with student ID and new grade)
  - **Bulk grade export**: Export all grades for a course, section, or specific assignment as CSV
  - **Bulk ORA2 staff grading**: Staff can grade multiple ORA2 submissions in sequence without returning to the grading queue between each
- Bulk operations MUST be processed asynchronously via Celery tasks to avoid blocking the LMS
- Bulk operations MUST report progress (percentage complete) and status (queued, in-progress, completed, failed) to the requesting instructor
- The system MUST support bulk operations for courses with up to 5,000 enrolled students without OOM errors or Celery task timeouts (task timeout: 1 hour for bulk regrade)
- Bulk grade export for a 5,000-student course MUST complete within 5 minutes

#### Multi-Language Assessment Support

- The system MUST support creating assessment content (problem text, rubric criteria, rubric options, feedback templates) in multiple languages using Open edX's content localization framework
- The system MUST support at minimum English and Bahasa Malay for assessment interfaces (problem display, submission UI, grading UI)
- Rubric criteria labels, option labels, and option explanations MUST support Unicode characters (including Malay diacritical marks and CJK characters for future language expansion)
- The ORA Grading MFE MUST display rubric content in the language configured for the course
- The system SHOULD support per-problem language tagging for analytics (to track assessment performance by language)

#### Assessment Accessibility

- All assessment interfaces (problem display, submission UI, ORA2 peer review UI, timed exam timer, drag-and-drop interactions) MUST comply with WCAG 2.1 Level AA
- Drag-and-drop v2 problems MUST support keyboard navigation and screen reader announcement of drag/drop actions
- Timed exam timers MUST be announced to screen readers at configurable intervals (default: every 5 minutes and at 1 minute remaining)
- Math expression input MUST support both LaTeX text entry and a visual equation editor with keyboard accessibility
- ORA2 peer review interfaces MUST support keyboard-only navigation for all rubric selection and feedback entry actions
- The system MUST support extended time accommodations for students with documented disabilities, configurable per student per exam

#### Student Feedback and Assessment Improvement

- The system MUST display assessment feedback to students after grading is complete:
  - For auto-graded problems: feedback is displayed immediately after submission (or after due date if `show_correctness` is set to `past_due`)
  - For ORA2 peer-assessed submissions: feedback is displayed after the peer grading deadline plus grace period
  - For ORA2 staff-assessed submissions: feedback is displayed within 5 minutes of the staff member submitting the grade
  - For XQueue-graded submissions: the `msg` field from the grader response is displayed as feedback
- The system MUST support rich feedback content (HTML, images, code snippets) in grader responses and rubric option explanations
- The system MUST send email notifications to students when their ORA2 submissions receive a final grade
- The system SHOULD support an assessment improvement workflow: after receiving feedback, students can view their original submission alongside the feedback and (if the instructor enables it) submit a revised response for re-grading
- The system MUST support course-level assessment analytics visible to instructors:
  - Per-problem submission rate and average score
  - Per-rubric-criterion average score and score distribution
  - Peer assessment agreement metrics (inter-rater reliability)
  - Time-on-task for timed exams (average completion time vs. allowed time)
  - XQueue grader performance (average grading time, error rate)

### Non-Functional Requirements

#### Performance

- ORA2 submission (text + file upload up to 10 MB) MUST complete within 10 seconds at p95
- ORA2 peer assessment page load (showing the submission to review plus rubric) MUST complete within 3 seconds at p95
- XQueue grader round-trip (submission to grade result posted to LMS) MUST complete within 30 seconds at p95 for typical submissions
- Timed exam page load (rendering all problems in the subsection) MUST complete within 5 seconds at p95 for exams with up to 100 problems
- Timed exam auto-submission on timer expiry MUST complete within 5 seconds of the timer reaching zero
- Bulk grade export for a 5,000-student course MUST complete within 5 minutes
- Bulk regrade for a single problem across 5,000 submissions MUST complete within 30 minutes
- The ORA Grading MFE MUST load the grading queue (up to 200 items) within 3 seconds at p95
- Gradebook update after any assessment type is graded MUST be reflected within 5 minutes

#### Reliability

- ORA2 submissions MUST be durably stored before the student sees a confirmation (write-ahead to database, not just browser state)
- XQueue MUST NOT lose submissions: if a grader worker crashes, the submission MUST be returned to the queue after the visibility timeout
- Timed exam state (timer remaining, answers so far) MUST be persisted server-side every 30 seconds during an active exam to survive browser crashes
- XQueue grader workers MUST be horizontally scalable: adding replica pods MUST increase throughput linearly
- The XQueue service MUST be available 99.9% of the time during business hours (8:00-22:00 UTC+8)
- ORA2 peer grading MUST handle the case where not enough peers complete grading by the deadline: the system MUST fall back to staff grading for under-reviewed submissions

#### Security

- XQueue grader workers MUST execute student code in isolated containers with no network access, limited CPU/memory, and no access to host filesystem
- Student-submitted code MUST NOT be able to access other students' submissions, environment variables, or secrets
- XQueue communication between LMS and XQueue service MUST use authenticated requests (username/password from ExternalSecrets)
- ORA2 file uploads MUST be scanned for file type validation (extension + MIME type check) to prevent executable uploads
- ORA2 uploaded files MUST NOT be served with executable MIME types; all file responses MUST set `Content-Disposition: attachment`
- Timed exam timer enforcement MUST be server-side; the client-side timer is a display convenience, but the actual time limit is enforced by the LMS backend
- Assessment submission events MUST include an IP address hash for audit purposes (not the raw IP, to comply with privacy requirements)
- Grade override actions MUST require `instructor` or `staff` role and MUST be logged with an audit trail

---

## Acceptance Criteria

### ORA2 Configuration

- [ ] AC-001: Given a course author in Studio, when they add an ORA2 component to a unit, then they can configure a rubric with 3 criteria, each with 4 options, and set peer assessment to require 3 reviews per submission and 5 reviews given per student
- [ ] AC-002: Given a student who has submitted an ORA2 response, when 3 peers have completed their reviews and the grading deadline has passed, then the student sees a final grade that is the median of the 3 peer scores (middle value for odd count, average of two middle values for even count) displayed on their submission page
- [ ] AC-003: Given an ORA2 assignment configured with file uploads allowing PDF and PNG up to 10 MB, when a student uploads a 9.5 MB PDF, then the upload succeeds and the file is stored at `/openedx/data/ora2/`
- [ ] AC-004: Given an ORA2 assignment configured with file uploads, when a student attempts to upload a `.exe` file, then the upload is rejected with a validation error message listing allowed file types
- [ ] AC-005: Given an ORA2 assignment where the rubric has been configured and one student has already submitted, when the course author attempts to modify the rubric criteria, then Studio prevents the change and displays a warning that the rubric is locked
- [ ] AC-006: Given an ORA2 assignment with peer calibration enabled, when a student attempts to start peer grading without completing calibration, then they are redirected to the calibration step first

### ORA Grading MFE

- [ ] AC-007: Given a course staff member navigating to `apps.academyv2.mereka.io/ora-grading`, when they select a course with 10 ORA2 submissions awaiting staff assessment, then the grading queue displays all 10 submissions ordered by submission time
- [ ] AC-008: Given a staff grader reviewing a submission in the ORA Grading MFE, when they select options for all rubric criteria and enter feedback text, then they can submit the grade and the next submission loads automatically
- [ ] AC-009: Given a staff grader who submits a grade via the ORA Grading MFE, when the grade is saved, then it appears in the Open edX gradebook within 5 minutes

### Timed Exams

- [ ] AC-010: Given a course author in Studio, when they set a subsection's `exam_type` to `timed` with `time_limit_minutes=60`, then the subsection is displayed to students with a 60-minute countdown timer and no proctoring prompts
- [ ] AC-011: Given a student taking a timed exam with 5 minutes remaining, when the timer reaches 5:00, then a visual and screen-reader-accessible warning is displayed
- [ ] AC-012: Given a student taking a timed exam, when the timer reaches 0:00, then all current answers are auto-submitted and the student sees a "Time expired -- your exam has been submitted" message
- [ ] AC-013: Given a timed exam that has been auto-submitted, when the student attempts to re-access the exam, then they see a read-only view of their submitted answers (if `show_correctness` allows) and cannot modify responses
- [ ] AC-014: Given an instructor who grants a 30-minute time extension to a specific student, when that student starts the timed exam, then they receive 90 minutes (60 + 30) on the timer
- [ ] AC-015: Given a timed exam, when a student submits before the timer expires, then the grade is released to the gradebook immediately (no proctoring review hold)

### XQueue Integration

- [ ] AC-016: Given the XQueue service running at `http://xqueue:8000` and a Python code grader worker deployed, when a student submits a Python code answer to an XQueue-backed problem, then the code is executed in a sandboxed environment and a grade result is returned within 30 seconds
- [ ] AC-017: Given a student submission containing an infinite loop, when the grader worker processes it, then the execution is terminated after the configured CPU time limit (10 seconds) and the student receives feedback indicating a timeout error
- [ ] AC-018: Given a student submission containing `import os; os.system("rm -rf /")`, when the grader worker processes it, then the sandboxed environment blocks the system call and the student receives feedback indicating a security violation
- [ ] AC-019: Given the XQueue grader worker crashes during processing, when the visibility timeout (60 seconds) expires, then the submission reappears in the queue and is picked up by another worker
- [ ] AC-020: Given an XQueue-graded problem, when the grader returns a result, then the grade (scaled to the problem's maximum points) appears in the gradebook within 5 minutes
- [ ] AC-021: Given a student submission containing `x = [0] * (256 * 1024 * 1024)` (256MB array allocation), when the grader worker processes it, then the execution is terminated when memory usage exceeds 256MB and the student receives feedback: "Your code exceeded the memory limit (256MB)"
- [ ] AC-022: Given a student submission containing `import os; [os.fork() for _ in range(100)]`, when the grader worker processes it, then the sandboxed environment blocks the fork() system call and the student receives feedback indicating a security violation
- [ ] AC-023: Given a student submission containing `import socket; s = socket.socket(); s.connect(("evil.com", 80))`, when the grader worker processes it, then the network access is blocked by the sandbox and the student receives feedback: "Network access is not permitted in the grading environment"
- [ ] AC-024: Given a student submission containing `open("/etc/passwd").read()`, when the grader worker processes it, then the file access is blocked (sandbox restricts reads to /tmp and the submission directory only) and the student receives feedback indicating a security violation
- [ ] AC-025: Given a student submission containing `import os; print(os.environ)`, when the grader worker processes it, then the output contains only a minimal set of safe environment variables (PATH, HOME) and does NOT contain any secrets (database credentials, API keys, Infisical tokens)

### Advanced Question Types

- [ ] AC-026: Given a course author in Studio, when they add a new advanced component, then drag-and-drop v2 and math expression input are available in the component picker
- [ ] AC-027: Given a drag-and-drop v2 problem with 5 items and 3 zones, when a student correctly places all items using keyboard navigation only, then the problem is scored as correct
- [ ] AC-028: Given a math expression input problem expecting `x^2 + 2*x + 1`, when a student enters `(x+1)^2` (mathematically equivalent), then the SymPy-based grader marks it as correct
- [ ] AC-029: Given a randomized problem pool of 20 questions configured to show 10, when two different students access the subsection, then each student sees a different subset of 10 questions

### Assessment Security

- [ ] AC-030: Given an exam subsection configured with randomized question order, when two students access the same exam, then the questions appear in different orders
- [ ] AC-031: Given a multiple-choice problem with answer shuffling enabled, when two students view the same problem, then the answer options appear in different orders
- [ ] AC-032: Given an exam configured with one-at-a-time question display, when a student advances to question 3, then questions 1 and 2 are no longer accessible
- [ ] AC-033: Given an exam configured with `max_attempts=1`, when a student submits their answer, then the submit button is disabled and no further attempts are allowed

### Grade Integration

- [ ] AC-034: Given a course with an ORA2 assignment (weight: 20%), a timed exam (weight: 40%), and standard problems (weight: 40%), when all three are graded for a student, then the final course grade accurately reflects the weighted sum
- [ ] AC-035: Given an instructor who overrides a student's ORA2 grade from 70% to 85% with a reason, then the gradebook reflects 85%, the original 70% is preserved in the audit log, and the reason is recorded
- [ ] AC-036: Given an instructor who performs a bulk grade export for a 500-student course, when the CSV is generated, then it contains one row per student per graded assessment with columns: student_id, assessment_name, assessment_type, score, max_score, submission_timestamp, grading_source

### Bulk Operations

- [ ] AC-037: Given a course with 2,000 submissions for a single problem, when an instructor triggers a bulk regrade, then the operation runs asynchronously, reports progress, and completes without LMS service degradation
- [ ] AC-038: Given an instructor who uploads a CSV with grade overrides for 100 students, when the bulk import is processed, then each student's grade is updated and an audit log entry is created for each override
- [ ] AC-039: Given a bulk regrade operation in progress, when the instructor checks the operation status, then they see a progress percentage and estimated time remaining

### Multi-Language and Accessibility

- [ ] AC-040: Given an ORA2 rubric with criteria labels in both English and Malay, when a student whose language preference is Malay views the rubric, then the Malay labels are displayed
- [ ] AC-041: Given a timed exam timer with 1 minute remaining, when a screen reader user is taking the exam, then the screen reader announces "1 minute remaining" via an ARIA live region
- [ ] AC-042: Given a drag-and-drop v2 problem, when a keyboard-only user presses Tab to navigate items and Enter/Space to select and drop, then the interaction completes successfully

### Student Feedback

- [ ] AC-043: Given an ORA2 submission that receives a final staff grade, when the grade is posted, then the student receives an email notification within 10 minutes containing the course name, assignment name, and a link to view feedback
- [ ] AC-044: Given an auto-graded problem with `show_correctness=past_due`, when the student submits before the due date, then they see "Answer submitted" but not whether it is correct; after the due date, the correct answer and explanation are shown

---

## Edge Cases

### ORA2 Peer Assessment Edge Cases

- **Insufficient peer reviewers**: If a submission does not receive `must_be_graded_by` peer reviews by the `peer_grading_deadline + grace_period`, the system MUST flag the submission for staff assessment fallback. The submission MUST NOT receive a grade of 0 due to lack of peers
- **Peer reviewer collusion**: If peer scores for a submission show high variance (standard deviation exceeding 30% of max score), the system SHOULD flag the submission for staff review. This heuristic catches both generous-generous collusion and adversarial-generous disagreement
- **Student submits but never grades peers**: If a student submits their ORA2 response but does not complete the required `must_grade` peer reviews by the deadline, the system MUST apply the configured penalty (default: 20% grade reduction; configurable as 0-100%). The student MUST receive a notification warning them before the grading deadline
- **Large file upload failure**: If a file upload fails mid-transfer (network timeout), the system MUST NOT mark the submission as complete. Partially uploaded files MUST be cleaned up within 24 hours by a background task. The student MUST see a clear error message and be able to retry
- **Rubric with zero-point options**: If a rubric criterion has an option with 0 points (e.g., "Not attempted"), and a peer selects it, the system MUST correctly compute the total score as the sum including 0 (not treat 0 as missing data)
- **ORA2 file storage exhaustion**: If the `/openedx/data/ora2` volume approaches 90% capacity, the system MUST alert the operations team and MUST NOT accept new file uploads until space is freed. Students MUST see a "File upload temporarily unavailable" message

### XQueue Edge Cases

- **Grader worker unavailable**: If no grader workers are polling the XQueue queue, submissions accumulate. If the queue depth exceeds 100 unprocessed submissions for more than 10 minutes, the system MUST alert the operations team. Students MUST see "Grading in progress" rather than an error
- **Malicious code submission**: Student-submitted code that attempts fork bombs, memory exhaustion, or disk writes MUST be contained by the sandbox. The grader worker MUST return a graceful error response ("Your code exceeded resource limits") rather than crashing
- **XQueue database connection pool exhaustion**: Under high load (100+ concurrent submissions), the XQueue MySQL connection pool may be exhausted. The system MUST use connection pooling with a maximum of 20 connections and queue additional requests with a 30-second timeout
- **Grader returns invalid response**: If a grader worker returns a malformed response (missing `correct` or `score` field), the XQueue MUST log the error and return the submission to the queue for retry (maximum 3 retries). After 3 failed attempts, the submission MUST be moved to a dead-letter state and the instructor MUST be notified
- **XQueue service restart during grading**: If the XQueue service restarts while submissions are being processed, in-flight submissions MUST be recovered from the database (XQueue persists submissions before dispatching to workers) and re-queued
- **Student submits same code rapidly**: If a student submits the same answer multiple times in quick succession (within 5 seconds), the system MUST deduplicate and process only the most recent submission

### Timed Exam Edge Cases

- **Browser crash during timed exam**: If the student's browser crashes and they reopen it within the time limit, the system MUST allow them to resume the exam with the remaining time. Server-side timer continues regardless of browser state
- **Clock skew**: The timed exam timer MUST be enforced server-side. Client-side clock manipulation MUST NOT extend the available time. The server MUST compare `current_time - exam_start_time` against `time_limit_minutes` on every submission
- **Network disconnection during auto-submission**: If the student's network disconnects when the timer expires, the auto-submission MUST be retried by the client when connectivity restores (within a 5-minute grace window). If the client does not submit within the grace window, the server-side job MUST force-submit based on the last persisted answers
- **Instructor changes time limit during active exams**: If an instructor changes `time_limit_minutes` while students have active timed exam attempts, existing attempts MUST retain their original time limit. Only new attempts use the updated limit
- **Simultaneous exam access from multiple devices**: If a student opens the timed exam from two devices simultaneously, the system MUST enforce a single active session. The second device MUST show "This exam is already in progress on another device"

### Grade Integration Edge Cases

- **Conflicting grade sources**: If a problem receives both an auto-grade and a manual instructor override, the manual override MUST take precedence. If the problem is subsequently regraded (bulk regrade), the system MUST NOT overwrite the manual override unless the instructor explicitly includes overridden grades in the regrade scope
- **Gradebook calculation with missing grades**: If a student has not submitted an ORA2 assignment, the grade MUST be treated as 0 (not excluded from the weighted average), unless the assignment is configured as optional (zero-weight)
- **Celery task failure during bulk regrade**: If a bulk regrade Celery task fails mid-execution (worker OOM, connection timeout), the system MUST record which submissions were regraded and which were not, allowing the instructor to resume the operation rather than restart from scratch

### Retry/Timeout Behavior

- XQueue grader worker poll interval: 5 seconds (configurable)
- XQueue submission visibility timeout: 60 seconds (if a worker takes a submission but does not return a result, the submission re-enters the queue)
- XQueue grader execution timeout: 30 seconds per submission (configurable per grader type)
- XQueue maximum retries per submission: 3 (after 3 failures, dead-lettered)
- ORA2 peer grading grace period: configurable per assignment (default: 24 hours after peer grading deadline)
- Timed exam auto-submission retry: 3 client-side retries with 5-second intervals; server-side force-submit after 5-minute grace window
- Bulk operation Celery task timeout: 1 hour (with checkpoint/resume support)

### Idempotency

- XQueue result submission MUST be idempotent: if the same grader result (same `submission_id` and `score`) is submitted twice, only one grade update is applied
- ORA2 peer assessment submission MUST be idempotent: if a peer submits the same assessment twice (same `submission_uuid` and `assessor_id`), the second submission is ignored
- Bulk grade import MUST be idempotent: re-uploading the same CSV MUST NOT create duplicate override records
- Timed exam auto-submission MUST be idempotent: multiple auto-submit triggers for the same attempt MUST result in exactly one submission

### Rate Limits

- ORA2 file upload: maximum 10 uploads per student per 10-minute window (to prevent abuse)
- XQueue submission: maximum 30 submissions per student per 10-minute window
- ORA Grading MFE: maximum 60 grade submissions per staff member per 10-minute window (generous limit for bulk grading sessions)
- Bulk grade export: maximum 5 concurrent export operations per course (to prevent resource exhaustion)

### Partial Failures

- If an ORA2 assignment has both peer and staff assessment steps, and the peer step completes but the staff step fails (database error), the system MUST preserve the peer scores and retry the staff grading step rather than discarding both
- If a bulk grade import partially fails (50 of 100 rows processed before error), the system MUST commit the 50 successful updates and report which rows failed with error details

---

## Observability

### Logs

- **ORA2 submission events**: Every ORA2 submission MUST be logged as structured JSON with: `event_type=ora2_submission`, `submission_uuid`, `user_id`, `course_id`, `assessment_id`, `file_count`, `total_file_size_bytes`, `timestamp`
- **ORA2 peer assessment events**: Every peer assessment MUST be logged with: `event_type=ora2_peer_assessment`, `submission_uuid`, `assessor_user_id`, `course_id`, `rubric_score`, `timestamp`
- **ORA2 staff assessment events**: Every staff assessment MUST be logged with: `event_type=ora2_staff_assessment`, `submission_uuid`, `grader_user_id`, `course_id`, `rubric_score`, `timestamp`
- **XQueue submission events**: Every XQueue submission MUST be logged with: `event_type=xqueue_submission`, `submission_id`, `queue_name`, `course_id`, `problem_id`, `user_id`, `timestamp`
- **XQueue grading events**: Every XQueue grading result MUST be logged with: `event_type=xqueue_graded`, `submission_id`, `grader_id`, `score`, `correct`, `grading_duration_ms`, `timestamp`
- **XQueue grader errors**: Every grading failure MUST be logged with: `event_type=xqueue_grader_error`, `submission_id`, `grader_id`, `error_type` (timeout, sandbox_violation, invalid_response, worker_crash), `error_message`, `retry_count`, `timestamp`
- **Timed exam lifecycle**: Every timed exam state transition MUST be logged with: `event_type=timed_exam_state_change`, `attempt_id`, `user_id`, `exam_id`, `old_state`, `new_state`, `time_remaining_seconds`, `timestamp`
- **Grade override events**: Every grade override MUST be logged with: `event_type=grade_override`, `user_id`, `course_id`, `problem_id`, `instructor_user_id`, `original_score`, `new_score`, `reason_length`, `timestamp`
- **Bulk operation events**: Every bulk operation MUST be logged with: `event_type=bulk_operation`, `operation_type` (regrade, export, import), `course_id`, `instructor_user_id`, `total_items`, `processed_items`, `failed_items`, `duration_ms`, `status`, `timestamp`
- **Sensitive data rule**: MUST NOT log: student email addresses (use hashed user ID), submission content (answers, essays, code), file contents, full IP addresses (use hash)

### Metrics

- `ora2_submissions_total` (counter, labels: `course_id`, `assessment_type`) -- total ORA2 submissions
- `ora2_submission_duration_seconds` (histogram, labels: `assessment_type`, `has_files`) -- time to submit
- `ora2_peer_assessments_total` (counter, labels: `course_id`) -- total peer assessments completed
- `ora2_peer_assessment_score` (histogram, labels: `course_id`) -- distribution of peer scores
- `ora2_staff_assessments_total` (counter, labels: `course_id`) -- total staff assessments completed
- `ora2_staff_grading_queue_size` (gauge, labels: `course_id`) -- submissions awaiting staff grading
- `ora2_file_upload_size_bytes` (histogram) -- uploaded file sizes
- `ora2_file_storage_used_bytes` (gauge) -- total storage used at `/openedx/data/ora2`
- `xqueue_submissions_total` (counter, labels: `queue_name`, `course_id`) -- total XQueue submissions
- `xqueue_queue_depth` (gauge, labels: `queue_name`) -- unprocessed submissions in queue
- `xqueue_grading_duration_seconds` (histogram, labels: `queue_name`, `grader_id`) -- grading latency
- `xqueue_grader_errors_total` (counter, labels: `queue_name`, `error_type`) -- grader failures by type
- `xqueue_grader_workers_active` (gauge, labels: `queue_name`) -- active grader worker pods
- `xqueue_dead_letter_total` (counter, labels: `queue_name`) -- submissions that failed all retries
- `timed_exam_attempts_total` (counter, labels: `course_id`, `final_state`) -- timed exam attempts
- `timed_exam_completion_time_seconds` (histogram, labels: `course_id`) -- actual time spent by students
- `timed_exam_auto_submit_total` (counter, labels: `course_id`) -- auto-submitted due to timer expiry
- `grade_overrides_total` (counter, labels: `course_id`, `assessment_type`) -- manual grade overrides
- `bulk_operations_total` (counter, labels: `operation_type`, `status`) -- bulk operation completions
- `bulk_operation_duration_seconds` (histogram, labels: `operation_type`) -- bulk operation durations
- `assessment_gradebook_sync_duration_seconds` (histogram, labels: `assessment_type`) -- time from grading to gradebook update

### Alerts

- **Critical**: `xqueue_queue_depth{queue_name="openedx"}` exceeds 100 for more than 10 minutes -- page oncall (grading pipeline stalled)
- **Critical**: `xqueue_grader_workers_active{queue_name="openedx"}` equals 0 for more than 5 minutes -- page oncall (no grader workers available)
- **Critical**: `ora2_file_storage_used_bytes` exceeds 90% of volume capacity -- page oncall (storage exhaustion imminent)
- **Warning**: `xqueue_grading_duration_seconds` p95 exceeds 30 seconds -- notify channel (grading latency degradation)
- **Warning**: `xqueue_dead_letter_total` increases by more than 10 in 1 hour -- notify channel (grading failures accumulating)
- **Warning**: `ora2_staff_grading_queue_size` exceeds 50 for any course for more than 48 hours -- notify channel (staff grading backlog)
- **Warning**: `timed_exam_auto_submit_total` / `timed_exam_attempts_total` exceeds 50% for any course over 7 days -- notify instructors (most students running out of time; time limit may be too short)
- **Warning**: `bulk_operation_duration_seconds{operation_type="regrade"}` p95 exceeds 30 minutes -- notify channel (bulk operations slow)
- **Info**: `ora2_peer_assessments_total` is zero for a course with submissions older than 72 hours -- notify instructor (peer grading not happening)
- **Info**: `xqueue_grader_errors_total{error_type="sandbox_violation"}` increases by more than 20 in 1 hour -- notify instructor (many students hitting sandbox limits; may need to adjust problem instructions)

### Dashboards

- **Assessment Overview**: Total submissions by type (ORA2, XQueue, timed exam, standard), daily assessment activity, gradebook sync latency, active timed exams
- **ORA2 Operations**: Submission rate over time, peer grading completion rate, staff grading queue size by course, file upload volume and storage usage, peer score distribution, inter-rater agreement
- **XQueue Operations**: Queue depth over time, grading latency percentiles, grader worker count, error rate by type, dead letter count, grader utilization (busy time / total time)
- **Timed Exams**: Active exams by course, completion time distribution, auto-submit rate, time extension usage, exam attempt state distribution
- **Bulk Operations**: Active operations, completion rate, average duration by type, failure rate
- **Assessment Analytics** (instructor-facing): Per-problem average score, per-rubric-criterion score breakdown, question difficulty analysis (percentage correct), assessment completion rate

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Audit and Baseline (Week 1-2)

1. Audit existing ORA2 configuration: verify `ORA2_FILEUPLOAD_BACKEND`, `ORA2_FILEUPLOAD_ROOT`, `ORA2_FILEUPLOAD_CACHE_NAME` are correctly set in both LMS and CMS settings (they are -- confirmed in production.py)
2. Audit existing XQueue deployment: verify the XQueue K8s service, MySQL database, and secrets are operational (service exists, database provisioned, secrets in ExternalSecrets)
3. Verify the ORA Grading MFE is accessible and functional at `apps.academyv2.mereka.io/ora-grading`
4. Verify the `edx-proctoring` no-op backend is available for timed-only exams
5. Confirm CodeJail is disabled (it is -- `nonexistingpythonbinary`) and document the path to enable it
6. Create test course with basic ORA2 assignments, timed exams, and standard problem types
7. Run baseline smoke tests: create ORA2 submission, complete peer review, take timed exam, submit auto-graded problem
8. Document any issues found during baseline audit

#### Phase 1: ORA2 Operationalization (Week 3-5)

1. Create 3-5 production-quality ORA2 assignments in a pilot course with rubrics, peer assessment, and staff grading
2. Test file upload with various file types and sizes (up to 10 MB)
3. Test peer assessment workflow end-to-end with 10+ internal testers
4. Verify ORA Grading MFE staff grading workflow
5. Verify grade integration: ORA2 scores appear correctly in the gradebook
6. Verify email notifications for ORA2 grading events
7. Set up Prometheus metrics for ORA2 (submission count, grading queue size, file storage usage)
8. Create ORA2 assessment guidelines documentation for course authors
9. Monitor storage usage at `/openedx/data/ora2` and set up the storage capacity alert

#### Phase 2: Timed Exams (Week 4-6)

1. Configure test subsections as timed exams using `exam_type=timed`
2. Verify timer enforcement: start exam, let timer expire, confirm auto-submission
3. Test time extensions (accommodations) via instructor dashboard
4. Test server-side timer enforcement (manipulate client clock, confirm server rejects late submissions)
5. Test browser crash recovery (close browser, reopen within time limit, confirm resume works)
6. Verify timed exam grades flow to gradebook immediately (no proctoring hold)
7. Set up timed exam metrics and alerts

#### Phase 3: XQueue Grader Deployment (Week 6-9)

1. Build and test a Python code grader worker container image
2. Deploy the grader worker as a K8s Deployment (1 replica initially) in `mereka-lms` namespace
3. Configure the grader worker to poll the `openedx` XQueue queue
4. Create a test XQueue-backed problem in Studio
5. Test end-to-end: student submits code -> XQueue dispatches -> grader evaluates in sandbox -> result posted back -> grade in gradebook
6. Test sandbox security: malicious code submissions (fork bomb, filesystem access, network access)
7. Test grader worker failure recovery: kill worker pod, confirm submission returns to queue
8. Scale to 2 grader worker replicas and test concurrent submissions
9. Build and test a generic script grader worker
10. Set up XQueue metrics and alerts (queue depth, grading latency, error rate)
11. Create XQueue grader authoring documentation for course authors

#### Phase 4: Advanced Question Types (Week 8-10)

1. Verify drag-and-drop v2 XBlock is available in Studio (ships with Ulmo base image)
2. Verify math expression input is available (ships with Ulmo base image)
3. Install Problem Builder XBlock via Tutor plugin if not already present
4. Create test problems for each advanced question type
5. Verify keyboard accessibility for drag-and-drop v2
6. Verify math expression input accepts equivalent expressions (SymPy evaluation)
7. Test randomized problem pools with a library of 20+ problems
8. Test OLX export/import for courses containing advanced question types
9. Document advanced question type availability and authoring guides

#### Phase 5: Bulk Operations and Analytics (Week 10-13)

1. Test bulk grade export for a course with 500+ enrollments
2. Test bulk grade import via CSV
3. Test bulk regrade for a single problem across 500+ submissions
4. Set up assessment analytics views in the instructor dashboard
5. Create Grafana dashboards for assessment operations
6. Test bulk operations at scale (2,000+ enrollments)
7. Verify Celery task timeout and checkpoint/resume for long-running bulk operations
8. Conduct load testing for concurrent assessment submissions (50+ simultaneous ORA2 submissions)

#### Phase 6: Enterprise Rollout (Week 13-16)

1. Enable advanced assessments for the first enterprise pilot client
2. Provide course author training on ORA2, timed exams, XQueue problems, and advanced question types
3. Monitor all assessment pipelines during the first week of enterprise usage
4. Collect feedback from course authors and students
5. Address issues identified during pilot
6. Enable for additional enterprise clients
7. Finalize operational runbook for assessment systems

### Feature Flags

- `ENABLE_ORA2_FILE_UPLOADS` -- gate ORA2 file upload capability (default: on; already configured in production.py)
- `ENABLE_ORA2_PEER_CALIBRATION` -- gate peer calibration step (default: off; enable per course)
- `ENABLE_ORA2_AI_ASSISTED_GRADING` -- gate AI-assisted grading suggestions for staff (default: off)
- `ENABLE_XQUEUE_GRADING` -- gate XQueue-backed problems in Studio (default: on; XQueue service is already deployed)
- `ENABLE_XQUEUE_CODE_GRADER` -- gate the Python code grader worker (default: off; enable after Phase 3)
- `ENABLE_TIMED_EXAMS` -- gate timed exam configuration in Studio (default: on; native Open edX feature)
- `ENABLE_ADVANCED_XBLOCKS` -- gate advanced XBlock problem types in Studio component picker (default: on for built-in types)
- `ENABLE_PROBLEM_BUILDER` -- gate Problem Builder XBlock (default: off; enable after installation)
- `ENABLE_BULK_ASSESSMENT_OPS` -- gate bulk grade import/export/regrade operations (default: on)
- `ENABLE_ASSESSMENT_ANALYTICS` -- gate assessment analytics views in instructor dashboard (default: off; enable after Phase 5)
- Feature flags MUST be configurable via Django Waffle flags or Open edX Feature Flags (in `FEATURES` dict)
- Feature flag changes MUST take effect without service restart

### Backward Compatibility

- Enabling advanced assessment features MUST NOT affect existing courses that use only standard multiple-choice, dropdown, and text input problems
- ORA2 configuration changes MUST NOT invalidate existing ORA2 assignments or grades
- XQueue grader deployment MUST NOT affect the existing XQueue service operation (additive: adding workers, not changing the service)
- Timed exam enablement MUST NOT retroactively change existing unproctored exams
- All new assessment types MUST be backward compatible with OLX course export/import
- Existing gradebook functionality MUST continue to work exactly as before for non-advanced assessment types
- Disabling any feature flag MUST NOT corrupt or lose existing assessment data; it only hides the UI for creating new assessments of that type

### Rollback Steps

#### ORA2 Rollback

1. ORA2 is a core Open edX feature and cannot be fully disabled without an image rebuild. In case of critical ORA2 issues:
2. Disable file uploads via `ENABLE_ORA2_FILE_UPLOADS=false` in Waffle flags
3. Direct students to contact instructors for manual submission alternatives
4. Staff grading can continue via Django admin if the ORA Grading MFE is unavailable
5. Investigate via Loki logs (`event_type=ora2_*`) and fix

#### XQueue Grader Rollback

1. Scale grader worker Deployment to 0 replicas: `kubectl scale deployment xqueue-grader --replicas=0 -n mereka-lms`
2. Submissions already in the queue will wait (no data loss); students see "Grading in progress"
3. Fix the grader worker issue
4. Scale back up: `kubectl scale deployment xqueue-grader --replicas=2 -n mereka-lms`
5. Workers process the backlogged queue automatically

#### Timed Exam Rollback

1. Timed exams are a native Open edX feature. In case of timer malfunction:
2. Set `ENABLE_TIMED_EXAMS=false` to prevent new timed exam creation
3. Active timed exams continue (cannot interrupt mid-exam)
4. Instructors can manually extend time limits for affected students
5. Investigate the timer issue and re-enable

#### Bulk Operations Rollback

1. Set `ENABLE_BULK_ASSESSMENT_OPS=false` to hide bulk operation UI
2. Cancel any running Celery tasks: `celery -A lms control revoke <task_id> --terminate`
3. Partially completed operations are committed (idempotent re-run is safe)
4. Instructors fall back to individual grade management via instructor dashboard

#### Advanced XBlocks Rollback

1. Set `ENABLE_ADVANCED_XBLOCKS=false` to hide new advanced problem types from Studio
2. Existing problems already embedded in courses continue to render and grade (XBlocks are self-contained)
3. Students can still submit answers to existing advanced problems
4. New courses cannot add new advanced problems until the flag is re-enabled

---

## Monorepo Location

| Component | Path | Notes |
|-----------|------|-------|
| Custom grader scripts | `services/xqueue-graders/graders/` | Python/shell grading scripts |
| Grader Dockerfile | `services/xqueue-graders/Dockerfile` | Sandboxed execution environment |
| Grader tests | `services/xqueue-graders/tests/` | pytest (grader unit tests) |
| XQueue K8s config | `deploy/k8s/base/apps/xqueue/` | XQueue Deployment + grader worker pods |
| ORA2 config | `infrastructure/tutor/` | Tutor plugin config for ORA2 settings |
| Advanced XBlock config | `infrastructure/tutor/` | Tutor plugin for drag-and-drop v2, math input, etc. |

**Note**: The XQueue service itself is an upstream Open edX image — we do not fork it. Custom graders are the only new source code.

---

## Open Questions

1. **CodeJail enablement priority**: Enabling CodeJail requires deploying an AppArmor profile on GKE nodes. Is AppArmor available on the current GKE node image? If not, should we use gVisor or a container-based sandbox instead? This affects the XQueue code grader security architecture.

2. **XQueue grader worker resource allocation**: What CPU and memory limits should be set for grader worker pods? Student code execution is CPU-bound and potentially memory-intensive. Need to determine: (a) expected peak concurrent submissions, (b) maximum acceptable grading latency, (c) available GKE node capacity for additional pods.

3. **ORA2 file storage volume sizing**: The current `/openedx/data/ora2` path is on the LMS pod's persistent volume. For enterprise scale (5,000+ students submitting files), should we migrate ORA2 file storage to Google Cloud Storage (GCS) via the `ORA2_FILEUPLOAD_BACKEND=swift` or `s3` backend? What is the current persistent volume size?

4. **Advanced XBlock availability in Ulmo**: Which advanced XBlocks (drag-and-drop v2, Problem Builder, Peer Instruction, Circuit Schematic Builder) ship with the Tutor 21.0.0 Ulmo base image, and which require additional pip installation? Need to test the Studio component picker to determine what is available out of the box.

5. **AI-assisted ORA2 grading model**: The ORA2 AI-assisted grading feature uses machine learning to predict scores based on staff-graded examples. Is this feature fully functional in the Ulmo release? What ML backend does it use? Does it require additional infrastructure (separate ML serving pod, model training pipeline)?

6. **Peer assessment at enterprise scale**: For a course with 2,000+ students, peer assessment workflows generate O(n * must_grade) assessment records. What is the database performance impact? Should we implement pagination or sharding for the peer assessment query paths?

7. **Multi-language rubric implementation**: Open edX's content localization framework handles course content translation, but does ORA2 specifically support per-rubric-criterion language variants? Or do course authors need to create separate course runs per language? Need to investigate the ORA2 multilingual support status.

8. **Assessment analytics data source**: Should assessment analytics (score distributions, rubric breakdowns) be built on top of the existing analytics pipeline (per `specs/analytics-pipeline_spec.md`) or implemented as direct database queries? The analytics pipeline may have data freshness delays that are unacceptable for near-real-time instructor dashboards.

9. **XQueue queue isolation**: The current configuration uses a single queue named `openedx`. For multiple grader types (Python, generic script), should we create separate queues with dedicated workers, or use a single queue with grader routing based on problem metadata? Separate queues are simpler to operate but require per-queue monitoring.

10. **Grade dispute workflow UX**: Should the grade dispute workflow be a simple "flag for review" button on the student's grade page, or a more structured process with forms, escalation tiers, and SLA tracking? The answer depends on enterprise client expectations and available instructor bandwidth.

11. **Timed exam accommodation workflow**: How should time accommodations be requested and approved? Options: (a) instructor manually sets per student in the instructor dashboard, (b) student self-service request with instructor approval, (c) enterprise admin bulk upload of accommodation lists. This affects both UX design and access control.

12. **XQueue grader container image registry**: Should XQueue grader worker container images be stored in the same Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx`) as the Open edX images, or in a separate repository? Course-author-provided grading scripts need a secure build and deployment pipeline.

13. **Integration with Badges & Credentials**: Should assessment completion events (particularly ORA2 staff-graded assignments and timed exam passes) trigger badge issuance (per `specs/badges-credentials-enterprise_spec.md`)? If so, what assessment events should be badge-eligible, and how is the mapping configured?
