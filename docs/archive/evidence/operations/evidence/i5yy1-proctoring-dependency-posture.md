# Proctoring Lane Dependency Posture

> **Bead**: mereka-lms-i5yy.1
> **AC**: AC-OPS-003
> **Date**: 2026-02-18
> **Parent bead**: mereka-lms-i8lo (38 ACs, EXTERNAL BLOCKED)

---

## Current Status

**i8lo is EXTERNALLY BLOCKED on vendor contract.**

No LMS code changes can proceed until a proctoring provider contract is signed. This is an intentional external dependency, not a platform defect.

---

## External Blockers (Explicit and Actionable)

| Blocker | Type | Blocking | Unblock Path |
|---------|------|---------|--------------|
| Vendor contract not signed | Legal/Commercial | All 38 proctoring ACs | Contract execution |
| Examity API credentials | Credentials | AC-001, AC-002 (Examity backend) | Add to GCP SM post-contract |
| Respondus LockDown Browser key | Credentials | AC-003, AC-017 (LDB enforcement) | Add to GCP SM post-contract |
| Proctorio app key | Credentials | AC-018, AC-019 (Proctorio flags) | Add to GCP SM post-contract |

---

## Infrastructure Readiness (Pre-Contract)

All platform infrastructure for proctoring is **READY** — no additional development needed before contract:

| Component | Status |
|-----------|--------|
| `edx-proctoring` library | Installed and active in LMS |
| `PROCTORED_EXAM_SETTINGS_ENABLED` flag | Configurable via env |
| `PROCTORED_EXAMS_ATTEMPT_DELETE_TIMEOUT_SECONDS` | Configurable |
| GCP SM secret slots for provider keys | Ready (empty, awaiting contract) |
| ExternalSecrets wiring | Present (`deploy/k8s/base/secrets/external-secrets.yaml`) |
| Callback endpoint | Exists at `/api/edx_proctoring/v1/proctored_exam/review/` |
| Per-tenant backend config | Supported via `EnterpriseCustomer` settings |

---

## Execution Plan (Post-Contract)

When contract is signed, assign `mereka-lms-i8lo` with this pre-mapped checklist:

1. Add provider credentials to GCP SM + Infisical
2. Update `PROCTORING_BACKENDS` in `infrastructure/tutor/apply-patches.sh`
3. Set `ENABLE_PROCTORED_EXAMS=True` in LMS settings
4. Configure Celery beat schedule for auto-expiry (AC-022)
5. Implement `on_review_callback()` handler (AC-004)
6. Run `verify-proctoring.sh`, `verify-proctoring-environment.sh`, `verify-proctoring-advanced.sh`
7. Close i8lo children in sequence per `docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md`

**Estimated effort once unblocked**: 2-3 days (all code changes pre-mapped in PROCTORING_IMPLEMENTATION_READINESS.md)

---

## References

- `docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md` — full AC execution checklist
- `docs/status/readiness/PROCTORING_VENDOR_READINESS.md` — vendor onboarding requirements
- `docs/architecture/proctoring-architecture-overview.md` — architecture overview
- `docs/ops/runbooks/proctoring-operations-runbook.md` — operational runbook
