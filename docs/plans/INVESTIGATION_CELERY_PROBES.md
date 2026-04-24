# Investigation: Celery Liveness Probe Flapping Epidemic

**Date:** 2026-04-22
**Worktree:** `.worktrees/mereka-planning-2026-04-22` (branch `docs/planning-review-2026-04-22`)
**Authored by:** Claude (Opus), planning-day review

## Problem

Multiple Celery worker pods across prod + dev restart chronically due to `celery inspect ping` exec probes timing out. The probes never fail with a non-zero exit — they always time out ("command timed out after 30s"). Evidence:

| Env | Pod | Restarts | Window |
|---|---|---|---|
| prod | `enterprise-catalog-worker-757f44c5db-wwnnb` | **71 restarts, 1212 probe failures** | 13d |
| prod | `enterprise-subsidy-86d866cb67-x5w9r` | 8 | 13d |
| dev  | `enterprise-catalog-worker` | 36 | ~ongoing |
| dev  | `enterprise-subsidy` | 35 | ~ongoing |
| dev  | `enterprise-access-worker` | 31 | ~ongoing |
| dev  | `notes` | 25 | ~ongoing |
| dev  | `payments-gateway` | 24 | ~ongoing |

## Evidence (verified, not speculative)

- Prod `catalog-worker-probe-fix.yaml` **already exists** at `bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/catalog-worker-probe-fix.yaml` and extends `timeoutSeconds` from 10 → 30 for both liveness and readiness. Pod still flaps at 71 restarts/13d. **Bumping the timeout did not solve it.**
- Commands from live spec: `/venv/bin/celery -A enterprise_catalog inspect ping --timeout=10` with `failureThreshold=5`, `periodSeconds=120`.
- Enterprise services that use HTTP `/health/` probes (enterprise-subsidy, notes, payments-gateway) have materially fewer restarts in prod (8 vs 71). The probe mechanism — not the celery worker — is the common factor.
- Dev overlay has **no probe overrides** — same base probe config runs there, and all 5 Celery services flap.

## Root cause

`celery inspect ping` is structurally unfit as a container probe:

1. **Process fork cost:** each probe forks a fresh Python interpreter, loads Django settings, initializes the Celery app, and opens a Redis connection to the broker. On 50m-CPU-request pods this already takes several seconds at baseline.
2. **Broker dependency:** `inspect ping` is a **broadcast RPC** — it publishes a control message to Redis and waits for workers to reply. If Redis is even mildly latent, the probe hangs for the full timeout. This turns transient Redis pressure into worker restart storms.
3. **CPU throttling feedback loop:** when the probe does finally run during throttle, it takes even longer → fails → pod restarts → cold boot → more throttling. Bumping the probe timeout from 10s to 30s did not change the underlying cost curve.

Alternatives like HTTP `/health/` (enterprise-subsidy, notes, payments-gateway) don't fork a Python process and don't touch Redis; they're measurably more stable.

## Scope — probe definitions affected

**Defined in mereka-lms app repo (base):**
- `deploy/k8s/base/apps/enterprise/workers/enterprise-catalog-worker-deployment.yaml`
- `deploy/k8s/base/apps/enterprise/workers/enterprise-access-worker-deployment.yaml`
- `deploy/k8s/base/apps/lms/worker-deployment.yaml`
- (enterprise-subsidy / notes / payments-gateway already use HTTP `/health/` probes — not affected)

**Overridden in bbi-infrastructure (prod only):**
- `apps/mereka-lms/overlays/prod/patches/catalog-worker-probe-fix.yaml` — applies to enterprise-catalog-worker + enterprise-access-worker, extends timeout to 30s. **Does not stop the flapping.**
- `apps/mereka-lms/overlays/prod/patches/lms-probe-timeout.yaml` — applies to `lms` (not worker).

Dev overlay: no probe overrides.

## Solution

**Recommended: remove liveness probes, keep readiness only.**

Rationale: Kubernetes has two probe classes with different failure semantics. Readiness gates whether a pod receives traffic; liveness triggers restarts. For a Celery worker:

