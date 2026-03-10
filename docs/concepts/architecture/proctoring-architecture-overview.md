# Proctoring Integration Architecture Overview
_Audience: Engineering + Architecture • Last updated: 2026-02-10_

## System Overview

The proctoring integration layer enables enterprise clients to administer secure, monitored examinations by integrating with third-party proctoring providers (Examity, Respondus, ProctorTrack, Proctorio). Built on Open edX's pluggable `edx-proctoring` backend architecture, the system adds exam setup workflows, identity verification, browser lockdown, screen/webcam recording, AI-based integrity analysis, and proctor review workflows. Each enterprise client configures their preferred provider and policies independently.

**Key differentiator**: Multi-tenant proctoring with per-enterprise provider selection and policy configuration, zero custom proctoring technology (leverage best-in-class third-party services).

> **Status**: Proctoring integration is **deferred** (Tier 6). This architecture documents target state for future implementation.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Studio (Course Authoring)                    │
│  - Configure exam as "proctored" or "timed"                     │
│  - Set proctoring rules (lockdown, time limit, allowed resources)│
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                LMS (Learner Exam Flow)                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ edx-proctoring Django App                                │   │
│  │ - Exam lifecycle (created → ready → started → submitted) │   │
│  │ - Proctoring provider router (per enterprise)            │   │
│  │ - Attempt tracking and status management                 │   │
│  └────────────────────┬─────────────────────────────────────┘   │
└───────────────────────┼─────────────────────────────────────────┘
                        │
       ┌────────────────┼────────────────┬────────────────┐
       │                │                │                │
       ▼                ▼                ▼                ▼
┌──────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────┐
│ Examity  │  │  Respondus   │  │ ProctorTrack │  │Proctorio │
│  (Live)  │  │  (Lockdown)  │  │    (AI)      │  │  (AI)    │
└────┬─────┘  └────┬─────────┘  └────┬─────────┘  └────┬─────┘
     │            │                   │                 │
     │ Webhook    │ Webhook           │ Webhook         │ Webhook
     └────────────┴───────────────────┴─────────────────┘
                        │
                        ▼
         ┌──────────────────────────────┐
         │   Proctoring Backend         │
         │   (edx-proctoring plugin)    │
         │   - Identity verification    │
         │   - Session recording        │
         │   - Review flagging          │
         │   - Result integration       │
         └──────────┬───────────────────┘
                    │
                    ▼
         ┌──────────────────────────────┐
         │   Gradebook Integration      │
         │   - Exam score + integrity   │
         │   - Review status visible    │
         │   - Grade policy enforcement │
         └──────────────────────────────┘

Data Flow:
┌──────────────────────────────────────────────────────────────┐
│ Learner → Pre-exam check → Identity verification → Exam     │
│ start → Recording (screen/webcam/audio) → Exam submit →     │
│ AI analysis → Proctor review (if flagged) → Result to LMS → │
│ Gradebook update                                             │
└──────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Exam Setup Flow (Course Author)
1. **Author** creates exam in Studio (Problem block)
2. **Author** enables proctoring: **Settings** → **Proctored Exam**
3. **Author** configures:
   - Time limit (e.g., 120 minutes)
   - Review policy (AI-only, live proctor, hybrid)
   - Allowed resources (open book, closed book, calculator)
4. **Studio** saves config to courseware modulestore (MongoDB)
5. **LMS** reads config when learner accesses exam unit

### Pre-Exam Check Flow (Learner)
1. **Learner** navigates to exam unit in LMS
2. **LMS** checks if learner has active proctoring attempt → **NO**
3. **LMS** displays "Start Proctored Exam" button
4. **Learner** clicks button → redirected to proctoring provider onboarding
5. **Provider** (e.g., Proctorio) prompts:
   - Install browser extension (Respondus/Proctorio)
   - Grant webcam/microphone/screen share permissions
   - Verify environment (close extra tabs, no external monitors)
   - Upload photo ID
6. **Provider** performs identity verification (facial recognition match)
7. **Provider** calls LMS webhook: `exam_ready` with session token
8. **LMS** creates `ProctoredExamStudentAttempt` (status: `ready`)
9. **Learner** clicks "Start Exam" → exam timer starts

