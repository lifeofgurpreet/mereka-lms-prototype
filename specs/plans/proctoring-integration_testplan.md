---
source_spec: specs/proctoring-integration_spec.md
status: deferred_until_2027
created: 2026-02-10
updated: 2026-02-10
---

# Proctoring Integration - Test Plan

**Source Spec**: `specs/proctoring-integration_spec.md`

**Status**: DEFERRED UNTIL 2027 - Test plan is ready for tracking and future implementation.

**Test Framework**: pytest (Python) - Open edX standard testframework

**Test Coverage Target**: 100% of 38 acceptance criteria + all edge cases + all NFRs

---

## IMPORTANT: DEFERRED STATUS

All tests below are marked **DEFERRED UNTIL 2027**. This testplan is ready for implementation when the project begins. Tests should be written alongside code implementation, following TDD principles where appropriate.

---

## Test Categories

- **Unit**: Single function/class, mocked dependencies
- **Integration**: Multiple components, test database, mockedexternal APIs (Proctorio, Examity, ProctorTrack, Respondus)
- **E2E**: Full flow including mocked provider APIs or no-opbackend
- **Load**: Performance testing (500 concurrent sessions, high webhook volume)
- **Security**: OWASP Top 10, webhook signature bypass, tenant isolation bypass, access control

---

