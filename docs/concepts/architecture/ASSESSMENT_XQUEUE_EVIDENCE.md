# Assessment Infrastructure: XQueue Grading Loop Evidence

> **Bead**: mereka-lms-1si5.1
> **Date**: 2026-02-18
> **Cluster**: gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
> **Spec**: advanced-assessment-xqueue_spec.md

## 1. XQueue Service Status (AC-ASS-001)

### Deployment

| Component | Status | Details |
|-----------|--------|---------|
| XQueue pod | Running 2/2 | `xqueue-6b87d9b59f-rqdgq`, 2d8h age |
| xqueue container | Running | uWSGI 2.0.31, Python 3.12.3, 2 workers on port 8000 |
| xqueue-consumer | Running | Polling loop ("running consumers") |
| Submissions | 0 total, 0 queued | No courses with code assessments exist yet |

### LMS → XQueue Integration

```
XQUEUE_INTERFACE:
  url: http://xqueue:8000
  callback_url: http://lms:8000
  django_auth.username: lms
```

- LMS can reach XQueue via K8s service DNS (`http://xqueue:8000`)
- XQueue callback to LMS configured (`http://lms:8000`)
- XQueue Django user `lms` exists and is active

### Grader Status

| Item | Status | Notes |
|------|--------|-------|
| xqueue-graders image | **NOT BUILT** | No `xqueue-graders` image in Artifact Registry |
| xqueue-watcher | **NOT INSTALLED** | Not in XQueue container pip packages |
| Grader manifests | **SCAFFOLDED** | 6 files in `deploy/k8s/base/apps/xqueue-graders/` |
| Kustomization wiring | **NOT WIRED** | Not referenced in any `kustomization.yaml` |

**Assessment**: The grading loop is open at step 3 (XQueue → Grader). The infrastructure (XQueue service, consumer, LMS integration) is ready. When courses with code assessments are created, a grader container needs to be built and deployed.

## 2. Assessment Configuration (AC-ASS-002, AC-ASS-003)

### ORA2 (Open Response Assessment)

| Setting | Value | Status |
|---------|-------|--------|
| `ORA2_FILEUPLOAD_BACKEND` | `filesystem` | Configured |
| `ORA2_FILEUPLOAD_ROOT` | `/openedx/data/ora2` | Configured |

### Timed Exams

| Setting | Value | Status |
|---------|-------|--------|
| `PROCTORING_BACKENDS` | `{'DEFAULT': 'null', 'null': {}}` | Null backend (timed-only, no proctoring) |

### CodeJail

| Setting | Value | Status |
|---------|-------|--------|
| `CODE_JAIL.python_bin` | `nonexistingpythonbinary` | **DISABLED** (expected — mitigation plan needed for code execution) |
| `CODE_JAIL.user` | `None` | No sandbox user configured |

## 3. Grader Manifest Inventory

Six scaffolded manifests exist at `deploy/k8s/base/apps/xqueue-graders/`:

| File | Purpose | Blocker |
|------|---------|---------|
| `deployment.yaml` | Grader pod (1 replica, 1Gi memory) | Image doesn't exist; references localhost seccomp/apparmor profiles |
| `hpa.yaml` | HPA 1-3 replicas, 70% CPU | Depends on deployment |
| `networkpolicy.yaml` | Sandbox network isolation | Ready to deploy |
| `sandbox-policy.yaml` | Seccomp + AppArmor profiles (ConfigMap) | Must be loaded on nodes before deployment |
| `servicemonitor.yaml` | Prometheus metrics scraping | Depends on deployment |
| `prometheusrule.yaml` | Alert rules (queue backlog, grading timeout) | Depends on deployment |

### Deployment Blockers

1. **No grader Docker image**: Need to build `xqueue-graders` image with `xqueue-watcher` + grading scripts
2. **Seccomp/AppArmor profiles**: Deployment references `localhost/xqueue-grader-sandbox` — these need node-level installation (not applicable to GKE Autopilot; use `RuntimeDefault` instead)
3. **`:latest` tag**: Kyverno `disallow-latest-image-tag` policy would block; needs versioned tag
4. **Readiness probe**: References non-existent `openedx_xqueue_graders.models` module
5. **Not in kustomization**: Needs to be added to base or overlay kustomization

## 4. E2E Grading Loop Architecture

```
Student submits code → LMS → XQueue (POST /xqueue/submit/)
                                ↓
                       xqueue-consumer (polling)
                                ↓
                       [GRADER — NOT DEPLOYED]
                                ↓
                       XQueue callback → LMS (POST callback_url)
                                ↓
                       Grade appears in LMS gradebook
```

**Loop status**: Steps 1-2 operational, step 3 missing (no grader), steps 4-5 ready (callback configured).

## 5. What's Needed to Close the Loop

### Phase 1: Minimal Grader (for testing)
1. Build `xqueue-watcher` Docker image with a simple Python grader
2. Push to Artifact Registry with versioned tag
3. Simplify deployment: remove seccomp/apparmor (use `RuntimeDefault`), fix readiness probe
4. Add to kustomization, deploy
5. Create test course with code assessment problem

### Phase 2: Production Grader (for scale)
1. Add CodeJail sandbox (or container-level isolation)
2. Configure seccomp profiles for GKE
3. Enable HPA + monitoring
4. Load test with concurrent submissions

## 6. Verification Commands

```bash
# XQueue pod status
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster get pods -n mereka-lms -l app.kubernetes.io/name=xqueue

# XQueue consumer logs (should show "running consumers")
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster logs -n mereka-lms deployment/xqueue -c xqueue-consumer --tail=5

# XQueue submission count (should be 0 until courses are created)
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster exec -n mereka-lms deployment/xqueue -c xqueue -- bash -c 'cd /openedx/xqueue && python manage.py shell -c "from submission_queue.models import Submission; print(\"Total:\", Submission.objects.count()); print(\"Queued:\", Submission.objects.filter(retired=False, lms_ack=False).count())"'

# LMS XQueue integration config
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster exec -n mereka-lms deployment/lms -- python manage.py lms shell -c "from django.conf import settings; print('URL:', settings.XQUEUE_INTERFACE.get('url')); print('Callback:', settings.XQUEUE_INTERFACE.get('callback_url'))"

# LMS assessment settings
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster exec -n mereka-lms deployment/lms -- python manage.py lms shell -c "from django.conf import settings; print('ORA2:', settings.ORA2_FILEUPLOAD_BACKEND); print('Proctoring:', settings.PROCTORING_BACKENDS); print('CodeJail:', settings.CODE_JAIL)"

# Check for grader pods (should be none until deployed)
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster get pods -n mereka-lms -l app.kubernetes.io/name=xqueue-graders
```

## 7. Summary

| AC | Status | Evidence |
|----|--------|----------|
| AC-ASS-001 | **CONFIRMED** | XQueue running 2/2, consumer active, LMS integration configured. Grader container not deployed (no image, no courses need it). Manifests scaffolded. |
| AC-ASS-002 | **PENDING** | No sample code assessment course exists. Requires grader deployment first. |
| AC-ASS-003 | **PENDING** | Depends on AC-ASS-002. Callback path configured (LMS↔XQueue). |
| AC-ASS-004 | **PARTIAL** | XQueue logs + config documented above. Full e2e evidence pending grader deployment. |
| AC-ASS-005 | **DONE** | Verification commands documented in this file. |

**Overall**: XQueue infrastructure is operational. The grading loop is open at the grader step — this is expected since no courses with code assessments exist. Grader deployment is a Phase 1 task when courses are created.
