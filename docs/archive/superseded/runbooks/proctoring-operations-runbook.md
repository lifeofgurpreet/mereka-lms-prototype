# Proctoring Operations Runbook
_Audience: Platform Eng + Academic Operations • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for proctoring integration in Mereka Academy.

> **Status**: Proctoring is **not yet implemented** (Tier 5). This runbook documents target-state procedures.
> **Spec**: `specs/proposals/proctoring-integration_spec.md`
> **Testmap**: `specs/testmaps/proctoring-integration_spec.testmap.yml`

## Prerequisites

- Proctoring provider account (LockDown Browser, Proctorio, or equivalent)
- LMS admin access with proctoring feature flags enabled
- Studio access for exam configuration

---

## Verification > Browser Lockdown

### Procedure
1. Install LockDown Browser on test machine
2. Navigate to a proctored exam in LMS
3. Verify browser lockdown activates:
   - Other applications are blocked
   - Copy/paste is disabled
   - Screen sharing is blocked
   - Right-click is disabled
4. Complete the exam and verify lockdown releases

### VM Environment Testing
1. Launch exam from within a VM
2. Verify VM detection triggers (if configured)
3. Verify appropriate warning/block behavior

### Proctorio Extension Testing
1. Install Proctorio Chrome extension
2. Navigate to a Proctorio-configured exam
3. Verify extension activates and captures required data

### Acceptance
- Browser lockdown engages for proctored exams
- Lockdown releases cleanly after exam submission
- Non-proctored exams are not affected
- VM detection works according to configuration

---

## Verification > Exam Setup

### Procedure
1. Log in to Studio as a course instructor
2. Create a new proctored exam:
   - Set exam type to "Proctored"
   - Configure time limit
   - Set proctoring provider
3. Publish the exam
4. Verify exam appears in LMS with proctoring badge

### Acceptance
- Proctored exam can be created in Studio
- Exam type and time limit are configurable
- Published exam shows proctoring requirements to students
- Exam settings persist across page refreshes

---

## Verification > Environment Check

### Pre-Exam System Check
1. Navigate to a proctored exam as a student
2. Verify system requirements check runs:
   - Browser version check
   - Camera/microphone permission request
   - Screen resolution check
   - Bandwidth test (if configured)
3. Verify clear pass/fail feedback

### UI Rendering
1. Verify environment check UI renders correctly on:
   - Chrome (latest)
   - Firefox (latest)
   - Edge (latest)
2. Verify mobile devices show "not supported" message

### Acceptance
- Environment check identifies system issues before exam start
- Clear guidance provided for failing checks
- Permission prompts are standard browser dialogs
- Unsupported browsers show informative message

---

## Verification > Resilience

### Network Interruption
1. Start a proctored exam
2. Simulate network interruption (disconnect WiFi for 30 seconds)
3. Verify exam state is preserved
4. Verify reconnection restores exam progress
5. Verify proctoring recording handles gaps gracefully

### Acceptance
- Brief network interruptions do not terminate the exam
- Exam progress is saved locally during interruption
- Proctoring provider handles recording gaps appropriately
- Student receives clear notification of connection issues

---

## Verification > Compliance

### Content Verification
1. Review proctoring-related content displayed to students:
   - Privacy notice before starting proctored exam
   - Data collection disclosure
   - Terms of service acceptance
2. Verify content matches approved legal text
3. Verify student must acknowledge before proceeding

### Acceptance
- Privacy notice is displayed before every proctored exam
- Consent is recorded with timestamp
- Students can opt out (if policy allows) with clear consequences explained

---

## Verification > GDPR

### Data Subject Requests
1. Verify process for handling GDPR data subject requests:
   - Data export request
   - Data deletion request
2. Coordinate with proctoring provider for data held on their systems
3. Verify response timeline meets GDPR requirements (30 days)

### Quarterly Audit
1. Review proctoring data retention policies
2. Verify data is deleted according to retention schedule
3. Confirm no PII is stored beyond the retention period
4. Document audit results

### Acceptance
- Process exists for handling data subject requests
- Proctoring provider confirms data deletion upon request
- Audit trail exists for all data handling actions
- Retention schedule is enforced automatically where possible
