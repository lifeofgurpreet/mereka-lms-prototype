---
spec: advanced-assessment-xqueue_spec.md
plan: advanced-assessment-xqueue_plan.md
tier: 5
status: draft
last_updated: "2026-02-10"
test_framework: pytest + shell_verification + smoke_test + manual_verification
---

# Test Plan: Advanced Assessment & XQueue Integration (Non-Proctored)

**Source Spec**: `specs/advanced-assessment-xqueue_spec.md`
**Plan**: `specs/plans/advanced-assessment-xqueue_plan.md`

## Test Strategy

This spec covers five major subsystems (ORA2, Timed Exams, XQueue Graders, Advanced XBlocks, Bulk Operations). Each has different testing requirements:

| Test Type | Description | Requires Cluster |
|-----------|-------------|------------------|
| `pytest` | Python unit/integration tests for XQueue grader workers | No |
| `shell_verification` | Bash scripts verifying configuration and runtime state | Varies |
| `smoke_test` | HTTP requests and end-to-end workflow tests against deployed services | Yes |
| `manual_verification` | Human-performed checks for UX, accessibility, and visual elements | Yes |
| `load_test` | Performance verification under simulated concurrent load | Yes |

The XQueue grader workers in `services/xqueue-graders/` are the primary new code and use `pytest`. All other subsystems (ORA2, timed exams, XBlocks) are existing Open edX features verified via configuration checks, smoke tests, and manual verification.

---

## Test Matrix

### ORA2 Configuration (AC-001 through AC-006)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-001 | Course author can create ORA2 with 3-criteria rubric, peer assessment (3 reviews, 5 given) | smoke_test | `scripts/qa/smoke-ora2.sh` | Test course + Studio session |
| AC-001 | (Negative) Rubric with >10 criteria is rejected by Studio | manual_verification | N/A | Studio form validation |
| AC-002 | After 3 peers review and deadline passes, student sees median final grade | smoke_test | `scripts/qa/smoke-ora2.sh` | 4+ test learners completing peer review cycle |
| AC-002 | (Negative) Student does not see grade before required peer reviews complete | smoke_test | `scripts/qa/smoke-ora2.sh` | Check grade visibility pre-completion |
| AC-003 | Student uploads 9.5 MB PDF; file stored at `/openedx/data/ora2/` | smoke_test | `scripts/qa/smoke-ora2.sh` | 9.5 MB test PDF fixture |
| AC-003 | (Negative) File exceeding configured max size is rejected | smoke_test | `scripts/qa/smoke-ora2.sh` | 51 MB test file |
| AC-004 | Student uploading `.exe` file receives validation error listing allowed types | smoke_test | `scripts/qa/smoke-ora2.sh` | Test `.exe` file |
| AC-005 | After first submission, rubric modification is blocked by Studio | manual_verification | N/A | Attempt rubric edit after submission |
| AC-006 | Student without calibration completion is redirected to calibration step | manual_verification | N/A | Requires `ENABLE_ORA2_PEER_CALIBRATION` flag on |

### ORA Grading MFE (AC-007 through AC-009)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-007 | Staff sees 10 submissions ordered by time in grading queue at `apps.academyv2.mereka.io/ora-grading` | smoke_test | `scripts/qa/smoke-ora2.sh` | 10+ ORA2 submissions from test learners |
| AC-007 | (Negative) Non-staff user cannot access ORA Grading MFE | smoke_test | `scripts/qa/smoke-ora2.sh` | Learner-role session |
| AC-008 | Staff selects rubric options, enters feedback, submits grade; next submission loads automatically | manual_verification | N/A | Staff grading session |
| AC-009 | Staff-submitted grade appears in gradebook within 5 minutes | smoke_test | `scripts/qa/verify-grade-integration.sh` | Staff grades ORA2 submission, check gradebook API |

