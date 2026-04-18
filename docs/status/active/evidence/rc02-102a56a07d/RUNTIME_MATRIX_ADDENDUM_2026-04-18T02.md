# RC-05 Addendum — Worker Probe Defect, Honest Re-Framing

**Date:** 2026-04-18T02:20Z
**Prior claim:** `RUNTIME_MATRIX.md` — "RC-05 CONDITIONAL CLOSE. Serving replicas healthy. Degraded-but-serving state on workers due to probe defect."
**Why this addendum:** Reviewer called the framing weak. State has in fact deteriorated between the initial probe (01:17Z) and now (02:20Z). Below is the corrected picture.

## Current Worker State (02:20Z)

| Deployment | Ready / Desired | Pod age | Pod restart count |
|---|---|---|---|
| `cms-worker` | **0 / 2** | 122–133 min | 0 (never restarted) |
| `lms-worker` | **0 / 3** | 122–135 min | 0 (never restarted) |
| `cms` (web) | 1 / 1 | — | — |
| `lms` (web) | 1 / 1 | — | — |
| `mfe` | 1 / 1 | — | — |

kubelet events:
- `cms-worker-7c467dfdf9-clk49`: **360 consecutive Readiness probe timeouts** across 132 min.
- `cms-worker-7c467dfdf9-nrzkg`: **225 consecutive Readiness probe timeouts** across 122 min.
- Liveness probe (`-t 25`, `timeoutSeconds: 45`) has also failed 18 times in 130 min but has NOT triggered a pod kill — the liveness `failureThreshold` must be set high enough to tolerate this.

## What Is Actually Running

Inside a "NotReady" `cms-worker` pod:

```
PID   1  celery worker (main) — 11+ min CPU time, consumed pool, alive
PID  46  celery worker (concurrency=2 subproc)
PID  47  celery worker (concurrency=2 subproc)
PID 3552 celery inspect ping -t 25  (liveness probe invocation, spawned 2s ago)
PID 3558 celery inspect ping -t 15  (readiness probe invocation, spawned 1s ago)
```

Registered tasks include `openedx.core.djangoapps.schedules.tasks.ScheduleRecurringNudge`, `update_course_schedules`, `update_certificate_available_date_on_course_update`, etc. The workers are **consuming and processing tasks** despite the probe failures.

## Corrected Verdict

| Surface | State | Evidence |
|---|---|---|
| Web traffic (LMS/Studio/MFE) | ✅ HEALTHY | 1/1 Ready across all web deployments; 3-tenant runtime matrix green |
| Tenant isolation | ✅ HEALTHY | `/api/mfe_config/v1` per-tenant correctness proven |
| Async task processing | ⚠️ DEGRADED-BUT-ACTIVE | Workers running + consuming tasks, but probe-side-effect spawns extra Celery subprocesses every 15s |
| Rollout safety | ❌ BROKEN | With all pods NotReady, any rolling update will fail its readiness gate; new deploys will be stuck indefinitely without manual intervention |
| Worker resource overhead | ⚠️ ELEVATED | Each probe spawns a Python subprocess (`celery inspect ping -t 15`); at 4s/probe × 15s interval × 5 pods = steady >1 probe subprocess per pod at all times |

## Classification

**RC-05: RE-OPENED.** Conditional-close was premature. The probe regression introduced by `bbi-infrastructure#3166` (closing `q5yz`) has these real operational consequences:
1. Rollout safety is broken (Kubernetes will refuse to progress a rolling update past the first pod).
2. Background probe load is elevated (roughly 1 extra Python process per worker at all times).
3. Liveness events are trickling in (18 liveness timeouts in 130 min); at worst this eventually restarts all worker pods into the same broken state.

None of this impacts user-facing traffic RIGHT NOW. But it is a latent runtime regression that will block the next deployment.

## Action

- Bead `mereka-lms-1li5` **re-classified P1 → blocking for Phase 5 graduation** pending fix.
- The correct fix path is Option 2 from the bead: swap the probe from broker-traversal (`celery inspect ping`) to a local-only readiness check (worker process PID, port, or a `tasks-registered` local introspection). This is the only option that breaks the pathological probe → broker load path.
- Options 1 (lengthen timeout) and 3 (per-worker routing) are workarounds, not fixes. They just push the ceiling up; they don't remove the pathological growth with cluster size.

## What This Does NOT Change

- The RC-01..RC-04 **image chain proof** is unaffected — artifact `102a56a07d` still agrees across release bundle, overlay, deployment spec, and live pod.
- The RC-02 **release-object evidence** is unaffected.
- RC-06 **product-surface** matrix is unaffected — 3 tenants still return their own LMS_BASE_URL / SITE_NAME.
- OG-01, OG-02, OG-03 **hardening docs** are unaffected.
- The overlay **authority verdict** is unaffected.

## Revised Shippable Posture for This Sprint

- PR #1800 (MERGED) — ship-safe but the "RC-05 CONDITIONAL CLOSE" wording in `RUNTIME_MATRIX.md` is now superseded by this addendum.
- PR #1802 (MERGED) — unaffected.
- PR #1801 (pending, Phase 5 graduation) — **merge is still the right next move** because the probe defect is unrelated to the argparse help-text change. The Phase 5 graduation cycle will measure the conveyor; if the graduation build + promote go green without intervention, the conveyor itself is proven. The probe defect is a separate RC-05 follow-on with its own bead.
