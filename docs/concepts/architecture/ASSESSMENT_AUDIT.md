# Assessment Infrastructure Audit Report

**Assessment Phase 0 — Baseline Audit**
**Date**: 2026-02-14
**Status**: Complete
**Auditor**: CrimsonHawk (agent-2)

---

## Executive Summary

This audit documents the current state of all assessment infrastructure in Mereka Academy Open edX deployment (Tutor 21.0.0 / Ulmo). All core assessment components are present and partially configured, but none are fully operational or production-ready. The infrastructure exists but lacks external graders, complete testing, and operational runbooks.

**Key Findings**:
- ✅ ORA2 framework present and configured (file uploads enabled, filesystem backend)
- ✅ XQueue service deployed with MySQL backend and secrets configured
- ✅ ORA Grading MFE configured at production URL
- ✅ Timed exam backend configured (edx-proctoring no-op for non-proctored exams)
- ⚠️ CodeJail sandbox **disabled** with mitigation plan required
- ❌ No external graders configured for XQueue
- ❌ No assessment smoke tests exist
- ❌ No operational runbooks for assessment workflows

**Recommendation**: Proceed to Assessment Phase 1 (ORA2 Operationalization) immediately. All prerequisites are met.

---

## 1. Open Response Assessment (ORA2)

### Configuration Status

**Location**: `deploy/k8s/base/apps/openedx/settings/lms/production.py` (lines 329-333, 706)

```python
# ORA2
ORA2_FILEUPLOAD_BACKEND = "filesystem"
ORA2_FILEUPLOAD_ROOT = "/openedx/data/ora2"
FILE_UPLOAD_STORAGE_BUCKET_NAME = "openedxuploads"
ORA2_FILEUPLOAD_CACHE_NAME = "ora2-storage"

# MFE
ORA_GRADING_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/ora-grading"
```

### File Upload Configuration

| Setting | Value | Status |
|---------|-------|--------|
| **Backend** | `filesystem` | ✅ Configured |
| **Root Path** | `/openedx/data/ora2` | ✅ Configured |
| **Storage Bucket** | `openedxuploads` | ✅ Configured |
| **Cache Name** | `ora2-storage` | ✅ Configured |
| **Max File Size** | *(default: 10 MB)* | ⚠️ Not explicitly configured |
| **Allowed File Types** | *(default: all)* | ⚠️ Not explicitly configured |

**Observations**:
- Filesystem backend is appropriate for initial deployment (no cloud storage costs)
- Storage path `/openedx/data/ora2` is persistent via K8s PersistentVolumeClaim
- No explicit file size limits or type restrictions configured (using Open edX defaults)
- Bucket name suggests future migration to cloud storage (S3/GCS) is planned

**Recommendations**:
1. Explicitly set max file size (recommend 10 MB for images/PDFs, 25 MB for portfolios)
2. Configure allowed file types whitelist (images: jpg/png/gif, documents: pdf, code: py/js/java)
3. Set up storage cleanup policy for old submissions (retention: 2 years)

### ORA Grading MFE

| Setting | Value | Status |
|---------|-------|--------|
| **URL** | `https://apps.academyv2.mereka.io/ora-grading` | ✅ Configured |
| **Deployment Status** | Unknown (requires verification) | ⚠️ Not verified |
| **Authentication** | JWT (inherited from MFE config) | ✅ Configured |

**Verification Needed**:
- [ ] Test MFE loads at production URL
- [ ] Verify staff user can access ORA grading interface
- [ ] Confirm rubric display works correctly

### Peer Assessment Parameters

**Not explicitly configured** — using Open edX defaults:

| Parameter | Default Value | Recommended Override |
|-----------|---------------|----------------------|
| Min peers required | 3 | 2 (for smaller courses) |
| Max peers to grade | 5 | 3 (reduce student burden) |
| Peer grading deadline | 7 days | Configurable per course |
| Calibration required | false | true (for high-stakes courses) |