### Timed Exams (AC-010 through AC-015)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-010 | Course author sets subsection `exam_type=timed` with 60-minute limit; student sees countdown, no proctoring prompts | smoke_test | `scripts/qa/smoke-timed-exams.sh` | Test course with timed subsection |
| AC-010 | (Negative) Setting `exam_type=proctored` is out of scope and has no proctoring backend configured | manual_verification | N/A | Verify no proctoring prompts appear |
| AC-011 | Timer warning displayed at 5 minutes and 1 minute remaining | manual_verification | N/A | Visual and screen-reader check |
| AC-012 | Timer reaches 0:00; answers auto-submitted; student sees "Time expired" message | smoke_test | `scripts/qa/smoke-timed-exams.sh` | Let timer expire in test session |
| AC-012 | (Negative) Client-side clock manipulation does not extend server-side time limit | shell_verification | `scripts/qa/verify-assessment-security.sh` | Server-side time comparison test |
| AC-013 | After auto-submission, student sees read-only view; cannot modify responses | smoke_test | `scripts/qa/smoke-timed-exams.sh` | Attempt re-access after submission |
| AC-014 | Instructor grants 30-minute extension; student receives 90-minute timer (60+30) | smoke_test | `scripts/qa/smoke-timed-exams.sh` | Instructor dashboard accommodation |
| AC-015 | Timed exam grade released to gradebook immediately upon submission (no proctoring hold) | smoke_test | `scripts/qa/verify-grade-integration.sh` | Submit before timer expires, check gradebook |

### Timed Exam Edge Cases

| Edge Case | Test Case | Type | File | Notes |
|-----------|-----------|------|------|-------|
| EC-timed-1 | Browser crash recovery: close browser, reopen within time limit, resume with remaining time | manual_verification | N/A | Close browser tab, reopen |
| EC-timed-2 | Simultaneous device access: second device shows "already in progress" | manual_verification | N/A | Open exam from two browsers |
| EC-timed-3 | Instructor changes time limit during active exam: existing attempts retain original limit | manual_verification | N/A | Change limit mid-exam |

### XQueue Integration (AC-016 through AC-020)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-016 | Student submits Python code; grader executes in sandbox; grade returned within 30 seconds | smoke_test | `scripts/qa/smoke-xqueue-grading.sh` | XQueue-backed problem in test course, grader worker deployed |
| AC-016 | XQueue service authenticates LMS requests using `XQUEUE_LMS_PASSWORD` | shell_verification | `scripts/qa/smoke-xqueue-grading.sh` | Verify ExternalSecret sync |
| AC-017 | Infinite loop submission terminated after CPU time limit (10s); student sees timeout feedback | pytest | `services/xqueue-graders/tests/test_python_grader.py` | Infinite loop code fixture |
| AC-017 | (smoke) Same test via deployed grader worker | smoke_test | `scripts/qa/smoke-xqueue-grading.sh` | Infinite loop submission |
| AC-018 | Malicious `import os; os.system("rm -rf /")` blocked by sandbox; student sees security violation | pytest | `services/xqueue-graders/tests/test_sandbox_security.py` | Malicious code fixtures |
| AC-018 | (smoke) Malicious code via deployed worker | smoke_test | `scripts/qa/smoke-xqueue-grading.sh` | Malicious code submission |
| AC-019 | Worker crashes during processing; submission reappears in queue after 60s visibility timeout | pytest | `services/xqueue-graders/tests/test_worker_recovery.py` | Simulated worker crash |
| AC-019 | (smoke) Kill worker pod; verify submission re-queued | smoke_test | `scripts/qa/smoke-xqueue-grading.sh` | `kubectl delete pod` during grading |
| AC-020 | XQueue-graded score appears in gradebook within 5 minutes | smoke_test | `scripts/qa/verify-grade-integration.sh` | Complete XQueue grading, check gradebook API |

### XQueue Unit Tests (pytest)

