# Assessment Epic Closure Evidence

> **Bead**: mereka-lms-1si5 (parent)
> **Date**: 2026-02-18
> **Spec**: specs/advanced-assessment-xqueue_spec.md (44 ACs)
> **Children**: 1si5.1 (grading loop), 1si5.2 (alerting/runbook)

## Executive Summary

XQueue infrastructure is **deployed and operational** on the production GKE cluster. The grading loop is open at the grader step — no external grader container exists because no courses currently use code assessments. ORA2 and timed exams are available via built-in XBlocks. All 44 spec ACs have verification scripts with `@covers` annotations.

## 1. Grader Callback Loop Status

```
Student → LMS → POST /xqueue/submit/ → XQueue (uWSGI) → MySQL queue
                                                           ↓
                                                    xqueue-consumer (polling)
                                                           ↓
                                                    [GRADER — NOT DEPLOYED]
                                                           ↓
                                                    XQueue → POST callback → LMS → Gradebook
```

| Segment | Status | Evidence |
|---------|--------|----------|
| Student → LMS | Working | LMS pod healthy, courseware accessible |
| LMS → XQueue | **Working** | `XQUEUE_INTERFACE` configured, Django auth user `lms` active |
| XQueue → MySQL | **Working** | Persistent MySQL backend, 0 submissions (no code assessments exist) |
| Consumer polling | **Working** | xqueue-consumer container running ("running consumers") |
| Consumer → Grader | **OPEN** | No grader image built, no grader deployed |
| Grader → Callback → LMS | **UNTESTABLE** | Depends on grader deployment |
| LMS → Gradebook | Working | Gradebook functional for ORA2/standard problems |

**Blocker**: Grading loop cannot be closed end-to-end without:
1. Building `xqueue-graders` Docker image (manifests scaffolded at `deploy/k8s/base/apps/xqueue-graders/`)
2. Creating a course with code assessment problems
3. Deploying grader and wiring into kustomization

**Risk**: LOW — no courses require code grading today. When needed, the infrastructure is ready.

## 2. Gradebook Evidence

| Feature | Status | Notes |
|---------|--------|-------|
| ORA2 grading → gradebook | **Available** | ORA2 XBlock installed, filesystem upload backend configured |
| Staff grading → gradebook | **Available** | SGA XBlock installed |
| Timed exam → gradebook | **Available** | `edx-proctoring` installed with null backend (timed-only) |
| XQueue code grading → gradebook | **Not testable** | Grader not deployed |
| Bulk grade export | **Available** | Built-in instructor dashboard feature |
| Grade override | **Available** | Built-in instructor tools |

## 3. XQueue Monitor Evidence

### PrometheusRules (5 alerts deployed)

| Alert | Status | Mechanism |
|-------|--------|-----------|
| `XQueuePodDown` | **Working** | kube-state-metrics `kube_deployment_status_replicas_available` |
| `XQueueHighQueueDepth` | **Working** | kube-state-metrics based |
| `XQueueConsumerBacklog` | **Working** | kube-state-metrics based |
| `XQueueGradingTimeoutRate` | Pending scrape | Needs ServiceMonitor label fix |
| `XQueueHighErrorRate` | Pending scrape | Needs ServiceMonitor label fix |

### ServiceMonitor

- ServiceMonitor `xqueue-metrics` deployed
- **Known issue**: Selector needs `app.kubernetes.io/name: xqueue` label on service + port name `http` to start scraping
- Documented in `docs/ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md`

## 4. Spec AC Coverage

### Verification Script Mapping

| Script | ACs Covered | Spec Scope |
|--------|-------------|------------|
| `verify-assessment-audit.sh` | AC-001..015 | ORA2, timed exams, gradebook |
| `verify-xqueue-deployment.sh` | AC-016..020 | XQueue service + grading loop |
| `verify-xqueue-graders.sh` | AC-021..025 | Grader sandbox security |
| `verify-assessment-bulk.sh` | AC-026..044 | Advanced XBlocks, bulk ops, a11y |
| `verify-ora2-operations.sh` | (supplementary) | ORA2 operational checks |
| `verify-timed-exams.sh` | (supplementary) | Timed exam operational checks |

**Total**: 44/44 ACs have `@covers` annotations in verify scripts.

### AC Status Summary

| Category | ACs | Status |
|----------|-----|--------|
| ORA2 (peer/staff grading) | AC-001..009 | Infrastructure ready, needs course content |
| Timed exams | AC-010..015 | Working (null proctoring backend) |
| XQueue + code grading | AC-016..020 | XQueue deployed, grader pending |
| Sandbox security | AC-021..025 | Grader not deployed (untestable) |
| Advanced XBlocks | AC-026..033 | XBlocks available in platform |
| Gradebook integration | AC-034..036 | Working for non-XQueue assessments |
| Bulk operations | AC-037..039 | Built-in LMS features available |
| i18n + a11y | AC-040..042 | Platform-level support |
| Notifications + display | AC-043..044 | Platform-level support |

## 5. Evidence File Index

| File | Bead | Content |
|------|------|---------|
| `docs/concepts/architecture/ASSESSMENT_XQUEUE_EVIDENCE.md` | 1si5.1 | XQueue deployment state, LMS integration, grader inventory |
| `docs/ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md` | 1si5.2 | Health checks, alert reference, troubleshooting |
| `docs/concepts/architecture/ASSESSMENT_EPIC_CLOSURE.md` | 1si5 | This file — parent closure evidence |

## 6. Remaining Work (Future Phases)

Captured in child beads (all pending, not blocking closure):

| Bead | Phase | Description |
|------|-------|-------------|
| 2xrp | Phase 0 | Audit ORA2, XQueue, timed exams, CodeJail |
| eq7w | Phase 1 | ORA2 operationalization (file uploads, peer, staff grading) |
| 1wzz | Phase 2 | Timed exams (timer, extensions, accessibility) |
| 3h7t | Phase 3 | XQueue grader workers (Python + sandbox + K8s) |
| 3jb8 | Phase 4 | Advanced XBlocks (drag-drop, math, randomized pools) |
| 12r9 | Phase 5 | Bulk operations, security, multi-language, analytics |

## 7. Risk Handoff

| Risk | Likelihood | Impact | Mitigation | Owner |
|------|-----------|--------|------------|-------|
| No grader when code course created | Medium | High | Scaffolded manifests ready; build + deploy takes ~1 hour | LMS team |
| ServiceMonitor not scraping | Low | Medium | Label fix documented in runbook | Platform team |
| ORA2 file storage on filesystem | Low | Medium | Works for single-pod; migrate to S3 if scaling | Platform team |
| CodeJail disabled | Low | Low | Not needed without code grading courses | LMS team |
