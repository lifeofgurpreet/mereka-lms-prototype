# Proctoring Implementation Readiness

> **Bead**: mereka-lms-i8lo.2
> **Date**: 2026-02-18
> **Status**: PRE-IMPLEMENTATION — all code changes mapped, ready to execute on contract
> **Parent**: mereka-lms-i8lo (38 ACs)

## Purpose

This document maps every code change required to implement proctoring (38 ACs). When vendor contract is signed, assign `i8lo` to an agent and hand this doc as the execution checklist. No discovery work needed — everything is pre-mapped here.

---

## 1. AC Coverage Map (All 38 ACs)

| AC | Group | Verify Script | Status | Implementation Required |
|----|-------|--------------|--------|------------------------|
| AC-001 | Backend | `verify-proctoring.sh` | Infrastructure ready | Configure real backend in PROCTORING_BACKENDS |
| AC-002 | Backend | `verify-proctoring.sh` | Infrastructure ready | Add Examity credentials to GCP SM + ExternalSecret |
| AC-003 | Browser/LDB | `verify-proctoring-environment.sh` | Infrastructure ready | Add Respondus backend key to PROCTORING_BACKENDS |
| AC-004 | Callbacks | `verify-proctoring-advanced.sh` | Infrastructure ready | Implement `on_review_callback()` handler |
| AC-005 | No-op backend | `verify-proctoring-advanced.sh` | Infrastructure ready | Enable null backend for staging tests |
| AC-006 | Studio config | `verify-proctoring.sh` | Infrastructure ready | Set ENABLE_PROCTORED_EXAMS=True |
| AC-007 | Exam deadline | `verify-proctoring.sh` | Working (timed exams active) | No change needed |
| AC-008 | Per-tenant backend | `verify-proctoring.sh` | Infrastructure ready | Enterprise tenant config per provider |
| AC-009 | Course rerun | `verify-proctoring-advanced.sh` | Working (edx-platform) | No change needed |
| AC-010 | Identity verify | `verify-proctoring-advanced.sh` | Infrastructure ready | Provider onboarding + API integration |
| AC-011 | Identity retry | `verify-proctoring-advanced.sh` | Infrastructure ready | Provider onboarding + API integration |
| AC-012 | Identity store | `verify-proctoring-advanced.sh` | Infrastructure ready | Provider onboarding + API integration |
| AC-013 | Facial recognition | `verify-proctoring-advanced.sh` | Infrastructure ready | Provider onboarding + API integration |
| AC-014 | Webcam check | `verify-proctoring-environment.sh` | Infrastructure ready | Set ENABLE_PROCTORED_EXAMS=True |
| AC-015 | Env check | `verify-proctoring-environment.sh` | Infrastructure ready | Set ENABLE_PROCTORED_EXAMS=True |
| AC-016 | Network check | `verify-proctoring-advanced.sh` | Infrastructure ready | Provider-side (no LMS change) |
| AC-017 | LDB enforcement | `verify-proctoring-environment.sh` | Infrastructure ready | Add Respondus backend key |
| AC-018 | Proctorio flags | `verify-proctoring-environment.sh` | Infrastructure ready | Add lock_fullscreen/disable_clipboard to Proctorio config |
| AC-019 | VM detection | `verify-proctoring-environment.sh` | Infrastructure ready | Provider-side + webhook handler |
| AC-020 | State transitions | `verify-proctoring.sh` | Infrastructure ready | edx-proctoring handles (no custom code) |
| AC-021 | Submission state | `verify-proctoring.sh` | Infrastructure ready | edx-proctoring handles (no custom code) |
| AC-022 | Auto-expiry | `verify-proctoring.sh` | Infrastructure ready | edx-proctoring Celery task (configure beat) |
| AC-023 | Outage resilience | `verify-proctoring-environment.sh` | Infrastructure ready | edx-proctoring JS + MySQL state (no custom code) |
| AC-024 | State validation | `verify-proctoring-advanced.sh` | Infrastructure ready | edx-proctoring handles (no custom code) |
| AC-025 | Review isolation | `verify-proctoring-advanced.sh` | Infrastructure ready | Enterprise tenant scoping |
| AC-026 | Reviewer reject | `verify-proctoring-advanced.sh` | Infrastructure ready | ORA Grading MFE + edx-proctoring |
| AC-027 | Admin override | `verify-proctoring-advanced.sh` | Infrastructure ready | edx-proctoring admin + audit log |
| AC-028 | SLA warning | `verify-proctoring-advanced.sh` | Infrastructure ready | Review dashboard config |
| AC-029 | Grade on verify | `verify-proctoring-advanced.sh` | Infrastructure ready | edx-proctoring → gradebook |
| AC-030 | Grade on reject | `verify-proctoring-advanced.sh` | Infrastructure ready | edx-proctoring → gradebook |
| AC-031 | Override grade | `verify-proctoring-advanced.sh` | Infrastructure ready | edx-proctoring admin |
| AC-032 | Pending display | `verify-proctoring-advanced.sh` | Infrastructure ready | edx-proctoring MFE |
| AC-033 | Multi-tenant isolation | `verify-proctoring-advanced.sh` | Infrastructure ready | Per-tenant credential scoping |
| AC-034 | Per-tenant SLA | `verify-proctoring-advanced.sh` | Infrastructure ready | TenantConfig model |
| AC-035 | GDPR deletion | `verify-proctoring-advanced.sh` | Infrastructure ready | edx-proctoring + Open edX retire_user |
| AC-036 | Consent notice | `verify-proctoring.sh` | Infrastructure ready | edx-proctoring consent view |
| AC-037 | Consent gate | `verify-proctoring.sh` | Infrastructure ready | edx-proctoring consent middleware |
| AC-038 | GDPR DSAR | `verify-proctoring.sh` | Infrastructure ready | edx-proctoring + Open edX DSAR pipeline |