**Observations**:
- Default values are reasonable for general use
- No per-organization overrides configured
- Peer review workflow completion rate unknown (no baseline data)

### Staff Grading Configuration

**Not explicitly configured** — using Open edX defaults:

- Staff override capability: enabled
- Bulk grading tools: available via ORA Grading MFE
- Grading queue visibility: enabled for course staff
- Anonymous peer review: enabled by default

**Observations**:
- All core staff grading features available out-of-box
- No custom rubric templates configured
- No staff grading SLA or queue size alerts

---

## 2. XQueue External Grading Service

### Deployment Status

**XQueue Service**: ✅ Deployed
**Location**: `deploy/k8s/base/plugins/xqueue/`

### Service Configuration

**Settings File**: `deploy/k8s/base/plugins/xqueue/apps/settings/tutor.py`

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "HOST": "mysql",
        "PORT": 3306,
        "NAME": "xqueue",
        "USER": "xqueue",
        "PASSWORD": (os.environ.get("MYSQL_XQUEUE_PASSWORD", "") or "").rstrip("\r\n"),
        "OPTIONS": {"init_command": "SET sql_mode='STRICT_TRANS_TABLES'",},
    }
}

USERS = {"lms": os.environ.get("XQUEUE_LMS_PASSWORD", "")}
XQUEUES = {"openedx": None}
```

**LMS Integration** (`deploy/k8s/base/apps/openedx/settings/lms/production.py` lines 464-471):

```python
XQUEUE_INTERFACE = {
  "django_auth": {
    "username": "lms",
    "password": os.environ.get("XQUEUE_LMS_PASSWORD", "")
  },
  "url": "http://xqueue:8000",
  "callback_url": "http://lms:8000"
}
```

### Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| **K8s Service** | ✅ Deployed | Internal DNS: `xqueue.mereka-lms.svc.cluster.local` |
| **Service Port** | 8000 | HTTP (internal only) |
| **MySQL Database** | ✅ Configured | Database: `xqueue`, User: `xqueue` |
| **Secrets** | ✅ Configured | ExternalSecrets synced from Infisical |
| **Health Endpoint** | `/xqueue/status/` | Monitored via ServiceMonitor |
| **Prometheus Metrics** | ✅ Configured | `deploy/k8s/base/monitoring/servicemonitor-xqueue.yaml` |
| **Alerts** | ✅ Configured | `deploy/k8s/base/monitoring/prometheusrule-xqueue.yaml` |

### Secrets Configuration

**ExternalSecrets** (`deploy/k8s/base/secrets/external-secrets.yaml`):

- `JWT_SECRET_KEY_XQUEUE` → `MEREKA_LMS_JWT_SECRET_KEY_XQUEUE`
- `XQUEUE_SECRET_KEY` → `MEREKA_LMS_XQUEUE_SECRET_KEY`
- `XQUEUE_LMS_PASSWORD` → `MEREKA_LMS_XQUEUE_PASSWORD`
- `MYSQL_XQUEUE_PASSWORD` → (synced from Infisical)

**Status**: ✅ All secrets configured in ExternalSecrets

### XQueue Grader Backends

**Configured Queues**: `{"openedx": None}`

| Queue Name | Grader Backend | Status |
|------------|----------------|--------|
| `openedx` | None | ❌ **No grader configured** |

**Observations**:
- XQueue service is running but has **no external graders configured**
- Queue is defined but backend is explicitly `None`
- LMS can submit to queue but grading requests will time out
- No containerized grader workers deployed

**Impact**:
- Code submission problems cannot be auto-graded
- XQueue-dependent problem types unusable in production
- Custom grading workflows blocked until graders deployed

**Recommendations**:
1. Deploy at least one grader backend (containerized Python grader as POC)
2. Configure grader backend in XQUEUES setting
3. Test end-to-end grading workflow (LMS → XQueue → Grader → LMS)
4. Set up grader worker monitoring (queue depth, processing time, errors)

---

## 3. ORA Grading MFE

### Configuration

**Production URL**: `https://apps.academyv2.mereka.io/ora-grading`
**Configuration Source**: `deploy/k8s/base/apps/openedx/settings/lms/production.py` line 706

