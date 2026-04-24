# Proctoring Vendor Readiness

> **Bead**: mereka-lms-33ff
> **Date**: 2026-02-18
> **Status**: BLOCKED — vendor contract not signed
> **Parent**: mereka-lms-i8lo (Proctoring: Integrate Enterprise Proctoring, 38 ACs)

## 1. Vendor Evaluation Matrix (AC-PRO-101)

### Provider Comparison

| Criteria | Proctorio | ProctorU | Honorlock | RPNow | Custom (self-hosted) |
|----------|-----------|----------|-----------|-------|---------------------|
| **LTI 1.3 integration** | Yes | Yes | Yes | Yes | Custom |
| **edx-proctoring backend** | Yes (built-in) | Yes (built-in) | No (LTI only) | No (LTI only) | Custom plugin |
| **Webhook/callback model** | Pull (LTI grade passback) | Pull (LTI grade passback) | LTI grade passback | LTI grade passback | Configurable |
| **Identity verification** | AI + human review | Live proctor option | AI + human review | Automated AI | Self-defined |
| **APAC data residency** | Check required | Check required | US only | Check required | Full control |
| **PDPA/GDPR compliance** | Yes | Yes | Yes | Yes | Self-certified |
| **Browser lockdown** | Extension-based | App-based | Extension-based | App-based | Custom |
| **Mobile support** | No | Limited | No | No | Custom |
| **Pricing model** | Per-exam | Per-minute | Per-exam | Per-exam | Infrastructure cost |
| **Est. cost (100 exams/mo)** | ~USD 200-400 | ~USD 300-600 | ~USD 150-300 | ~USD 100-250 | ~USD 50-150 |
| **API for bulk operations** | Limited | Yes | Limited | Limited | Full control |
| **Support SLA** | Business hours | 24/7 | Business hours | Business hours | Self |
| **Free trial** | Yes (limited) | Yes | Yes | Yes | N/A |
| **Mereka recommendation** | **Shortlisted** | Optional | Not recommended | Optional | Phase 2 |

### Decision Criteria Weights

| Criteria | Weight | Rationale |
|----------|--------|-----------|
| edx-proctoring backend support | 30% | Reduces integration complexity |
| APAC data residency | 25% | PDPA compliance for MY/SG learners |
| Cost per exam | 20% | Budget constraint at scale |
| LTI 1.3 support | 15% | Future-proof integration |
| Support SLA | 10% | Ops team coverage |

**Recommended shortlist**: Proctorio (built-in edx-proctoring plugin) or ProctorU (most battle-tested with Open edX).

---

## 2. Contract Package Checklist (AC-PRO-102)

### Pre-Signature Checklist

| Item | Owner | Approver | Status | Artifact |
|------|-------|----------|--------|----------|
| Provider selected from evaluation matrix | Platform lead | CTO | ⬜ PENDING | This doc §1 |
| Data Processing Agreement (DPA) reviewed | Legal | Legal counsel | ⬜ PENDING | — |
| PDPA compliance confirmation | Legal | DPO | ⬜ PENDING | — |
| Data residency confirmation (APAC) | Legal | DPO | ⬜ PENDING | — |
| Pricing agreement / PO raised | Finance | CFO | ⬜ PENDING | — |
| API credentials provisioned by provider | Platform | Provider | ⬜ PENDING | — |
| Sandbox/test environment access granted | Platform | Provider | ⬜ PENDING | — |
| SLA reviewed and accepted | Platform lead | CTO | ⬜ PENDING | — |
| Contract countersigned | Legal | CEO | ⬜ PENDING | — |

### Post-Signature Go/No-Go Fields

| Gate | Go Condition | No-Go Condition | Owner |
|------|-------------|-----------------|-------|
| Legal | DPA + PDPA signed | Any clause requiring data outside APAC | Legal |
| Finance | PO approved | Budget overrun >20% | Finance |
| Technical | API credentials delivered | edx-proctoring plugin incompatible | Platform |
| Security | Secrets provisioned in GCP SM | API keys in plaintext | Security |
| Staging | Sandbox test exam passes | Auth loop or grade passback fails | LMS team |

