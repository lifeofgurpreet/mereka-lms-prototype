---
source_spec: specs/proposals/proctoring-integration_spec.md
status: deferred_until_2027
created: 2026-02-10
updated: 2026-02-10
spec: proposals/proctoring-integration_spec.md
last_updated: '2026-02-10'
---

# Proctoring Integration - Implementation Plan

**Source Spec**: `specs/proposals/proctoring-integration_spec.md`

**Status**: DEFERRED UNTIL 2027 - No paid subscriptions required. This plan is ready for tracking and future implementation.

**Spec Summary**: 38 Acceptance Criteria covering proctoringbackend architecture, exam setup, identity verification, browser lockdown, AI/live proctoring, exam lifecycle, proctor review, grading integration, multi-tenant configuration, compliance, performance, reliability, and security.

---

## IMPORTANT: DEFERRED STATUS

All tasks below are marked **DEFERRED UNTIL 2027**. This specwas created to establish the full contract and architecturefor future implementation. No work should begin until:

1. Multiple enterprise clients confirm proctoring as a contract requirement
2. Budget approved for provider contracts (Examity, Proctorio, etc.)
3. Engineering capacity allocated (estimated 22+ weeks, 3-4 engineers)
4. Legal review completed for data processing agreements withproviders
5. Open questions in spec resolved (provider selection, reviewer staffing model, etc.)

---

## Task Categories

Tasks are grouped by category and ordered by dependency. Eachtask includes:
- **Complexity**: S (<2h), M (2-8h), L (>8h)
- **AC Mapping**: Which acceptance criteria this task addresses
- **File Path**: Where the work happens
- **Dependencies**: Prerequisites (or "None" if independent)
- **Status**: ALL MARKED AS DEFERRED

---

## Build Tasks (DEFERRED)

### Infrastructure and Dependencies

- [ ] **[M] [DEFERRED]** Verify edx-proctoring package version in Tutor Ulmo base image (`infrastructure/tutor/verify-proctoring-deps.sh`) | AC: #1 | Depends: None
  - Check Tutor 21.0.0 (Ulmo) includes compatible edx-proctoring version
  - Document required version and plugin interface compatibility
  - Verify ProctoringBackendProvider interface is available

- [ ] **[L] [DEFERRED]** Research and evaluate existing open-source proctoring backend plugins (`docs/research/proctoring-plugins-evaluation.md`) | AC: #1, #2, #3, #4 | Depends: None
  - Evaluate edx-proctoring-proctorio (if exists)
  - Evaluate edx-proctoring-proctortrack (community plugin)
  - Evaluate edx-proctoring-examity (if exists)
  - Evaluate edx-proctoring-respondus (if exists)
  - Document compatibility with Ulmo, maintenance status, licensing
  - Decision: build from scratch vs fork existing plugins

- [ ] **[M] [DEFERRED]** Design PostgreSQL/MySQL schema for proctoring metadata (`infrastructure/tutor/schemas/proctoring_schema.sql`) | AC: All | Depends: None
  - Tables: `proctoring_providers`, `enterprise_proctoring_config`, `exam_attempts`, `identity_verifications`, `proctor_reviews`, `consent_records`, `state_transitions`, `provider_sessions`
  - Indexes on: `user_id`, `exam_id`, `enterprise_customer_uuid`, `provider_session_id`, `status`, `created_at`, `expires_at`
  - Foreign keys between attempts, verifications, reviews
  - Encrypted columns for sensitive metadata

### Proctoring Backend Architecture

- [ ] **[L] [DEFERRED]** Implement proctoring backend provider registry (`lms/djangoapps/proctoring_mereka/registry.py`) |AC: #1, #5 | Depends: Schema, deps verification
  - ProctoringBackendProvider interface wrapper
  - Provider registration system (plugin discovery)
  - Provider selection logic based on enterprise config
  - No-op backend for development/testing

- [ ] **[L] [DEFERRED]** Implement Proctorio backend adapter(`lms/djangoapps/proctoring_mereka/backends/proctorio.py`) |AC: #1 | Depends: Registry
  - Implement all ProctoringBackendProvider interface methods
  - Proctorio API client (REST API integration)
  - Browser extension detection logic
  - Monitoring settings configuration (video, audio, screen,lockdown)
  - Webhook callback handler for AI analysis results
  - Error handling and retry logic

- [ ] **[L] [DEFERRED]** Implement Examity backend adapter (`lms/djangoapps/proctoring_mereka/backends/examity.py`) | AC:#2 | Depends: Registry
  - Implement all ProctoringBackendProvider interface methods
  - Examity API client (REST API integration)
  - Appointment-based scheduling integration
  - Live proctor communication channel
  - Session start/stop/pause handling
  - Webhook callback handler for proctor review results

- [ ] **[M] [DEFERRED]** Implement ProctorTrack backend adapter (`lms/djangoapps/proctoring_mereka/backends/proctortrack.py`) | AC: #4 | Depends: Registry
  - Implement all ProctoringBackendProvider interface methods
  - ProctorTrack API client
  - AI integrity scoring integration
  - Automated flagging rules

- [ ] **[M] [DEFERRED]** Implement Respondus LockDown Browserbackend adapter (`lms/djangoapps/proctoring_mereka/backends/respondus.py`) | AC: #3 | Depends: Registry
  - Implement all ProctoringBackendProvider interface methods
  - Respondus Server API integration
  - LockDown Browser detection and enforcement
  - Exam URL communication to LockDown Browser

- [ ] **[S] [DEFERRED]** Implement no-op testing backend (`lms/djangoapps/proctoring_mereka/backends/noop.py`) | AC: #5 |Depends: Registry
  - Full state machine simulation
  - No external API calls
  - Deterministic test responses
  - Development environment default

### Exam Setup and Configuration (Studio)

- [ ] **[L] [DEFERRED]** Extend Studio subsection settings UIfor proctored exams (`cms/djangoapps/contentstore/views/subsection.py`, `cms/static/js/views/subsection_editor.js`) | AC:#6, #7, #8, #9 | Depends: Backend architecture
  - Add proctored exam type selector (proctored, practice_proctored, onboarding)
  - Add backend provider dropdown (populated from enterpriseconfig)
  - Add time limit, due date, review policy fields
  - Add accommodation policy toggle
  - Validation: backend enabled for enterprise customer
  - Preview mode for proctored exam UI