## Test Plan Table

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| **Provider Integration** |
| 1 | Given edx-proctoring installed, when Proctorio backendregistered, then ProctoringBackendProvider.get_backend('proctorio') returns Proctorio adapter | unit | `tests/unit/proctoring/test_provider_registry.py` | None |
| 1 | Given all four providers registered, when get_backend called for each, then correct adapter returned | unit | `tests/unit/proctoring/test_provider_registry.py` | None |
| 2 | Given Examity backend with valid credentials, when register_exam_attempt() called, then Examity API creates exam record and returns provider_session_id | integration | `tests/integration/proctoring/test_examity_backend.py` | Mock ExamityAPI (success) |
| 2 | Given Examity API returns 503, when register_exam_attempt() called, then error logged, retry triggered | integration| `tests/integration/proctoring/test_examity_backend.py` | Mock Examity API (503) |
| 3 | Given Respondus backend configured, when student accesses exam from standard browser, then LockDown Browser detection fails and download prompt displayed | integration | `tests/integration/proctoring/test_respondus_backend.py` | Mock User-Agent (standard browser) |
| 3 | Given student uses Respondus LockDown Browser, when exam accessed, then detection succeeds and exam proceeds | integration | `tests/integration/proctoring/test_respondus_backend.py` | Mock User-Agent (LockDown Browser) |
| 4 | Given ProctorTrack backend, when on_review_callback() receives AI result with integrity_score < threshold, then attempt status updated to second_review_required | integration |`tests/integration/proctoring/test_proctortrack_backend.py` |Mock ProctorTrack webhook (low score) |
| 4 | Given ProctorTrack AI result with integrity_score >= threshold, when callback processed, then attempt status updatedto verified | integration | `tests/integration/proctoring/test_proctortrack_backend.py` | Mock ProctorTrack webhook (highscore) |
| 5 | Given no-op backend in dev environment, when full examflow executed, then all state transitions occur without external API calls | e2e | `tests/e2e/proctoring/test_noop_backend.py` | No-op backend |
| **Exam Setup** |
| 6 | Given course author in Studio, when subsection exam settings edited, then proctored exam type selectable and backendprovider dropdown populated from enterprise config | integration | `tests/integration/studio/test_proctored_exam_settings.py` | Mock enterprise config (Proctorio, Examity enabled) |
| 6 | Given enterprise customer with only Proctorio enabled,when dropdown displayed, then only Proctorio shown | integration | `tests/integration/studio/test_proctored_exam_settings.py` | Mock enterprise config (Proctorio only) |
| 7 | Given exam with time_limit=60 and due_date=2027-06-15T23:59:00Z, when student accesses at 2027-06-16T00:00:01Z, thenexam blocked with "deadline passed" message | integration |`tests/integration/proctoring/test_exam_access.py` | Time-mocked test (past due date) |
| 7 | Given exam with due_date in future, when student accesses before start_date, then exam blocked with "not yet available" message | integration | `tests/integration/proctoring/test_exam_access.py` | Time-mocked test (before start) |
| 8 | Given enterprise with only Proctorio enabled, when course author selects Examity, then Studio validation error displayed | unit | `tests/unit/studio/test_exam_validation.py` | Mock enterprise config |
| 8 | Given backend credentials not configured, when course published, then warning displayed | integration | `tests/integration/studio/test_publish_validation.py` | Mock enterprise config (no credentials) |
| 9 | Given course with proctored exams, when re-run created,then all proctored exam settings preserved in new run | integration | `tests/integration/studio/test_course_rerun.py` | Fixture: course with proctored exam |
| **Identity Verification** |
| 10 | Given student starting proctored exam first time, whenidentity verification begins, then photo ID captured via webcam and sent to provider | integration | `tests/integration/proctoring/test_identity_verification.py` | Mock provider API,Mock webcam |
| 10 | Given provider processes photo ID, when result returns, then verification result stored with user_id, enterprise_customer_uuid, timestamp, provider reference | integration | `tests/integration/proctoring/test_identity_verification.py` |Mock provider API (success) |
| 11 | Given identity verification returns failed, when student attempts to proceed, then exam blocked and 2 additional attempts offered | integration | `tests/integration/proctoring/test_identity_verification.py` | Mock provider API (failed result) |
| 11 | Given 3 failed verification attempts, when student attempts again, then lockout enforced, support contact displayed| integration | `tests/integration/proctoring/test_identity_verification.py` | Mock provider API (3 failures) |
| 12 | Given identity verification returns passed, when student proceeds, then result stored and environment check begins| integration | `tests/integration/proctoring/test_identity_verification.py` | Mock provider API (passed result) |
| 13 | Given student completed onboarding verification, whenstarting subsequent exam, then baseline facial recognition used (no photo ID re-capture) | integration | `tests/integration/proctoring/test_onboarding_verification.py` | Fixture: onboarding completed, Mock provider API (baseline match) |
| 13 | Given baseline verification fails (appearance changed), when provider flags mismatch, then human review triggered |integration | `tests/integration/proctoring/test_onboarding_verification.py` | Mock provider API (baseline mismatch) |
| **Environment Check** |
| 14 | Given student webcam blocked by browser, when environment check runs, then webcam check fails with "Please allow camera access" message | integration | `tests/integration/proctoring/test_environment_check.py` | Mock browser permissions (camera blocked) |
| 14 | Given all environment checks pass, when results displayed, then all components show green checkmark | integration |`tests/integration/proctoring/test_environment_check.py` | Mock all checks (pass) |
| 15 | Given all checks pass, when student reviews results, then proceed button enabled | integration | `tests/integration/proctoring/test_environment_check.py` | Mock all checks (pass) |
| 16 | Given upload bandwidth < 1.5 Mbps, when network checkruns, then fails with "Minimum 1.5 Mbps required" message | integration | `tests/integration/proctoring/test_environment_check.py` | Mock network check (low bandwidth) |
| 16 | Given upload bandwidth >= 1.5 Mbps, when network checkruns, then passes | integration | `tests/integration/proctoring/test_environment_check.py` | Mock network check (sufficient bandwidth) |
| **Browser Lockdown** |
| 17 | Given exam requires Respondus LockDown Browser, when student in LockDown Browser, then copy/paste blocked, screenshots blocked, other apps blocked, other tabs blocked | e2e | `tests/e2e/proctoring/test_lockdown_browser.py` | Respondus LockDown Browser test environment |
| 17 | Given student attempts to open another app, when in LockDown Browser, then blocked by LockDown Browser | e2e | `tests/e2e/proctoring/test_lockdown_browser.py` | Respondus LockDown Browser test environment |
| 18 | Given exam configured with Proctorio lock_fullscreen=true and disable_clipboard=true, when student takes exam, thenfullscreen enforced and clipboard blocked | integration | `tests/integration/proctoring/test_proctorio_lockdown.py` | Mock Proctorio extension API |
| 18 | Given Proctorio settings configured in Studio, when exam starts, then settings passed to Proctorio extension | integration | `tests/integration/proctoring/test_proctorio_lockdown.py` | Mock Proctorio extension API |
| 19 | Given student uses VM, when provider detects VM, thenvm_detected event flagged | integration | `tests/integration/proctoring/test_vm_detection.py` | Mock provider API (VM detection) |
| 19 | Given configurable policy is "flag for review", when VM detected, then event logged, exam continues | unit | `tests/unit/proctoring/test_vm_policy.py` | Feature flag: VM_POLICY=flag |
| **Exam Session Lifecycle** |
| 20 | Given student starts exam, when timer begins, then attempt transitions from ready_to_start to started, state changelogged with timestamp, user_id | integration | `tests/integration/proctoring/test_state_machine.py` | Fixture: attempt inready_to_start |
| 20 | Given state transition occurs, when logged, then log includes: attempt_id, user_id, exam_id, old_state, new_state,triggered_by, timestamp, enterprise_customer_uuid | unit | `tests/unit/proctoring/test_state_logging.py` | Mock logger |
| 21 | Given student submits exam, when submission processed,then attempt transitions to submitted, provider notified viastop_exam_attempt() | integration | `tests/integration/proctoring/test_exam_submission.py` | Mock provider API |
| 21 | Given provider API call fails, when stop_exam_attempt() returns error, then retry triggered | integration | `tests/integration/proctoring/test_exam_submission.py` | Mock provider API (error) |
| 22 | Given attempt in started state > time_limit + 30 min,when auto-expiry job runs, then transitions to timed_out, provider notified | integration | `tests/integration/proctoring/test_auto_expiry.py` | Time-mocked test |
| 22 | Given attempt timed out, when student attempts to submit late, then submission rejected with timeout message | integration | `tests/integration/proctoring/test_auto_expiry.py`| Fixture: timed_out attempt |
| 23 | Given provider outage during exam, when student recording stream fails, then answers preserved in browser session storage, reconnect prompt displayed | e2e | `tests/e2e/proctoring/test_provider_outage_recovery.py` | Mock provider API (connection loss) |
| 23 | Given connectivity restores within time limit, when student reconnects, then exam resumes | e2e | `tests/e2e/proctoring/test_provider_outage_recovery.py` | Mock provider API (connection restored) |
| 24 | Given attempt in verified state, when transition to started attempted, then rejected with invalid state error | unit | `tests/unit/proctoring/test_state_machine_validation.py`| None |
| 24 | Given valid state transition requested, when state machine processes, then transition succeeds | unit | `tests/unit/proctoring/test_state_machine_validation.py` | None |
| **Proctor Review** |
| 25 | Given 10 attempts for enterprise A in review queue andfor enterprise B, when reviewer R (authorized for A) accesses dashboard, then only 10 attempts for A visible | integration | `tests/integration/proctoring/test_review_dashboard_isolation.py` | Fixture: attempts from A and B, JWT for reviewerA |
| 25 | Given platform operator, when review dashboard accessed, then all attempts from all enterprises visible | integration | `tests/integration/proctoring/test_review_dashboard_isolation.py` | Fixture: attempts from multiple enterprises, superuser JWT |
| 26 | Given reviewer selects attempt, when clicks Reject andenters reason (25 chars), then attempt transitions to rejected, reason stored, student notified via email | integration |`tests/integration/proctoring/test_review_actions.py` | Mockemail service |
| 26 | Given reviewer clicks Reject with reason < 20 chars, when submitted, then validation error displayed | unit | `tests/unit/proctoring/test_review_validation.py` | None |
| 27 | Given reviewer rejects attempt, when proctoring_adminuser accesses, then can override to verified with audit log entry | integration | `tests/integration/proctoring/test_review_override.py` | Fixture: rejected attempt, admin JWT |
| 27 | Given non-admin user, when override attempted, then rejected with 403 Forbidden | security | `tests/security/proctoring/test_review_access_control.py` | Fixture: rejected attempt, non-admin JWT |
| 28 | Given attempt in review queue > review_sla_hours, whendashboard loads, then attempt highlighted with SLA warning |integration | `tests/integration/proctoring/test_sla_tracking.py` | Time-mocked test (SLA breached) |
| 28 | Given attempt breaches SLA, when threshold crossed, then alert fired to enterprise admin and channel | integration| `tests/integration/proctoring/test_sla_alerts.py` | Mock alert service |
| **Grading Integration** |
| 29 | Given attempt transitions to verified, when gradebooksync runs, then student grade appears in gradebook within 5 minutes | integration | `tests/integration/proctoring/test_grade_release.py` | Mock gradebook API |
| 29 | Given gradebook sync completes, when student views grades, then numeric grade and proctoring_status=verified displayed | integration | `tests/integration/proctoring/test_grade_display.py` | Fixture: verified attempt |
| 30 | Given attempt transitions to rejected, when gradebooksync runs, then grade set to 0 and proctoring_status=rejected| integration | `tests/integration/proctoring/test_grade_rejection.py` | Mock gradebook API |
| 30 | Given grade set to 0, when student views grades, thendisplayed with "Proctoring integrity violation" message | integration | `tests/integration/proctoring/test_grade_display.py` | Fixture: rejected attempt |
| 31 | Given instructor overrides rejected attempt, when override processed, then original grade restored and proctoring_status=verified with override audit entry | integration | `tests/integration/proctoring/test_instructor_override.py` | Fixture: rejected attempt with original grade |
| 31 | Given instructor override, when audit log queried, then override entry includes instructor_user_id, reason, timestamp | unit | `tests/unit/proctoring/test_override_audit.py` |None |
| 32 | Given attempt in submitted state (pending review), when student views grades, then "Pending Proctoring Review" displayed with no numeric grade | integration | `tests/integration/proctoring/test_grade_display.py` | Fixture: submitted attempt |
| 32 | Given grade pending, when included in course grade calculation, then excluded from final grade | integration | `tests/integration/proctoring/test_grade_calculation.py` | Fixture: multiple assessments, one pending proctoring |
| **Multi-Tenant Isolation** |
| 33 | Given enterprise A uses Examity and B uses Proctorio,when students take exams simultaneously, then each routed tocorrect provider with no credential cross-contamination | integration | `tests/integration/proctoring/test_multitenancy_routing.py` | Mock Examity API, Mock Proctorio API, Fixtures: enterprises A and B |
| 33 | Given provider credentials stored per enterprise, whenprovider API called for enterprise A, then only A's credentials used | security | `tests/security/proctoring/test_credential_isolation.py` | Mock provider API, Fixtures: enterpriseswith different credentials |
| 34 | Given enterprise A review_sla_hours=12 and B review_sla_hours=48, when SLA warnings displayed, then correct per-enterprise threshold used | integration | `tests/integration/proctoring/test_multitenancy_sla.py` | Fixtures: enterprises with different SLAs, attempts breaching SLA |
| 35 | Given GDPR deletion request for student in enterpriseA, when processed, then only that student's data deleted, allother data intact | integration | `tests/integration/proctoring/test_gdpr_deletion_isolation.py` | Fixtures: multiple students in enterprise A, students in enterprise B |
| 35 | Given deletion complete, when querying student's proctoring data, then zero records returned | integration | `tests/integration/proctoring/test_gdpr_deletion_isolation.py` | Post-deletion verification |
| **Compliance** |
| 36 | Given student starting proctored exam, when consent notice displayed, then includes: data collected, who accesses,retention period, right to refuse, contact info | unit | `tests/unit/proctoring/test_consent_notice_content.py` | None |
| 36 | Given consent notice, when student clicks "I Agree", then consent recorded with user_id, exam_id, enterprise_customer_uuid, consent_version, timestamp, ip_address_hash | integration | `tests/integration/proctoring/test_consent_recording.py` | Mock IP address |
| 37 | Given student does not accept consent, when attempts to proceed, then exam blocked with "Consent required" message| integration | `tests/integration/proctoring/test_consent_required.py` | Student declines consent |
| 37 | Given student declines consent, when consent_events metric queried, then decline action recorded | unit | `tests/unit/proctoring/test_consent_metrics.py` | Mock metrics |
| 38 | Given GDPR DSAR for student, when processed, then allproctoring metadata exported and provider coordinated for recording access within 30 days | integration | `tests/integration/proctoring/test_gdpr_dsar.py` | Mock provider API (DSAR request) |
| 38 | Given DSAR export, when inspected, then includes: allattempt records, review outcomes, consent records, state transitions | integration | `tests/integration/proctoring/test_gdpr_dsar.py` | Fixture: student with multiple proctored attempts |

