---
spec: advanced-assessment-xqueue_spec.md
tier: 5
status: draft
estimated_effort: "16-22 weeks (4 engineers)"
prerequisites:
  - multi-tenancy-architecture_spec.md (Tier 4.1)
  - auth-sso-enterprise_spec.md (Tier 4.2)
  - enterprise-microservices_spec.md (Tier 4.3)
  - observability-stack_spec.md (Tier 2)
  - k8s-deployment_spec.md (Tier 1)
  - secrets-management_spec.md (Tier 0)
last_updated: "2026-02-10"
---

# Implementation Plan: Advanced Assessment & XQueue Integration (Non-Proctored)

**Source Spec**: `specs/advanced-assessment-xqueue_spec.md`
**Tier**: 5 -- Enterprise Features (parallelizable after Tier 4)
**Monorepo Location**: Custom grader code in `services/xqueue-graders/`; XQueue service uses upstream image.

---

## Summary

This plan breaks down the Advanced Assessment & XQueue spec into independently implementable and testable tasks across six phases matching the spec's rollout plan. The work covers:

1. ORA2 configuration and operationalization (already deployed, needs config + testing)
2. Timed exam configuration (native Open edX feature, needs verification + hardening)
3. XQueue external grader deployment (new containerized graders polling existing XQueue service)
4. Advanced XBlock enablement (verify/install existing open-source packages)
5. Bulk operations and analytics (Celery tasks, dashboards)
6. Enterprise rollout (pilot, training, monitoring)

The XQueue service and ORA2 framework are already deployed. The primary new code is the containerized grader workers in `services/xqueue-graders/`.

---

## Prerequisites (Tier 4 Complete)

Before starting this spec, the following must be substantially complete:

| Prerequisite | Why |
|--------------|-----|
| `multi-tenancy-architecture_spec.md` | EnterpriseCustomer model, tenant isolation for assessment data |
| `auth-sso-enterprise_spec.md` | Per-tenant IdP for staff/instructor roles |
| `enterprise-microservices_spec.md` | Enterprise API layer consumed by bulk operations |
| `observability-stack_spec.md` | Prometheus, Loki, Tempo for assessment metrics/logs |
| `k8s-deployment_spec.md` | GKE cluster, namespace, networking for grader pods |
| `secrets-management_spec.md` | ExternalSecrets for XQueue/grader credentials |

---

## Task Breakdown

### Phase 0: Audit and Baseline (Week 1-2)

#### Build

- [ ] **[M] P0-1.** Audit ORA2 configuration in production.py: verify `ORA2_FILEUPLOAD_BACKEND`, `ORA2_FILEUPLOAD_ROOT=/openedx/data/ora2`, `ORA2_FILEUPLOAD_CACHE_NAME=ora2-storage` settings in LMS and CMS (`infrastructure/tutor/apply-patches.sh`, `tutor_env/config.yml`) | AC: #1, #3, #4 | Depends: None

- [ ] **[M] P0-2.** Audit XQueue K8s deployment: verify xqueue service at port 8000, MySQL database `xqueue` accessible, ExternalSecrets for `XQUEUE_SECRET_KEY` and `XQUEUE_LMS_PASSWORD` are syncing (`deploy/k8s/base/secrets/external-secrets.yaml`, `deploy/k8s/base/apps/`) | AC: #16 | Depends: None

- [ ] **[S] P0-3.** Verify ORA Grading MFE accessibility at `apps.academyv2.mereka.io/ora-grading` and confirm staff/instructor role gating (`infrastructure/tutor/apply-patches.sh`) | AC: #7 | Depends: None

- [ ] **[S] P0-4.** Verify `edx-proctoring` no-op backend is available for timed-only exams by checking Django settings `PROCTORING_BACKENDS` configuration (`infrastructure/tutor/apply-patches.sh`) | AC: #10 | Depends: None