- [ ] **[M] [DEFERRED]** Implement exam configuration validation (`lms/djangoapps/proctoring_mereka/validators.py`) | AC:#8 | Depends: Studio UI
  - Validate backend is enabled for enterprise customer
  - Validate time limits (15-480 minutes)
  - Validate due date is in future
  - Warn if backend credentials not configured

- [ ] **[M] [DEFERRED]** Implement course import/export withproctoring settings (`cms/djangoapps/contentstore/views/import_export.py`) | AC: Implicit | Depends: Studio UI
  - Preserve proctored exam settings in OLX export
  - Validate proctoring settings on import
  - Course re-run: copy proctored exam config to new run

### Exam Scheduling and Time Windows

- [ ] **[M] [DEFERRED]** Implement exam window enforcement (`lms/djangoapps/proctoring_mereka/access.py`) | AC: #10, #11 |Depends: Backend architecture
  - Check start_date: block access before window opens
  - Check due_date: block access after window closes
  - Warn if remaining time < time_limit_minutes
  - Support per-student time extensions (accommodations table)

- [ ] **[L] [DEFERRED]** Implement appointment-based scheduling for Examity (`lms/djangoapps/proctoring_mereka/scheduling.py`) | AC: #12 | Depends: Examity backend
  - Integrate with Examity scheduling API
  - Display available time slots
  - Booking confirmation
  - Booking cancellation/rescheduling
  - Calendar UI component

- [ ] **[M] [DEFERRED]** Implement per-student accommodationssystem (`lms/djangoapps/proctoring_mereka/accommodations.py`) | AC: Implicit | Depends: Exam window enforcement
  - Store time extensions per user per exam
  - Admin interface for adding accommodations
  - Accessible from instructor dashboard

### Student Identity Verification

- [ ] **[L] [DEFERRED]** Implement identity verification flow(`lms/djangoapps/proctoring_mereka/identity_verification.py`) | AC: #13, #14, #15, #16 | Depends: Backend architecture
  - Photo ID capture via webcam
  - Send to provider for AI facial recognition
  - Store verification result (passed/failed/pending)
  - Link to user_id and enterprise_customer_uuid
  - Re-verification logic (max 3 attempts)
  - Lockout after failed attempts

- [ ] **[M] [DEFERRED]** Implement onboarding/baseline verification (`lms/djangoapps/proctoring_mereka/onboarding.py`) | AC: #16 | Depends: Identity verification
  - Establish identity baseline (photo, facial scan)
  - Store baseline reference in provider system
  - Subsequent exams verify against baseline (no re-capture)
  - Baseline expiry and refresh logic

- [ ] **[M] [DEFERRED]** Build identity verification UI (`lms/static/proctoring/js/identity_verification.js`, `lms/templates/proctoring/identity_verification.html`) | AC: #13 | Depends: Identity verification flow
  - Webcam access prompt
  - Photo ID positioning guide
  - Live preview
  - Capture button
  - Processing status display
  - Success/failure messaging

### Pre-Exam Environment Check

- [ ] **[L] [DEFERRED]** Implement environment check system (`lms/djangoapps/proctoring_mereka/environment_check.py`) | AC: #17, #18 | Depends: Backend architecture
  - Webcam check: detect camera, verify video feed
  - Microphone check: detect mic, verify audio capture
  - Screen share check: verify screen capture permission
  - Browser check: detect browser type, version, required extensions
  - Network check: measure upload bandwidth (target: >=1.5 Mbps)
  - Secondary device check: prompt confirmation
  - Per-component pass/fail results
  - Actionable error messages for each failure

- [ ] **[M] [DEFERRED]** Build environment check UI (`lms/static/proctoring/js/environment_check.js`, `lms/templates/proctoring/environment_check.html`) | AC: #17 | Depends: Environment check system
  - Component checklist with real-time status updates
  - Progress indicator
  - Troubleshooting instructions per failure
  - Retry button for individual checks
  - Standalone check page (accessible before exam window)

### Browser Lockdown and Monitoring

- [ ] **[L] [DEFERRED]** Implement Respondus LockDown Browserintegration (`lms/djangoapps/proctoring_mereka/lockdown/respondus.py`) | AC: #19 | Depends: Respondus backend
  - Detect LockDown Browser via User-Agent or custom header
  - Display download/launch prompt if not detected
  - Communicate exam URL to LockDown Browser via Respondus Server API
  - Block exam access from non-LockDown browsers when required
  - Lockdown enforcement verification

- [ ] **[L] [DEFERRED]** Implement Proctorio browser extension integration (`lms/djangoapps/proctoring_mereka/lockdown/proctorio.py`) | AC: #20 | Depends: Proctorio backend
  - Detect Proctorio extension via JavaScript API
  - Display installation instructions if not detected
  - Configure monitoring settings per exam (video, audio, screen, room scan, fullscreen, clipboard, printing, tabs)
  - Pass settings to Proctorio extension via API
  - Admin-configurable lockdown policies

- [ ] **[M] [DEFERRED]** Implement VM/remote desktop detection (`lms/djangoapps/proctoring_mereka/security.py`) | AC: #21| Depends: Provider backends
  - Query provider APIs for VM detection capabilities
  - Log detection events
  - Configurable policy: warn vs block vs flag for review

### Screen Recording and Analysis

- [ ] **[M] [DEFERRED]** Implement recording session management (`lms/djangoapps/proctoring_mereka/recording.py`) | AC: #22, #23, #24 | Depends: Provider backends
  - Initiate webcam/screen/audio recording via provider API
  - Store provider session ID (reference to recording, not recording itself)
  - Recording start/stop/pause handling
  - Network interruption recovery
  - Data retention configuration per enterprise customer

- [ ] **[L] [DEFERRED]** Implement AI analysis result processing (`lms/djangoapps/proctoring_mereka/ai_analysis.py`) | AC:#23 | Depends: Recording session
  - Receive webhook from ProctorTrack/Proctorio with AI results
  - Parse integrity score (0-100)
  - Parse flagged events (event_type, timestamp, severity, description)
  - Store results in database
  - Trigger review workflow if score below threshold

- [ ] **[M] [DEFERRED]** Implement live proctor communicationchannel (Examity) (`lms/djangoapps/proctoring_mereka/live_proctor.py`) | AC: #24 | Depends: Examity backend
  - Embed Examity chat interface in exam UI
  - Handle proctor-initiated exam pause
  - Handle proctor-initiated exam termination
  - Real-time status updates from proctor