---

## Edge Case Tests (Negative Tests)

| Edge Case | Test Case | Type | File | Mocks/Fixtures |
|-----------|-----------|------|------|----------------|
| Network failure during exam | Given internet drops during exam, when connection lost > 5 min, then attempt transitions to error, instructor notified | integration | `tests/integration/proctoring/test_network_failure.py` | Mock network disconnection |
| Network failure recovery | Given connection restores withinmin, when student reconnects, then exam resumes if provider session active | integration | `tests/integration/proctoring/test_network_failure.py` | Mock network reconnection |
| Provider API timeout during exam start | Given provider register_exam_attempt() times out > 10s, when retry also fails,then exam start blocked with "service unavailable" message |integration | `tests/integration/proctoring/test_provider_timeout.py` | Mock provider API (timeout) |
| Provider webhook never arrives | Given provider does not deliver callback within 72h, when timeout reached, then alert fired to enterprise admin and ops team | integration | `tests/integration/proctoring/test_webhook_timeout.py` | Time-mockedtest |
| Concurrent attempts (duplicate tabs) | Given student openstwo tabs and attempts to start same exam, when second attemptmade, then rejected with "exam already in progress" error |integration | `tests/integration/proctoring/test_concurrent_attempts.py` | Concurrent requests |
| Browser crash during exam | Given browser crashes and reopens within time limit, when student attempts resume, then allowed if provider session active | integration | `tests/integration/proctoring/test_browser_crash_recovery.py` | Mock provider session status check |
| Instructor changes exam during active session | Given instructor modifies exam content, when student has active attempt,then student continues with original version | integration |`tests/integration/proctoring/test_exam_content_versioning.py` | Mock content change during active attempt |
| Timezone confusion | Given exam window in UTC, when displayed to student, then both UTC and student local timezone shown| unit | `tests/unit/proctoring/test_timezone_display.py` |Mock student timezone |
| Student appearance changed | Given baseline verification, when student appearance changed significantly, then provider flags mismatch, human review triggered | integration | `tests/integration/proctoring/test_appearance_change.py` | Mock provider API (appearance mismatch) |
| Photo ID quality issues | Given blurry photo ID captured, when provider returns inconclusive, then retry prompted (up toattempts) | integration | `tests/integration/proctoring/test_photo_id_quality.py` | Mock provider API (inconclusive result) |
| Non-standard photo ID | Given photo ID format not recognized, when provider cannot process, then fallback to manual human review | integration | `tests/integration/proctoring/test_non_standard_id.py` | Mock provider API (unsupported format) |
| Minor student without government ID | Given enterprise allows minors, when alternative ID used, then processed per enterprise accommodation_policy | integration | `tests/integration/proctoring/test_minor_student_id.py` | Mock enterprise config (minor policy) |
| LockDown Browser crashes | Given LockDown Browser crashes,when student relaunches, then exam resume allowed if providersession active, time limit continues | integration | `tests/integration/proctoring/test_lockdown_crash.py` | Mock LockDown Browser crash/relaunch |
| Extension conflict | Given browser extensions conflict withProctorio, when environment check detects, then instructs todisable conflicting extensions | integration | `tests/integration/proctoring/test_extension_conflict.py` | Mock browser extension detection (conflict) |
| OS update during exam | Given OS triggers update during exam, when recorded by provider, then LMS does not interpret assubmission | integration | `tests/integration/proctoring/test_os_update.py` | Mock provider recording (OS update event) |
| Accessibility software conflict | Given student uses screenreader, when conflicts with lockdown, then lockdown-exempt mode activated per documented accommodation | integration | `tests/integration/proctoring/test_accessibility_software.py` |Mock accommodation flag |
| Reviewer disagrees with AI | Given AI flags exam as suspicious, when human reviewer determines false positive, then verifies attempt (AI score preserved for analytics) | integration| `tests/integration/proctoring/test_reviewer_ai_disagreement.py` | Mock AI result (low score), reviewer verifies |
| All reviewers unavailable | Given no reviewer available andqueue exceeds SLA, when threshold breached, then escalationto enterprise admin and ops team, no auto-verify/reject | integration | `tests/integration/proctoring/test_reviewer_unavailable.py` | Time-mocked test (SLA breach, no reviewers) |
| Mass flagging event | Given provider AI flags > 50% of attempts in single exam, when spike detected, then alert fired toops team (possible AI model issue) | integration | `tests/integration/proctoring/test_mass_flagging.py` | Fixture: mass flagged attempts |
| Review of already-graded attempt | Given instructor manually released grade, when proctoring review rejects, then conflict flagged for instructor (no auto-override) | integration |`tests/integration/proctoring/test_grade_conflict.py` | Fixture: manually graded attempt, review rejects |
| GDPR deletion with pending review | Given deletion requestwhile attempt pending review, when processed, then deletion completes, attempt marked rejected with reason "data deleted per GDPR" | integration | `tests/integration/proctoring/test_gdpr_deletion_pending_review.py` | Fixture: pending review attempt |
| Provider retention mismatch | Given enterprise retention_days < provider minimum, when configured, then warning logged,actual retention period disclosed in consent | integration |`tests/integration/proctoring/test_retention_mismatch.py` | Mock enterprise config (short retention), Mock provider minimum |
| Cross-border data transfer | Given student in EU and provider in US, when consent displayed, then cross-border transferexplicitly disclosed | integration | `tests/integration/proctoring/test_cross_border_disclosure.py` | Mock student location (EU), Mock provider location (US) |
| Recording subpoena | Given recording subpoenaed, when chain-of-custody report generated, then links recording to attempt, identity verification, review outcome | integration | `tests/integration/proctoring/test_recording_chain_of_custody.py`| Mock subpoena request |
| Webhook rate limit exceeded | Given 1001 webhook requests in 1 min, when 1001st arrives, then HTTP 429 returned with Retry-After header | load | `tests/load/proctoring/test_webhook_rate_limit.py` | 1001 concurrent webhook requests |
| Provider API rate limit (HTTP 429) | Given provider returns429, when LMS retries, then respects Retry-After header, does not retry before specified time | integration | `tests/integration/proctoring/test_provider_rate_limit.py` | Mock provider API (429 with Retry-After) |
| Webhook duplicate delivery | Given same webhook delivered 3times, when processed, then first processes, second and third are no-ops (idempotency) | integration | `tests/integration/proctoring/test_webhook_idempotency.py` | Duplicate webhookpayloads |
| State transition idempotency | Given attempt in started state, when transition to started requested, then no-op (idempotent) | unit | `tests/unit/proctoring/test_state_transition_idempotency.py` | None |
| Identity verification idempotency | Given provider sends same verification result twice, when processed, then only one record stored | integration | `tests/integration/proctoring/test_verification_idempotency.py` | Duplicate verification results |

