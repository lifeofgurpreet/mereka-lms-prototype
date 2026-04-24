---
title: Proctoring Integration for Enterprise Open edX
type: feature_spec
status: draft
owner: engineering
vehicle: talent_platform
version: 1.0.0
depends_on:
- specs/enterprise-microservices_spec.md
- specs/multi-tenancy-architecture_spec.md
- specs/advanced-assessment-xqueue_spec.md
links:
  related_docs:
  - docs/concepts/architecture/proctoring-architecture-overview.md
  - docs/runbooks/proctoring-operations-runbook.md
  - docs/ops/runbooks/TROUBLESHOOTING.md
  related_specs:
  - specs/enterprise-microservices_spec.md
  - specs/k8s-deployment_spec.md
  - specs/secrets-management_spec.md
  - specs/multi-site-domains_spec.md
  - specs/observability-stack_spec.md
  - specs/proposals/mobile-apps-enterprise_spec.md
  - specs/cross-cutting-requirements_spec.md
id: SPEC-PROCTORING-INTEGRATION
spec_class: proposal
created: '2026-02-10'
last_reviewed: '2026-02-10'
review_due: '2026-05-11'
domain: platform
normativity: proposed
summary: Proposal-stage contract for enterprise proctoring integration work that remains
  outside the normative root lane.
---

# Human Summary

## What we're building

A production-grade proctoring integration layer for Mereka Academy's Open edX platform that enables enterprise clients to administer secure, monitored examinations. The system integrates with third-party proctoring providers (Examity, Respondus LockDown Browser, ProctorTrack, Proctorio) through Open edX's pluggable proctoring backend architecture (`edx-proctoring`), adding exam setup workflows, student identity verification, browser lockdown enforcement, screen recording and analysis, exam session management, proctor review workflows, and grading integration.

The proctoring system operates as an extension of the existing Open edX assessment infrastructure. Course authors configure proctored exams in Studio, students take exams under monitoring conditions (AI-proctored or live-proctored depending on provider and enterprise client policy), proctoring sessions are recorded and analyzed for integrity violations, human proctors review flagged sessions, and results flow back into the Open edX gradebook. Each enterprise client can configure their preferred proctoring provider and policies independently via the enterprise admin portal.

The integration is multi-tenant: enterprise client A may use Examity with live proctoring, while enterprise client B uses Proctorio with AI-only monitoring. Proctoring provider credentials, policies, and review workflows are isolated per enterprise customer UUID. The platform handles the orchestration layer; actual proctoring technology (camera/screen monitoring, AI analysis, lockdown enforcement) is provided by the third-party services.

## Why it matters

Enterprise clients purchasing learning platforms for high-stakes training (compliance certifications, professional development, regulated industry qualifications) require verifiable exam integrity. Without proctoring, certifications issued by Mereka Academy carry lower credibility for enterprise clients in regulated industries (finance, healthcare, aviation, legal). Multiple prospective enterprise clients have listed proctoring as a requirement for contract signing. This spec establishes the full contract so that when the decision to implement is made, the engineering team can execute against a well-defined architecture without the design discovery phase that typically delays proctoring rollouts by 4-8 weeks.

## Success looks like

- At least 2 proctoring providers (one AI-proctored, one live-proctored) are operational in production
- A course author can configure a proctored exam in Studio within 10 minutes without platform engineering assistance
- A student can complete the end-to-end proctored exam flow (identity verification, environment check, exam, submission) within the scheduled exam window with zero platform-caused failures
- Proctor review of a flagged session can be completed within 24 hours of exam submission
- Exam results (pass/fail and integrity status) are reflected in the Open edX gradebook within 5 minutes of review completion
- Zero cross-tenant proctoring data leakage: enterprise client A cannot access exam recordings or results belonging to enterprise client B
- False positive rate for AI-flagged integrity violations is below 10% (measured over first 1000 proctored sessions)
- System supports at least 500 concurrent proctored exam sessions across all enterprise clients without degradation
- Compliance documentation (GDPR, FERPA) is complete and auditable for all proctoring data flows

---

# Agent Contract

## Scope

