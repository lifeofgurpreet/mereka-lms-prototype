# Generic MFE Instability Root Cause

> **Lane**: R5 — Generic MFE Instability Root Cause
> **Date**: 2026-03-13
> **Agent**: Agent 1
> **PR**: (pending)

## Start Snapshot

| Property | Value |
|----------|-------|
| **UTC** | `2026-03-13T09:20:51Z` |
| **MFE image** | `ghcr.io/.../mfe:6233c55b0c51ed5846d6b4b4c4746d9a80c857b3` |
| **MFE pod restarts** | 9 (all within first 24 minutes of pod creation) |
| **MFE pod stable since** | `2026-03-13T04:37:22Z` (~5 hours at time of investigation) |
| **MFE memory usage** | 19Mi (well under 1Gi limit) |

## Answers

### A. What exact process is exiting or failing?

The MFE container's entrypoint shell script is being killed by SIGKILL (exit code 137)
before Caddy can start listening on port 8002.

The entrypoint runs a `sed` loop across **72 JS files (57.6 MB total)** to fix baked null
config values, then `exec`s Caddy. The sed loop is added by the `bbi-infrastructure` dev
overlay, not by the mereka-lms base deployment.

### B. Is the trigger OOM, liveness/readiness, startup wrapper, config, or upstream dependency?

**Liveness probe misfire** — specifically, absence of a startup probe.

| Factor | Evidence |
|--------|----------|
| OOM | **NO** — current usage 19Mi, limit 1Gi, reason is "Error" not "OOMKilled" |
| Liveness probe | **YES** — kills pod at ~25-30s (initialDelay=5s + 3 failures × 10s) |
| Startup probe | **MISSING** — no startup probe exists |
| Startup wrapper | **Contributes** — sed loop takes 58 seconds on cold cache |
| Config | Not a factor |
| Upstream dependency | Not a factor |

**Timeline**:
1. Container starts → entrypoint shell script begins sed loop
2. Sed loop processes 72 JS files (57.6 MB) with 13 substitutions each → takes **58 seconds**
3. Liveness probe starts checking TCP port 8002 at t=5s (Caddy not started yet)
4. Three consecutive failures at t=5s, t=15s, t=25s → kubelet SIGKILLs container at ~25-30s
5. CrashLoopBackOff with exponential backoff (10s, 20s, 40s, 80s...)
6. After enough restarts, page cache makes sed loop faster → Caddy starts before probe kills
7. Pod stabilizes — currently 5+ hours with zero restarts since last recovery

### C. Are pages only failing during pod churn, or is there a second steady-state bug?

**Pod churn only.** When the MFE pod is stable:
- `/profile/u/gurpreet` loads correctly (~12-15s, slow but functional)
- `/account/` loads correctly (~10s)
- `/authn/login` renders correctly (~8s)

No steady-state bug. The "An unexpected error occurred" messages reported by the user
correspond to the restart window when the MFE pod's Caddy is not serving.

The slowness (~10-15s for MFE pages) is a separate concern (LMS API latency, not MFE).

### D. What is the smallest durable fix?

Add a `startupProbe` to the MFE base deployment. This gates liveness/readiness probes
until Caddy is actually listening.

```yaml
startupProbe:
  tcpSocket:
    port: 8002
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 24    # 10 + 24×5 = 130s max startup
  timeoutSeconds: 5
```

This gives 130 seconds for the entrypoint (sed + caddy startup) to complete before
the pod is killed. The current 58s sed loop + ~2s caddy start = ~60s, well within 130s.

Once the startup probe passes, liveness and readiness probes take over with their
normal 10s period and 3-failure threshold.

## Classification

| Surface | Classification | During restart | When stable |
|---------|---------------|----------------|-------------|
| `/profile/u/gurpreet` | INTERMITTENT_MFE_INSTABILITY | "An unexpected error" | Works (slow) |
| `/account/` | INTERMITTENT_MFE_INSTABILITY | "An unexpected error" | Works |
| `/authn/login` | INTERMITTENT_MFE_INSTABILITY | Blank/error page | Works |

**Root cause**: Missing startup probe → liveness probe kills pod during 58s sed startup loop.
**Not**: OOM, config error, upstream dependency failure, or steady-state bug.

## Fix Applied

**File**: `deploy/k8s/base/apps/mfe/deployment.yaml`

```diff
+          startupProbe:
+            tcpSocket:
+              port: 8002
+            initialDelaySeconds: 10
+            periodSeconds: 5
+            failureThreshold: 24
+            timeoutSeconds: 5
           livenessProbe:
             tcpSocket:
               port: 8002
-            initialDelaySeconds: 5
             periodSeconds: 10
             failureThreshold: 3
             timeoutSeconds: 5
           readinessProbe:
             tcpSocket:
               port: 8002
-            initialDelaySeconds: 5
             periodSeconds: 10
             failureThreshold: 3
             timeoutSeconds: 5
```

## Remaining Blockers

| # | Blocker | Owner | Priority |
|---|---------|-------|----------|
| 1 | Merge startup probe PR | mereka-lms CI | P1 |
| 2 | ArgoCD sync to dev cluster | bbi-infrastructure | P1 |
| 3 | MFE page slowness (10-15s) | LMS API performance | P2 |
