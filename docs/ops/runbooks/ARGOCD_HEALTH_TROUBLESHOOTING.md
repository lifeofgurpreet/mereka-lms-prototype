# ArgoCD Health Troubleshooting Runbook

## Overview

ArgoCD can show **Degraded** for an app that is fully synced and functionally
working. This is almost always a health-check configuration problem, not a real
failure. This runbook covers how ArgoCD determines health, the most common
causes of stale Degraded status, and how to fix them.

---

## How ArgoCD Determines Health

ArgoCD evaluates health at two levels:

### 1. Built-in resource health checks

ArgoCD ships with Lua-based health checks for standard Kubernetes resource
kinds. For Deployments, the built-in logic is:

```
Healthy    = spec.replicas == status.availableReplicas
             AND all pods pass their readiness probe
Progressing = rollout is in progress (updatedReplicas < spec.replicas)
Degraded   = progressDeadlineExceeded condition is True
             OR a container is in CrashLoopBackOff / OOMKilled
Missing    = resource exists in git but not in cluster
```

### 2. Custom health.lua overrides

ArgoCD allows per-resource Lua scripts in the `argocd-cm` ConfigMap
(`resource.customizations.health.*`). If a custom script returns
`hs.status = "Degraded"` for a resource that looks healthy to `kubectl`,
the override is the source of truth for ArgoCD.

To inspect active custom health checks:

```bash
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A 20 "resource.customizations"
```

### 3. Application-level health aggregation

An ArgoCD Application is **Healthy** only when every managed resource is
Healthy. A single Degraded or Missing child resource makes the whole app
Degraded, even if the app is Synced.

---

## Quick Diagnostic (5 commands)

Run these in order. Stop at the first failure and follow the fix.

```bash
# 1. Which resources are Degraded?
kubectl get application mereka-lms-prod -n argocd \
  -o jsonpath='{.status.resources[*]}' | python3 -m json.tool | \
  grep -E '"name"|"kind"|"health"'

# 2. Are pods actually ready?
kubectl get pods -n mereka-lms

# 3. Any recent OOMKill or CrashLoop?
kubectl get events -n mereka-lms --field-selector="reason=OOMKilling" --sort-by='.lastTimestamp'
kubectl get events -n mereka-lms --field-selector="reason=BackOff"    --sort-by='.lastTimestamp'

# 4. Is a rollout stuck?
kubectl rollout status deployment/<name> -n mereka-lms

# 5. Run the verification script
./scripts/qa/verify-argocd-health-config.sh --offline --online
```

---

## Common Causes of Stale Degraded

### Cause 1: Missing readiness probe

**Symptom**: ArgoCD reports the Deployment as Degraded immediately after
deploy, even though the pod is running.

**Why it happens**: Without a readiness probe, `kubectl get pods` shows the
pod as Running but ArgoCD's built-in health check requires `readyReplicas ==
spec.replicas`. If the pod never becomes Ready (no readiness probe to pass), it
stays Degraded.

**Fix**: Add a readiness probe to every container in the Deployment.

```yaml
readinessProbe:
  httpGet:
    path: /health/     # Django services use /health/ with trailing slash
    port: 8000
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

For the enterprise services in this project:
- `enterprise-catalog`: `/health/` on port 8160
- `enterprise-subsidy`: `/health/` on port 18280
- `enterprise-access`: `/health/` on port 18270
- LMS/CMS: `/heartbeat` on port 8000 (custom tutor path)

**Do not use** `/healthz` for Django services — that path is a Kubernetes
convention for Go services and does not exist in Django/edx-platform.

---

### Cause 2: Probe timeouts too aggressive

**Symptom**: Pods enter CrashLoopBackOff or are evicted under GKE node
pressure. ArgoCD reports Degraded intermittently.

**Why it happens**: If `timeoutSeconds` is 1 (the default) and the pod takes
2+ seconds to respond under load (e.g., after a cold start or GC pause), the
probe fails. After `failureThreshold` failures the pod is restarted. ArgoCD
sees the restart as Degraded.