### Exam Session Lifecycle

- [ ] **[L] [DEFERRED]** Implement exam attempt state machine(`lms/djangoapps/proctoring_mereka/state_machine.py`) | AC:#25, #26, #27, #28 | Depends: Backend architecture
  - States: created, download_software_clicked, ready_to_start, started, ready_to_submit, submitted, second_review_required, verified, rejected, error, expired, timed_out
  - State transition validation (prevent invalid transitions)
  - Transition triggers: student action, proctor action, system timer, provider webhook
  - State change logging with full audit trail
  - Idempotent transitions

- [ ] **[M] [DEFERRED]** Implement auto-expiry job (`lms/djangoapps/proctoring_mereka/tasks.py`) | AC: #27 | Depends: State machine
  - Celery periodic task (runs every 5 minutes)
  - Query attempts in 'started' state older than time_limit +min grace period
  - Transition to 'timed_out'
  - Notify provider of session end

- [ ] **[M] [DEFERRED]** Implement error recovery system (`lms/djangoapps/proctoring_mereka/recovery.py`) | AC: #27 | Depends: State machine
  - Network failure detection
  - Local answer preservation (browser session storage)
  - Resume logic (verify provider session still active)
  - Student-initiated retry request
  - Instructor override for technical failures

### Proctor Review Workflow

- [ ] **[L] [DEFERRED]** Build proctor review dashboard (`lms/djangoapps/proctoring_mereka/review_dashboard.py`, `/proctoring/review/`) | AC: #29, #30, #31, #32 | Depends: State machine, AI analysis
  - Review queue view (attempts in submitted/second_review_required state)
  - Filters: enterprise customer, course, exam, status, daterange, integrity score
  - Sorting: submission time, integrity score, flags count
  - Detail view: flagged events timeline, provider recordinglink, identity verification status, review policy
  - Action buttons: Verify, Reject, Escalate, Request More Info
  - Role-based access control (proctor_reviewer role)
  - Multi-tenant isolation (reviewer sees only their enterprise customer)

- [ ] **[M] [DEFERRED]** Implement review action processing (`lms/djangoapps/proctoring_mereka/review_actions.py`) | AC: #31, #32 | Depends: Review dashboard
  - Verify action: transition to 'verified', trigger grade release
  - Reject action: require reason (min 20 chars), transitionto 'rejected', set grade to 0, notify student
  - Escalate action: assign to senior reviewer, move to escalation queue
  - Request More Info: add notes, return to queue
  - Irreversible commits (except proctoring_admin override)
  - Full audit log of all actions

- [ ] **[M] [DEFERRED]** Implement two-tier review system (`lms/djangoapps/proctoring_mereka/escalation.py`) | AC: #31 | Depends: Review actions
  - Initial review queue (junior reviewers)
  - Escalation queue (senior reviewers)
  - Escalation rules (AI ambiguous cases, contested rejections)
  - Reviewer assignment logic

- [ ] **[M] [DEFERRED]** Implement SLA tracking and alerts (`lms/djangoapps/proctoring_mereka/sla.py`) | AC: #32 | Depends: Review dashboard
  - Track time in review queue
  - Highlight attempts exceeding enterprise SLA (default 24h)
  - Email notifications to reviewers
  - Escalation to enterprise admin if SLA breached

### Integration with Open edX Course Authoring

- [ ] **[M] [DEFERRED]** Implement proctoring settings summary view in Studio (`cms/djangoapps/contentstore/views/proctoring_summary.py`) | AC: Implicit | Depends: Studio UI
  - List all proctored exams in course
  - Show configuration: backend, time limit, review policy
  - Quick-edit links

- [ ] **[M] [DEFERRED]** Implement pre-publish validation (`cms/djangoapps/contentstore/views/publish.py`) | AC: Implicit| Depends: Exam validation
  - Check proctoring backend credentials are active
  - Warn if proctored exams configured but backend disabled
  - Prevent publish if critical validation fails

### Grading and Result Integration

- [ ] **[L] [DEFERRED]** Implement proctoring-aware grading pipeline (`lms/djangoapps/grades/grading_with_proctoring.py`)| AC: #33, #34, #35, #36 | Depends: State machine, review actions
  - Hold grades in 'pending' state while proctoring review inprogress
  - Release grade when attempt reaches 'verified'
  - Set grade to 0 when attempt reaches 'rejected'
  - Update gradebook entry with proctoring_status field
  - Trigger enterprise integrated channels sync on grade change
  - Support instructor override of 'rejected' status

- [ ] **[M] [DEFERRED]** Implement instructor override system(`lms/djangoapps/instructor/proctoring_overrides.py`) | AC:#35 | Depends: Grading pipeline
  - Instructor dashboard UI for proctoring overrides
  - Override 'rejected' to 'verified' with reason
  - Restore original grade
  - Full audit log of overrides

- [ ] **[M] [DEFERRED]** Implement enterprise integrated channels proctoring sync (`enterprise/djangoapps/integrated_channels/proctoring_sync.py`) | AC: #36 | Depends: Grading pipeline
  - Include proctoring_status in grade passback
  - Sync on grade updates (verified, rejected, overridden)
  - Per-provider sync schedules

### Multi-Tenant Proctoring Configuration

- [ ] **[L] [DEFERRED]** Implement EnterpriseProctoringConfigmodel and admin (`enterprise/djangoapps/enterprise/models.py`, `enterprise/admin.py`) | AC: #37, #38 | Depends: Backend architecture
  - Model fields: enterprise_customer_uuid, enabled_providers, default_provider, provider_credentials (encrypted), review_sla_hours, identity_verification_required, recording_retention_days, allow_practice_exams, allow_onboarding_exams, default_monitoring_settings, accommodation_policy
  - Django admin interface for platform operators
  - Credential encryption at rest (AES-256)

- [ ] **[L] [DEFERRED]** Implement enterprise admin portal proctoring configuration page (`enterprise/djangoapps/enterprise_admin/proctoring_config.py`, UI) | AC: #38 | Depends: EnterpriseProctoringConfig
  - Enable/disable providers
  - Enter/update provider API credentials
  - Test connection button (validate credentials)
  - Set default monitoring levels (Proctorio/ProctorTrack)
  - Configure review SLA
  - View proctoring usage statistics (exams administered, pass/fail rates, avg review time)