---

## Non-Functional Requirement (NFR) Tests

### Performance Tests

| NFR | Test Case | Type | File | Target |
|-----|-----------|------|------|--------|
| Environment check latency | Given student on environment check, when all checks run, then completes within 30s at p95 |load | `tests/load/proctoring/test_environment_check_performance.py` | p95 <= 30s |
| Identity verification latency | Given student submits photoID, when provider processes, then result returned within 60sat p95 | load | `tests/load/proctoring/test_identity_verification_performance.py` | p95 <= 60s (provider-dependent) |
| Exam state transition latency | Given state transition occurs, when propagated to provider, then completes within 2s atp95 | load | `tests/load/proctoring/test_state_transition_performance.py` | p95 <= 2s |
| Webhook processing latency | Given webhook received, when processed, then completes within 5s at p95 | load | `tests/load/proctoring/test_webhook_processing_performance.py` | p95 <=5s |
| Review dashboard load time | Given review queue with 100 items, when dashboard loads, then completes within 3s at p95 |load | `tests/load/proctoring/test_review_dashboard_performance.py` | p95 <= 3s |
| Concurrent sessions (500) | Given 500 concurrent proctoredsessions, when system under load, then p95 latency increase <= 20% vs 50 concurrent | load | `tests/load/proctoring/test_500_concurrent_sessions.py` | p95 latency increase <= 20% |
| Grade release latency | Given attempt verified, when gradereleased to gradebook, then completes within 5 min | integration | `tests/integration/proctoring/test_grade_release_performance.py` | <= 5 min |