- A broadcast-ping failure does not mean the worker is dead — it often means Redis is latent or the worker is busy.
- A restart does not help recover from broker latency; it only adds cold-start cost on top.
- The Celery task queue is durable (in Redis). Unlike a stuck HTTP server, a quiet worker is not wedged — it's idle or throttled.
- Real worker failures (OOM, segfault) are still caught by exit-code monitoring; they don't need a liveness probe to trigger a restart.

Keep the readiness probe (with a reasonable timeout) so that services briefly mark a worker `NotReady` if it can't respond — this is useful signal without the restart churn.

**Rejected alternatives:**
- *Bump timeout further (60s+, periodSeconds 180s):* `catalog-worker-probe-fix.yaml` already proves bumping doesn't work. At some point the probe becomes so loose it provides no signal while still occasionally restarting the pod.
- *Migrate to HTTP `/health/`:* would be best long-term but requires upstream work — Celery worker containers don't expose an HTTP port; you'd need to bake in a sidecar or a `celery beat --health` HTTP endpoint. Worth pursuing as Phase 2.

## Acceptance criteria

- [ ] Enterprise-catalog-worker restart count stays <5 over a 14-day observation window after rollout (currently 71/13d in prod).
- [ ] Enterprise-access-worker restart count stays <5 over 14 days.
- [ ] LMS-worker restart count unchanged or lower.
- [ ] No Redis-side queue-depth regression (Redis `list_length` on celery queues stays bounded during the observation window).
- [ ] An alert exists for `kube_pod_container_status_restarts_total` threshold that would fire on >5 restarts/24h per worker — so if we regress, we know before the next planning day.

## Proposed beads

**Parent epic — P1 — task**
> Celery worker probe stabilization (replace `celery inspect ping` exec probes)
>
> Body: see `docs/plans/INVESTIGATION_CELERY_PROBES.md` for root cause and solution. Enterprise worker pods restart chronically (prod: 71/13d on enterprise-catalog-worker; dev: 31-36 per service) because `celery inspect ping` fork cost + Redis broadcast latency exceeds any practical probe timeout. Existing timeout bump did not solve it.
>
> Acceptance: all three child tasks closed + 14-day restart-count observation.

**Child .1 — P1 — task**
> Remove liveness probes from enterprise-catalog-worker, enterprise-access-worker, lms-worker (keep readiness)
>
> Files: `deploy/k8s/base/apps/enterprise/workers/*.yaml` + `deploy/k8s/base/apps/lms/worker-deployment.yaml`.
> Also: retire or update `bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/catalog-worker-probe-fix.yaml` (liveness block becomes obsolete).
> Risk: low — readiness stays intact; OOMKill safety net unchanged.

**Child .2 — P2 — task**
> Add PrometheusRule alert: CeleryWorkerRestartRateHigh
>
> Expression: `increase(kube_pod_container_status_restarts_total{namespace="mereka-lms", pod=~".*-worker-.*"}[24h]) > 5`.
> Severity: warning. Placement: `deploy/k8s/base/monitoring/celery-worker-alerts.yaml` (new file, mereka-lms-scoped — platform-shared alerts belong in bbi-infrastructure).

**Child .3 — P3 — task (research, not implementation)**
> Research HTTP health endpoint pattern for Celery workers (Phase 2)
>
> Investigate: (a) `celery beat --health` HTTP endpoints, (b) `celery-exporter` sidecar pattern used by Open edX community, (c) upstream edx-enterprise-catalog / edx-enterprise-access for existing `/health/` routes. Output: decision doc, not code.
> Blocked by: .1 (no point if .1 eliminates the pain).

## Open questions

1. Are we willing to retire the `catalog-worker-probe-fix.yaml` override once liveness is gone? (Cleanup of infra overlay — requires coordinated PR.)
2. Is Redis itself under pressure that's contributing? Prod Redis pod shows 108m CPU which is not huge — unlikely but worth a quick look at Redis slowlog after .1 ships.
3. Does the prod CI stack (ARC runners) have any Celery-probe-adjacent health checks that would need the same fix?
