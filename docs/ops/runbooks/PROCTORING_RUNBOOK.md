# Proctoring Operations Runbook
_Audience: Platform Eng + Educators • Owner: Engineering Lead • Last updated: 2026-02-18_

> **Bead**: mereka-lms-i8lo.1
> **Date**: 2026-02-18
> **Status**: Proctoring DISABLED (null backend, timed exams only)

Companion surfaces:

- [ASSESSMENT_OPERATIONS_RUNBOOK.md](ASSESSMENT_OPERATIONS_RUNBOOK.md)
- [../../guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md](../../guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md)

Deferred companion decisions:

- provider-backed setup remains deferred until a real provider lane exists
- reviewer staffing remains deferred until provider-backed proctoring is live

## Current State

| Setting | Value | Notes |
|---------|-------|-------|
| `PROCTORING_BACKENDS` | `{'DEFAULT': 'null', 'null': {}}` | Null backend (timed-only) |
| `edx-proctoring` | Installed | Part of edx-platform dependencies |
| Provider contract | **NOT SIGNED** | Blocked on vendor selection |

Do not treat provider onboarding or reviewer staffing as active current-owner
docs on this branch. Those remain deferred owner-gap decisions until a real
provider-backed lane exists.

## 1. Enabling Proctoring (AC-PROCTOR-001)

### Prerequisites

- [ ] Provider contract signed (Proctorio, ProctorU, or custom)
- [ ] Provider API credentials provisioned
- [ ] Secrets created in the governed secrets path
- [ ] ExternalSecret added for proctoring secrets
- [ ] LMS settings updated with provider backend

### Enable Steps

```bash
# 1. Store the provider secrets in Infisical, then sync the governed bridge
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh

# 2. Add ExternalSecret mapping
# Edit deploy/k8s/base/secrets/external-secrets.yaml
# Add PROCTORING_BACKEND_API_KEY and PROCTORING_BACKEND_API_SECRET

# 3. Update LMS production settings
# In apply-patches.sh, add to production.py:
# PROCTORING_BACKENDS = {
#     'DEFAULT': '<provider_name>',
#     '<provider_name>': {
#         'api_key': os.environ.get('PROCTORING_BACKEND_API_KEY', ''),
#         'api_secret': os.environ.get('PROCTORING_BACKEND_API_SECRET', ''),
#     }
# }

# 4. Refresh rendered Open edX build context and rebuild
./scripts/infra/prepare-tutor-build-context.sh --target openedx
# Build + deploy via canonical release flow

# 5. Verify
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "from django.conf import settings; print(settings.PROCTORING_BACKENDS)"
```

### Disable Steps

```bash
# Revert PROCTORING_BACKENDS to null backend
# In apply-patches.sh:
# PROCTORING_BACKENDS = {'DEFAULT': 'null', 'null': {}}

# Refresh rendered Open edX build context and rebuild
./scripts/infra/prepare-tutor-build-context.sh --target openedx
# Deploy via canonical release flow
```

## 2. Provider Contract Checklist (AC-PROCTOR-002)

### Vendor Selection Criteria

| Criteria | Proctorio | ProctorU | Custom |
|----------|-----------|----------|--------|
| LTI integration | Yes | Yes | Custom |
| edx-proctoring support | Yes | Yes | Custom |
| Data residency (APAC) | Check | Check | Self-hosted |
| Price per exam | Varies | Varies | Infrastructure cost |
| API for bulk ops | Limited | Yes | Full control |

### Secret Ownership Matrix

| Secret | Owner | Location | Rotation |
|--------|-------|----------|----------|
| `PROCTORING_BACKEND_API_KEY` | Security team | Governed secrets bridge | Quarterly |
| `PROCTORING_BACKEND_API_SECRET` | Security team | Governed secrets bridge | Quarterly |
| Provider admin credentials | Platform lead | Vendor portal | As needed |
| LTI consumer key | LMS team | Governed secrets bridge | On provider change |
| LTI consumer secret | LMS team | Governed secrets bridge | On provider change |

### Pre-Go-Live Checklist

- [ ] Provider contract signed and countersigned
- [ ] API credentials issued by provider
- [ ] Secrets provisioned through the governed bridge
- [ ] ExternalSecret deployed and synced
- [ ] LMS settings updated with correct backend
- [ ] Test exam created and proctored session verified
- [ ] Student-facing documentation updated
- [ ] Support team briefed on proctoring session issues
- [ ] Monitoring alerts added for proctoring API errors

## 3. Incident Response for Proctoring Sessions (AC-PROCTOR-003)

### During Active Exam

| Incident | Impact | Response | Rollback |
|----------|--------|----------|----------|
| Provider API down | Students cannot start proctored exams | Contact provider support; allow timed-only fallback for affected students | Switch to `null` backend temporarily |
| LMS pod restart during exam | Active sessions interrupted | Sessions auto-resume on pod recovery (exam state in MySQL) | No rollback needed; verify session continuity |
| Proctoring JS fails to load | Webcam/screen sharing unavailable | Check MFE CDN; clear browser cache | Revert MFE image if new deploy |
| Student flagged incorrectly | False positive violation | Manual review in proctoring dashboard | Override via instructor tools |

### Rollback Procedure

```bash
# Emergency: disable proctoring (all active exams switch to timed-only)
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from django.conf import settings
# This is a runtime change; for persistent change, update apply-patches.sh
settings.PROCTORING_BACKENDS = {'DEFAULT': 'null', 'null': {}}
print('Proctoring disabled (runtime only)')
"

# For persistent change: update apply-patches.sh → rebuild → deploy
```

### Monitoring (when enabled)

```bash
# Check proctoring-related errors in LMS logs
kubectl logs -n mereka-lms deployment/lms --tail=100 | grep -i "proctoring\|proctor"

# Check for exam session timeouts
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from edx_proctoring.models import ProctoredExamStudentAttempt
from django.utils import timezone
from datetime import timedelta
recent = ProctoredExamStudentAttempt.objects.filter(
    created__gte=timezone.now() - timedelta(hours=1)
).values_list('status', flat=True)
from collections import Counter
print(Counter(recent))
"
```

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Provider outage during exam | Low | High | Null backend fallback + manual grade override |
| Student privacy concern | Medium | High | Data residency compliance + consent flow |
| False positive flagging | Medium | Medium | Manual review process + appeal workflow |
| Integration regression on deploy | Low | Medium | Test exam in staging before production |
| Secret rotation breaks integration | Low | High | Rotate in off-peak hours + verify immediately |