### Reliability Tests

| NFR | Test Case | Type | File | Target |
|-----|-----------|------|------|--------|
| Proctoring availability | Given proctoring system, when measured over time, then available 99.9% during exam windows | monitoring | Manual verification via Grafana dashboard | 99.9%uptime |
| Provider API unreachable | Given provider API down, when exam start attempted, then blocked, exams in progress not interrupted | integration | `tests/integration/proctoring/test_provider_outage.py` | No new starts, in-progress continue |
| Network connectivity loss | Given network lost during exam,when connectivity drops, then answers preserved locally, resume allowed on restore within time limit | e2e | `tests/e2e/proctoring/test_network_loss_recovery.py` | Local preservation+ resume |
| Webhook retry | Given webhook delivery fails, when providerretries, then LMS processes idempotently (same callback twice = same outcome) | integration | `tests/integration/proctoring/test_webhook_idempotency.py` | Idempotent processing |
| Provider outage > 15 min | Given provider down > 15 min during exam window, when threshold breached, then alert to enterprise admin, option to extend window or allow unproctored | integration | `tests/integration/proctoring/test_provider_extended_outage.py` | Alert fired, options provided |
| Atomic state transitions | Given state change with side effects (event, notification), when transaction fails, then allrolled back | integration | `tests/integration/proctoring/test_state_transaction_atomicity.py` | Full rollback on error |