**Verify script coverage**: All 38 ACs covered across 3 scripts.

---

## 2. Code Changes Required (Ordered by Dependency)

### Step 1: Provider Selection + Secrets (Day 0 after contract)

```bash
# Create GCP SM secrets (bbi-k8 project)
# Replace <provider> with: proctorio, examity, proctortrack, or respondus_ldb
gcloud secrets create MEREKA_LMS_PROCTORING_BACKEND_API_KEY --project=bbi-k8
printf '%s' '<api-key-from-provider>' | \
  gcloud secrets versions add MEREKA_LMS_PROCTORING_BACKEND_API_KEY --data-file=- --project=bbi-k8

gcloud secrets create MEREKA_LMS_PROCTORING_BACKEND_API_SECRET --project=bbi-k8
printf '%s' '<api-secret-from-provider>' | \
  gcloud secrets versions add MEREKA_LMS_PROCTORING_BACKEND_API_SECRET --data-file=- --project=bbi-k8

# Optional: webhook secret if provider pushes callbacks
gcloud secrets create MEREKA_LMS_PROCTORING_WEBHOOK_SECRET --project=bbi-k8
printf '%s' '<webhook-secret>' | \
  gcloud secrets versions add MEREKA_LMS_PROCTORING_WEBHOOK_SECRET --data-file=- --project=bbi-k8
```

### Step 2: ExternalSecret Mapping

**File**: `deploy/k8s/base/secrets/external-secrets.yaml`

Add under `spec.data[]`:
```yaml
- secretKey: PROCTORING_BACKEND_API_KEY
  remoteRef:
    key: MEREKA_LMS_PROCTORING_BACKEND_API_KEY
- secretKey: PROCTORING_BACKEND_API_SECRET
  remoteRef:
    key: MEREKA_LMS_PROCTORING_BACKEND_API_SECRET
- secretKey: PROCTORING_WEBHOOK_SECRET
  remoteRef:
    key: MEREKA_LMS_PROCTORING_WEBHOOK_SECRET
```

### Step 3: LMS Settings Update

**File**: `deploy/k8s/base/apps/openedx/settings/lms/production.py`

Replace the current null backend block:
```python
# BEFORE (current)
PROCTORING_BACKENDS = {
    'DEFAULT': 'null',  # No-op backend for timed-only exams
}

# AFTER (Proctorio example)
PROCTORING_BACKENDS = {
    'DEFAULT': 'proctorio',
    'proctorio': {
        'client_id': os.environ.get('PROCTORING_BACKEND_API_KEY', ''),
        'client_secret': os.environ.get('PROCTORING_BACKEND_API_SECRET', ''),
        'base_url': 'https://api.proctorio.com',
        'lock_fullscreen': True,
        'disable_clipboard': True,
    }
}

# Enable proctored exams (not just timed)
FEATURES['ENABLE_PROCTORED_EXAMS'] = True
```

**For ProctorU** (alternative):
```python
PROCTORING_BACKENDS = {
    'DEFAULT': 'proctoru',
    'proctoru': {
        'student_login_url': 'https://go.proctoru.com/api/sessions',
        'client_id': os.environ.get('PROCTORING_BACKEND_API_KEY', ''),
        'client_secret': os.environ.get('PROCTORING_BACKEND_API_SECRET', ''),
    }
}
```

### Step 4: Celery Beat for Auto-Expiry (AC-022)

**File**: `deploy/k8s/base/apps/openedx/settings/lms/production.py`

```python
# edx-proctoring auto-expiry task (runs every 5 min)
CELERYBEAT_SCHEDULE['proctored-exam-completion-expired'] = {
    'task': 'edx_proctoring.tasks.clean_up_old_attempts',
    'schedule': crontab(minute='*/5'),
}
```

### Step 5: Enterprise Per-Tenant Config (AC-008, AC-033, AC-034)

**File**: `infrastructure/tutor/plugins/multi-tenancy/models.py`