| Test Case | Type | File | Mocks/Fixtures |
|-----------|------|------|----------------|
| Python grader: correct output scores 1.0 | pytest | `services/xqueue-graders/tests/test_python_grader.py` | Expected output fixture |
| Python grader: wrong output scores 0.0 with feedback | pytest | `services/xqueue-graders/tests/test_python_grader.py` | Wrong output fixture |
| Python grader: syntax error returns graceful error | pytest | `services/xqueue-graders/tests/test_python_grader.py` | Syntax error code |
| Python grader: CPU timeout (10s) returns timeout error | pytest | `services/xqueue-graders/tests/test_python_grader.py` | Infinite loop fixture |
| Python grader: memory limit (256MB) returns OOM error | pytest | `services/xqueue-graders/tests/test_python_grader.py` | Memory hog fixture |
| Python grader: fork bomb contained by process limit | pytest | `services/xqueue-graders/tests/test_sandbox_security.py` | Fork bomb code |
| Python grader: filesystem write blocked outside /tmp | pytest | `services/xqueue-graders/tests/test_sandbox_security.py` | FS write attempt code |
| Python grader: network access blocked | pytest | `services/xqueue-graders/tests/test_sandbox_security.py` | HTTP request code |
| Generic script grader: correct JSON output processed | pytest | `services/xqueue-graders/tests/test_generic_grader.py` | Valid grading script |
| Generic script grader: invalid JSON returns error | pytest | `services/xqueue-graders/tests/test_generic_grader.py` | Broken output script |
| Submission deduplication: same code within 5s processed once | pytest | `services/xqueue-graders/tests/test_deduplication.py` | Rapid duplicate submissions |
| Idempotent result submission: same score twice produces one update | pytest | `services/xqueue-graders/tests/test_idempotency.py` | Duplicate result submission |
| Dead letter after 3 retries: submission moved to DLQ | pytest | `services/xqueue-graders/tests/test_worker_recovery.py` | Persistently failing grader |
| Connection pool: max 20 connections with 30s timeout | pytest | `services/xqueue-graders/tests/test_connection_pool.py` | Mock MySQL connections |

### Advanced Question Types (AC-021 through AC-024)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-021 | Drag-and-drop v2 and math expression input available in Studio component picker | manual_verification | N/A | Studio "Add Advanced Component" dialog |
| AC-022 | Drag-and-drop v2: keyboard-only navigation (Tab/Enter/Space) completes interaction correctly | manual_verification | N/A | Keyboard-only test |
| AC-023 | Math expression: `(x+1)^2` accepted as equivalent to `x^2+2*x+1` (SymPy evaluation) | smoke_test | `scripts/qa/smoke-advanced-xblocks.sh` | Math problem in test course |
| AC-024 | Randomized pool of 20 questions shows 10 different subset to two students | smoke_test | `scripts/qa/smoke-advanced-xblocks.sh` | Content library with 20 problems |
| AC-024 | (Negative) Same student sees same subset on re-access (deterministic per student) | smoke_test | `scripts/qa/smoke-advanced-xblocks.sh` | Re-access same subsection |

### Advanced XBlock Edge Cases

| Edge Case | Test Case | Type | File | Notes |
|-----------|-----------|------|------|-------|
| EC-xblock-1 | Chemical equation input available in Studio | manual_verification | N/A | Check component picker |
| EC-xblock-2 | Numerical input with tolerance accepts value within range | manual_verification | N/A | Test problem with tolerance |
| EC-xblock-3 | OLX export/import for course with advanced types succeeds | shell_verification | `scripts/qa/verify-olx-advanced-types.sh` | Export, then import to new course |
| EC-xblock-4 | All advanced types report grades to gradebook | smoke_test | `scripts/qa/verify-grade-integration.sh` | Submit each type, check grades |