### Security Tests

| NFR | Test Case | Type | File | Target |
|-----|-----------|------|------|--------|
| TLS version | Given provider API communication, when inspected, then uses TLS 1.2 or higher | security | `tests/security/proctoring/test_tls_version.py` | TLS >= 1.2 |
| Credential encryption at rest | Given provider credentialsstored, when database inspected, then encrypted with AES-256| security | `tests/security/proctoring/test_credential_encryption.py` | AES-256 encryption |
| Webhook signature validation | Given webhook with invalid HMAC-SHA256 signature, when received, then rejected with HTTP| security | `tests/security/proctoring/test_webhook_signature.py` | Invalid signature rejected |
| Webhook signature bypass attempts | Given malformed/missing/forged signature, when webhook received, then all rejected |security | `tests/security/proctoring/test_webhook_signature_bypass.py` | All bypass attempts fail |
| Review dashboard RBAC | Given user without proctor_reviewerrole, when dashboard accessed, then 403 Forbidden returned |security | `tests/security/proctoring/test_review_dashboard_rbac.py` | Non-reviewer blocked |
| Review action authentication | Given review action requested, when auth checked per request (no cached session), then authenticated and authorized | security | `tests/security/proctoring/test_review_action_auth.py` | Per-request auth |
| No recordings stored locally | Given proctoring session, when LMS database/filesystem inspected, then zero recordings, photo IDs, biometric data stored | security | `tests/security/proctoring/test_no_local_recordings.py` | Zero sensitive datalocally |
| Webhook rate limit | Given 1001 webhook requests/min, whenthreshold exceeded, then HTTP 429 returned | security | `tests/security/proctoring/test_webhook_rate_limit.py` | Rate limit enforced |
| Authentication failure logging | Given proctoring API authfails, when logged, then includes source IP, endpoint, failure reason | security | `tests/security/proctoring/test_auth_failure_logging.py` | Full logging of auth failures |
| Metadata encryption in transit | Given proctoring metadatatransmitted, when inspected, then TLS-encrypted | security |`tests/security/proctoring/test_metadata_encryption_transit.py` | TLS encryption |
| Metadata encryption at rest | Given proctoring metadata indatabase, when inspected, then database encryption enabled |security | `tests/security/proctoring/test_metadata_encryption_rest.py` | Database encryption |
| No credentials in logs | Given proctoring logs, when inspected, then zero API credentials, no credentials in error messages or responses | security | `tests/security/proctoring/test_no_credentials_in_logs.py` | Zero credential exposure |

