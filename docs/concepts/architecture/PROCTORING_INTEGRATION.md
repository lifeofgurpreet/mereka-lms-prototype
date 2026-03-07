# Proctoring Integration Architecture
_Audience: Developers, Site Operators • Owner: Platform Team • Last updated: 2026-02-24_

**Status**: Proctoring integration is **deferred** (Tier 6). This document describes the target-state architecture for future implementation. No proctoring provider is currently contracted.

Spec: `specs/proctoring-integration_spec.md` (38 ACs)

---

## Provider Options

Open edX's `edx-proctoring` package supports a pluggable backend interface. Each provider fits a different use-case profile:

| Provider | Mode | Lockdown | Identity | Review | Best For |
|----------|------|----------|----------|--------|----------|
| **Examity** | Live proctor | No | Photo ID + face | Human | High-stakes, regulatory |
| **Respondus LDB** | Desktop app | Full OS | No | Instructor | Institutional exams |
| **ProctorTrack** | AI + live | Partial | Facial recognition | AI → human escalation | Enterprise volume |
| **Proctorio** | AI only | Browser ext. | Facial recognition | AI only | Scale / cost-sensitive |

All four are integrated via the `ProctoringBackendProvider` plugin interface. Provider selection is per-enterprise-tenant — Enterprise A may use Examity while Enterprise B uses Proctorio.

---

## Integration Architecture

```
┌──────────────────────────────────────────────────────┐
│                Studio (Course Authoring)              │
│  Subsection → Edit → Exam Type: Proctored            │
│  Configures: time_limit, provider, review_policy     │
└─────────────────────┬────────────────────────────────┘
                      │ modulestore (MongoDB Atlas)
                      ▼
┌──────────────────────────────────────────────────────┐
│                LMS (Learner Exam Flow)                │
│                                                      │
│  ┌───────────────────────────────────────────────┐   │
│  │          edx-proctoring Django App            │   │
│  │  Models: ProctoredExam, StudentAttempt,       │   │
│  │          ReviewPolicy                         │   │
│  │  APIs:   /api/edx_proctoring/v1/...           │   │
│  │  State:  created → ready → started →          │   │
│  │          submitted → verified | rejected      │   │
│  └─────────────┬─────────────────────────────────┘   │
└────────────────┼─────────────────────────────────────┘
                 │ PROCTORING_BACKENDS[enterprise_uuid]
    ┌────────────┼──────────────┬────────────────┐
    ▼            ▼              ▼                ▼
┌────────┐ ┌──────────┐ ┌────────────┐ ┌──────────┐
│Examity │ │ Respondus│ │ProctorTrack│ │Proctorio │
│  API   │ │  LDB App │ │   API      │ │  Ext.    │
└───┬────┘ └────┬─────┘ └─────┬──────┘ └────┬─────┘
    │           │             │              │
    └───────────┴─────────────┴──────────────┘
                      │ Webhooks
                      ▼
         /api/edx_proctoring/v1/proctored_exam/callback/
                      │
                      ▼
              Gradebook integration
        (ProctoredExamStudentAttempt.status
         → subsection grade calculation)
```

### XBlock Integration
Proctoring hooks into the LMS via the XBlock runtime. When a learner opens a subsection marked as proctored:
1. The LMS checks `ProctoredExam.exam_type` for the current subsection.
2. If proctored: the XBlock renders the pre-exam flow instead of the content.
3. `edx-proctoring` calls `ProctoringBackendProvider.start_exam_attempt()` to create a session with the provider.
4. On exam complete: `stop_exam_attempt()` is called and the attempt transitions to `submitted`.

### LTI Integration Note
Proctoring does **not** use LTI. Provider communication is via direct REST APIs and webhooks, not the LTI launch protocol. LTI is used separately for third-party content tools.

### Webhook Flow
Providers call back to the LMS after review completion:

```
Provider → POST /api/edx_proctoring/v1/proctored_exam/review_callback/
                { attempt_id, status: "verified"|"rejected", reason, ... }

LMS:
  1. Validate HMAC signature (MEREKA_LMS_PROCTORING_WEBHOOK_SECRET)
  2. Locate ProctoredExamStudentAttempt by attempt_id
  3. Update attempt.status
  4. Trigger gradebook sync (Celery task, within 5 min)
```

---

## Configuration Requirements

### Django Settings (LMS production.py)

```python
# Enable proctored exam infrastructure
FEATURES["ENABLE_SPECIAL_EXAMS"] = True
FEATURES["ENABLE_PROCTORED_EXAMS"] = True

# Provider backends (one entry per contracted provider)
PROCTORING_BACKENDS = {
    "null": {},           # Development / no-op backend
    "software_secure": {"secret_key": env("PROCTORING_WEBHOOK_SECRET")},
    "proctorio": {
        "client_id": env("PROCTORING_PROCTORIO_CLIENT_ID"),
        "private_key": env("PROCTORING_PROCTORIO_PRIVATE_KEY"),
        "lock_fullscreen": True,
        "disable_clipboard": True,
    },
    "examity": {
        "api_url": "https://api.examity.com/v4",
        "client_id": env("PROCTORING_EXAMITY_API_KEY"),
        "client_secret": env("PROCTORING_EXAMITY_API_SECRET"),
    },
}

# Default backend for new proctored exams
PROCTORING_BACKEND_PROVIDER = "null"   # Change to "proctorio" or "examity" after onboarding
```

### Secrets (Infisical → GCP SM → ExternalSecrets → K8s)

Add to `deploy/k8s/base/secrets/external-secrets.yaml` when a provider is onboarded:

| Infisical Key | Mapped K8s Secret Key | Purpose |
|---------------|-----------------------|---------|
| `MEREKA_LMS_PROCTORING_WEBHOOK_SECRET` | `proctoring-webhook-secret` | HMAC validation for provider callbacks |
| `MEREKA_LMS_PROCTORING_EXAMITY_API_KEY` | `examity-api-key` | Examity API authentication |
| `MEREKA_LMS_PROCTORING_EXAMITY_API_SECRET` | `examity-api-secret` | Examity API authentication |
| `MEREKA_LMS_PROCTORING_PROCTORTRACK_API_KEY` | `proctortrack-api-key` | ProctorTrack API authentication |

### K8s Network Prerequisites

- LMS `Ingress` must expose `/api/edx_proctoring/` externally (Caddy already routes this path).
- Provider webhook IPs must be allowed through any IP allowlist or WAF rules.
- Proctoring provider callbacks use HTTPS. TLS termination at Caddy; no additional config needed.

---

## Security and Privacy Considerations

### Data Collected by Providers
| Data Type | Collected By | Stored Where | Retention |
|-----------|-------------|--------------|-----------|
| Webcam video | Provider extension/app | Provider cloud | 30–90 days |
| Screen recording | Provider extension/app | Provider cloud | 30–90 days |
| Microphone audio | Provider extension/app | Provider cloud | 30–90 days |
| Photo ID scan | Provider onboarding flow | Provider cloud | Per provider policy |
| Facial feature vectors | Provider AI model | Provider cloud | Per provider policy |
| Exam metadata (attempt, timestamps) | LMS | MySQL (Cloud SQL) | Per data retention policy |

**Mereka infrastructure does not store recordings.** All media is stored and processed by the contracted provider.

### Consent Requirements (AC-036, AC-037)
Before a learner can start a proctored exam, `edx-proctoring` displays a consent notice that must include:
- What data is collected (video, audio, screen, photo ID)
- Who has access (provider, enterprise customer, Mereka)
- Data retention period
- Right to refuse (with consequence: cannot take proctored exam)
- Contact for data queries

Acceptance is recorded in `ProctoredExamStudentAttempt.taking_as_proctored` (timestamp + user ID). If the learner does not consent, exam start is blocked.

### GDPR / PDPA Obligations (AC-035, AC-038)
- **DSAR (Data Subject Access Request)**: Must surface all `ProctoredExamStudentAttempt` records for the user, plus coordinate with the provider for recording access. SLA: 30 days.
- **Right to Erasure**: Delete `ProctoredExamStudentAttempt` rows for the user; forward erasure request to provider. Scoped to the individual user — other users' data must not be affected.
- **DPA (Data Processing Agreement)**: Required with each provider before go-live. Mereka as data controller; provider as data processor.

### Authentication and Secrets
- Provider webhook callbacks are authenticated with HMAC-SHA256 (`MEREKA_LMS_PROCTORING_WEBHOOK_SECRET`).
- Provider API credentials are per-tenant, stored in Infisical and injected via ExternalSecrets. Never hardcoded.
- Provider routing uses `enterprise_customer_uuid` from the learner's session to select the correct backend credentials — credential cross-contamination between tenants is prevented by the `PROCTORING_BACKENDS` keying structure in `edx-proctoring`.

---

## Deployment Prerequisites

Before activating proctoring for any enterprise customer, the following must be complete:

### Infrastructure (Platform Team)
- [ ] `ENABLE_SPECIAL_EXAMS = True` in LMS production settings
- [ ] `ENABLE_PROCTORED_EXAMS = True` in LMS production settings
- [ ] `PROCTORING_BACKENDS` dict includes the contracted provider key
- [ ] Provider secrets added to Infisical, GCP Secret Manager, and ExternalSecrets
- [ ] Webhook endpoint reachable externally (verify with provider's ping test)
- [ ] HMAC webhook secret rotated and stored securely

### Compliance (Legal + Security)
- [ ] Data Processing Agreement signed with provider
- [ ] Privacy notice updated to reference proctoring data flows
- [ ] GDPR/PDPA impact assessment completed
- [ ] Learner consent notice reviewed by legal

### Operational Readiness
- [ ] `docs/operations/PROCTORING_VENDOR_READINESS.md` updated with provider details
- [ ] Runbook (`docs/ops/runbooks/PROCTORING_RUNBOOK.md`) reviewed and approved
- [ ] Grafana alert added for webhook delivery failures
- [ ] Exam attempt state machine tested with no-op backend in staging
- [ ] Provider support contact and escalation path documented

### Per-Enterprise Configuration
- [ ] `enterprise_customer_uuid` → provider mapping configured in `PROCTORING_BACKENDS`
- [ ] `TenantConfig` updated with `proctoring_backend` field (when multi-tenancy is live)
- [ ] Studio users briefed on how to configure a proctored subsection
- [ ] Learner-facing help content updated

---

## Related Files

| File | Purpose |
|------|---------|
| `specs/proctoring-integration_spec.md` | 38-AC machine-checkable specification |
| `docs/concepts/architecture/proctoring-architecture-overview.md` | Detailed component diagram + data flows |
| `docs/operations/PROCTORING_VENDOR_READINESS.md` | Provider evaluation matrix |
| `docs/ops/runbooks/PROCTORING_RUNBOOK.md` | Operational runbook |
| `scripts/qa/verify-proctoring-integration.sh` | Consolidated verification script |
| `scripts/qa/verify-proctoring.sh` | Core AC verification (AC-001–002, 006–008, 020–022, 036–038) |
| `scripts/qa/verify-proctoring-environment.sh` | Browser/environment AC verification (AC-003, 014–019, 023) |
| `scripts/qa/verify-proctoring-advanced.sh` | Provider/review AC verification (AC-004–005, 009–013, 016, 024–035) |