- [ ] **[M] [DEFERRED]** Implement provider credential management (`lms/djangoapps/proctoring_mereka/credentials.py`) | AC: #38 | Depends: EnterpriseProctoringConfig
  - Secrets integration (Infisical or K8s secrets)
  - Per-enterprise-customer credential isolation
  - Credential rotation support
  - Never log credentials

### Compliance and Data Privacy

- [ ] **[M] [DEFERRED]** Implement proctoring consent flow (`lms/djangoapps/proctoring_mereka/consent.py`) | AC: #39, #40| Depends: Backend architecture
  - Consent notice text (what data collected, who accesses, retention, right to refuse, contact info)
  - Display before identity verification
  - Explicit "I Agree" button
  - Record consent: user_id, exam_id, enterprise_customer_uuid, consent_version, timestamp, ip_address_hash
  - Block exam if consent not accepted

- [ ] **[M] [DEFERRED]** Build consent UI (`lms/templates/proctoring/consent.html`, JS) | AC: #39 | Depends: Consent flow
  - Clear, readable consent notice
  - Enterprise-specific customization
  - Checkbox + confirmation button
  - "I do not consent" option with explanation of consequences

- [ ] **[L] [DEFERRED]** Implement GDPR DSAR handler (`lms/djangoapps/proctoring_mereka/gdpr.py`) | AC: #41 | Depends: Allproctoring data models
  - Export all proctoring session metadata for user
  - Coordinate with provider APIs to access recordings
  - Generate data package within 30 days
  - Support GDPR right to erasure: delete metadata, send deletion request to provider

- [ ] **[M] [DEFERRED]** Implement data retention enforcement(`lms/djangoapps/proctoring_mereka/retention.py`) | AC: #42| Depends: Recording session management
  - Per-enterprise-customer retention_days configuration
  - Communicate retention to provider at session creation
  - Audit log of data access events
  - Data processing agreement (DPA) verification flag in provider config

- [ ] **[M] [DEFERRED]** Implement cross-border data transfercompliance (`lms/djangoapps/proctoring_mereka/data_sovereignty.py`) | AC: #42 | Depends: Provider backends
  - Provider infrastructure location metadata
  - Consent notice disclosure of cross-border transfer
  - Verify Standard Contractual Clauses or adequacy decision
  - Block session if DPA requirements not met

---

## Test Tasks (DEFERRED)

- [ ] **[L] [DEFERRED]** Write unit tests for provider registry (`tests/unit/proctoring/test_registry.py`) | AC: #1, #5 |Depends: Registry implementation
  - Provider registration and lookup
  - No-op backend returns correct interface
  - Multi-provider concurrent usage

- [ ] **[L] [DEFERRED]** Write integration tests for Proctorio backend (`tests/integration/proctoring/test_proctorio_backend.py`) | AC: #1 | Depends: Proctorio backend
  - Mock Proctorio API
  - register_exam_attempt, start_exam_attempt, stop_exam_attempt
  - Webhook callback processing
  - Extension detection

- [ ] **[L] [DEFERRED]** Write integration tests for Examitybackend (`tests/integration/proctoring/test_examity_backend.py`) | AC: #2 | Depends: Examity backend
  - Mock Examity API
  - Appointment scheduling flow
  - Live proctor communication
  - Session pause/terminate

- [ ] **[M] [DEFERRED]** Write unit tests for exam window enforcement (`tests/unit/proctoring/test_exam_windows.py`) | AC:#10, #11 | Depends: Exam window enforcement
  - Before start_date: blocked
  - After due_date: blocked
  - Per-student time extensions

- [ ] **[L] [DEFERRED]** Write integration tests for identityverification flow (`tests/integration/proctoring/test_identity_verification.py`) | AC: #13, #14, #15, #16 | Depends: Identity verification
  - Photo ID capture and send to provider
  - Verification result processing (passed/failed/pending)
  - Re-verification logic (max 3 attempts)
  - Onboarding baseline flow

- [ ] **[L] [DEFERRED]** Write integration tests for environment check (`tests/integration/proctoring/test_environment_check.py`) | AC: #17, #18 | Depends: Environment check
  - All checks pass: proceed to exam
  - Webcam fails: actionable error
  - Network bandwidth fails: actionable error

- [ ] **[M] [DEFERRED]** Write unit tests for state machine (`tests/unit/proctoring/test_state_machine.py`) | AC: #25, #26, #27, #28 | Depends: State machine
  - Valid state transitions succeed
  - Invalid state transitions rejected
  - Auto-expiry logic (timed_out)
  - Error state handling

- [ ] **[L] [DEFERRED]** Write integration tests for proctorreview workflow (`tests/integration/proctoring/test_review_workflow.py`) | AC: #29, #30, #31, #32 | Depends: Review dashboard, review actions
  - Review queue displays correct attempts
  - Multi-tenant isolation (reviewer sees only their enterprise)
  - Verify action: transition to verified, grade released
  - Reject action: transition to rejected, grade set to 0, student notified
  - Escalate action: move to escalation queue
  - SLA tracking and highlighting

- [ ] **[L] [DEFERRED]** Write integration tests for gradingpipeline (`tests/integration/proctoring/test_grading_pipeline.py`) | AC: #33, #34, #35, #36 | Depends: Grading pipeline
  - Grade held while in submitted state
  - Grade released when verified
  - Grade set to 0 when rejected
  - Instructor override restores grade
  - Enterprise integrated channels sync triggered

- [ ] **[L] [DEFERRED]** Write integration tests for multi-tenant isolation (`tests/integration/proctoring/test_multitenancy.py`) | AC: #37, #38 | Depends: EnterpriseProctoringConfig,review dashboard
  - Enterprise A admin cannot see enterprise B proctoring data
  - Webhook for enterprise A routed to enterprise A context only
  - Provider credentials isolated per enterprise

- [ ] **[M] [DEFERRED]** Write integration tests for consentflow (`tests/integration/proctoring/test_consent.py`) | AC: #39, #40 | Depends: Consent flow
  - Consent accepted: proceed to identity verification
  - Consent not accepted: exam blocked
  - Consent record stored with all required fields