- In scope:
  - Integration architecture with the `edx-proctoring` Django application (Open edX's pluggable proctoring backend)
  - Proctoring provider adapter layer supporting Examity, Respondus LockDown Browser, ProctorTrack, and Proctorio
  - Exam setup and configuration workflow in Studio (course authoring tool)
  - Exam scheduling system for time-windowed proctored assessments
  - Student identity verification flow (photo ID capture, facial recognition matching)
  - Pre-exam environment check (webcam, microphone, screen share, browser lockdown)
  - Browser lockdown integration (Respondus LockDown Browser, Proctorio extension)
  - Screen recording, webcam recording, and audio recording during exam sessions
  - AI-based integrity analysis (anomaly detection, face tracking, audio analysis)
  - Exam session lifecycle management (created, ready, started, submitted, reviewing, verified, rejected)
  - Proctor review dashboard for human review of flagged sessions
  - Grading integration: proctoring results flowing into the Open edX gradebook
  - Multi-tenant configuration: per-enterprise-customer proctoring provider and policy selection
  - Data privacy controls: recording retention, data deletion, consent management
  - Observability: logging, metrics, alerts, dashboards for proctoring operations
  - Rollout plan from zero to production with phased provider enablement

- Out of scope:
  - Building a proprietary proctoring engine (AI models, facial recognition, browser lockdown software)
  - Proctoring for non-Open edX content or assessments
  - Mobile app proctoring (covered separately; most proctoring providers do not support mobile browsers)
  - Building a custom exam authoring interface (Studio is the authoring tool)
  - Physical test center management or in-person proctoring logistics
  - Payment processing for proctoring fees (handled by enterprise billing, not the platform)
  - Proctoring provider contract negotiation or pricing
  - Accessibility accommodations beyond what the proctoring providers support natively

## Non-goals

- Building our own AI proctoring engine (we integrate with third-party providers who own the ML/AI)
- Replacing the Open edX `edx-proctoring` Django application (we extend it via its plugin architecture)
- Supporting proctoring for self-paced assessments without time windows (proctored exams require scheduling)
- Guaranteeing exam integrity at a legally binding level (proctoring is a deterrent and detection tool, not a guarantee)
- Supporting real-time human proctoring at scale without a provider (live proctoring requires provider staff)
- Building a proctoring-specific mobile SDK (mobile proctoring depends on provider capabilities)
- Implementing proctoring for practice/ungraded assessments (proctoring applies only to graded, high-stakes exams)

## Assumptions

- The Open edX LMS is running Tutor 21.0.0 (Ulmo) with the `edx-proctoring` package available in the base image (ships with standard Tutor build)
- The `edx-proctoring` package provides the `ProctoringBackendProvider` plugin interface that third-party providers implement
- Enterprise clients have independent contracts with their chosen proctoring provider(s) and will supply API credentials
- Students have access to a desktop/laptop computer with webcam, microphone, and stable internet (minimum 1.5 Mbps upload) for proctored exams
- Browser lockdown solutions (Respondus, Proctorio) require students to install a browser extension or dedicated application before taking the exam
- The existing GKE infrastructure can handle the additional load from proctoring API calls (estimated: 100 RPS at peak, 500 concurrent sessions)
- The existing observability stack (Prometheus, Loki, Tempo) can ingest proctoring-related metrics and logs
- Cloud SQL (MySQL 8) can store proctoring session metadata; actual recordings are stored by the proctoring provider, not in our infrastructure
- The enterprise microservices suite (per `specs/enterprise-microservices_spec.md`) is deployed, providing the enterprise customer and catalog infrastructure that proctoring depends on

---

## Requirements

### Functional

#### Proctoring Backend Architecture

- The system MUST integrate with the Open edX `edx-proctoring` Django application via its `ProctoringBackendProvider` plugin interface
- The system MUST support the following proctoring providers as pluggable backends:
  - **Examity**: Live and AI-proctored exams via REST API integration
  - **Respondus LockDown Browser**: Browser lockdown with optional webcam monitoring
  - **ProctorTrack**: AI-proctored with automated integrity scoring
  - **Proctorio**: AI-proctored via browser extension with configurable monitoring levels
- Each proctoring provider backend MUST implement the `ProctoringBackendProvider` interface methods:
  - `register_exam_attempt(exam, context)` -- register a new exam attempt with the provider
  - `start_exam_attempt(exam, attempt)` -- signal exam start to the provider
  - `stop_exam_attempt(exam, attempt)` -- signal exam submission to the provider
  - `get_attempt_status(attempt)` -- poll provider for attempt status
  - `on_review_callback(payload)` -- receive review results from provider via webhook
  - `get_instructor_url(exam, attempt)` -- return URL for proctor review in provider's dashboard
  - `get_student_url(exam, attempt)` -- return URL for student to launch the proctored environment
- The system MUST support a provider adapter registry that maps `provider_name` strings to `ProctoringBackendProvider` implementations
- The system MUST allow different enterprise customers to use different proctoring providers simultaneously without interference
- The system MUST support running multiple provider backends concurrently (e.g., some courses use Examity while others use Proctorio within the same enterprise customer)
- The system SHOULD support a "no-op" proctoring backend for development and testing environments that simulates the full exam flow without contacting any external provider

#### Exam Setup and Configuration (Studio)

- Course authors MUST be able to configure a subsection as a proctored exam in Studio by setting the subsection's `exam_type` to `proctored`
- The proctored exam configuration MUST include the following settings:
  - `exam_type`: `proctored` | `timed` | `practice_proctored` | `onboarding`
  - `time_limit_minutes`: integer, the allowed exam duration (minimum 15, maximum 480)
  - `due_date`: ISO 8601 datetime, the deadline after which the exam is no longer available
  - `is_practice_exam`: boolean, whether this is a practice run that does not count toward grades
  - `backend`: string, the proctoring provider to use (e.g., `examity`, `respondus`, `proctortrack`, `proctorio`)
  - `review_policy`: string, free-text instructions for human proctors (e.g., "Flag if student leaves webcam frame for more than 15 seconds")
  - `allow_accommodations`: boolean, whether ADA/disability accommodations are permitted (extra time, break allowances)
- The system MUST validate that the specified `backend` is enabled for the enterprise customer whose catalog contains this course
- The system MUST support `practice_proctored` exams that allow students to test their proctoring setup without grade impact
- The system MUST support `onboarding` exams that establish the student's identity baseline (photo, facial scan) before they can take proctored exams
- Studio MUST display a warning if a course author selects a proctoring backend that is not enabled for any enterprise customer with access to this course
- The system SHOULD provide a "preview as student" mode in Studio that shows the full proctored exam UI without requiring provider interaction

#### Exam Scheduling and Time Windows

- The system MUST support scheduled exam windows defined by `start_date` and `due_date` on the proctored subsection
- Students MUST NOT be able to begin a proctored exam before the `start_date`
- Students MUST NOT be able to begin a proctored exam after the `due_date`
- The system MUST support per-student time extensions (accommodations) that add extra minutes to `time_limit_minutes` without changing the exam window
- If a student starts a proctored exam and the remaining time until `due_date` is less than `time_limit_minutes`, the system MUST warn the student that they may not have enough time to complete
- The system MUST support flexible scheduling: within the exam window, students can start at any time (no appointment booking required)
- The system SHOULD support appointment-based scheduling for live-proctored exams (Examity) where a student books a specific time slot with a human proctor
- Appointment-based scheduling MUST integrate with the provider's scheduling API to show available slots and confirm bookings
- The system MUST enforce that only one proctored exam attempt per student per exam is active at any time (no parallel attempts)

#### Student Identity Verification

- The system MUST require identity verification before a student can begin a proctored exam (except practice exams)
- Identity verification MUST include:
  - **Photo ID capture**: Student presents a government-issued photo ID to the webcam; the system captures a clear image
  - **Facial recognition match**: The system (via the proctoring provider) compares the photo ID face to the live webcam feed of the student
  - **Name verification**: The captured name from the photo ID is compared against the student's LMS profile name
- The identity verification result MUST be one of: `passed`, `failed`, `pending_review`
- If identity verification fails, the student MUST NOT be allowed to proceed to the exam
- If identity verification is `pending_review`, the student MAY proceed to the exam, but the exam results MUST be held for proctor review before being released to the gradebook
- The system MUST store the identity verification result (pass/fail/pending, timestamp, provider reference ID) but MUST NOT store the photo ID image in the LMS database; the provider retains the image per their data retention policy
- The system MUST support re-verification if the initial attempt fails (maximum 3 attempts before lockout)
- The system SHOULD support a onboarding/baseline identity verification flow that establishes the student's identity once, with subsequent exams verifying against the established baseline rather than requiring full ID re-capture
- The system MUST link identity verification records to both the `user_id` and the `enterprise_customer_uuid` for audit purposes

#### Pre-Exam Environment Check

- Before starting a proctored exam, the system MUST perform an environment readiness check:
  - **Webcam check**: Verify webcam is accessible and producing a video feed
  - **Microphone check**: Verify microphone is accessible and capturing audio
  - **Screen share check**: Verify the system can capture screen content (for providers that require it)
  - **Browser check**: Verify the browser version and required extensions/applications are installed
  - **Network check**: Verify upload bandwidth meets the minimum threshold (1.5 Mbps for video streaming)
  - **Secondary device check**: Prompt the student to confirm no secondary devices are in the testing area (provider-specific)
- The environment check MUST produce a pass/fail result for each component
- If any required component fails, the student MUST NOT be able to start the exam until the issue is resolved
- The environment check MUST display clear, actionable instructions for resolving each failure (e.g., "Grant camera permission in your browser settings")
- The environment check results MUST be recorded as part of the exam session metadata
- The system SHOULD provide a standalone environment check page accessible before the exam window so students can verify readiness in advance

#### Browser Lockdown and Monitoring

- The system MUST support browser lockdown via Respondus LockDown Browser and Proctorio browser extension
- For Respondus LockDown Browser:
  - The system MUST detect whether the student is using the Respondus LockDown Browser application
  - If the exam requires LockDown Browser and the student is not using it, the system MUST display a download/launch prompt and block exam access
  - While LockDown Browser is active, the student MUST NOT be able to: open other applications, copy/paste, take screenshots, access other browser tabs, print, or use external monitors
  - The system MUST communicate the exam URL to the LockDown Browser via the Respondus Server API
- For Proctorio:
  - The system MUST detect whether the Proctorio browser extension is installed and active
  - If the exam requires Proctorio and the extension is not detected, the system MUST display installation instructions and block exam access
  - The Proctorio extension MUST be configured with monitoring settings specified by the course author or enterprise admin:
    - `record_video`: boolean (webcam recording)
    - `record_audio`: boolean (microphone recording)
    - `record_screen`: boolean (screen recording)
    - `record_room_scan`: boolean (360-degree room scan before exam)
    - `lock_fullscreen`: boolean (force fullscreen mode)
    - `disable_clipboard`: boolean (prevent copy/paste)
    - `disable_printing`: boolean (prevent printing)
    - `disable_new_tabs`: boolean (prevent new tab/window)
    - `close_open_tabs`: boolean (close existing tabs on exam start)
- The browser lockdown configuration MUST be stored per exam and MUST be enforceable without requiring platform engineering changes (admin-configurable)
- The system MUST detect and log attempts to circumvent browser lockdown (e.g., virtual machines, remote desktop software) if the provider supports such detection

#### Screen Recording and Analysis

- For providers that support recording (Examity, ProctorTrack, Proctorio):
  - The system MUST facilitate webcam video recording throughout the exam session, streamed to the provider's infrastructure
  - The system MUST facilitate screen recording throughout the exam session (if configured), streamed to the provider's infrastructure
  - The system MUST facilitate audio recording throughout the exam session (if configured), streamed to the provider's infrastructure
  - Recordings MUST NOT be stored on Mereka Academy infrastructure; they MUST be stored on the proctoring provider's infrastructure per the provider's data retention policy
  - The system MUST store a reference ID (`provider_session_id`) that links the LMS exam attempt to the provider's recording
- For AI-proctored sessions (ProctorTrack, Proctorio):
  - The provider MUST analyze recordings for integrity violations including: student face not visible, multiple faces detected, unauthorized person present, student leaves frame, suspicious eye movement patterns, unauthorized objects (phone, notes), audio anomalies (other voices, web search sounds), virtual machine detected, secondary monitor detected
  - The AI analysis MUST produce an integrity score (0-100) and a list of flagged events with timestamps
  - Flagged events MUST include: `event_type`, `timestamp_offset_seconds`, `severity` (low, medium, high, critical), `description`
  - The system MUST receive AI analysis results via webhook callback from the provider
- For live-proctored sessions (Examity):
  - A human proctor MUST monitor the student in real-time via webcam and screen share
  - The human proctor MUST be able to pause the exam timer if a legitimate interruption occurs
  - The human proctor MUST be able to terminate the exam if a critical violation is detected
  - Communication between the proctor and student MUST occur via the provider's chat interface (not via the LMS)
- The system MUST NOT access or process recording content directly; all analysis is performed by the proctoring provider

#### Exam Session Lifecycle

- Each proctored exam attempt MUST follow this state machine:
  - `created` -- exam attempt record created in the LMS, student has not started
  - `download_software_clicked` -- student has initiated browser lockdown software download
  - `ready_to_start` -- environment check passed, identity verified, awaiting student action
  - `started` -- exam timer is running, student is answering questions
  - `ready_to_submit` -- student has indicated they want to submit (confirmation step)
  - `submitted` -- exam answers submitted, proctoring session ended, awaiting review
  - `second_review_required` -- AI flagged issues, awaiting human review
  - `verified` -- proctoring review passed, exam grade is valid and released
  - `rejected` -- proctoring review determined integrity violation, exam grade is invalidated
  - `error` -- a system error occurred during the exam (network failure, provider outage)
  - `expired` -- the exam window closed while the attempt was in progress
  - `timed_out` -- the exam timer ran out before submission
- State transitions MUST be logged with: `attempt_id`, `user_id`, `exam_id`, `old_state`, `new_state`, `triggered_by` (student, proctor, system, provider), `timestamp`, `enterprise_customer_uuid`
- The system MUST prevent invalid state transitions (e.g., `verified` -> `started`)
- The system MUST handle the `error` state gracefully: if a proctoring session is interrupted by a technical failure, the student MUST be given the option to resume the attempt (if the provider supports resume) or to request a new attempt from the instructor
- The system MUST auto-expire attempts that remain in `started` state for longer than `time_limit_minutes + 30 minutes` (grace period for submission delays) by transitioning to `timed_out`
- The system MUST enforce that a student can have at most one `started` attempt per exam at any time

#### Proctor Review Workflow

- The system MUST provide a proctor review dashboard accessible to users with the `proctor_reviewer` role
- The proctor review dashboard MUST be accessible at a dedicated URL path (e.g., `https://academyv2.mereka.io/proctoring/review/`)
- The proctor review dashboard MUST display:
  - A queue of exam attempts in `submitted` or `second_review_required` state, ordered by submission time (oldest first)
  - For each attempt: student identifier (hashed or anonymized), exam name, course name, enterprise customer name, submission timestamp, AI integrity score (if available), number of flagged events
  - Filtering by: enterprise customer, course, exam, status, date range, AI integrity score threshold
  - Sorting by: submission time, integrity score, number of flags
- When a reviewer selects an attempt, the review detail view MUST display:
  - Timeline of flagged events with timestamps and severity
  - Direct link to the provider's recording playback page (via `get_instructor_url()`)
  - Student's identity verification status and result
  - The exam review policy set by the course author
  - Action buttons: `Verify` (mark as passed), `Reject` (mark as integrity violation), `Escalate` (request second review), `Request More Info` (add notes, return to queue)
- The reviewer MUST provide a reason when rejecting an attempt (free-text, minimum 20 characters)
- The system MUST support a two-tier review process: initial review by AI or junior reviewer, escalation to senior reviewer for contested or ambiguous cases
- The system MUST log all review actions with: `reviewer_user_id`, `attempt_id`, `action`, `reason`, `timestamp`
- Review actions MUST be irreversible once committed, except by a user with the `proctoring_admin` role who can override a `rejected` status to `verified` with an audit log entry
- The proctor review dashboard MUST be scoped by `enterprise_customer_uuid`: a reviewer for enterprise customer A MUST NOT see attempts from enterprise customer B
- The system SHOULD send email notifications to reviewers when new attempts enter the review queue
- The system SHOULD provide SLA tracking: attempts in the review queue for longer than the configured review SLA (default: 24 hours) MUST be highlighted

#### Integration with Open edX Course Authoring

- Proctored exam configuration MUST be available in Studio's subsection settings editor
- Course authors MUST be able to set exam type, time limit, proctoring backend, and review policy without engineering intervention
- The system MUST validate that the selected proctoring backend is configured and credentials are active before allowing the course to be published with proctored exams
- The system MUST support importing/exporting courses with proctored exam settings preserved (OLX format)
- The system MUST support course re-runs: when a course is re-run, proctored exam settings MUST be copied to the new run
- The system SHOULD provide a summary view in Studio showing all proctored exams in a course with their configuration

#### Grading and Result Integration

- When a proctored exam attempt reaches `verified` status, the exam grade MUST be released to the Open edX gradebook within 5 minutes
- When a proctored exam attempt reaches `rejected` status, the exam grade MUST be set to 0 in the gradebook and the student MUST be notified via email
- The gradebook entry for a proctored exam MUST include a `proctoring_status` field: `pending`, `verified`, `rejected`, `error`
- While an exam attempt is in any state other than `verified` or `rejected`, the grade MUST be held as `pending` and MUST NOT count toward the student's final course grade
- The system MUST support instructor override: an instructor MUST be able to manually release a grade for a `rejected` attempt if they determine the rejection was a false positive
- Instructor overrides MUST be logged with the instructor's user ID, reason, and timestamp
- The system MUST support grade passback to enterprise integrated channels: if a proctored exam grade is updated (verified, rejected, overridden), the change MUST propagate to configured integrated channels (per `specs/enterprise-microservices_spec.md`) on the next sync cycle
- The system MUST NOT release partial exam data to the gradebook; the entire exam attempt is either graded or pending

#### Multi-Tenant Proctoring Configuration

- Each enterprise customer MUST have an independent proctoring configuration stored as an `EnterpriseProctoringConfig` record linked to `enterprise_customer_uuid`
- The `EnterpriseProctoringConfig` MUST include:
  - `enterprise_customer_uuid`: FK to the enterprise customer
  - `enabled_providers`: list of provider names enabled for this enterprise customer (e.g., `["examity", "proctorio"]`)
  - `default_provider`: the default provider used when a course author does not specify one
  - `provider_credentials`: per-provider API credentials (stored encrypted in the database or referenced from K8s secrets)
  - `review_sla_hours`: the target time for completing proctor reviews (default: 24)
  - `identity_verification_required`: boolean (default: true)
  - `recording_retention_days`: number of days recordings are retained by the provider (communicated to the provider via API; default: 180)
  - `allow_practice_exams`: boolean (default: true)
  - `allow_onboarding_exams`: boolean (default: true)
  - `default_monitoring_settings`: JSON object with default Proctorio/ProctorTrack monitoring levels
  - `accommodation_policy`: text describing the enterprise's ADA/disability accommodation policy
- The system MUST enforce that a course can only use proctoring backends enabled in the enterprise customer's `EnterpriseProctoringConfig`
- The system MUST NOT allow a course author to configure a proctoring backend for which the enterprise customer has not provided valid credentials
- The enterprise admin portal MUST expose a proctoring configuration page where enterprise admins can:
  - Enable/disable proctoring providers
  - Enter/update provider API credentials
  - Set default monitoring levels
  - Configure review SLA
  - View proctoring usage statistics (exams administered, pass/fail rates, average review time)
- Provider API credentials MUST be validated (test connection) when entered, before being saved

#### Compliance and Data Privacy

- The system MUST display a proctoring consent notice to students before they begin the identity verification process
- The consent notice MUST clearly state:
  - What data will be collected (webcam video, screen recording, audio, photo ID)
  - Who will access the data (proctoring provider, human reviewers, enterprise admin)
  - How long the data will be retained
  - The student's right to refuse proctoring (with the consequence of not being able to take the exam)
  - Contact information for data privacy inquiries
- The student MUST explicitly accept the consent notice (click "I Agree") before the proctoring session begins
- The consent acceptance MUST be recorded with: `user_id`, `exam_id`, `enterprise_customer_uuid`, `consent_version`, `timestamp`, `ip_address_hash`
- The system MUST support GDPR data subject access requests (DSAR): when a student requests their data, the system MUST provide all proctoring session metadata (attempt records, review outcomes, consent records) and coordinate with the proctoring provider for recording access
- The system MUST support GDPR right to erasure: when requested, the system MUST delete all proctoring session metadata from the LMS database and send a deletion request to the proctoring provider via API
- The system MUST support FERPA compliance for US-based enterprise clients: proctoring records are education records and MUST be protected accordingly
- Recording retention MUST be configurable per enterprise customer and MUST be communicated to the proctoring provider via API at session creation time
- The system MUST NOT transfer proctoring data (recordings, identity verification results) across geographic regions unless the enterprise customer's data processing agreement explicitly permits it
- The system MUST maintain an audit log of all proctoring-related data access events (who accessed what, when, from where)
- The system MUST support data processing agreements (DPAs) with each proctoring provider; the platform verifies DPA status in the provider configuration but does not enforce the legal agreement itself

### Non-Functional Requirements

#### Performance

- Proctoring environment check (webcam, microphone, screen, browser, network) MUST complete within 30 seconds at p95
- Identity verification round-trip (photo capture, AI comparison, result) MUST complete within 60 seconds at p95 (dependent on provider)
- Exam attempt state transitions MUST propagate from the LMS to the provider within 2 seconds at p95
- Provider webhook callbacks (review results, status updates) MUST be processed within 5 seconds of receipt at p95
- The proctor review dashboard MUST load the review queue (up to 100 items) within 3 seconds at p95
- The system MUST support at least 500 concurrent proctored exam sessions across all enterprise customers without degradation (p95 latency increase <= 20% compared to 50 concurrent sessions)
- Grading integration (releasing verified/rejected results to gradebook) MUST complete within 5 minutes of review action

#### Reliability

- The proctoring integration layer MUST be available 99.9% of the time during scheduled exam windows (measured per enterprise customer)
- If a proctoring provider's API is unreachable, the system MUST NOT allow new proctored exam starts but MUST NOT interrupt exams already in progress
- If network connectivity is lost during an active exam session, the system MUST preserve the student's answers locally (browser session storage) and allow resume when connectivity is restored, subject to the time limit
- Webhook delivery from proctoring providers MUST be retried by the provider; the LMS MUST support idempotent webhook processing (same callback delivered twice produces the same outcome)
- The system MUST handle provider-side outages gracefully: if a provider is down for more than 15 minutes during an active exam window, the system MUST alert the enterprise admin and offer the option to extend the exam window or allow unproctored submission (with notation)
- Database transactions for exam state changes MUST be atomic: either the state change and all associated side effects (event publishing, notification) succeed, or all are rolled back

#### Security

- All communication with proctoring provider APIs MUST use TLS 1.2 or higher
- Provider API credentials MUST be stored encrypted at rest (AES-256) in the database or referenced from K8s secrets via ExternalSecrets
- Proctoring provider webhook endpoints MUST validate request signatures (HMAC-SHA256 or provider-specific signing) to prevent spoofing
- The proctor review dashboard MUST enforce role-based access control: only users with `proctor_reviewer` or `proctoring_admin` roles can access review functionality
- Review actions MUST be authenticated and authorized per request (no cached session-level authorization)
- The system MUST NOT store exam recordings, photo ID images, or biometric data in the LMS database or Mereka Academy infrastructure; these remain on the provider's infrastructure
- The system MUST implement rate limiting on the webhook endpoint: 1000 requests/minute per provider to prevent abuse
- The system MUST log all authentication failures on proctoring API endpoints with source IP, endpoint, and failure reason
- Proctoring session metadata MUST be encrypted in transit (TLS) and at rest (database encryption)
- The system MUST NOT expose proctoring API credentials in logs, error messages, or API responses

---

## Acceptance Criteria

### Provider Integration

- [ ] AC-001: Given the `edx-proctoring` package is installed, when a proctoring backend for Proctorio is registered, then `ProctoringBackendProvider.get_backend('proctorio')` returns the Proctorio adapter instance
- [ ] AC-002: Given an Examity backend is configured with valid API credentials, when `register_exam_attempt()` is called, then a corresponding exam record is created in the Examity system and a `provider_session_id` is returned
- [ ] AC-003: Given a Respondus LockDown Browser backend is configured, when a student accesses the exam URL from a standard browser, then the system detects the missing LockDown Browser and displays a download prompt
- [ ] AC-004: Given a ProctorTrack backend is configured, when `on_review_callback()` receives an AI analysis result, then the exam attempt status is updated to `second_review_required` if integrity score is below the configured threshold
- [ ] AC-005: Given a "no-op" backend is configured in a development environment, when the full exam flow is executed, then all state transitions occur correctly without contacting any external provider

### Exam Setup

- [ ] AC-006: Given a course author in Studio, when they edit a subsection's exam settings, then they can select `proctored` as the exam type and choose from providers enabled for the enterprise customer
- [ ] AC-007: Given a proctored exam with `time_limit_minutes=60` and `due_date=2026-06-15T23:59:00Z`, when a student accesses the exam at 2026-06-16T00:00:01Z, then the exam is blocked with a "deadline passed" message
- [ ] AC-008: Given an enterprise customer with only `proctorio` enabled, when a course author attempts to select `examity` as the backend, then Studio displays a validation error
- [ ] AC-009: Given a course with proctored exams is re-run, when the new course run is created, then all proctored exam settings (type, time limit, backend, review policy) are preserved in the new run

### Identity Verification

- [ ] AC-010: Given a student starting a proctored exam for the first time, when the identity verification flow begins, then the system captures a photo ID image via webcam and sends it to the provider for analysis
- [ ] AC-011: Given identity verification returns `failed`, when the student attempts to proceed, then the exam is blocked and the student is offered up to 2 additional verification attempts
- [ ] AC-012: Given identity verification returns `passed`, when the student proceeds, then the verification result (passed, timestamp, provider reference) is stored linked to `user_id` and `enterprise_customer_uuid`
- [ ] AC-013: Given a student has completed onboarding identity verification, when they start a subsequent proctored exam, then the system verifies against the baseline (facial recognition) without requiring full photo ID re-capture

### Environment Check

- [ ] AC-014: Given a student on the pre-exam environment check page, when their webcam is blocked by browser permissions, then the check fails with the message "Please allow camera access in your browser settings"
- [ ] AC-015: Given all environment checks pass, when the student reviews the results, then each component (webcam, microphone, screen share, browser, network) shows a green checkmark
- [ ] AC-016: Given the student's upload bandwidth is below 1.5 Mbps, when the network check runs, then it fails with a message indicating the minimum required bandwidth

### Browser Lockdown

- [ ] AC-017: Given an exam configured with Respondus LockDown Browser, when a student is in the LockDown Browser, then the student cannot open other applications, copy/paste, take screenshots, or access other tabs
- [ ] AC-018: Given an exam configured with Proctorio with `lock_fullscreen=true` and `disable_clipboard=true`, when the student takes the exam, then fullscreen mode is enforced and clipboard access is blocked
- [ ] AC-019: Given a student attempts to use a virtual machine to take a proctored exam, when the provider detects the VM, then the attempt is flagged with a `vm_detected` event

### Exam Session Lifecycle

- [ ] AC-020: Given a student starts a proctored exam, when the exam timer begins, then the attempt state transitions from `ready_to_start` to `started` and the state change is logged with timestamp and user ID
- [ ] AC-021: Given a student submits a proctored exam, when the submission is processed, then the attempt state transitions to `submitted` and the proctoring provider is notified via `stop_exam_attempt()`
- [ ] AC-022: Given an exam attempt in `started` state for longer than `time_limit_minutes + 30 minutes`, when the auto-expiry check runs, then the attempt transitions to `timed_out` and the provider is notified
- [ ] AC-023: Given a proctoring provider outage during an active exam, when the student's recording stream fails, then the student's answers are preserved in browser session storage and a `reconnect` prompt is displayed
- [ ] AC-024: Given an attempt in `verified` state, when any action attempts to transition it to `started`, then the transition is rejected with an invalid state error

### Proctor Review

- [ ] AC-025: Given 10 exam attempts in `second_review_required` state for enterprise customer A and 5 for customer B, when reviewer R (authorized for customer A only) accesses the review dashboard, then only the 10 attempts for customer A are visible
- [ ] AC-026: Given a reviewer selects an attempt, when they click "Reject" and enter a reason (25 characters), then the attempt transitions to `rejected`, the reason is stored, and the student is notified via email
- [ ] AC-027: Given a reviewer rejects an attempt, when a `proctoring_admin` user accesses the attempt, then they can override the rejection to `verified` with an audit log entry
- [ ] AC-028: Given an attempt has been in the review queue for longer than the enterprise's `review_sla_hours`, when the review dashboard loads, then the attempt is highlighted with an SLA warning

### Grading Integration

- [ ] AC-029: Given a proctored exam attempt transitions to `verified`, when the gradebook sync runs, then the student's exam grade appears in the Open edX gradebook within 5 minutes
- [ ] AC-030: Given a proctored exam attempt transitions to `rejected`, when the gradebook sync runs, then the student's exam grade is set to 0 and the `proctoring_status` field shows `rejected`
- [ ] AC-031: Given an instructor overrides a rejected attempt, when the override is processed, then the original exam grade is restored and `proctoring_status` changes to `verified` with an override audit entry
- [ ] AC-032: Given a proctored exam attempt is in `submitted` state (pending review), when the student views their grades, then the exam shows as "Pending Proctoring Review" with no numeric grade

### Multi-Tenant Isolation

- [ ] AC-033: Given enterprise customer A uses Examity and customer B uses Proctorio, when students from both take exams simultaneously, then each student's session is routed to their respective provider with no credential cross-contamination
- [ ] AC-034: Given enterprise customer A's proctoring configuration includes `review_sla_hours=12`, when customer B's configuration has `review_sla_hours=48`, then SLA warnings on the review dashboard use the correct per-customer threshold
- [ ] AC-035: Given a GDPR deletion request for a student in enterprise customer A, when the deletion is processed, then only that student's proctoring data is deleted; all other data (including other students in customer A) remains intact

### Compliance

- [ ] AC-036: Given a student is about to start a proctored exam, when the consent notice is displayed, then it includes: data collected, who accesses it, retention period, right to refuse, and contact information
- [ ] AC-037: Given a student does not accept the consent notice, when they attempt to proceed, then the exam start is blocked and the student is informed they cannot take the proctored exam without consent
- [ ] AC-038: Given a GDPR DSAR for a student, when the request is processed, then the system provides all proctoring session metadata and coordinates with the provider for recording access within 30 days

---

## Edge Cases

### Exam Session Edge Cases

- **Network failure during exam**: If the student's internet connection drops during a proctored exam, the LMS MUST preserve answers in browser session storage and the proctoring provider MUST handle recording gaps. When connectivity restores within the time limit, the student MUST be able to resume. If connectivity does not restore within 5 minutes, the system MUST transition the attempt to `error` state and notify the instructor
- **Provider API timeout during exam start**: If the proctoring provider's `register_exam_attempt()` API times out (> 10 seconds), the system MUST retry once. If the retry also fails, the system MUST block the exam start and display "Proctoring service temporarily unavailable. Please try again in a few minutes."
- **Provider webhook never arrives**: If the provider does not deliver a review callback within 72 hours of exam submission, the system MUST alert the enterprise admin and the proctoring operations team. The exam MUST remain in `submitted` state (not auto-verified)
- **Concurrent attempts**: If a student opens two browser tabs and attempts to start the same exam twice, the system MUST detect the duplicate via a database-level unique constraint (`user_id`, `exam_id`, `state IN ('started', 'ready_to_start')`) and reject the second attempt with an error
- **Browser crash during exam**: If the browser crashes and the student reopens it within the time limit, the system MUST allow resume if the proctoring provider session is still active. The system MUST query the provider's session status before allowing resume
- **Instructor changes exam during active session**: If an instructor modifies the exam content (adds/removes questions) while a student has an active proctored attempt, the student MUST continue with the version of the exam they started (content versioning is handled by Open edX modulestore)
- **Timezone confusion**: All exam windows (`start_date`, `due_date`) MUST be stored and displayed in UTC with a clear timezone indicator. The student's local timezone MUST be shown alongside the UTC time for clarity

### Identity Verification Edge Cases

- **Student changes appearance**: If a student's facial appearance has changed significantly since their onboarding verification (e.g., new hairstyle, facial hair, glasses), the provider's AI may flag a mismatch. The system MUST allow human review of flagged identity mismatches rather than automatic rejection
- **Photo ID quality issues**: If the captured photo ID image is blurry, too dark, or partially obscured, the provider may return an `inconclusive` result. The system MUST prompt the student to retry with better positioning/lighting (up to 3 total attempts)
- **Non-standard photo ID**: If the student's government ID format is not recognized by the provider's AI (uncommon country, non-Roman script), the system MUST fall back to manual identity review by a human proctor
- **Minor student without government ID**: If enterprise policy allows minors, the system MUST support alternative identity verification methods as defined in the enterprise customer's `accommodation_policy` (e.g., school-issued ID, parent verification)

### Browser Lockdown Edge Cases

- **LockDown Browser crashes**: If the Respondus LockDown Browser application crashes during an exam, the student MUST be able to relaunch it and resume the exam if the provider session is still active. The time limit continues running
- **Extension conflict**: If a student's browser has extensions that conflict with Proctorio (e.g., ad blockers, VPNs), the environment check MUST detect the conflict and instruct the student to disable conflicting extensions
- **OS update during exam**: If the student's operating system triggers an update notification or restart during a proctored exam, the proctoring provider handles this as a recorded event. The LMS MUST NOT interpret this as a submission
- **Accessibility software conflict**: If a student uses screen readers, magnification software, or other accessibility tools that may conflict with browser lockdown, the system MUST support a lockdown-exempt mode for students with documented accommodations

### Proctor Review Edge Cases

- **Reviewer disagrees with AI**: If the AI flags an exam as suspicious but the human reviewer determines it is a false positive, the reviewer MUST be able to verify the attempt. The AI score MUST be preserved for analytics but MUST NOT override human judgment
- **All reviewers unavailable**: If no reviewer is available and the review queue exceeds the SLA, the system MUST escalate by notifying the enterprise admin and the Mereka Academy operations team. It MUST NOT auto-verify or auto-reject unreviewed attempts
- **Mass flagging event**: If a provider's AI model produces an anomalous spike in flagged exams (> 50% of attempts in a single exam flagged), the system MUST alert the operations team. This may indicate a model issue at the provider, not actual cheating
- **Review of already-graded attempt**: If an instructor has already manually released a grade for a pending attempt, and the proctoring review subsequently rejects it, the system MUST flag the conflict for the instructor rather than automatically overriding the manual grade

### Data Privacy Edge Cases

- **GDPR deletion with pending review**: If a student requests data deletion while their exam attempt is still pending review, the system MUST complete the deletion but mark the pending attempt as `rejected` with reason "data deleted per GDPR request" so the student does not receive credit for an unverifiable exam
- **Provider data retention mismatch**: If the enterprise customer's `recording_retention_days` is shorter than the provider's minimum retention period, the system MUST log a warning and communicate the actual retention period in the consent notice
- **Cross-border data transfer**: If a student is located in the EU and the proctoring provider's processing infrastructure is in the US, the consent notice MUST explicitly disclose the cross-border transfer. The system MUST verify that the provider has appropriate data transfer mechanisms (Standard Contractual Clauses, adequacy decision, etc.) before allowing the session
- **Recording subpoena**: If proctoring recordings are subpoenaed for academic integrity proceedings, the system MUST be able to generate a chain-of-custody report linking the recording (stored at the provider) to the specific exam attempt, student identity verification, and review outcome

### Rate Limiting

- The proctoring webhook endpoint MUST return HTTP 429 with `Retry-After` header when the rate limit (1000 requests/minute per provider) is exceeded
- Proctoring provider API calls from the LMS MUST implement exponential backoff with jitter (base: 2 seconds, max: 60 seconds, max retries: 5) for transient failures (HTTP 429, 500, 502, 503, 504)
- If a provider returns HTTP 429, the system MUST respect the `Retry-After` header and MUST NOT retry before the specified time

### Idempotency

- Webhook callbacks from proctoring providers MUST be processed idempotently: if the same callback is delivered multiple times (same `provider_session_id` and `event_type`), the system MUST produce the same outcome without duplicate side effects (no duplicate emails, no duplicate grade updates)
- Exam state transitions MUST be idempotent: requesting a transition to the current state MUST be a no-op
- Identity verification result storage MUST be idempotent: if the provider sends the same verification result twice, only one record is stored

---

## Observability

### Logs

- **Exam lifecycle events**: Every state transition MUST be logged as structured JSON to stdout with: `event_type=proctoring_state_change`, `attempt_id`, `user_id`, `exam_id`, `course_id`, `enterprise_customer_uuid`, `old_state`, `new_state`, `triggered_by`, `provider_name`, `timestamp`
- **Provider API calls**: Every outbound API call to a proctoring provider MUST be logged with: `provider_name`, `endpoint`, `http_method`, `http_status`, `latency_ms`, `enterprise_customer_uuid`, `exam_id`. MUST NOT log request/response bodies (may contain credentials or PII)
- **Webhook processing**: Every inbound webhook MUST be logged with: `provider_name`, `event_type`, `provider_session_id`, `http_status` (our response), `processing_time_ms`, `enterprise_customer_uuid`
- **Identity verification events**: MUST log: `event_type=identity_verification`, `user_id`, `enterprise_customer_uuid`, `result` (passed/failed/pending), `attempt_number`, `provider_name`. MUST NOT log: photo ID data, facial recognition scores, biometric data
- **Review actions**: MUST log: `event_type=proctor_review`, `reviewer_user_id`, `attempt_id`, `action` (verify/reject/escalate), `enterprise_customer_uuid`, `reason_length` (not reason text, to avoid PII in logs)
- **Consent events**: MUST log: `event_type=proctoring_consent`, `user_id`, `enterprise_customer_uuid`, `exam_id`, `consent_version`, `action` (accepted/declined), `timestamp`
- **Error events**: All proctoring errors MUST be logged with: `error_type`, `error_message`, `provider_name`, `enterprise_customer_uuid`, `exam_id`, `attempt_id`, `stack_trace` (for server-side errors only)
- **Sensitive data rule**: MUST NOT log: student email addresses (use hashed form), photo ID data, facial recognition scores, provider API credentials, recording URLs, full GDPR request details

### Metrics

- `proctoring_exam_attempts_total` (counter, labels: `enterprise_customer_uuid`, `provider_name`, `exam_type`, `final_state`) -- total exam attempts
- `proctoring_active_sessions` (gauge, labels: `enterprise_customer_uuid`, `provider_name`) -- currently active proctored sessions
- `proctoring_state_transition_duration_seconds` (histogram, labels: `from_state`, `to_state`, `provider_name`) -- time between state transitions
- `proctoring_identity_verification_total` (counter, labels: `enterprise_customer_uuid`, `provider_name`, `result`) -- verification outcomes
- `proctoring_identity_verification_duration_seconds` (histogram, labels: `provider_name`) -- time for identity verification
- `proctoring_environment_check_total` (counter, labels: `component`, `result`) -- environment check results per component
- `proctoring_environment_check_duration_seconds` (histogram) -- time for full environment check
- `proctoring_provider_api_requests_total` (counter, labels: `provider_name`, `endpoint`, `http_status`) -- outbound API calls
- `proctoring_provider_api_latency_seconds` (histogram, labels: `provider_name`, `endpoint`) -- provider API latency
- `proctoring_webhook_received_total` (counter, labels: `provider_name`, `event_type`, `processing_status`) -- inbound webhooks
- `proctoring_webhook_processing_duration_seconds` (histogram, labels: `provider_name`, `event_type`) -- webhook processing time
- `proctoring_review_queue_size` (gauge, labels: `enterprise_customer_uuid`, `status`) -- attempts awaiting review
- `proctoring_review_queue_age_seconds` (histogram, labels: `enterprise_customer_uuid`) -- age of oldest unreviewed attempt
- `proctoring_review_actions_total` (counter, labels: `enterprise_customer_uuid`, `action`, `reviewer_role`) -- review decisions
- `proctoring_review_duration_seconds` (histogram, labels: `enterprise_customer_uuid`) -- time from submission to review completion
- `proctoring_grade_release_duration_seconds` (histogram, labels: `enterprise_customer_uuid`, `final_state`) -- time from review to gradebook update
- `proctoring_ai_integrity_score` (histogram, labels: `provider_name`, `enterprise_customer_uuid`) -- distribution of AI integrity scores
- `proctoring_false_positive_rate` (gauge, labels: `provider_name`, `enterprise_customer_uuid`) -- percentage of AI-flagged sessions verified by human review
- `proctoring_consent_events_total` (counter, labels: `enterprise_customer_uuid`, `action`) -- consent accept/decline

### Alerts

- **Critical**: `proctoring_active_sessions` exceeds 500 -- page oncall (approaching capacity limit)
- **Critical**: `proctoring_provider_api_requests_total{http_status=~"5.."}` rate exceeds 10% over 5 minutes for any provider -- page oncall (provider outage during exam window)
- **Critical**: `proctoring_webhook_received_total{processing_status="failed"}` rate exceeds 5% over 15 minutes -- page oncall (webhook processing failure, results not flowing back)
- **Warning**: `proctoring_review_queue_age_seconds` exceeds `review_sla_hours` for any enterprise customer -- notify channel and enterprise admin
- **Warning**: `proctoring_identity_verification_total{result="failed"}` rate exceeds 20% over 1 hour for any enterprise customer -- notify channel (may indicate provider issue or student population issue)
- **Warning**: `proctoring_false_positive_rate` exceeds 15% over 7 days for any provider -- notify channel (AI model quality degradation)
- **Warning**: `proctoring_environment_check_total{result="failed"}` rate exceeds 30% for any component over 1 hour -- notify channel (may indicate a common technical issue)
- **Warning**: `proctoring_provider_api_latency_seconds` p95 exceeds 10 seconds for any provider -- notify channel
- **Info**: `proctoring_consent_events_total{action="declined"}` rate exceeds 10% over 24 hours for any enterprise customer -- notify enterprise admin (students declining proctoring)
- **Info**: `proctoring_exam_attempts_total{final_state="error"}` rate exceeds 5% over 24 hours -- notify channel (technical error rate)

### Dashboards

- **Proctoring Overview**: Total active sessions (real-time), daily exam attempts by provider/enterprise customer, verification pass/fail rate, overall review queue size, consent acceptance rate
- **Provider Health**: Per-provider API latency percentiles, error rate, webhook processing success rate, active sessions by provider
- **Exam Integrity**: AI integrity score distribution by provider, false positive rate trend, rejection rate by enterprise customer, most common flagged event types
- **Review Operations**: Review queue size over time by enterprise customer, average review duration, SLA compliance rate, reviewer throughput (reviews per hour per reviewer)
- **Identity Verification**: Verification success/failure rate by provider, verification duration percentiles, re-verification rate, onboarding completion rate
- **Compliance**: Consent acceptance/decline rate by enterprise customer, GDPR DSAR count and response time, data deletion request count and completion rate
- **Capacity**: Concurrent sessions over time, peak concurrent sessions by hour of day, sessions per GKE pod, provider API call volume

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Infrastructure and Backend Preparation (Week 1-3)

1. Verify `edx-proctoring` package is present in the LMS image and is the correct version for the Ulmo release
2. Install and configure proctoring provider backend packages (`edx-proctoring-proctorio`, `edx-proctoring-examity`, etc.) as Tutor plugins
3. Create the `EnterpriseProctoringConfig` Django model and admin interface
4. Implement the provider adapter registry and "no-op" testing backend
5. Provision proctoring-related secrets in Infisical:
   - `MEREKA_LMS_PROCTORING_EXAMITY_API_KEY`
   - `MEREKA_LMS_PROCTORING_EXAMITY_API_SECRET`
   - `MEREKA_LMS_PROCTORING_EXAMITY_ORGANIZATION_ID`
   - `MEREKA_LMS_PROCTORING_PROCTORTRACK_API_KEY`
   - `MEREKA_LMS_PROCTORING_PROCTORTRACK_API_SECRET`
   - `MEREKA_LMS_PROCTORING_WEBHOOK_SECRET` (HMAC key for validating inbound webhooks)
6. Create ExternalSecret manifest for proctoring secrets
7. Configure webhook endpoint in the LMS with signature validation
8. Set up Prometheus metrics collection for proctoring endpoints
9. Deploy and test with the "no-op" backend on the staging/local environment

#### Phase 1: Single Provider Pilot -- AI Proctoring (Week 4-6)

1. Enable Proctorio backend for one pilot enterprise customer
2. Configure the pilot enterprise customer's `EnterpriseProctoringConfig` with Proctorio credentials
3. Create 2-3 practice proctored exams in a test course
4. Run 20+ practice exam sessions with internal testers to validate:
   - Environment check flow
   - Proctorio extension detection and enforcement
   - Exam session lifecycle (start, submit, review)
   - Webhook callback processing
   - Review dashboard functionality
5. Fix issues identified during internal testing
6. Open practice exams to pilot enterprise client's students (10-20 students)
7. Collect feedback on student experience, identify UX friction points
8. Measure: environment check pass rate, exam completion rate, false positive rate

#### Phase 2: First Graded Proctored Exam (Week 7-9)

1. Configure the first graded proctored exam with the pilot enterprise customer
2. Enable identity verification for the pilot enterprise customer
3. Run the first graded exam with a small cohort (20-50 students)
4. Monitor all observability channels during the exam window
5. Complete proctor review for all submitted attempts within SLA
6. Verify grading integration: grades appear in gradebook after review
7. Conduct post-exam retrospective: student feedback, proctor feedback, system metrics
8. Adjust monitoring settings based on false positive rate

#### Phase 3: Second Provider -- Live Proctoring (Week 10-13)

1. Enable Examity backend for a second enterprise customer that requires live proctoring
2. Configure appointment-based scheduling integration with Examity
3. Run internal testing with 10+ sessions
4. Pilot with second enterprise customer's students
5. Validate live proctor communication works correctly
6. Validate proctor-initiated exam pause and termination
7. Run first graded live-proctored exam
8. Compare operational costs and student experience between AI and live proctoring

#### Phase 4: Additional Providers and Scale (Week 14-18)

1. Enable ProctorTrack backend if additional enterprise customers require it
2. Enable Respondus LockDown Browser integration if required
3. Load test: simulate 500 concurrent proctored sessions
4. Security review: penetration test on webhook endpoints, review dashboard access controls, tenant isolation verification
5. Compliance review: GDPR and FERPA documentation, DPA verification with all active providers
6. Enable proctoring configuration in the enterprise admin portal (self-service for enterprise admins)
7. Onboard third and fourth enterprise customers

#### Phase 5: Production Hardening (Week 19-22)

1. Enable all alerts and dashboards
2. Write and test the operational runbook
3. Conduct tabletop exercise: "proctoring provider goes down during a high-stakes exam"
4. Conduct tabletop exercise: "GDPR deletion request for a student with pending review"
5. Establish review SLA monitoring and reviewer staffing model
6. Document incident response procedures for proctoring-specific scenarios
7. Collect 1000+ session data points to validate false positive rate target (< 10%)

### Feature Flags

- `ENABLE_PROCTORING` -- global gate for all proctoring functionality (default: off)
- `ENABLE_PROCTORING_PROCTORIO` -- gate Proctorio backend availability (default: off)
- `ENABLE_PROCTORING_EXAMITY` -- gate Examity backend availability (default: off)
- `ENABLE_PROCTORING_PROCTORTRACK` -- gate ProctorTrack backend availability (default: off)
- `ENABLE_PROCTORING_RESPONDUS` -- gate Respondus LockDown Browser backend availability (default: off)
- `ENABLE_PROCTORING_IDENTITY_VERIFICATION` -- gate identity verification requirement (default: on when proctoring is enabled)
- `ENABLE_PROCTORING_REVIEW_DASHBOARD` -- gate review dashboard access (default: off)
- `ENABLE_PROCTORING_ENTERPRISE_ADMIN_CONFIG` -- gate self-service proctoring configuration in enterprise admin portal (default: off)
- `ENABLE_PROCTORING_APPOINTMENT_SCHEDULING` -- gate appointment-based scheduling for live proctoring (default: off)
- All feature flags MUST be configurable per `enterprise_customer_uuid` where applicable (not just globally)
- Feature flag changes MUST take effect without service restart (Django Waffle flags or Open edX Feature Flags)

### Backward Compatibility

- Enabling proctoring MUST NOT affect existing unproctored exams or assessments in any course
- Students not enrolled in courses with proctored exams MUST see no changes in their LMS experience
- The `edx-proctoring` package is already part of the Open edX base image; enabling it MUST NOT require an image rebuild
- The LMS MUST continue to function normally if all proctoring feature flags are disabled (no hard dependency)
- Existing course exports (OLX) that do not include proctoring settings MUST import correctly without errors
- The grading system MUST continue to work normally for non-proctored assessments even when proctoring is enabled

### Rollback Steps

#### Per-Provider Rollback

1. Disable the failing provider's feature flag (e.g., `ENABLE_PROCTORING_PROCTORIO=false`)
2. Exams already in progress with that provider continue (the provider's session is independent of the flag)
3. New exam starts with that provider are blocked
4. Inform the enterprise admin and suggest switching to an alternative provider or postponing exams
5. Investigate the issue using Loki logs and Grafana dashboards
6. Re-enable when the issue is resolved

#### Full Proctoring Rollback

1. Set `ENABLE_PROCTORING=false` globally
2. All proctored exam starts are blocked across all enterprise customers
3. Exams already in progress are NOT interrupted (the proctoring session is managed by the provider)
4. Exam attempts already submitted continue through the review and grading pipeline (webhooks still process)
5. Students see standard (unproctored) exam behavior for new exams
6. Inform all enterprise admins of the temporary proctoring outage
7. Re-enable by setting `ENABLE_PROCTORING=true`

#### Review Dashboard Rollback

1. Set `ENABLE_PROCTORING_REVIEW_DASHBOARD=false`
2. Review actions can still be performed via Django admin as a fallback
3. Webhook callbacks continue to update attempt statuses
4. Re-enable when dashboard issues are resolved

#### Webhook Endpoint Rollback

1. If the webhook endpoint is compromised or processing incorrectly, disable it by removing the URL path from the LMS URL configuration
2. Providers will retry webhook delivery (most providers retry for 24-72 hours)
3. Fix the issue and re-enable the endpoint
4. Process backlogged webhooks (idempotent processing ensures no duplicate side effects)

#### Grade Integration Rollback

1. If grades are being incorrectly released or blocked, disable the grade release Celery task
2. Grades can be manually released by instructors via the instructor dashboard
3. Fix the integration issue and re-enable the Celery task
4. The task will process all pending grade releases on restart

---

## Open Questions

1. **Provider selection priority**: Which proctoring providers should be integrated first? The spec lists four (Examity, Respondus, ProctorTrack, Proctorio), but enterprise client requirements may favor a specific subset. Need input from the sales/partnerships team on which providers are most requested by prospective clients.

2. **Provider pricing model impact**: How do proctoring provider costs (per-session, per-seat, or platform license) affect the enterprise billing model? Should proctoring be bundled into the enterprise subscription or billed separately as an add-on? This affects whether the platform needs to track per-session usage for billing purposes.

3. **edx-proctoring version compatibility**: The spec assumes `edx-proctoring` is compatible with Tutor 21.0.0 (Ulmo). Need to verify the exact version of `edx-proctoring` bundled with the Ulmo release and confirm that the provider backend plugin architecture supports all four target providers. Some providers may require newer versions.

4. **Recording storage jurisdiction**: Where do each proctoring provider's recording storage servers reside geographically? For enterprise clients with data residency requirements (EU, Singapore, Australia), the provider's storage location may be a compliance blocker. Need data processing location information from each provider.

5. **AI proctoring accuracy benchmarks**: What are the documented false positive and false negative rates for each provider's AI analysis? The spec targets < 10% false positive rate, but this depends on the provider's model quality. Need published accuracy data from providers to validate this target.

6. **Human reviewer staffing**: Who will perform human proctor reviews? Options: (a) Mereka Academy staff, (b) enterprise client staff, (c) the proctoring provider's review team, (d) a combination. This affects the review dashboard's access model and the SLA achievability. If using the provider's reviewers, the review dashboard may be redundant (providers have their own).

7. **Mobile proctoring support**: Several proctoring providers (notably Proctorio and Respondus) do not support mobile browsers. Should the spec explicitly block proctored exams on mobile, or should it support providers that offer mobile SDKs (Examity has a mobile app)? This intersects with `specs/proposals/mobile-apps-enterprise_spec.md`.

8. **Accessibility compliance**: How do browser lockdown solutions interact with accessibility tools (screen readers, magnification, voice control)? Need to evaluate each provider's VPAT (Voluntary Product Accessibility Template) and determine what accommodations are technically feasible. Some lockdown solutions may conflict with WCAG 2.1 requirements.

9. **Exam scheduling complexity**: Should the initial implementation support appointment-based scheduling (required for Examity live proctoring) or only flexible-window scheduling? Appointment scheduling requires significant UI work (calendar component, timezone handling, available slots display). It could be deferred to a later phase.

10. **Multi-provider per enterprise customer**: The spec allows an enterprise customer to have multiple proctoring providers enabled simultaneously (different courses use different providers). Is this a real requirement, or should we simplify to one provider per enterprise customer? Multiple providers add complexity to the admin portal, review workflow, and billing.

11. **Proctor review SLA enforcement**: Should the SLA be enforced programmatically (auto-escalate, auto-notify) or just tracked on the dashboard? If a review exceeds the SLA, who is responsible -- Mereka Academy operations or the enterprise client's designated reviewers?

12. **Integration with enterprise integrated channels**: Should proctoring results (pass/fail, integrity score) be included in the data synced to external LMS/HR platforms via integrated channels (Degreed, Cornerstone)? If so, what fields should be included, and does this require consent from the student beyond the standard data sharing consent?

13. **Proctoring for re-takes**: If a student's exam is rejected due to an integrity violation, can the student retake the exam? How many retakes are allowed? Is this configured per enterprise customer, per course, or per exam? The Open edX subsection settings support `max_attempts` but the interaction with proctoring rejection needs clarification.

14. **Cost estimation**: What is the estimated monthly cost for proctoring at scale (500 sessions/month, 1000 sessions/month, 5000 sessions/month) for each provider? This information is needed to size the enterprise pricing model and to determine whether proctoring is economically viable for lower-tier enterprise clients.

15. **Existing edx-proctoring plugins**: Are there existing open-source `edx-proctoring` backend plugins for the four target providers, or do we need to build adapters from scratch? Open edX has community-maintained plugins for some providers (e.g., `edx-proctoring-proctortrack`). Evaluating existing plugins could significantly reduce implementation effort.

16. **Student support during exams**: What is the support model for students experiencing technical issues during a proctored exam? Options: (a) provider's live chat support, (b) Mereka Academy support, (c) enterprise client's support desk, (d) self-service troubleshooting. This affects whether the platform needs an in-exam support channel.