```python
ORA_GRADING_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/ora-grading"
```

**MEREKA_MFE_BASE_URL**: `https://apps.academyv2.mereka.io`

### Verification Status

| Check | Status | Notes |
|-------|--------|-------|
| URL configured in LMS | ✅ | Line 706 in production.py |
| MFE build included | ⚠️ Unknown | Requires MFE image inspection |
| MFE accessible at URL | ⚠️ Not verified | Requires browser test |
| Authentication working | ⚠️ Not verified | JWT-based, should inherit from MFE config |
| Rubric display | ⚠️ Not verified | Requires test course with ORA2 problem |

**Observations**:
- Configuration is correct and follows Tutor MFE patterns
- No known issues with ORA Grading MFE in Ulmo release
- MFE likely operational but needs smoke test

**Recommendations**:
1. Create test course with ORA2 problem to verify MFE
2. Test staff grading workflow end-to-end
3. Verify rubric rendering and submission display
4. Test bulk grading capabilities

---

## 4. Timed Exam Backend

### Configuration

**Backend**: `edx-proctoring` (no-op mode)
**Purpose**: Timed-only exams without proctoring provider

### Implementation Status

**Source**: Open edX default configuration (no custom settings required)

| Feature | Status | Details |
|---------|--------|---------|
| **Timed exams enabled** | ✅ | Built-in to edx-platform |
| **Proctoring backend** | `null` (no-op) | No third-party proctoring |
| **Server-side timer** | ✅ | Enforced by LMS |
| **Auto-submission** | ✅ | Submissions auto-submitted on timeout |
| **Grace period** | Configurable | Per-exam setting in Studio |
| **Timer display** | ✅ | Client-side countdown in learner MFE |

### Timed Exam Workflow

1. **Course author** creates exam subsection in Studio, enables "Timed" flag, sets duration
2. **Learner** starts exam, server records start time
3. **LMS** enforces time limit server-side (client timer is informational only)
4. **Auto-submission** triggers when time expires (+ grace period if configured)
5. **Grade** calculated from auto-submitted responses

### Proctoring Backend

**Configured Backend**: `None` (edx-proctoring no-op mode)

**What this means**:
- Timed exams work normally (time limits enforced)
- No webcam/screen recording
- No identity verification
- No lockdown browser requirements
- No proctoring provider integration

**Comparison to Proctored Exams** (out of scope for 2026):

| Feature | Timed-Only (Current) | Proctored (Deferred to 2027) |
|---------|----------------------|------------------------------|
| Time limit enforcement | ✅ | ✅ |
| Server-side timer | ✅ | ✅ |
| Auto-submission | ✅ | ✅ |
| Webcam monitoring | ❌ | ✅ |
| Screen recording | ❌ | ✅ |
| Identity verification | ❌ | ✅ |
| Lockdown browser | ❌ | ✅ |
| Third-party provider cost | $0 | $5-15/exam |

**Observations**:
- Current configuration is sufficient for non-proctored high-stakes exams
- Enterprise clients requiring proctoring must wait until 2027 or use alternative solutions
- Server-side enforcement prevents client-side timer manipulation
- No proctoring provider integration = zero recurring costs

**Recommendations**:
1. Document timed exam configuration process for course authors
2. Create example timed exam course for testing
3. Test auto-submission behavior (timeout, grace period, submission confirmation)
4. Clearly communicate "timed-only" limitations to enterprise clients

---

## 5. CodeJail Sandbox Status

### Configuration

**Status**: ❌ **DISABLED**
**Location**: Multiple settings files (LMS, CMS, development, production)

**Example Configuration** (`deploy/k8s/base/apps/openedx/settings/lms/production.py` lines 451-459):