### Exam Session Flow
1. **Learner** takes exam while proctoring software monitors:
   - Screen recording (captures all on-screen activity)
   - Webcam recording (face tracking, gaze detection)
   - Audio recording (detects multiple voices)
   - Browser lockdown (prevents tab switching, copy/paste)
2. **Provider** streams telemetry to cloud (or records locally)
3. **Provider** AI analyzes in real-time:
   - Face absent from frame → flag
   - Multiple faces detected → flag
   - Audio anomalies (conversation) → flag
   - Tab switch attempts → flag
4. **Learner** completes exam, clicks "Submit"
5. **LMS** updates attempt (status: `submitted`)
6. **Provider** finalizes recording, runs full AI analysis

### Review Flow
1. **Provider** AI generates incident report:
   - Timestamps of flagged events
   - Severity score (low/medium/high)
   - Video clips of suspicious behavior
2. **If high severity**: Provider notifies human proctor
3. **Proctor** reviews session recording (video, audio, screen)
4. **Proctor** makes decision:
   - `verified` (no violations, exam is valid)
   - `rejected` (violations detected, exam is invalid)
   - `second_review_required` (needs additional review)
5. **Provider** calls LMS webhook: `exam_reviewed` with status
6. **LMS** updates attempt (status: `verified` or `rejected`)
7. **Gradebook** applies grade:
   - `verified` → exam score counted
   - `rejected` → exam score = 0, re-take allowed

---

## Integration Points

### edx-proctoring Django App
- **Package**: `edx-proctoring` (Open edX standard)
- **Models**:
  - `ProctoredExam` (exam config, provider, time limit)
  - `ProctoredExamStudentAttempt` (learner session, status, result)
  - `ProctoredExamReviewPolicy` (review rules per exam)
- **APIs**:
  - `POST /api/edx_proctoring/v1/proctored_exam/attempt` - Start exam
  - `PUT /api/edx_proctoring/v1/proctored_exam/attempt/{id}` - Submit/stop exam
  - `GET /api/edx_proctoring/v1/proctored_exam/attempt/{id}/status` - Get status

### Proctoring Provider Backends (Plugins)
- **Interface**: `ProctoringBackendProvider` (plugin interface)
- **Implementations**:
  - `examity` - Examity live/record+review proctoring
  - `respondus` - Respondus LockDown Browser
  - `proctortrack` - Verificient ProctorTrack (AI + live)
  - `proctorio` - Proctorio (AI-only)
- **Methods**:
  - `start_exam_attempt()` - Create session with provider
  - `stop_exam_attempt()` - Finalize session
  - `get_exam_attempt_status()` - Poll provider for review result

### Proctoring Provider APIs
- **Examity**: `POST /api/v1/exams` (create session), webhook: `exam_completed`
- **Proctorio**: Browser extension (no HTTP API), webhook: `exam_reviewed`
- **Respondus**: Desktop app (no HTTP API), manual review dashboard
- **ProctorTrack**: `POST /api/v1/sessions` (create), webhook: `review_complete`

### Gradebook Integration
- **Subsection Grade Calculation**: Checks `ProctoredExamStudentAttempt.status`
- **If `verified`**: Use exam score from gradebook
- **If `rejected`**: Override score to 0, mark as "integrity violation"
- **If `pending_review`**: Show "pending" in gradebook, no grade yet

---

## Key Design Decisions

### 1. Build vs. Buy: Custom Proctoring vs. Third-Party
**Decision**: Integrate with third-party providers (no custom proctoring engine)

**Rationale**:
- **Expertise**: AI proctoring, facial recognition, live proctoring are specialized domains.
- **Compliance**: Third-party providers handle privacy/security compliance (GDPR, biometric data).
- **Cost**: Building custom AI models would cost millions; third-party services are $5-20 per exam.

**Trade-offs**:
- Vendor lock-in (switching providers requires re-integration).
- Ongoing per-exam fees (vs. one-time build cost).