- [ ] **[S] P0-5.** Document CodeJail status: confirm `nonexistingpythonbinary` configuration, document path to enable AppArmor-secured sandbox (`docs/architecture/codejail-status.md`) | AC: N/A (open question #1) | Depends: None

- [ ] **[M] P0-6.** Create test course in Studio with basic ORA2 assignments, timed exam subsections, and standard problem types for baseline smoke testing (`scripts/qa/setup-assessment-test-course.sh`) | AC: #1, #10, #21 | Depends: P0-1, P0-4

- [ ] **[M] P0-7.** Run baseline smoke tests: ORA2 submission, peer review cycle, timed exam start/stop, auto-graded problem submission (`scripts/qa/smoke-assessment-baseline.sh`) | AC: #1, #2, #10, #12, #21 | Depends: P0-6

#### Docs

- [ ] **[S] P0-8.** Create assessment audit report documenting current state of ORA2, XQueue, timed exams, and advanced XBlocks (`docs/architecture/assessment-audit-report.md`) | Depends: P0-1 through P0-5

---

### Phase 1: ORA2 Operationalization (Week 3-5)

#### Build

- [ ] **[L] P1-1.** Configure ORA2 file upload settings: allowed file types (`.pdf`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.doc`, `.docx`), max file size (10 MB default, 50 MB max), max files per submission (5 default, 20 max) via Tutor plugin config (`infrastructure/tutor/plugins/ora2-config.yml`, `infrastructure/tutor/apply-patches.sh`) | AC: #3, #4 | Depends: P0-1

- [ ] **[M] P1-2.** Configure ORA2 file type validation to enforce extension + MIME type check and reject executable uploads (`.exe`, `.bat`, `.sh`, `.cmd`); ensure `Content-Disposition: attachment` on all file responses (`infrastructure/tutor/apply-patches.sh`) | AC: #4 | Depends: P1-1

- [ ] **[L] P1-3.** Configure peer assessment parameters: `must_grade` (default: 5), `must_be_graded_by` (default: 3), deadlines, grace period (default: 24h); verify rubric immutability after first submission (`infrastructure/tutor/plugins/ora2-config.yml`) | AC: #1, #2, #5, #6 | Depends: P0-1

- [ ] **[M] P1-4.** Configure ORA2 peer calibration step (behind `ENABLE_ORA2_PEER_CALIBRATION` Waffle flag) and anonymous peer review (default: enabled) (`infrastructure/tutor/apply-patches.sh`) | AC: #6 | Depends: P1-3

- [ ] **[M] P1-5.** Verify ORA Grading MFE grading queue: submissions ordered by time, filtering by course/assignment/status, inline file rendering, rubric selection, draft save, final submit (`infrastructure/tutor/plugins/ora2-config.yml`) | AC: #7, #8, #9 | Depends: P0-3

- [ ] **[M] P1-6.** Verify grade propagation: staff-assessed ORA2 grades appear in gradebook within 5 minutes; configure Celery task priority if needed (`infrastructure/tutor/apply-patches.sh`) | AC: #9, #29 | Depends: P1-5

- [ ] **[S] P1-7.** Configure ORA2 email notifications for final grade events (ACE email integration) (`infrastructure/tutor/apply-patches.sh`) | AC: #38 | Depends: P1-6

- [ ] **[M] P1-8.** Configure ORA2 peer fallback: when submissions do not receive `must_be_graded_by` reviews by deadline+grace, auto-flag for staff assessment (`infrastructure/tutor/apply-patches.sh`) | AC: #2 (edge case: insufficient reviewers) | Depends: P1-3

- [ ] **[S] P1-9.** Configure ORA2 file storage capacity alert: monitor `/openedx/data/ora2` volume usage, alert at 90% (`infrastructure/monitoring/alerts/ora2-file-storage.json`) | AC: #3 (edge case: storage exhaustion) | Depends: P1-1

#### Observability

- [ ] **[M] P1-10.** Set up Prometheus metrics for ORA2: `ora2_submissions_total`, `ora2_submission_duration_seconds`, `ora2_peer_assessments_total`, `ora2_staff_assessments_total`, `ora2_staff_grading_queue_size`, `ora2_file_upload_size_bytes`, `ora2_file_storage_used_bytes` (`infrastructure/monitoring/dashboards/ora2-operations.json`, `infrastructure/monitoring/alerts/ora2-*.json`) | Req: OBS metrics | Depends: P1-1

- [ ] **[M] P1-11.** Set up structured logging for ORA2 events: `ora2_submission`, `ora2_peer_assessment`, `ora2_staff_assessment` event types with required fields (no PII) (`infrastructure/tutor/apply-patches.sh`) | Req: OBS logs | Depends: P1-1

- [ ] **[S] P1-12.** Create Grafana dashboard "ORA2 Operations": submission rate, peer grading completion, staff queue size, file storage usage, peer score distribution (`infrastructure/monitoring/dashboards/ora2-operations.json`) | Req: OBS dashboards | Depends: P1-10

#### Docs

- [ ] **[M] P1-13.** Create ORA2 assessment guidelines for course authors: rubric design patterns, peer assessment configuration, file upload best practices, grading workflow (`docs/operations/ora2-assessment-guide.md`) | Depends: P1-3

---

### Phase 2: Timed Exams (Week 4-6)

#### Build

- [ ] **[M] P2-1.** Configure timed exam subsystem: verify `exam_type=timed` with no-op proctoring backend, timer enforcement (5-480 minutes), `show_timer=true`, `hide_after_due` support (`infrastructure/tutor/apply-patches.sh`) | AC: #10 | Depends: P0-4

- [ ] **[M] P2-2.** Verify timed exam state transitions: `created -> ready_to_start -> started -> ready_to_submit -> submitted` and `started -> timed_out`; verify auto-submission on timer expiry (`infrastructure/tutor/apply-patches.sh`) | AC: #12, #13 | Depends: P2-1

- [ ] **[S] P2-3.** Verify timer warnings at 5 minutes and 1 minute remaining; verify ARIA live region for screen reader accessibility (`infrastructure/tutor/apply-patches.sh`) | AC: #11, #36 | Depends: P2-1

- [ ] **[M] P2-4.** Verify per-student time extensions via instructor dashboard; test 60+30=90 minute accommodation scenario (`infrastructure/tutor/apply-patches.sh`) | AC: #14 | Depends: P2-1

- [ ] **[S] P2-5.** Verify server-side timer enforcement: client clock manipulation must not extend time; server compares `current_time - exam_start_time` against `time_limit_minutes` on every submission (`infrastructure/tutor/apply-patches.sh`) | AC: #12 (edge case: clock skew) | Depends: P2-2

- [ ] **[M] P2-6.** Verify browser crash recovery: close browser, reopen within time limit, confirm resume with remaining time; verify server-side state persistence every 30 seconds (`infrastructure/tutor/apply-patches.sh`) | AC: #12 (edge case: browser crash) | Depends: P2-2

- [ ] **[S] P2-7.** Verify timed exam grade release: grades flow to gradebook immediately upon submission (no proctoring review hold) (`infrastructure/tutor/apply-patches.sh`) | AC: #15 | Depends: P2-2

- [ ] **[S] P2-8.** Verify re-entry prevention: after submission, student sees read-only view and cannot modify responses; instructor can reset attempts (`infrastructure/tutor/apply-patches.sh`) | AC: #13 | Depends: P2-2

- [ ] **[S] P2-9.** Verify simultaneous device access prevention: second device shows "This exam is already in progress on another device" (`infrastructure/tutor/apply-patches.sh`) | AC: #10 (edge case: multi-device) | Depends: P2-2

#### Observability

- [ ] **[M] P2-10.** Set up Prometheus metrics for timed exams: `timed_exam_attempts_total`, `timed_exam_completion_time_seconds`, `timed_exam_auto_submit_total` (`infrastructure/monitoring/alerts/timed-exam-*.json`) | Req: OBS metrics | Depends: P2-1

- [ ] **[S] P2-11.** Set up structured logging for timed exam lifecycle: `timed_exam_state_change` events with `attempt_id`, `user_id`, `exam_id`, `old_state`, `new_state`, `time_remaining_seconds` (`infrastructure/tutor/apply-patches.sh`) | Req: OBS logs | Depends: P2-1

- [ ] **[S] P2-12.** Create Grafana dashboard "Timed Exams": active exams, completion time distribution, auto-submit rate, time extension usage (`infrastructure/monitoring/dashboards/timed-exams.json`) | Req: OBS dashboards | Depends: P2-10

---

### Phase 3: XQueue Grader Deployment (Week 6-9)

#### Build

- [ ] **[L] P3-1.** Create `services/xqueue-graders/` directory structure: `graders/python_grader.py`, `graders/generic_script_grader.py`, `Dockerfile`, `requirements.txt`, `tests/`, `README.md` | AC: #16, #17, #18 | Depends: P0-2

- [ ] **[L] P3-2.** Implement Python code grader worker: polls `GET /xqueue/get_submission/`, executes student Python in sandboxed container (no network, no fs writes outside tmp, CPU limit 10s, memory limit 256MB, process limit 50), validates output, submits result via `PUT /xqueue/put_result/` (`services/xqueue-graders/graders/python_grader.py`) | AC: #16, #17, #18 | Depends: P3-1

- [ ] **[L] P3-3.** Implement sandboxed execution environment: Docker-in-Docker or gVisor-based sandbox with network isolation, filesystem restrictions, resource limits (CPU, memory, process count), configurable timeouts (`services/xqueue-graders/Dockerfile`, `services/xqueue-graders/sandbox/`) | AC: #16, #17, #18 | Depends: P3-1

- [ ] **[M] P3-4.** Implement generic script grader worker: receives student input via stdin, executes course-author-provided grading script, outputs JSON grading result (`services/xqueue-graders/graders/generic_script_grader.py`) | AC: #16 | Depends: P3-2

- [ ] **[M] P3-5.** Implement XQueue grader error handling: timeout detection (30s per submission), graceful error responses, retry logic (max 3 retries), dead-letter state for persistent failures, instructor notification (`services/xqueue-graders/graders/base_grader.py`) | AC: #19, #20 (edge cases: invalid response, worker crash, malicious code) | Depends: P3-2

- [ ] **[M] P3-6.** Implement submission deduplication: if same student submits same code within 5 seconds, process only the most recent submission (`services/xqueue-graders/graders/base_grader.py`) | AC: #16 (edge case: rapid submission) | Depends: P3-2

- [ ] **[M] P3-7.** Create K8s Deployment manifest for XQueue grader worker: 1-2 replicas, resource limits, health checks, environment variables from ExternalSecrets (`deploy/k8s/base/apps/xqueue/grader-deployment.yaml`, `deploy/k8s/base/apps/xqueue/grader-configmap.yaml`) | AC: #16 | Depends: P3-2

- [ ] **[S] P3-8.** Add XQueue grader secrets to ExternalSecrets: `XQUEUE_GRADER_USERNAME`, `XQUEUE_GRADER_PASSWORD` (if separate from LMS auth) (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: #16 | Depends: P0-2

- [ ] **[M] P3-9.** Build and push grader worker container image to Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx/xqueue-grader`) (`services/xqueue-graders/Dockerfile`, `.github/workflows/build-grader.yml`) | AC: #16 | Depends: P3-7

- [ ] **[M] P3-10.** Create XQueue-backed problem template in Studio for integration testing: Python code submission problem with expected output validation (`scripts/qa/setup-xqueue-test-problem.sh`) | AC: #16, #20 | Depends: P3-7

- [ ] **[S] P3-11.** Implement idempotent result submission: same `submission_id` + `score` submitted twice produces only one grade update (`services/xqueue-graders/graders/base_grader.py`) | AC: #20 (edge case: idempotency) | Depends: P3-2

- [ ] **[S] P3-12.** Configure XQueue MySQL connection pooling: max 20 connections, 30s queue timeout (`deploy/k8s/base/apps/xqueue/grader-configmap.yaml`) | AC: #16 (edge case: connection pool exhaustion) | Depends: P3-7

#### Observability

- [ ] **[M] P3-13.** Set up Prometheus metrics for XQueue: `xqueue_submissions_total`, `xqueue_queue_depth`, `xqueue_grading_duration_seconds`, `xqueue_grader_errors_total`, `xqueue_grader_workers_active`, `xqueue_dead_letter_total` (`infrastructure/monitoring/dashboards/xqueue-operations.json`, `infrastructure/monitoring/alerts/xqueue-*.json`) | Req: OBS metrics | Depends: P3-7

- [ ] **[M] P3-14.** Set up structured logging for XQueue events: `xqueue_submission`, `xqueue_graded`, `xqueue_grader_error` event types with required fields (`services/xqueue-graders/graders/base_grader.py`) | Req: OBS logs | Depends: P3-2

- [ ] **[S] P3-15.** Set up XQueue critical alerts: queue depth >100 for 10min (page), grader workers =0 for 5min (page), grading latency p95 >30s (warning), dead letters >10/hr (warning) (`infrastructure/monitoring/alerts/xqueue-critical.json`, `infrastructure/monitoring/alerts/xqueue-warning.json`) | Req: OBS alerts | Depends: P3-13

- [ ] **[S] P3-16.** Create Grafana dashboard "XQueue Operations": queue depth, grading latency percentiles, worker count, error rate, dead letter count, grader utilization (`infrastructure/monitoring/dashboards/xqueue-operations.json`) | Req: OBS dashboards | Depends: P3-13

#### Docs

- [ ] **[M] P3-17.** Create XQueue grader authoring guide for course authors: how to create XQueue-backed problems in Studio, expected input/output format, testing locally (`docs/operations/xqueue-grader-authoring.md`) | Depends: P3-10

- [ ] **[S] P3-18.** Create XQueue grader deployment runbook: how to build/push images, deploy workers, scale replicas, rollback, check queue depth (`docs/operations/xqueue-grader-runbook.md`) | Depends: P3-9

---

### Phase 4: Advanced Question Types (Week 8-10)

#### Build

- [ ] **[M] P4-1.** Verify drag-and-drop v2 XBlock availability in Studio component picker (ships with Redwood base image); if missing, install via Tutor plugin (`infrastructure/tutor/plugins/advanced-xblocks.yml`) | AC: #21, #22 | Depends: P0-6

- [ ] **[M] P4-2.** Verify math expression input availability in Studio (ships with Redwood); test SymPy-based equivalence checking (`x^2+2*x+1` vs `(x+1)^2`) (`infrastructure/tutor/plugins/advanced-xblocks.yml`) | AC: #21, #23 | Depends: P0-6

- [ ] **[M] P4-3.** Install Problem Builder XBlock if not present: `pip install xblock-problem-builder` via Tutor plugin; gate behind `ENABLE_PROBLEM_BUILDER` Waffle flag (`infrastructure/tutor/plugins/advanced-xblocks.yml`) | AC: #21 | Depends: P4-1

- [ ] **[S] P4-4.** Verify additional built-in types: chemical equation input, image annotation, numerical input with tolerance, custom JavaScript problems (`jsinput`) (`infrastructure/tutor/plugins/advanced-xblocks.yml`) | AC: #21 | Depends: P4-1

- [ ] **[M] P4-5.** Configure randomized problem pools: verify content library creation, randomized selection of N problems from library per student (`infrastructure/tutor/apply-patches.sh`) | AC: #24 | Depends: P4-1

- [ ] **[S] P4-6.** Verify keyboard accessibility for drag-and-drop v2: Tab navigation, Enter/Space for select/drop, screen reader announcements (`infrastructure/tutor/plugins/advanced-xblocks.yml`) | AC: #22, #37 | Depends: P4-1

- [ ] **[M] P4-7.** Verify OLX export/import for courses containing all advanced question types (`scripts/qa/verify-olx-advanced-types.sh`) | AC: #21 | Depends: P4-1 through P4-4

- [ ] **[S] P4-8.** Verify all advanced question types integrate with gradebook: correct answers contribute to course grade for drag-and-drop, math input, chemical equation, image annotation, numerical input, jsinput (`infrastructure/tutor/plugins/advanced-xblocks.yml`) | AC: #29 | Depends: P4-1

#### Docs

- [ ] **[S] P4-9.** Create advanced question type availability guide: which types ship with Redwood, which need pip install, configuration options, known limitations (`docs/operations/advanced-xblock-guide.md`) | Depends: P4-1 through P4-4

---

### Phase 5: Assessment Security, Bulk Operations, and Analytics (Week 10-13)

#### Build -- Assessment Security

- [ ] **[M] P5-1.** Verify randomized question order: two students accessing same exam see questions in different orders (`infrastructure/tutor/apply-patches.sh`) | AC: #25 | Depends: P2-1

- [ ] **[S] P5-2.** Verify randomized answer order: multiple-choice answer options shuffled per student (`infrastructure/tutor/apply-patches.sh`) | AC: #26 | Depends: P2-1

- [ ] **[M] P5-3.** Verify one-at-a-time question display: students see one question, cannot navigate back to previous (configurable per subsection) (`infrastructure/tutor/apply-patches.sh`) | AC: #27 | Depends: P2-1

- [ ] **[S] P5-4.** Verify max_attempts enforcement: with `max_attempts=1`, submit button disabled after first attempt (`infrastructure/tutor/apply-patches.sh`) | AC: #28 | Depends: P2-1

- [ ] **[S] P5-5.** Verify `show_correctness` setting: `always`, `past_due`, `never` behaviors; correct answers shown only after due date when set to `past_due` (`infrastructure/tutor/apply-patches.sh`) | AC: #39 | Depends: P2-1

- [ ] **[M] P5-6.** Verify IP-based submission logging: student IP address hash logged with each submission event (not raw IP) (`infrastructure/tutor/apply-patches.sh`) | AC: #25 (security requirement) | Depends: P2-1

#### Build -- Grade Integration

- [ ] **[M] P5-7.** Verify weighted grade calculation: course with ORA2 (20%), timed exam (40%), standard problems (40%) produces correct final grade (`infrastructure/tutor/apply-patches.sh`) | AC: #29 | Depends: P1-6, P2-7

- [ ] **[M] P5-8.** Verify grade override: instructor overrides grade, gradebook updates, original grade preserved in audit log with reason and timestamp (`infrastructure/tutor/apply-patches.sh`) | AC: #30 | Depends: P5-7

- [ ] **[S] P5-9.** Verify grade override precedence: manual override takes precedence over auto-grade; bulk regrade does not overwrite manual override unless explicitly included (`infrastructure/tutor/apply-patches.sh`) | AC: #30 (edge case: conflicting grade sources) | Depends: P5-8

#### Build -- Bulk Operations

- [ ] **[L] P5-10.** Verify/configure bulk grade export: CSV with columns (student_id, assessment_name, assessment_type, score, max_score, submission_timestamp, grading_source) for courses with 500+ enrollments; must complete within 5 minutes for 5,000 students (`infrastructure/tutor/apply-patches.sh`) | AC: #31, #32 | Depends: P5-7

- [ ] **[L] P5-11.** Verify/configure bulk grade import: CSV upload with student ID and new grade; audit log entry for each override; idempotent re-upload (`infrastructure/tutor/apply-patches.sh`) | AC: #33 | Depends: P5-8

- [ ] **[L] P5-12.** Verify/configure bulk regrade: asynchronous Celery task with progress reporting, 1-hour timeout, checkpoint/resume on failure; handles 5,000 submissions within 30 minutes (`infrastructure/tutor/apply-patches.sh`) | AC: #32, #34 | Depends: P5-7

- [ ] **[S] P5-13.** Verify bulk ORA2 staff grading: sequential grading workflow without returning to queue between submissions (`infrastructure/tutor/apply-patches.sh`) | AC: #32 | Depends: P1-5

#### Build -- Multi-Language

- [ ] **[M] P5-14.** Verify multi-language rubric support: rubric criteria labels in English and Malay; student sees rubric in their language preference; Unicode support (Malay diacriticals, CJK) (`infrastructure/tutor/apply-patches.sh`) | AC: #35 | Depends: P1-3

- [ ] **[S] P5-15.** Verify ORA Grading MFE displays rubric in course-configured language (`infrastructure/tutor/apply-patches.sh`) | AC: #35 | Depends: P5-14

#### Build -- Student Feedback

- [ ] **[M] P5-16.** Verify feedback display timing: auto-graded (immediate or past_due), ORA2 peer (after deadline+grace), ORA2 staff (within 5 min), XQueue (msg field from grader) (`infrastructure/tutor/apply-patches.sh`) | AC: #38, #39 | Depends: P1-7, P3-2

- [ ] **[S] P5-17.** Verify rich feedback content: HTML, images, code snippets in grader responses and rubric option explanations (`infrastructure/tutor/apply-patches.sh`) | AC: #38 | Depends: P5-16

#### Observability

- [ ] **[M] P5-18.** Set up metrics for grade integration: `grade_overrides_total`, `bulk_operations_total`, `bulk_operation_duration_seconds`, `assessment_gradebook_sync_duration_seconds` (`infrastructure/monitoring/dashboards/assessment-overview.json`) | Req: OBS metrics | Depends: P5-7

- [ ] **[M] P5-19.** Set up structured logging for grade overrides and bulk operations: `grade_override`, `bulk_operation` event types with required fields (`infrastructure/tutor/apply-patches.sh`) | Req: OBS logs | Depends: P5-8

- [ ] **[S] P5-20.** Set up warning alerts: staff grading queue >50 for 48h, bulk regrade p95 >30min, peer assessments zero for 72h (`infrastructure/monitoring/alerts/assessment-warning.json`) | Req: OBS alerts | Depends: P5-18

- [ ] **[M] P5-21.** Create Grafana dashboards: "Assessment Overview", "Bulk Operations", "Assessment Analytics" (instructor-facing: per-problem avg score, rubric breakdown, question difficulty) (`infrastructure/monitoring/dashboards/assessment-overview.json`, `infrastructure/monitoring/dashboards/assessment-analytics.json`) | Req: OBS dashboards | Depends: P5-18

#### Docs

- [ ] **[M] P5-22.** Create bulk operations guide for instructors: grade export/import format, bulk regrade workflow, progress monitoring (`docs/operations/bulk-assessment-operations.md`) | Depends: P5-10 through P5-12

---

### Phase 6: Enterprise Rollout and Feature Flags (Week 13-16)

#### Build

- [ ] **[M] P6-1.** Configure all feature flags as Django Waffle flags (take effect without restart): `ENABLE_ORA2_FILE_UPLOADS` (on), `ENABLE_ORA2_PEER_CALIBRATION` (off), `ENABLE_ORA2_AI_ASSISTED_GRADING` (off), `ENABLE_XQUEUE_GRADING` (on), `ENABLE_XQUEUE_CODE_GRADER` (off), `ENABLE_TIMED_EXAMS` (on), `ENABLE_ADVANCED_XBLOCKS` (on), `ENABLE_PROBLEM_BUILDER` (off), `ENABLE_BULK_ASSESSMENT_OPS` (on), `ENABLE_ASSESSMENT_ANALYTICS` (off) (`infrastructure/tutor/apply-patches.sh`) | AC: all (rollout) | Depends: All Phase 1-5

- [ ] **[M] P6-2.** Load testing: 50+ simultaneous ORA2 submissions, concurrent XQueue grading, concurrent timed exams; verify no OOM or service degradation (`scripts/qa/load-test-assessments.sh`) | AC: #32 (performance) | Depends: All Phase 1-5

- [ ] **[S] P6-3.** Verify backward compatibility: existing courses with standard problems unaffected; existing ORA2 assignments and grades preserved; feature flag disable does not corrupt data (`scripts/qa/verify-backward-compat.sh`) | AC: all (backward compatibility) | Depends: P6-1

#### Rollout

- [ ] **[S] P6-4.** Enable advanced assessments for first enterprise pilot client; activate `ENABLE_XQUEUE_CODE_GRADER` and `ENABLE_ASSESSMENT_ANALYTICS` (`infrastructure/tutor/apply-patches.sh`) | Depends: P6-1, P6-2

- [ ] **[M] P6-5.** Monitor all assessment pipelines during first week of enterprise usage; respond to alerts, tune thresholds (`infrastructure/monitoring/`) | Depends: P6-4

#### Docs

- [ ] **[L] P6-6.** Create comprehensive assessment operations runbook: ORA2 troubleshooting, XQueue grader rollback, timed exam issues, bulk operation recovery, alert response procedures (`docs/operations/assessment-runbook.md`) | Depends: All Phase 1-5

- [ ] **[M] P6-7.** Create course author training materials: ORA2, timed exams, XQueue problems, advanced question types, bulk operations, analytics (`docs/operations/assessment-training-guide.md`) | Depends: All Phase 1-5

---

## Test Tasks (Summary)

Test tasks are detailed in the companion test plan (`specs/plans/advanced-assessment-xqueue_testplan.md`). Key test categories:

| Category | Type | Location | Count |
|----------|------|----------|-------|
| XQueue grader unit tests | pytest | `services/xqueue-graders/tests/` | ~15 tests |
| ORA2 smoke tests | shell_verification | `scripts/qa/smoke-ora2.sh` | ~8 tests |
| Timed exam smoke tests | shell_verification | `scripts/qa/smoke-timed-exams.sh` | ~6 tests |
| XQueue integration tests | smoke_test | `scripts/qa/smoke-xqueue-grading.sh` | ~8 tests |
| Advanced XBlock verification | manual_verification | Documented in testplan | ~6 tests |
| Assessment security verification | shell_verification | `scripts/qa/verify-assessment-security.sh` | ~5 tests |
| Grade integration verification | shell_verification | `scripts/qa/verify-grade-integration.sh` | ~4 tests |
| Bulk operations verification | smoke_test | `scripts/qa/smoke-bulk-operations.sh` | ~4 tests |
| Multi-language verification | manual_verification | Documented in testplan | ~3 tests |
| Load tests | smoke_test | `scripts/qa/load-test-assessments.sh` | ~3 tests |

---

## Milestones

| Milestone | Week | Deliverables | Exit Criteria |
|-----------|------|--------------|---------------|
| M0: Audit Complete | 2 | Assessment audit report, test course created, baseline smoke tests pass | All existing services verified operational |
| M1: ORA2 Operational | 5 | ORA2 assignments in pilot course, peer assessment workflow tested, file uploads working, metrics live | AC-001 through AC-009 pass |
| M2: Timed Exams Verified | 6 | Timed exams configured, timer enforcement verified, accessibility confirmed, metrics live | AC-010 through AC-015 pass |
| M3: XQueue Graders Live | 9 | Python grader worker deployed, sandbox security verified, worker failover tested, metrics live | AC-016 through AC-020 pass |
| M4: Advanced Types Enabled | 10 | All required XBlocks available in Studio, keyboard accessibility verified, gradebook integration confirmed | AC-021 through AC-024 pass |
| M5: Bulk Ops + Analytics | 13 | Bulk export/import/regrade operational at scale, dashboards created, security features verified | AC-025 through AC-039 pass |
| M6: Enterprise Rollout | 16 | First pilot client using advanced assessments, runbook complete, training materials delivered | Production monitoring stable for 7 days |

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| CodeJail AppArmor unavailable on GKE nodes | XQueue code grader requires alternative sandbox (gVisor, container-based) | P3-3 uses container-based sandbox as primary approach; CodeJail documented as future enhancement |
| ORA2 file storage exhaustion at enterprise scale | File uploads disabled, student work lost | P1-9 alert at 90%; investigate GCS migration (open question #3) |
| Timed exam timer bugs in browser edge cases | Students lose exam time or get extra time | P2-5 server-side enforcement is authoritative; client timer is display only |
| XQueue grader worker resource contention | Slow grading degrades student experience | P3-7 defines resource limits; P3-13 monitors queue depth and latency |
| Peer assessment does not scale to 2,000+ students | Database query performance degrades | Open question #6; monitor during pilot (M6), add pagination if needed |
| Advanced XBlocks not available in Redwood base image | Requires custom image build, extending build time | P4-1 through P4-4 verify availability first; fallback to pip install via Tutor plugin |
| Bulk regrade Celery task OOM for large courses | Partial regrade requires manual recovery | P5-12 implements checkpoint/resume; P5-18 monitors task duration |
| AI-assisted ORA2 grading not functional in Redwood | Feature delayed or descoped | Open question #5; gated behind `ENABLE_ORA2_AI_ASSISTED_GRADING` (default: off) |

---

## Estimated Effort by Phase

| Phase | Effort | Engineers |
|-------|--------|-----------|
| P0: Audit & Baseline | 1-2 weeks | 1 |
| P1: ORA2 Operationalization | 3 weeks | 1-2 |
| P2: Timed Exams | 2 weeks | 1 |
| P3: XQueue Graders | 4 weeks | 2 |
| P4: Advanced XBlocks | 2 weeks | 1 |
| P5: Security + Bulk + Analytics | 3 weeks | 2 |
| P6: Enterprise Rollout | 3 weeks | 1-2 |
| **Total** | **16-22 weeks** | **4 engineers** |

Note: Phases 1-2 and 3-4 can overlap with different engineers.