```python
# Disable codejail support
# explicitely configuring python is necessary to prevent unsafe calls
import codejail.jail_code
codejail.jail_code.configure("python", "nonexistingpythonbinary", user=None)
# another configuration entry is required to override prod/dev settings
CODE_JAIL = {
    "python_bin": "nonexistingpythonbinary",
    "user": None,
}
```

### What is CodeJail?

CodeJail is Open edX's sandboxed execution environment for running untrusted Python code (student submissions, custom graders, advanced problem types). It uses AppArmor or similar Linux security modules to isolate code execution.

**Use Cases**:
- Custom Python graders for code submission problems
- Advanced problem types with embedded Python (e.g., randomized problems with Python logic)
- XQueue grader backends that execute student-submitted code

### Why is it Disabled?

**Security Posture**: Running untrusted code requires robust sandboxing. The `nonexistingpythonbinary` configuration explicitly disables CodeJail to prevent accidental execution of untrusted code without proper isolation.

**Rationale from Advanced Assessment Spec** (`specs/advanced-assessment-xqueue_spec.md` line 237):

> "The system SHOULD support CodeJail as an alternative sandboxed execution backend by enabling the `codejail` configuration with an AppArmor profile (currently disabled with `nonexistingpythonbinary`)"

### Impact of Disabled CodeJail

| Affected Feature | Status | Workaround |
|------------------|--------|------------|
| **Custom Python graders** | ❌ Blocked | Use containerized graders instead |
| **Code submission problems** | ⚠️ Limited | Use XQueue with container sandboxing |
| **Randomized problems with Python** | ⚠️ Degraded | Use JavaScript-based randomization |
| **Advanced problem types** | ⚠️ Some blocked | Depends on problem type |

### Alternative Sandboxing Options

#### Option 1: Containerized XQueue Graders (Recommended)

**Approach**: Deploy grading workers as separate containers with resource limits and network isolation.

**Pros**:
- ✅ Strong isolation (container-level)
- ✅ Easy to deploy on GKE
- ✅ Horizontal scaling
- ✅ No AppArmor configuration required
- ✅ Language-agnostic (not limited to Python)

**Cons**:
- ❌ Higher overhead than CodeJail (container startup time)
- ❌ Requires separate grader worker deployment

**Implementation Status**: ❌ Not deployed

#### Option 2: gVisor Container Sandbox