### Evidence Artifacts Required at Contract Closure

- [ ] Signed contract PDF → secure legal/vendor evidence store (not committed to this repo)
- [ ] DPA acknowledgement → secure legal/vendor evidence store (not committed to this repo)
- [ ] API credentials → GCP SM `bbi-k8` project (see §3)
- [ ] Sandbox test evidence → `docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md`

---

## 3. Environment Readiness Smoke Checklist (AC-PRO-103)

Run these checks on the live cluster after provider contract is signed.

### Step 1: edx-proctoring Module Import

```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
import edx_proctoring
from edx_proctoring.api import get_backend_provider
print('edx_proctoring version:', edx_proctoring.__version__)
print('Current backend:', get_backend_provider())
"
# Expected: version printed, backend = null (until switched)
```

### Step 2: PROCTORING_BACKENDS Config Path

```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from django.conf import settings
print('PROCTORING_BACKENDS:', settings.PROCTORING_BACKENDS)
print('ENABLE_SPECIAL_EXAMS:', settings.FEATURES.get('ENABLE_SPECIAL_EXAMS', False))
"
# Expected: DEFAULT = null, ENABLE_SPECIAL_EXAMS = True
```

### Step 3: Provider Secret Placeholders

```bash
# Verify secrets exist in GCP SM (bbi-k8 project)
gcloud secrets list --project=bbi-k8 --filter="name:MEREKA_LMS_PROCTORING" \
  --format='value(name)'
# Expected after provisioning:
# MEREKA_LMS_PROCTORING_BACKEND_API_KEY
# MEREKA_LMS_PROCTORING_BACKEND_API_SECRET

# Verify ExternalSecret is mapped
kubectl get externalsecret -n mereka-lms openedx-secrets -o jsonpath=\
  '{.spec.data[?(@.secretKey=="PROCTORING_BACKEND_API_KEY")].remoteRef.key}'
```

### Step 4: Provider Backend Plugin Present

```bash
# For Proctorio (example):
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from edx_proctoring.backends import get_backend_by_name
try:
    b = get_backend_by_name('proctorio')
    print('Proctorio backend: AVAILABLE')
except Exception as e:
    print('Proctorio backend: NOT AVAILABLE -', e)
"
```

### Step 5: Feature Flag Verification

```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from django.conf import settings
flags = {k: v for k, v in settings.FEATURES.items() if 'EXAM' in k or 'PROCTOR' in k}
print('Exam/proctoring feature flags:', flags)
"
# Expected: ENABLE_SPECIAL_EXAMS=True, ENABLE_PROCTORED_EXAMS=True (after config update)
```

---

## 4. Blocker Tracker (AC-PRO-104)

### Current Status

| Blocker | Type | Status | Unblock Steps | ETA |
|---------|------|--------|---------------|-----|
| Provider not selected | Decision | 🔴 BLOCKED | 1. Review §1 matrix → 2. CTO decision → 3. Issue PO | Unknown |
| Contract not signed | Legal/Finance | 🔴 BLOCKED | Follows provider selection | Unknown |
| API credentials missing | Technical | 🔴 BLOCKED | Follows contract signing | Unknown |
| GCP SM secrets missing | Technical | 🔴 BLOCKED | Follows API credentials | Unknown |
| ExternalSecret not mapped | Technical | 🔴 BLOCKED | Follows GCP SM secrets | Unknown |
| LMS settings not updated | Technical | 🔴 BLOCKED | Follows ExternalSecret mapping | Unknown |
| Staging test not run | Verification | 🔴 BLOCKED | Follows LMS settings update | Unknown |

### Unblock Sequence