Add proctoring fields to `TenantConfig`:
```python
proctoring_provider = models.CharField(
    max_length=64, blank=True, default='null',
    help_text="edx-proctoring backend name for this tenant (e.g. proctorio, proctoru)"
)
proctoring_review_sla_hours = models.IntegerField(
    default=48,
    help_text="SLA hours for proctoring review (AC-034)"
)
```

### Step 6: Rebuild + Deploy

```bash
./infrastructure/tutor/apply-patches.sh
tutor images build openedx -a PIP_COMMAND=pip
OPENEDX_TAG="$(date +%Y%m%d)-proctoring-$(git rev-parse --short HEAD)"
docker tag docker.io/overhangio/openedx:latest \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OPENEDX_TAG}
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OPENEDX_TAG}
./scripts/infra/canonical-release.sh \
  --openedx-tag ${OPENEDX_TAG} \
  --apply --commit --push --verify-runtime
```

### Step 7: Staging Verification

```bash
# Verify proctoring backend loaded
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from edx_proctoring.backends import get_backend_by_name
b = get_backend_by_name('proctorio')
print('Backend:', b.__class__.__name__)
print('Config:', b.get_configuration())
"

# Run all 3 verify scripts
./scripts/qa/verify-proctoring.sh
./scripts/qa/verify-proctoring-advanced.sh
./scripts/qa/verify-proctoring-environment.sh

# Create staging test exam (manual)
# 1. Log into Studio: https://studio.academyv2.mereka.io
# 2. Create subsection → exam type = Proctored → save
# 3. Enroll test student → start exam → verify environment check flow
# 4. Complete exam → verify grade passback within 5 min
```

---

## 3. Files to Change (Complete List)

| File | Change | AC Coverage |
|------|--------|-------------|
| `deploy/k8s/base/secrets/external-secrets.yaml` | Add 3 proctoring secret mappings | AC-002, AC-019 |
| `deploy/k8s/base/apps/openedx/settings/lms/production.py` | Update PROCTORING_BACKENDS + ENABLE_PROCTORED_EXAMS + Celery beat | AC-001..008, AC-014..022 |
| `infrastructure/tutor/plugins/multi-tenancy/models.py` | Add proctoring_provider + review_sla_hours fields | AC-008, AC-033, AC-034 |
| `infrastructure/tutor/plugins/multi-tenancy/migrations/` | New migration for tenant model fields | AC-008 |
| `docs/ops/runbooks/PROCTORING_RUNBOOK.md` | Update "Current State" table with live provider + test evidence | All |
| `docs/operations/PROCTORING_VENDOR_READINESS.md` | Update blocker tracker (mark resolved) | All |

**No new services or containers required.** edx-proctoring is already installed in the LMS image.

---

## 4. Verify Script Summary

| Script | ACs Covered | Run State |
|--------|-------------|-----------|
| `scripts/qa/verify-proctoring.sh` | AC-001, 002, 006, 007, 008, 020, 021, 022, 036, 037, 038 | 10 PASS, 0 FAIL, SKIPs expected |
| `scripts/qa/verify-proctoring-advanced.sh` | AC-004, 005, 009, 010, 011, 012, 013, 016, 024, 025, 026, 027, 028, 029, 030, 031, 032, 033, 034, 035 | Run after contract |
| `scripts/qa/verify-proctoring-environment.sh` | AC-003, 014, 015, 017, 018, 019, 023 | 10 PASS, 0 FAIL, 5 SKIP (expected) |

**Total**: All 38 ACs mapped across 3 scripts with `@covers` annotations and `@spec: proctoring-integration_spec.md`.

---

## 5. Estimated Effort After Contract

| Phase | Tasks | Effort |
|-------|-------|--------|
| Day 0 | Create GCP SM secrets, update ExternalSecret | 30 min |
| Day 0 | Update LMS settings (PROCTORING_BACKENDS + feature flags) | 1 hour |
| Day 1 | Tenant model migration + rebuild + deploy to staging | 2 hours |
| Day 1-2 | Staging test exam: identity check → exam → review → grade | 4 hours |
| Day 2-3 | Run all 3 verify scripts in staging, close gaps | 2 hours |
| Day 3 | Deploy to production + smoke test | 1 hour |
| Day 3 | Close parent bead i8lo | — |

**Total**: ~2-3 working days after contract is signed.

---

## Related

- `docs/operations/PROCTORING_VENDOR_READINESS.md` — Vendor matrix + blocker tracker (33ff)
- `docs/ops/runbooks/PROCTORING_RUNBOOK.md` — Operational runbook (i8lo.1)
- `specs/proctoring-integration_spec.md` — Full 38-AC specification
- `scripts/qa/verify-proctoring.sh` — AC-001/002/006..008/020..022/036..038
- `scripts/qa/verify-proctoring-advanced.sh` — AC-004/005/009..013/016/024..035
- `scripts/qa/verify-proctoring-environment.sh` — AC-003/014/015/017..019/023