- [ ] **[L] [DEFERRED]** Write integration tests for GDPR compliance (`tests/integration/proctoring/test_gdpr.py`) | AC: #| Depends: GDPR handler
  - DSAR: all proctoring data exported
  - Right to erasure: metadata deleted, provider notified

- [ ] **[L] [DEFERRED]** Write E2E test for full proctored exam flow (`tests/e2e/proctoring/test_proctored_exam_flow.py`)| AC: Multiple | Depends: All build tasks
  - Student starts exam → environment check → identity verification → exam session → submission → AI analysis → review → grade release
  - Use no-op backend or Stripe test mode equivalent
  - Verify all state transitions

- [ ] **[M] [DEFERRED]** Write load tests for concurrent sessions (`tests/load/proctoring/test_concurrent_sessions.py`) |NFR: Performance | Depends: All build tasks
  - Simulate 500 concurrent proctored sessions
  - Verify p95 latency targets maintained
  - No degradation vs 50 concurrent sessions

- [ ] **[M] [DEFERRED]** Write security tests for webhook signature validation (`tests/security/proctoring/test_webhook_security.py`) | NFR: Security | Depends: Provider backends
  - Invalid signature: rejected (HTTP 400)
  - Missing signature: rejected
  - Forged signature: rejected
  - Replay attack: idempotency prevents duplicate processing

- [ ] **[M] [DEFERRED]** Write security tests for review dashboard access control (`tests/security/proctoring/test_review_dashboard_security.py`) | NFR: Security | Depends: Review dashboard
  - Non-reviewer role: access denied
  - Reviewer for enterprise A: cannot access enterprise B data
  - JWT manipulation attempts: rejected

---

## Observability Tasks (DEFERRED)

- [ ] **[M] [DEFERRED]** Implement structured logging for proctoring events (`lms/djangoapps/proctoring_mereka/logging.py`) | Observability | Depends: All build tasks
  - Log all state transitions with full context
  - Log provider API calls (no credentials, no PII)
  - Log webhook processing
  - Log identity verification events (no photo ID data)
  - Log review actions (reason length, not reason text)
  - Log consent events
  - PII rules: hash emails, never log photo ID data, never log facial recognition scores

- [ ] **[M] [DEFERRED]** Implement Prometheus metrics for proctoring (`lms/djangoapps/proctoring_mereka/metrics.py`) | Observability | Depends: All build tasks
  - Metrics: `proctoring_exam_attempts_total`, `proctoring_active_sessions`, `proctoring_state_transition_duration_seconds`, `proctoring_identity_verification_total`, `proctoring_identity_verification_duration_seconds`, `proctoring_environment_check_total`, `proctoring_environment_check_duration_seconds`, `proctoring_provider_api_requests_total`, `proctoring_provider_api_latency_seconds`, `proctoring_webhook_received_total`, `proctoring_webhook_processing_duration_seconds`, `proctoring_review_queue_size`, `proctoring_review_queue_age_seconds`,`proctoring_review_actions_total`, `proctoring_review_duration_seconds`, `proctoring_grade_release_duration_seconds`, `proctoring_ai_integrity_score`, `proctoring_false_positive_rate`, `proctoring_consent_events_total`
  - Expose via existing LMS /metrics/ endpoint

- [ ] **[L] [DEFERRED]** Create Grafana dashboards for proctoring (`infrastructure/monitoring/grafana/dashboards/proctoring.json`) | Observability | Depends: Metrics
  - Proctoring Overview: active sessions, daily attempts, verification pass/fail rate, review queue size, consent acceptance rate
  - Provider Health: per-provider API latency, error rate, webhook processing, active sessions
  - Exam Integrity: AI integrity score distribution, false positive rate, rejection rate, flagged event types
  - Review Operations: review queue size over time, avg review duration, SLA compliance, reviewer throughput
  - Identity Verification: verification success/failure rate,duration percentiles, re-verification rate
  - Compliance: consent acceptance/decline rate, DSAR count/response time, data deletion requests

- [ ] **[M] [DEFERRED]** Create Prometheus alert rules for proctoring (`deploy/k8s/base/monitoring/prometheusrule-proctoring.yaml`) | Observability | Depends: Metrics
  - Critical: `proctoring_active_sessions > 500` (approachingcapacity)
  - Critical: Provider API 5xx rate > 10% over 5 min (page oncall)
  - Critical: Webhook processing failure rate > 5% over 15 min (page oncall)
  - Warning: Review queue age exceeds SLA (notify channel + enterprise admin)
  - Warning: Identity verification failure rate > 20% over 1hour (notify channel)
  - Warning: False positive rate > 15% over 7 days (notify channel)
  - Warning: Environment check failure rate > 30% for any component over 1 hour (notify channel)
  - Warning: Provider API latency p95 > 10s (notify channel)
  - Info: Consent decline rate > 10% over 24h (notify enterprise admin)
  - Info: Exam error rate > 5% over 24h (notify channel)

---

## Documentation Tasks (DEFERRED)

- [ ] **[M] [DEFERRED]** Write proctoring architecture overview (`docs/concepts/architecture/proctoring-architecture-overview.md`)| Depends: All build tasks
  - System diagram
  - Provider integration architecture
  - Data flows: exam setup → environment check → identity verification → exam session → recording → AI analysis → proctorreview → grading
  - Multi-tenant isolation model
  - Security architecture

- [ ] **[L] [DEFERRED]** Write proctoring operations runbook(`docs/runbooks/proctoring-operations-runbook.md`) | Depends:All build + observability tasks
  - Operational procedures: deploy, rollback, scaling
  - Provider outage incident playbook
  - Review queue backlog incident playbook
  - False positive spike incident playbook
  - Consent decline spike incident playbook
  - GDPR DSAR response procedure
  - Oncall handbook

- [ ] **[M] [DEFERRED]** Write provider setup guides (`docs/operations/proctoring-provider-setup/`) | Depends: Provider backends
  - Proctorio setup: API credentials, extension installation,monitoring configuration
  - Examity setup: API credentials, appointment scheduling, live proctor configuration
  - ProctorTrack setup: API credentials, AI scoring configuration
  - Respondus setup: Server API credentials, LockDown Browserdeployment
  - Webhook endpoint configuration for each provider

- [ ] **[M] [DEFERRED]** Write student-facing proctoring guide (`docs/user-guides/taking-proctored-exams.md`) | Depends: All build tasks
  - What is proctoring
  - System requirements (camera, microphone, bandwidth)
  - Environment check instructions
  - Identity verification instructions
  - Browser lockdown software installation
  - Exam day checklist
  - Troubleshooting common issues
  - Privacy and data handling FAQs