**Fix**: Increase `timeoutSeconds` to at least 5 for Python/Java services:

```yaml
readinessProbe:
  timeoutSeconds: 5    # was 1 — GKE nodes under pressure can add 2-3s latency
  failureThreshold: 3
livenessProbe:
  timeoutSeconds: 5
  initialDelaySeconds: 30   # give the app time to fully start
  failureThreshold: 3
```

**Warning**: Do not exceed 10s for `timeoutSeconds` — ArgoCD's built-in health
check interprets very long probe timeouts as a misconfiguration in some
versions.

---

### Cause 3: progressDeadlineSeconds exceeded (stuck rollout)

**Symptom**: A rolling update starts but never completes. ArgoCD shows
Degraded with the message `Deployment exceeded its progress deadline`.

**Why it happens**:
- A new pod can't start because the node is out of memory
- An init container is stuck (e.g., `migrate` init container waiting for DB)
- The image pull is slow (large image from Artifact Registry on a cold node)

**Diagnostics**:

```bash
# Check rollout status
kubectl rollout status deployment/lms -n mereka-lms

# Describe the deployment for conditions
kubectl describe deployment lms -n mereka-lms | grep -A 10 "Conditions:"

# Check events for the stuck pods
kubectl get events -n mereka-lms --sort-by='.lastTimestamp' | tail -20
```

**Fixes**:

1. If the init container (migrate) is stuck waiting for the DB:
   ```bash
   # Check if DB is reachable from the init container
   kubectl exec -n mereka-lms deploy/lms -c migrate -- \
     python manage.py lms check --database default
   ```

2. If OOMKill is the root cause, increase the memory limit (see Cause 4).

3. If the image pull is slow, pre-pull the image on the node:
   ```bash
   kubectl debug node/<node-name> -it --image=busybox
   # Inside: crictl pull ghcr.io/biji-biji-initiative/mereka-lms/...
   ```

4. As a temporary unblock (do not use routinely):
   ```bash
   kubectl rollout undo deployment/lms -n mereka-lms
   ```

---

### Cause 4: OOMKill loop → Degraded

**Symptom**: Pod keeps restarting. `kubectl describe pod` shows
`OOMKilled: true`. ArgoCD shows Degraded for that Deployment.

**Why it happens**: The container's memory limit is hit. Linux OOM-killer
terminates the process. Kubernetes restarts it (CrashLoopBackOff), which
ArgoCD reports as Degraded.

**Diagnostics**:

```bash
# Check container restart count and last termination reason
kubectl get pods -n mereka-lms -o wide
kubectl describe pod <pod-name> -n mereka-lms | grep -A 5 "Last State:"

# Check recent OOM events
kubectl get events -n mereka-lms --field-selector="reason=OOMKilling"
```

**Fix**: Increase memory limits in the Deployment spec:

```yaml
resources:
  requests:
    memory: 512Mi   # Scheduler uses this for placement
  limits:
    memory: 2Gi     # Increase if OOMKill is happening at <512Mi
```

For LMS/CMS workers (Celery): they inherit the same Python process as LMS and
can use 1-2 GB per worker under load. Start at `limits.memory: 2Gi` for
workers.

For MFE containers (Node.js serving static files): 256 Mi is sufficient.
OOMKill on MFE containers usually means the Node.js build is running inside
the container at startup — check the Dockerfile entrypoint.

---

### Cause 5: ArgoCD hook resource not deleted → stale Degraded

**Symptom**: App was Healthy after initial deploy, then went Degraded after a
sync. The Degraded resource is a Job or Hook resource.

**Why it happens**: ArgoCD hook resources (annotated with
`argocd.argoproj.io/hook`) run as part of sync operations. If they don't have
a `argocd.argoproj.io/hook-delete-policy`, they persist after the sync and
ArgoCD's health check evaluates their final state. A Job that completed
successfully but is now `Completed` can confuse the health check in some ArgoCD
versions.

**Fix**: Add an explicit delete policy to all hook resources:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