---

## Test Fixtures

### Common Fixtures (`tests/conftest.py`)

- `db`: Test database (MySQL or PostgreSQL)
- `mock_proctorio_api`: Mock Proctorio REST API client
- `mock_examity_api`: Mock Examity REST API client
- `mock_proctortrack_api`: Mock ProctorTrack REST API client
- `mock_respondus_api`: Mock Respondus Server API client
- `mock_email_service`: Mock email delivery service
- `mock_alert_service`: Mock alert notification service (Slack/PagerDuty)
- `test_enterprise_a`: Fixture for enterprise A data (Proctorio enabled)
- `test_enterprise_b`: Fixture for enterprise B data (Examityenabled)
- `platform_admin_user`: Platform superuser
- `proctoring_admin_user`: User with proctoring_admin role
- `proctor_reviewer_user_a`: Reviewer authorized for enterprise A
- `proctor_reviewer_user_b`: Reviewer authorized for enterprise B
- `student_user`: Standard student user
- `test_exam_proctored`: Fixture for proctored exam (Proctorio, 60 min time limit)
- `test_exam_practice`: Fixture for practice proctored exam
- `test_exam_onboarding`: Fixture for onboarding exam
- `test_attempt_created`: Fixture for attempt in created state
- `test_attempt_ready_to_start`: Fixture for attempt in ready_to_start state
- `test_attempt_started`: Fixture for attempt in started state
- `test_attempt_submitted`: Fixture for attempt in submittedstate
- `test_attempt_verified`: Fixture for attempt in verified state
- `test_attempt_rejected`: Fixture for attempt in rejected state
- `test_identity_verification_passed`: Fixture for passed identity verification
- `test_identity_verification_failed`: Fixture for failed identity verification
- `test_consent_record`: Fixture for consent record