- [ ] **[M] [DEFERRED]** Write proctor reviewer training guide (`docs/user-guides/proctor-reviewer-guide.md`) | Depends: Review dashboard
  - Reviewer role and responsibilities
  - Review dashboard walkthrough
  - How to review flagged sessions
  - Common flagged events and how to interpret them
  - When to verify vs reject vs escalate
  - False positive identification
  - Writing rejection reasons
  - SLA expectations

- [ ] **[S] [DEFERRED]** Write enterprise admin proctoring configuration guide (`docs/user-guides/enterprise-proctoring-configuration.md`) | Depends: Enterprise admin portal
  - Enable/disable providers
  - Enter provider credentials
  - Test connection
  - Set monitoring levels
  - Configure review SLA
  - View usage statistics

- [ ] **[S] [DEFERRED]** Update main troubleshooting doc (`docs/ops/runbooks/TROUBLESHOOTING.md`) | Depends: All build tasks
  - Add proctoring diagnostic commands
  - Common proctoring issues and fixes
  - Provider API troubleshooting

---

## Rollout Tasks (DEFERRED)

### Phase 0: Infrastructure and Backend Preparation (DEFERRED)

- [ ] **[M] [DEFERRED]** Provision proctoring secrets in Infisical (`scripts/infra/provision-proctoring-secrets.sh`) | Depends: None
  - `MEREKA_LMS_PROCTORING_EXAMITY_API_KEY`
  - `MEREKA_LMS_PROCTORING_EXAMITY_API_SECRET`
  - `MEREKA_LMS_PROCTORING_EXAMITY_ORGANIZATION_ID`
  - `MEREKA_LMS_PROCTORING_PROCTORIO_API_KEY`
  - `MEREKA_LMS_PROCTORING_PROCTORIO_API_SECRET`
  - `MEREKA_LMS_PROCTORING_PROCTORTRACK_API_KEY`
  - `MEREKA_LMS_PROCTORING_PROCTORTRACK_API_SECRET`
  - `MEREKA_LMS_PROCTORING_RESPONDUS_API_KEY`
  - `MEREKA_LMS_PROCTORING_RESPONDUS_API_SECRET`
  - `MEREKA_LMS_PROCTORING_WEBHOOK_SECRET` (HMAC key for validating webhooks)
  - Sync to GCP Secret Manager

- [ ] **[M] [DEFERRED]** Create ExternalSecret manifest for proctoring (`deploy/k8s/base/secrets/proctoring-secrets.yaml`)| Depends: Infisical secrets
  - Map secrets from GCP SM to K8s Secret `proctoring-secrets`
  - Refresh interval: 1h

- [ ] **[M] [DEFERRED]** Install proctoring provider packagesas Tutor plugins (`infrastructure/tutor/plugins/proctoring/`) | Depends: Provider backend implementations
  - Package each provider backend as Tutor plugin
  - Plugin configuration files
  - Plugin dependency management
  - Rebuild LMS image with plugins

- [ ] **[M] [DEFERRED]** Run database migrations for proctoring schema (`infrastructure/tutor/migrations/proctoring/`) | Depends: Schema design
  - Create all proctoring tables
  - Create indexes
  - Run as init container in K8s deployment

- [ ] **[M] [DEFERRED]** Configure webhook endpoints in provider dashboards (`docs/operations/proctoring-webhook-configuration.md`) | Depends: LMS webhook handler
  - Proctorio webhook: `https://academyv2.mereka.io/proctoring/webhooks/proctorio/`
  - Examity webhook: `https://academyv2.mereka.io/proctoring/webhooks/examity/`
  - ProctorTrack webhook: `https://academyv2.mereka.io/proctoring/webhooks/proctortrack/`
  - Configure webhook signing secrets
  - Test delivery with provider testing tools

- [ ] **[M] [DEFERRED]** Deploy with no-op backend for testing (`scripts/deploy/deploy-proctoring-noop.sh`) | Depends: Allinfrastructure
  - Set `ENABLE_PROCTORING=true`, all provider feature flags=false
  - Set default backend to no-op
  - Verify LMS starts without errors
  - Test full exam flow with no-op backend
  - Monitor logs and metrics for 48 hours

### Phase 1: Single Provider Pilot - AI Proctoring (DEFERRED)

- [ ] **[M] [DEFERRED]** Enable Proctorio backend for pilot enterprise customer (`scripts/deploy/enable-proctorio-pilot.sh`) | Depends: Phase 0
  - Set `ENABLE_PROCTORING_PROCTORIO=true`
  - Configure pilot enterprise customer's EnterpriseProctoringConfig with Proctorio credentials
  - Test credential validation (test connection)

- [ ] **[M] [DEFERRED]** Create 2-3 practice proctored examsin test course (`scripts/qa/create-practice-proctored-exams.sh`) | Depends: Proctorio enabled
  - Configure as practice_proctored exams
  - Set monitoring levels (video, screen, lockdown)
  - Set review policy

- [ ] **[L] [DEFERRED]** Internal testing (20+ practice examsessions) (`docs/qa/proctoring-pilot-testing-plan.md`) | Depends: Practice exams created
  - Environment check flow
  - Proctorio extension detection and installation
  - Exam session lifecycle (start, submit, review)
  - Webhook callback processing
  - Review dashboard functionality
  - Collect feedback on UX friction
  - Measure: environment check pass rate, exam completion rate
  - Fix issues identified

- [ ] **[M] [DEFERRED]** Open practice exams to pilot clientstudents (10-20 students) (`scripts/qa/open-pilot-practice-exams.sh`) | Depends: Internal testing complete
  - Notify pilot students
  - Monitor exam sessions in real-time
  - Collect student feedback
  - Measure false positive rate (AI-flagged sessions verifiedby human review)

### Phase 2: First Graded Proctored Exam (DEFERRED)

- [ ] **[M] [DEFERRED]** Configure first graded proctored exam (`scripts/qa/create-graded-proctored-exam.sh`) | Depends: Phase 1 complete
  - Use same pilot enterprise customer
  - Enable identity verification
  - Set as graded exam (not practice)
  - Configure review workflow