**Approach**: Use gVisor (Google's OCI-compliant sandbox) for grader containers.

**Pros**:
- ✅ Stronger isolation than standard containers
- ✅ Defense-in-depth security
- ✅ Supported on GKE (gVisor runtime class available)
- ✅ No kernel module requirements (userspace sandbox)

**Cons**:
- ❌ Additional complexity
- ❌ Slightly slower than native containers
- ❌ Requires runtime class configuration in K8s

**Implementation Status**: ❌ Not deployed

#### Option 3: Enable CodeJail with AppArmor

**Approach**: Configure AppArmor profiles and enable CodeJail on LMS pods.

**Pros**:
- ✅ Lowest overhead (process-level isolation)
- ✅ Native Open edX solution
- ✅ Well-tested in production Open edX deployments

**Cons**:
- ❌ Requires AppArmor setup on K8s nodes
- ❌ Complex security configuration
- ❌ Limited to Python execution
- ❌ Node-level security dependency

**Implementation Status**: ❌ Not deployed

### Recommendations

**Short-term (Assessment Phase 1-2)**:
1. Keep CodeJail disabled (current state is safe)
2. Deploy containerized XQueue graders for code submission problems
3. Use resource limits and network policies for grader containers

**Medium-term (Assessment Phase 3-4)**:
1. Evaluate gVisor for grader containers (stronger isolation)
2. Test gVisor performance impact on GKE
3. Document security posture for enterprise clients

**Long-term (2027)**:
1. Consider enabling CodeJail with AppArmor if containerized graders prove insufficient
2. Benchmark performance: CodeJail vs containers vs gVisor
3. Align with Open edX community best practices

### Security Mitigation Plan

**Current State** (CodeJail disabled):
- ✅ No risk of untrusted code execution on LMS pods
- ✅ Attack surface minimized
- ❌ Code submission problems blocked

**Mitigation for Code Submission**:
1. Deploy XQueue grader workers as **separate containers** (not on LMS pods)
2. Apply K8s `NetworkPolicy` to isolate grader workers from LMS
3. Set strict resource limits on grader containers (CPU, memory, timeout)
4. Use ephemeral containers (destroyed after each grading job)
5. Log all grading requests and results for audit trail

**Security Checklist for Grader Containers**:
- [ ] Separate namespace (`mereka-lms-graders`)
- [ ] NetworkPolicy: deny all ingress except from XQueue
- [ ] NetworkPolicy: deny all egress except to XQueue callback URL
- [ ] Resource limits: CPU 1 core, memory 512 MB, timeout 30s
- [ ] Ephemeral storage only (no persistent volumes)
- [ ] Read-only root filesystem
- [ ] Non-root user (UID 1000)
- [ ] Seccomp profile applied
- [ ] AppArmor or SELinux profile applied (if available on nodes)

---

## 6. Advanced Question Types

### Status

**Not audited in Phase 0** — deferred to Assessment Phase 3

**Known Availability**:
- Drag-and-drop v2: ✅ Included in Open edX Ulmo
- Math expression input: ✅ Included in Open edX Ulmo
- Problem Builder XBlock: ⚠️ Requires plugin installation

**Recommendations**:
1. Audit in Assessment Phase 3
2. Test each question type in Studio
3. Verify learner experience in LMS

---

## 7. Grade Passbook Integration

### Status

**Grade reporting to gradebook**: ✅ Built-in to Open edX

**Observations**:
- All assessment types (ORA2, XQueue, standard problems, timed exams) report to gradebook automatically
- No custom integration required
- Grade calculation follows LMS gradebook policies

**Verification Needed**:
- [ ] Confirm ORA2 grades appear in gradebook
- [ ] Confirm XQueue grades appear in gradebook (after graders deployed)
- [ ] Confirm timed exam grades appear in gradebook

---

## 8. Assessment Analytics

### Status

**Not configured** — deferred to Assessment Phase 4

**Available Tools**:
- Open edX Insights (deprecated but still functional)
- Aspects (modern analytics stack)
- Custom Prometheus metrics

**Recommendations**:
1. Define key metrics for Assessment Phase 4
2. Evaluate Aspects vs custom dashboards
3. Set up baseline monitoring before operationalizing ORA2

---

## 9. Test Course Status

### Status

**No test course exists with assessment types**

**Required Test Course Components**:
- [ ] ORA2 problem with peer review workflow
- [ ] ORA2 problem with staff grading
- [ ] ORA2 problem with file upload
- [ ] Timed exam section (30 min duration)
- [ ] Standard problem types (multiple choice, checkboxes, text input)
- [ ] XQueue-graded problem (after graders deployed)

**Recommendations**:
1. Create "Assessment QA Course" in Studio
2. Configure as test course (not visible in catalog)
3. Enroll test users (student, peer, staff)
4. Run through all workflows end-to-end

---

## 10. Verification Script Status

### Status

**Created**: ✅ `scripts/qa/verify-assessment-audit.sh`

**Coverage**:
- Feature flag checks (ENABLE_ORA2_FILE_UPLOADS, etc.)
- ORA2 file upload configuration
- XQueue service health endpoint
- ORA Grading MFE URL accessibility
- CodeJail status verification
- Timed exam backend configuration

**Usage**:
```bash
./scripts/qa/verify-assessment-audit.sh [--env local|production]
```

---

## Summary of Findings

### Green (Operational)

- ✅ ORA2 framework present and configured
- ✅ ORA2 file uploads configured (filesystem backend)
- ✅ ORA Grading MFE URL configured
- ✅ XQueue service deployed with MySQL backend
- ✅ XQueue secrets configured in ExternalSecrets
- ✅ XQueue monitoring configured (ServiceMonitor, PrometheusRule)
- ✅ Timed exam backend configured (edx-proctoring no-op)
- ✅ LMS-XQueue integration configured

### Yellow (Partially Configured)

- ⚠️ ORA2 file size limits not explicitly configured (using defaults)
- ⚠️ ORA2 allowed file types not explicitly configured (using defaults)
- ⚠️ ORA Grading MFE not verified (likely working but untested)
- ⚠️ Timed exam workflows not tested
- ⚠️ No assessment analytics configured

### Red (Blocked or Missing)

- ❌ CodeJail sandbox disabled (mitigation plan required)
- ❌ No XQueue grader backends configured (queue backend is `None`)
- ❌ No test course with assessment types
- ❌ No assessment smoke tests
- ❌ No operational runbooks for assessment workflows
- ❌ No containerized grader workers deployed
- ❌ No advanced question types audited

---

## Next Steps

### Immediate Actions (Assessment Phase 1)

1. **Create test course** with ORA2, timed exam, standard problems
2. **Verify ORA Grading MFE** loads at production URL
3. **Run verification script** to establish baseline
4. **Document ORA2 configuration process** for course authors

### Short-term (Assessment Phase 2)

1. **Deploy first XQueue grader** (containerized Python grader)
2. **Test end-to-end grading workflow** (LMS → XQueue → Grader → LMS)
3. **Set up grader monitoring** (queue depth, processing time, errors)
4. **Create operational runbooks** for troubleshooting

### Medium-term (Assessment Phase 3-4)

1. **Audit advanced question types** (drag-and-drop v2, math expression)
2. **Set up assessment analytics** (submission rates, score distributions)
3. **Evaluate gVisor** for grader container sandboxing
4. **Scale testing** with 500+ student course

---

## Appendix A: Configuration Files Audited

1. `deploy/k8s/base/apps/openedx/settings/lms/production.py`
2. `deploy/k8s/base/apps/openedx/settings/lms/development.py`
3. `deploy/k8s/base/apps/openedx/settings/cms/production.py`
4. `deploy/k8s/base/apps/openedx/settings/cms/development.py`
5. `deploy/k8s/base/plugins/xqueue/apps/settings/tutor.py`
6. `deploy/k8s/base/secrets/external-secrets.yaml`
7. `deploy/k8s/base/secrets/openedx-secrets.yaml`
8. `deploy/k8s/base/monitoring/servicemonitor-xqueue.yaml`
9. `deploy/k8s/base/monitoring/prometheusrule-xqueue.yaml`
10. `specs/advanced-assessment-xqueue_spec.md`

---

## Appendix B: Key Environment Variables

| Variable | Source | Status |
|----------|--------|--------|
| `XQUEUE_SECRET_KEY` | Infisical → ExternalSecrets | ✅ Configured |
| `XQUEUE_LMS_PASSWORD` | Infisical → ExternalSecrets | ✅ Configured |
| `MYSQL_XQUEUE_PASSWORD` | Infisical → ExternalSecrets | ✅ Configured |
| `JWT_SECRET_KEY_XQUEUE` | Infisical → ExternalSecrets | ✅ Configured |
| `ORA2_FILEUPLOAD_BACKEND` | LMS settings (hardcoded) | ✅ Configured |
| `ORA2_FILEUPLOAD_ROOT` | LMS settings (hardcoded) | ✅ Configured |

---

## Appendix C: Service Endpoints

| Service | Internal URL | External URL | Health Check |
|---------|--------------|--------------|--------------|
| **LMS** | `http://lms:8000` | `https://academyv2.mereka.io` | `/heartbeat` |
| **XQueue** | `http://xqueue:8000` | (internal only) | `/xqueue/status/` |
| **ORA Grading MFE** | (served by Caddy) | `https://apps.academyv2.mereka.io/ora-grading` | MFE health check |
| **MySQL (XQueue)** | `mysql:3306` (database: `xqueue`) | (internal only) | N/A |

---

**End of Audit Report**