---

## Test Coverage Verification

After implementing all tests, verify coverage:

```bash
cd lms/djangoapps/proctoring_mereka
pytest --cov=. --cov-report=html --cov-report=term tests/
```

**Target**: >=90% coverage for all critical paths (provider backends, state machine, review workflow, grading integration,identity verification, environment check)

**Exclusions**: External provider API clients are mocked, sotheir internal logic is not covered (intentional)

---

## CI/CD Integration

Add to CI pipeline (`.github/workflows/test.yml` or similar):

```yaml
test-proctoring:
  stage: test
  script:
    - cd lms/djangoapps/proctoring_mereka
    - pytest tests/unit/ tests/integration/ --cov=. --cov-report=xml --cov-report=term
    - pytest tests/security/ --strict
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
```

**Security tests MUST pass** (no bypass vulnerabilities allowed)

**Load tests run nightly** (not on every commit)

**E2E tests run pre-deployment** (staging environment)

---

## Manual Test Cases (Not Automated)

Some tests require manual verification due to external dependencies:

1. **Provider Dashboard Verification**: After E2E test, verify provider dashboard (Proctorio, Examity, etc.) shows correctsession, recording, metadata
2. **Browser Extension Installation**: Manually verify Proctorio/Respondus extension installation instructions are correctand functional
3. **Live Proctor Communication (Examity)**: Manually verifylive proctor chat works correctly during exam
4. **Grafana Dashboard Verification**: After metrics test, verify dashboards display correct proctoring data
5. **Alert Firing Verification**: Trigger alert condition (e.g., active sessions > 500), verify Slack/PagerDuty alert is received
6. **Student-Facing Documentation**: Manual review of student-facing proctoring guide for clarity and accuracy
7. **Consent Notice Legal Review**: Legal team review of consent notice text for GDPR/FERPA compliance

These manual tests are documented in the runbook (`docs/runbooks/proctoring-operations-runbook.md`)

---

## Test Data Management

**Test Database**: Separate MySQL/PostgreSQL instance for tests, reset between test runs

**Provider API Mocks**: All provider API calls use mock responses (no real provider calls in automated tests)

**No-op Backend**: Use for E2E tests (simulates full flow without external APIs)

**Test Users**: Ephemeral test users, deleted after test run

**Cleanup**: All test data is ephemeral, deleted after test run

---

## Summary

**Total Test Cases**: 128+ (38 AC tests + 40 edge case tests+ 7 performance tests + 6 reliability tests + 13 security tests + 24 additional integration tests)

**By Type**:
- Unit: 28 tests
- Integration: 68 tests
- E2E: 8 tests
- Load: 11 tests
- Security: 13 tests

**By AC Coverage**:
- All 38 acceptance criteria have at least one test
- All edge cases have negative tests
- All NFRs (performance, reliability, security) have tests

**Test Execution Time**: <15 minutes (unit + integration), ~4minutes (all tests including E2E and load)

**Test Stability**: All tests MUST be deterministic (no flakytests allowed)

**Test Maintenance**: Testmap YAML tracks AC → test mapping for automated coverage verification

---

## Testmap Integration

All tests in this plan are mapped to acceptance criteria in `specs/_generated/testmaps/proctoring-integration_spec.testmap.yml` for traceability and automated coverage verification.

Verify coverage:
```bash
python ~/projects/team-skills/plugins/core/skills/specs-vs-docs/tools/check_test_coverage.py specs/_generated/testmaps/proctoring-integration_spec.testmap.yml
```

---

## When Implementation Begins

1. Write tests alongside code (TDD where appropriate)
2. Start with unit tests for foundational components (registry, state machine)
3. Build up to integration tests (provider backends, review workflow)
4. E2E tests last (full proctored exam flow)
5. Load and security tests before production rollout
6. Update testmap YAML as tests are implemented
7. Verify 90%+ coverage before each phase deployment

This test plan is ready for execution when the proctoring integration project begins in 2027 or later.