- [ ] **[L] [DEFERRED]** Run first graded exam (20-50 students) (`docs/qa/first-graded-exam-plan.md`) | Depends: Graded exam configured
  - Monitor all observability channels during exam window
  - Real-time oncall coverage during exam
  - Complete proctor review for all submitted attempts withinSLA
  - Verify grading integration: grades appear in gradebook after review
  - Conduct post-exam retrospective
  - Adjust monitoring settings based on false positive rate

### Phase 3: Second Provider - Live Proctoring (DEFERRED)

- [ ] **[M] [DEFERRED]** Enable Examity backend for second enterprise customer (`scripts/deploy/enable-examity.sh`) | Depends: Phase 2 complete
  - Set `ENABLE_PROCTORING_EXAMITY=true`
  - Configure second enterprise customer's EnterpriseProctoringConfig with Examity credentials
  - Configure appointment-based scheduling integration

- [ ] **[M] [DEFERRED]** Internal testing (10+ live proctoredsessions) (`docs/qa/examity-testing-plan.md`) | Depends: Examity enabled
  - Appointment booking flow
  - Live proctor communication
  - Proctor-initiated pause/termination
  - Validate human review workflow

- [ ] **[L] [DEFERRED]** Pilot with second enterprise customer (`scripts/qa/examity-pilot.sh`) | Depends: Internal testing
  - Run first graded live-proctored exam
  - Compare operational costs vs AI proctoring
  - Compare student experience vs AI proctoring
  - Measure: student satisfaction, completion rate, technicalissues

### Phase 4: Additional Providers and Scale (DEFERRED)

- [ ] **[M] [DEFERRED]** Enable ProctorTrack and Respondus backends (`scripts/deploy/enable-additional-providers.sh`) | Depends: Phase 3 complete
  - Set `ENABLE_PROCTORING_PROCTORTRACK=true`
  - Set `ENABLE_PROCTORING_RESPONDUS=true`
  - Configure credentials for additional enterprise customers

- [ ] **[L] [DEFERRED]** Load testing (500 concurrent sessions) (`tests/load/proctoring/test_500_concurrent.py`) | Depends: All providers enabled
  - Simulate 500 concurrent proctored exam sessions
  - Verify p95 latency targets maintained
  - Verify no provider API rate limits hit
  - Measure: API latency, webhook processing latency, database load, GKE pod scaling

- [ ] **[L] [DEFERRED]** Security review (`docs/security/proctoring-security-audit.md`) | Depends: All providers enabled
  - Penetration test on webhook endpoints
  - Review dashboard access control audit
  - Tenant isolation verification (cross-tenant data leak tests)
  - Secrets exposure audit
  - OWASP Top 10 compliance check
  - Fix all Critical/High findings

- [ ] **[M] [DEFERRED]** Compliance review (`docs/compliance/proctoring-compliance-audit.md`) | Depends: All providers enabled
  - GDPR documentation complete and auditable
  - FERPA documentation complete and auditable
  - Verify DPAs signed with all active providers
  - Data retention policies documented and enforced
  - Consent flow audit (clear disclosure, explicit acceptance)

- [ ] **[M] [DEFERRED]** Enable self-service proctoring configuration in enterprise admin portal (`scripts/deploy/enable-enterprise-proctoring-config.sh`) | Depends: Security/compliance reviews complete
  - Set `ENABLE_PROCTORING_ENTERPRISE_ADMIN_CONFIG=true`
  - Enterprise admins can configure proctoring without platform engineering
  - Monitor usage and support requests

- [ ] **[M] [DEFERRED]** Onboard third and fourth enterprisecustomers (`scripts/deploy/onboard-enterprise-proctoring.sh`)| Depends: Self-service config enabled
  - Provide self-service configuration guide
  - Support during initial setup
  - Monitor first exams for each customer

### Phase 5: Production Hardening (DEFERRED)

- [ ] **[M] [DEFERRED]** Enable all alerts and dashboards (`scripts/deploy/enable-proctoring-monitoring.sh`) | Depends: Phase 4 complete
  - All Prometheus alerts active
  - All Grafana dashboards published
  - Oncall integration tested (PagerDuty/Opsgenie)

- [ ] **[M] [DEFERRED]** Tabletop exercise: provider outage during high-stakes exam (`docs/qa/tabletop-provider-outage.md`) | Depends: Monitoring enabled
  - Simulate provider API down for 30 minutes during active exam window
  - Execute runbook procedures
  - Verify student experience (error handling, resume capability)
  - Verify alert escalation
  - Refine runbook based on learnings

- [ ] **[M] [DEFERRED]** Tabletop exercise: GDPR deletion request with pending review (`docs/qa/tabletop-gdpr-deletion.md`) | Depends: Monitoring enabled
  - Simulate GDPR deletion request for student with proctoredexam in review queue
  - Execute runbook procedures
  - Verify metadata deleted, provider notified, attempt rejected
  - Refine runbook based on learnings

- [ ] **[M] [DEFERRED]** Establish review SLA monitoring andreviewer staffing (`docs/operations/reviewer-staffing-model.md`) | Depends: Monitoring enabled
  - Define reviewer staffing levels per enterprise customer
  - Set up SLA monitoring alerts
  - Establish escalation procedures for SLA breaches
  - Train reviewers on runbook and procedures

- [ ] **[M] [DEFERRED]** Collect 1000+ session data for falsepositive rate validation (`scripts/analytics/measure-false-positive-rate.py`) | Depends: Phase 4 complete
  - Query proctoring_ai_integrity_score and proctoring_review_actions_total metrics
  - Calculate: (AI-flagged sessions verified by human review)/ (total AI-flagged sessions)
  - Verify false positive rate < 10% target
  - If above 10%, adjust AI threshold or escalate to provider

### Feature Flags (DEFERRED)