```
1. Platform lead + CTO review vendor matrix (§1)
   ↓
2. Legal reviews DPA + PDPA (parallel with finance PO)
   ↓
3. Contract countersigned → provider provisions API credentials
   ↓
4. Platform creates GCP SM secrets (bbi-k8 project):
   gcloud secrets create MEREKA_LMS_PROCTORING_BACKEND_API_KEY --project=bbi-k8
   printf '%s' '<key>' | gcloud secrets versions add MEREKA_LMS_PROCTORING_BACKEND_API_KEY \
     --data-file=- --project=bbi-k8
   gcloud secrets create MEREKA_LMS_PROCTORING_BACKEND_API_SECRET --project=bbi-k8
   printf '%s' '<secret>' | gcloud secrets versions add MEREKA_LMS_PROCTORING_BACKEND_API_SECRET \
     --data-file=- --project=bbi-k8
   ↓
5. Update ExternalSecret: deploy/k8s/base/secrets/external-secrets.yaml
   (add PROCTORING_BACKEND_API_KEY and PROCTORING_BACKEND_API_SECRET mappings)
   ↓
6. Update LMS settings: deploy/k8s/base/apps/openedx/settings/lms/production.py
   PROCTORING_BACKENDS = {
       'DEFAULT': '<provider>',
       '<provider>': {
           'api_key': os.environ.get('PROCTORING_BACKEND_API_KEY', ''),
           'api_secret': os.environ.get('PROCTORING_BACKEND_API_SECRET', ''),
       }
   }
   ↓
7. Run governed Tutor refresh (`./scripts/infra/prepare-tutor-build-context.sh --target openedx`) → build image → deploy via canonical-release.sh
   ↓
8. Run §3 smoke checklist
   ↓
9. Run staging test exam → verify grade passback
   ↓
10. Close parent bead i8lo
```

### Files That Change When Unblocked

| File | Change Required |
|------|----------------|
| `deploy/k8s/base/secrets/external-secrets.yaml` | Add 2 proctoring secret mappings |
| `deploy/k8s/base/apps/openedx/settings/lms/production.py` | Update `PROCTORING_BACKENDS` dict |
| `infrastructure/tutor/apply-patches.sh` | Add proctoring backend config if using Tutor path |
| `docs/ops/runbooks/PROCTORING_RUNBOOK.md` | Update "Current State" table with live provider |
| `docs/status/readiness/PROCTORING_VENDOR_READINESS.md` | This file — update blocker tracker |

---

## 5. Parent i8lo Dependency Update (AC-PRO-105)

### What i8lo Needs After Contract

When vendor contract is signed, parent bead `i8lo` (38 ACs) can proceed. Required changes:

**Code changes** (in `mereka-lms` repo):
1. `external-secrets.yaml` — add 2 secret mappings
2. `production.py` — update `PROCTORING_BACKENDS` with real provider
3. `apply-patches.sh` — add proctoring config block if Tutor path
4. New verify script: `scripts/qa/verify-proctoring-integration.sh` covering AC-PROCTOR-001..038

**Infrastructure changes**:
1. GCP SM secrets created (4–6 secrets depending on provider)
2. ExternalSecret synced and verified
3. Image rebuilt with updated settings
4. Staging test exam created and verified

**Estimated effort after contract**: 2–4 hours technical work + 1–2 days staging verification.

### Handoff to Parent i8lo

- This document is the pre-work evidence for `i8lo`
- When vendor is selected, assign `i8lo` implementation to WhiteCliff or BoldBadger
- Reference this doc's §4 unblock sequence as the implementation checklist

---

## Related

- `docs/ops/runbooks/PROCTORING_RUNBOOK.md` — operational runbook (i8lo.1)
- `specs/proctoring_spec.md` — full 38-AC specification
- `deploy/k8s/base/apps/openedx/settings/lms/production.py` — current `PROCTORING_BACKENDS = null`
- `deploy/k8s/base/secrets/external-secrets.yaml` — ExternalSecret mapping to update