### 2. Multi-Tenancy: Per-Tenant Providers vs. Platform-Wide Provider
**Decision**: Per-enterprise provider selection

**Rationale**:
- **Flexibility**: Enterprise A may prefer Examity (live proctor), Enterprise B may prefer Proctorio (AI-only).
- **Contracts**: Large clients may negotiate their own proctoring provider contracts.
- **Compliance**: Some clients require data residency (provider must store data in specific regions).

**Trade-offs**:
- Requires provider credentials per tenant (stored in Infisical).
- Must test integration with 4+ providers (vs. one platform-wide provider).

### 3. Browser Lockdown: Required vs. Optional
**Decision**: Optional (provider-dependent)

**Rationale**:
- **Accessibility**: Some learners cannot install Respondus LockDown Browser (BYOD restrictions).
- **Use case**: Low-stakes exams may not need lockdown (trust + honor code sufficient).
- **Provider support**: Not all providers offer browser lockdown (e.g., Examity requires live proctor, not lockdown).

**Trade-offs**:
- Weaker security for exams without lockdown (learners can Google answers).
- Inconsistent learner experience across exams.

### 4. Identity Verification: Photo ID vs. Facial Recognition Only
**Decision**: Photo ID + facial recognition (provider-dependent)

**Rationale**:
- **Fraud prevention**: Photo ID reduces exam proxy fraud (someone else taking exam).
- **Compliance**: High-stakes certifications (e.g., regulatory compliance) require ID verification.
- **Provider standard**: Most providers default to photo ID + face match.

**Trade-offs**:
- Privacy concerns (biometric data, ID scans stored by provider).
- Accessibility issues (learners without government-issued ID).

### 5. Review: Auto-Grade vs. Human Review
**Decision**: Hybrid (AI flags, human reviews high-severity only)

**Rationale**:
- **Scale**: Cannot afford human review for all exams (cost: $10-20 per review).
- **Accuracy**: AI false positive rate is ~10% (flags innocent behavior like looking away).
- **Trust**: Human review for high-stakes exams, auto-grade for low-stakes.

**Trade-offs**:
- Human review delays (24-48 hours for proctor review).
- AI false positives stress learners (flagged for innocent behavior).

---

## Security and Privacy Considerations

### Data Collection
- **Video**: Screen recording, webcam recording
- **Audio**: Microphone recording (detects multiple voices)
- **Biometric**: Facial recognition data (facial feature vectors)
- **Photo ID**: Uploaded ID scans (driver's license, passport)

### Data Storage
- **Provider servers**: All recordings stored by provider (not on Mereka infrastructure)
- **Retention**: Typically 30-90 days (configurable per provider)
- **Deletion**: GDPR right-to-be-forgotten requests forwarded to provider

### Consent
- **Explicit consent required**: Learner must agree to proctoring terms before exam
- **Consent record**: Stored in `ProctoredExamStudentAttempt` (timestamp, IP address)
- **Opt-out**: Learners can opt-out (but forfeit exam, no grade)

### Data Processing Agreements (DPAs)
- **Mereka ↔ Provider**: DPA required for each provider (GDPR/PDPA compliance)
- **Provider ↔ Learner**: Provider's privacy policy governs data usage
- **Enterprise ↔ Mereka**: Enterprise DPA includes proctoring data flows

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Pre-exam check latency | p95 <30s |
| Exam start latency (after check) | p95 <5s |
| AI review completion (after submit) | p95 <10 minutes |
| Human review completion | p95 <24 hours |
| Concurrent proctored sessions | 500 (no degradation) |
| Provider webhook processing | p95 <2s |

---

## Related Specs and ADRs
- **Spec**: `specs/proposals/proctoring-integration_spec.md`
- **Runbook**: `docs/archive/superseded/runbooks/proctoring-operations-runbook.md`
- **Architecture**: `docs/concepts/architecture/proctoring-architecture-overview.md`
- **Enterprise Services**: `specs/enterprise-microservices_spec.md`
- **Multi-Tenancy**: `specs/multi-tenancy-architecture_spec.md`
- **Secrets Management**: `specs/secrets-management_spec.md`