- [ ] **[S] [DEFERRED]** Configure proctoring feature flags (`infrastructure/tutor/proctoring-feature-flags.yml`) | Depends: None
  - `ENABLE_PROCTORING` -- global gate (default: off)
  - `ENABLE_PROCTORING_PROCTORIO` -- Proctorio backend (default: off)
  - `ENABLE_PROCTORING_EXAMITY` -- Examity backend (default:off)
  - `ENABLE_PROCTORING_PROCTORTRACK` -- ProctorTrack backend(default: off)
  - `ENABLE_PROCTORING_RESPONDUS` -- Respondus backend (default: off)
  - `ENABLE_PROCTORING_IDENTITY_VERIFICATION` -- identity verification requirement (default: on when proctoring enabled)
  - `ENABLE_PROCTORING_REVIEW_DASHBOARD` -- review dashboardaccess (default: off)
  - `ENABLE_PROCTORING_ENTERPRISE_ADMIN_CONFIG` -- self-service config (default: off)
  - `ENABLE_PROCTORING_APPOINTMENT_SCHEDULING` -- appointment-based scheduling (default: off)
  - All flags configurable per enterprise_customer_uuid
  - Flags take effect without service restart (Django Waffleor Open edX Feature Flags)

### Backward Compatibility (DEFERRED)

- [ ] **[S] [DEFERRED]** Verify no impact on existing unproctored exams (`tests/regression/test_unproctored_exams.py`) | Depends: Proctoring enabled
  - Students not in proctored courses see no changes
  - Existing assessments work normally
  - Grading pipeline unaffected for non-proctored content

- [ ] **[S] [DEFERRED]** Verify course import/export compatibility (`tests/regression/test_course_import_export.py`) | Depends: Studio UI changes
  - Courses without proctoring settings import correctly
  - Courses with proctoring settings export and re-import correctly

### Rollback Steps (DEFERRED)

#### Per-Provider Rollback

- [ ] **[S] [DEFERRED]** Document per-provider rollback procedure (`docs/runbooks/proctoring-rollback.md`) | Depends: None
  - Disable provider feature flag (e.g., `ENABLE_PROCTORING_PROCTORIO=false`)
  - Exams in progress continue (provider session independent)
  - New exam starts blocked
  - Inform enterprise admin, suggest alternative provider
  - Investigate using logs/dashboards
  - Re-enable when resolved

#### Full Proctoring Rollback

- [ ] **[S] [DEFERRED]** Document full proctoring rollback procedure (`docs/runbooks/proctoring-rollback.md`) | Depends: None
  - Set `ENABLE_PROCTORING=false` globally
  - All proctored exam starts blocked
  - Exams in progress not interrupted
  - Submitted attempts continue through review pipeline
  - Students see standard exam behavior
  - Inform all enterprise admins
  - Re-enable when resolved

#### Review Dashboard Rollback

- [ ] **[S] [DEFERRED]** Document review dashboard rollback procedure (`docs/runbooks/proctoring-rollback.md`) | Depends:None
  - Set `ENABLE_PROCTORING_REVIEW_DASHBOARD=false`
  - Review actions via Django admin as fallback
  - Webhooks continue to update statuses
  - Re-enable when dashboard issues resolved

---

## Summary

**Total Tasks**: 137

**By Complexity**:
- Small (S): 9 tasks
- Medium (M): 71 tasks
- Large (L): 57 tasks

**By Category**:
- Build: 66 tasks
- Test: 21 tasks
- Observability: 4 tasks
- Documentation: 8 tasks
- Rollout: 38 tasks

**Status**: ALL TASKS DEFERRED UNTIL 2027

**Critical Path** (when implementation begins):
1. Infrastructure prep (verify deps, schema, secrets) →
2. Backend architecture (registry, providers) →
3. Studio UI (exam setup) →
4. Student flows (environment check, identity verification, exam session) →
5. Review workflow →
6. Grading integration →
7. Multi-tenant config →
8. Compliance (consent, GDPR) →
9. Testing →
10. Phase 0 deployment (no-op) →
11. Phase 1 (Proctorio pilot) →
12. Phase 2 (first graded exam) →
13. Phase 3 (Examity) →
14. Phase 4 (additional providers, load testing, security) →
15. Phase 5 (production hardening)

**Estimated Timeline**: 22+ weeks (per spec Rollout Plan)

**Dependencies External to This Spec**:
- Enterprise client contracts with proctoring providers (Examity, Proctorio, etc.)
- Provider API credentials supplied by enterprise customers
- Legal review of data processing agreements with providers
- Budget approval for provider contracts
- Reviewer staffing model decision (Mereka staff vs enterprise staff vs provider staff)
- Mobile proctoring decision (out of scope or defer to mobileSDK)
- Resolution of all 16 Open Questions in spec

---

## Verification Checklist (For Future Implementation)

Before marking any phase complete:
- [ ] All acceptance criteria for that phase are covered by tests
- [ ] Testmap YAML is updated with new test files
- [ ] Metrics are being collected and dashboards are displaying data
- [ ] Alerts have been tested (fire and resolve)
- [ ] Runbook has been validated by oncall team
- [ ] Rollback procedure has been rehearsed
- [ ] Load testing completed with no degradation
- [ ] Security review completed with no Critical findings
- [ ] Compliance review completed (GDPR, FERPA documentation)
- [ ] All secrets in Infisical/GCP SM, none hardcoded
- [ ] Provider contracts and DPAs signed
- [ ] False positive rate measured and < 10%
- [ ] Student-facing documentation published
- [ ] Proctor reviewer training completed

---

## Open Questions to Resolve Before Implementation

1. **Provider selection priority**: Which providers to integrate first?
2. **Provider pricing model impact**: How do provider costs affect enterprise billing?
3. **edx-proctoring version compatibility**: Confirm exact version in Ulmo and plugin interface compatibility
4. **Recording storage jurisdiction**: Provider storage locations for data residency compliance
5. **AI proctoring accuracy benchmarks**: Published false positive/negative rates from providers
6. **Human reviewer staffing**: Who performs proctor reviews?(Mereka/enterprise/provider staff)
7. **Mobile proctoring support**: Block mobile or support providers with mobile SDKs?
8. **Accessibility compliance**: How do lockdown solutions interact with accessibility tools?
9. **Exam scheduling complexity**: Appointment-based scheduling in initial implementation or defer?
10. **Multi-provider per enterprise**: Real requirement or simplify to one provider per customer?
11. **SLA enforcement**: Programmatic escalation or just tracking?
12. **Enterprise integrated channels**: Include proctoring results in data syncs?
13. **Proctoring for re-takes**: Can students retake rejectedexams? How many times?
14. **Cost estimation**: Monthly cost at scale (500/1000/5000sessions) per provider
15. **Existing edx-proctoring plugins**: Evaluate open-sourceplugins vs build from scratch
16. **Student support model**: Who provides technical supportduring exams?

All questions must be resolved before Phase 0 begins.