### Assessment Security (AC-025 through AC-028)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-025 | Two students see questions in different order for randomized-order exam | smoke_test | `scripts/qa/verify-assessment-security.sh` | Randomized subsection, two test sessions |
| AC-026 | Answer options shuffled differently for two students | smoke_test | `scripts/qa/verify-assessment-security.sh` | Multiple-choice with shuffling enabled |
| AC-027 | One-at-a-time display: advancing to Q3 makes Q1/Q2 inaccessible | manual_verification | N/A | Navigate forward, attempt back navigation |
| AC-028 | After submitting with `max_attempts=1`, submit button disabled | smoke_test | `scripts/qa/verify-assessment-security.sh` | Single-attempt problem |
| AC-028 | (Negative) Attempting second submission via API returns error | shell_verification | `scripts/qa/verify-assessment-security.sh` | Direct API call after first attempt |

### Grade Integration (AC-029 through AC-031)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-029 | Weighted grade: ORA2 (20%) + timed exam (40%) + standard (40%) produces correct final grade | smoke_test | `scripts/qa/verify-grade-integration.sh` | Course with all three assessment types |
| AC-030 | Grade override: instructor changes 70% to 85%; gradebook reflects 85%; audit log shows original, new, reason | smoke_test | `scripts/qa/verify-grade-integration.sh` | Override via instructor dashboard |
| AC-030 | (Negative) Bulk regrade does not overwrite manual override unless explicitly included | shell_verification | `scripts/qa/verify-grade-integration.sh` | Override then regrade |
| AC-031 | Bulk grade export CSV contains correct columns for 500-student course | smoke_test | `scripts/qa/smoke-bulk-operations.sh` | Course with 500+ enrollments |

### Bulk Operations (AC-032 through AC-034)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-032 | Bulk regrade of 2,000 submissions runs async, reports progress, completes without LMS degradation | smoke_test | `scripts/qa/smoke-bulk-operations.sh` | Course with 2,000 submissions |
| AC-032 | (Negative) LMS response time does not degrade during bulk regrade | load_test | `scripts/qa/load-test-assessments.sh` | Concurrent LMS requests during regrade |
| AC-033 | CSV grade override for 100 students: each grade updated, audit log entry per override | smoke_test | `scripts/qa/smoke-bulk-operations.sh` | 100-row CSV fixture |
| AC-033 | (Negative) Idempotent re-upload of same CSV does not create duplicate override records | shell_verification | `scripts/qa/smoke-bulk-operations.sh` | Re-upload same CSV |
| AC-034 | Instructor sees progress percentage and estimated time remaining for active bulk regrade | manual_verification | N/A | Check instructor dashboard during regrade |

### Multi-Language and Accessibility (AC-035 through AC-037)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-035 | Malay rubric labels displayed when learner language preference is Malay | manual_verification | N/A | ORA2 with bilingual rubric, Malay-preference learner |
| AC-036 | Screen reader announces "1 minute remaining" via ARIA live region during timed exam | manual_verification | N/A | Screen reader + timed exam at 1 min |
| AC-037 | Keyboard-only user completes drag-and-drop v2 via Tab/Enter/Space | manual_verification | N/A | Keyboard-only interaction test |

### Student Feedback (AC-038, AC-039)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-038 | ORA2 final staff grade triggers email notification within 10 minutes with course name, assignment, feedback link | smoke_test | `scripts/qa/smoke-ora2.sh` | Staff grades submission, check email delivery |
| AC-038 | (Negative) Email does not contain raw grades or student-submitted content | shell_verification | `scripts/qa/smoke-ora2.sh` | Inspect email content |
| AC-039 | With `show_correctness=past_due`: before due date, student sees "Answer submitted" only; after due date, correct answer shown | smoke_test | `scripts/qa/verify-assessment-security.sh` | Problem with `past_due` setting |

---

## Edge Case Tests (from Spec)

### ORA2 Edge Cases