Common delete policies:
- `HookSucceeded` — delete after successful completion (recommended for DB migrations)
- `BeforeHookCreation` — delete before re-creating on next sync (safe for idempotent jobs)
- `HookFailed` — delete only on failure (use for debugging)

**Check for hook resources in this repo**:
```bash
grep -rl "argocd.argoproj.io/hook" deploy/k8s/
```

---

### Cause 6: Server-added fields causing spurious Degraded

**Symptom**: ArgoCD shows OutOfSync even on a fresh deploy with no git changes.
Health status oscillates between Healthy and Degraded.

**Why it happens**: Kubernetes mutating admission controllers (e.g.,
cert-manager, Istio, GKE autopilot) add fields to resources after creation.
ArgoCD diffs the desired state (git) against the live state and finds
unexpected fields. In some cases this triggers a re-sync that can fail if the
mutation is not idempotent.

**Check the ignoreDifferences config**:
```bash
cat deploy/k8s/patches/argocd-configmap-ignore.yaml
```

**Add ignoreDifferences for known volatile fields** (edit the ConfigMap patch
or the Application spec in `infrastructure`):

```yaml
# In the ArgoCD Application spec
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/template/metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
    - group: ""
      kind: Service
      jsonPointers:
        - /spec/clusterIP
        - /spec/clusterIPs
```

---

## Fixes: Add Probes to a Deployment

If the offline check identified a Deployment missing probes, add them to the
YAML in `deploy/k8s/base/apps/`. Follow the enterprise catalog pattern
(`deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml`) as the
reference implementation.

Minimum probe configuration for any Django service:

```yaml
readinessProbe:
  httpGet:
    path: /health/
    port: 8000
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
livenessProbe:
  httpGet:
    path: /health/
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 15
  timeoutSeconds: 5
  failureThreshold: 3
```

For non-HTTP services (Redis, MySQL):
```yaml
readinessProbe:
  exec:
    command: ["redis-cli", "ping"]
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
```

---

## When to Use `argocd.argoproj.io/refresh: hard`

**Use hard refresh** when:
- ArgoCD is stuck showing OutOfSync after you merged a fix to git
- The resource cache in ArgoCD is stale (ArgoCD reconciles on a 3-minute timer
  by default)
- You want to force ArgoCD to re-evaluate health without triggering a sync

```bash
# Trigger a hard refresh (re-fetches git and re-evaluates health)
kubectl annotate application mereka-lms-prod \
  -n argocd \
  argocd.argoproj.io/refresh=hard

# Wait 30 seconds then check
kubectl get application mereka-lms-prod -n argocd \
  -o jsonpath='{.status.health.status}'
```

**Do not use hard refresh** as a fix for actual health problems — it only
refreshes the view; it does not change the underlying resource state.

**Do not use `kubectl patch` to silence Degraded status**. ArgoCD will
revert any direct patch to an Application or ApplicationSet it manages. See
`docs/adr/` and `.claude/rules/gitops-enforcement.md` for the mandatory
GitOps workflow.

---

## Escalation Path

1. Run `./scripts/qa/verify-argocd-health-config.sh --offline --online`
2. Check `kubectl describe pod <degraded-pod> -n mereka-lms` for the exact
   failure reason
3. Check `kubectl get events -n mereka-lms --sort-by='.lastTimestamp'`
4. If the root cause is a code bug (not config), raise a bead: `br new`
5. Fix in git, raise a PR to `infrastructure`, wait for ArgoCD to reconcile
   (≤3 minutes after merge)

---

## Related Documents

- `docs/ops/runbooks/ARGOCD_DRIFT.md` — "Synced but wrong" drift detection
- `deploy/k8s/patches/argocd-configmap-ignore.yaml` — resource exclusions
- `.claude/rules/gitops-enforcement.md` — ABSOLUTE RULE: no direct kubectl patch on ArgoCD-managed resources
- `specs/k8s-deployment_spec.md` — AC-003, AC-028, AC-032 (probe + health requirements)