| Edge Case | Test Case | Type | File | Notes |
|-----------|-----------|------|------|-------|
| Insufficient peer reviewers | Submission flagged for staff fallback after deadline+grace; not graded 0 | smoke_test | `scripts/qa/smoke-ora2.sh` | ORA2 with too few peers |
| Student submits but never grades peers | Penalty applied (configurable 0-100%); notification sent before deadline | manual_verification | N/A | Skip peer grading, check penalty |
| Large file upload failure mid-transfer | Submission not marked complete; partially uploaded file cleaned up; retry available | manual_verification | N/A | Simulate network interruption |
| Rubric with zero-point option | Total score correctly includes 0 (not treated as missing) | smoke_test | `scripts/qa/smoke-ora2.sh` | Rubric with 0-point option |
| ORA2 file storage at 90% | Alert fires; new uploads rejected with user-friendly message | shell_verification | `scripts/qa/smoke-ora2.sh` | Monitor storage metric |

### XQueue Edge Cases

| Edge Case | Test Case | Type | File | Notes |
|-----------|-----------|------|------|-------|
| No grader workers available | Queue accumulates; alert fires at >100 unprocessed for 10min; student sees "Grading in progress" | shell_verification | `scripts/qa/smoke-xqueue-grading.sh` | Scale graders to 0 |
| Malicious fork bomb | Sandbox contains fork bomb; graceful error returned | pytest | `services/xqueue-graders/tests/test_sandbox_security.py` | Fork bomb fixture |
| Invalid grader response (missing fields) | XQueue logs error; submission returned to queue (max 3 retries); dead-lettered after 3 | pytest | `services/xqueue-graders/tests/test_worker_recovery.py` | Malformed response fixture |
| XQueue restart during grading | In-flight submissions recovered from database and re-queued | smoke_test | `scripts/qa/smoke-xqueue-grading.sh` | Restart XQueue pod during grading |
| Rapid duplicate submission (within 5s) | Only most recent submission processed | pytest | `services/xqueue-graders/tests/test_deduplication.py` | Rapid submissions |

### Grade Integration Edge Cases

| Edge Case | Test Case | Type | File | Notes |
|-----------|-----------|------|------|-------|
| Conflicting grade sources (auto + manual override) | Manual override takes precedence; regrade does not overwrite | shell_verification | `scripts/qa/verify-grade-integration.sh` | Override then regrade |
| Missing ORA2 grade treated as 0 | Gradebook uses 0, not excluded from weighted average | smoke_test | `scripts/qa/verify-grade-integration.sh` | Student with unsubmitted ORA2 |
| Celery task failure mid-bulk-regrade | Partially completed; can resume from checkpoint | manual_verification | N/A | Kill worker during bulk regrade |

---

## Performance Tests

| NFR | Test Case | Type | File | Pass Criteria |
|-----|-----------|------|------|---------------|
| ORA2 submission p95 < 10s | Submit text + 10MB file, measure p95 | load_test | `scripts/qa/load-test-assessments.sh` | p95 < 10,000ms |
| ORA2 peer assessment page load p95 < 3s | Load peer review page, measure p95 | load_test | `scripts/qa/load-test-assessments.sh` | p95 < 3,000ms |
| XQueue grading round-trip p95 < 30s | Submit code, measure time to grade result | load_test | `scripts/qa/load-test-assessments.sh` | p95 < 30,000ms |
| Timed exam page load p95 < 5s (100 problems) | Load exam with 100 problems, measure p95 | load_test | `scripts/qa/load-test-assessments.sh` | p95 < 5,000ms |
| Bulk grade export < 5 min for 5,000 students | Trigger export, measure completion time | smoke_test | `scripts/qa/smoke-bulk-operations.sh` | Duration < 300s |
| Bulk regrade < 30 min for 5,000 submissions | Trigger regrade, measure completion time | smoke_test | `scripts/qa/smoke-bulk-operations.sh` | Duration < 1,800s |
| 50+ simultaneous ORA2 submissions | Concurrent ORA2 submissions under load | load_test | `scripts/qa/load-test-assessments.sh` | No OOM, no 500 errors |

---

## Coverage Summary

| AC Range | Category | Test Count | Automated | Manual |
|----------|----------|------------|-----------|--------|
| AC-001 to AC-006 | ORA2 Configuration | 10 | 7 | 3 |
| AC-007 to AC-009 | ORA Grading MFE | 5 | 3 | 2 |
| AC-010 to AC-015 | Timed Exams | 11 | 6 | 5 |
| AC-016 to AC-020 | XQueue Integration | 10 | 10 | 0 |
| AC-021 to AC-024 | Advanced Question Types | 7 | 3 | 4 |
| AC-025 to AC-028 | Assessment Security | 6 | 5 | 1 |
| AC-029 to AC-031 | Grade Integration | 5 | 5 | 0 |
| AC-032 to AC-034 | Bulk Operations | 5 | 4 | 1 |
| AC-035 to AC-037 | Multi-Language/Accessibility | 3 | 0 | 3 |
| AC-038 to AC-039 | Student Feedback | 4 | 3 | 1 |
| Edge Cases | All categories | ~20 | ~14 | ~6 |
| Performance | NFR | 7 | 7 | 0 |
| **Total** | | **~93** | **~67** | **~26** |

---

## Test Scripts Inventory

| Script | Tests Covered | Phase |
|--------|--------------|-------|
| `services/xqueue-graders/tests/test_python_grader.py` | AC-016, AC-017 (unit) | 3 |
| `services/xqueue-graders/tests/test_generic_grader.py` | AC-016 (generic script) | 3 |
| `services/xqueue-graders/tests/test_sandbox_security.py` | AC-018 (security) | 3 |
| `services/xqueue-graders/tests/test_worker_recovery.py` | AC-019 (recovery, DLQ) | 3 |
| `services/xqueue-graders/tests/test_deduplication.py` | Deduplication edge case | 3 |
| `services/xqueue-graders/tests/test_idempotency.py` | Idempotent result | 3 |
| `services/xqueue-graders/tests/test_connection_pool.py` | Connection pool | 3 |
| `scripts/qa/smoke-ora2.sh` | AC-001 to AC-006, AC-038, ORA2 edge cases | 1 |
| `scripts/qa/smoke-timed-exams.sh` | AC-010 to AC-015 | 2 |
| `scripts/qa/smoke-xqueue-grading.sh` | AC-016 to AC-019 (end-to-end) | 3 |
| `scripts/qa/smoke-advanced-xblocks.sh` | AC-021 to AC-024 | 4 |
| `scripts/qa/verify-assessment-security.sh` | AC-025 to AC-028, AC-039 | 5 |
| `scripts/qa/verify-grade-integration.sh` | AC-009, AC-015, AC-020, AC-029, AC-030 | 5 |
| `scripts/qa/smoke-bulk-operations.sh` | AC-031 to AC-034 | 5 |
| `scripts/qa/verify-olx-advanced-types.sh` | OLX export/import for advanced types | 4 |
| `scripts/qa/load-test-assessments.sh` | Performance NFRs | 6 |

---

## CI Integration

```yaml
- name: XQueue Grader Unit Tests
  run: |
    cd services/xqueue-graders
    pip install -r requirements.txt -r requirements-test.txt
    pytest tests/ -v --tb=short

- name: Assessment Baseline Smoke Tests
  run: scripts/qa/smoke-assessment-baseline.sh

- name: Assessment Security Verification
  run: scripts/qa/verify-assessment-security.sh

- name: Grade Integration Verification
  run: scripts/qa/verify-grade-integration.sh
```

---

## Self-Check

- [x] Every AC (001-039) has at least one test case
- [x] Edge cases from spec have negative/monitoring test cases
- [x] Test type appropriate for each case (pytest for grader code, shell_verification for config, smoke_test for runtime, manual for UX/accessibility)
- [x] File paths specified for all verification scripts and test files
- [x] Fixtures/notes column explains what is needed for each test
- [x] Source spec linked in header
