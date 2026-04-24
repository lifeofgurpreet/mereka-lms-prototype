# OG-01: Stale ArgoCD Operation — Operator Runbook

**Charter**: Mereka LMS Conveyor Closure (rc02-102a56a07d)
**Item**: OG-01 — Hardening: stale Argo `operation` field recovery
**Date**: 2026-04-18
**Audience**: On-call operators; assumes `kubectl` + `argocd` CLI access

---

## What Is a "Stale Argo Operation"?

An ArgoCD **Application** object carries two operation-related fields:

| Field | Purpose |
|---|---|
| `.operation` | The *desired* operation — set by the controller when a sync is requested |
| `.status.operationState` | The *current* execution state — updated live as the sync runs |

A **stale operation** occurs when `.operation` is still populated (or `.status.operationState.phase` is stuck in `Running`) after the sync runner has died, been evicted, or lost contact with the repo server. The controller no longer has a running goroutine to advance the state, so the app appears to be perpetually syncing.

### When Does This Happen on rke2-nonprod?

Common triggers observed in this cluster:

1. **ARC runner terminated mid-dispatch** — the Dispatch Dev Promotion job posts `workflow_dispatch` to bbi-infrastructure, then the runner pod is evicted before receiving the acknowledgement. The ArgoCD sync was already triggered by a previous auto-heal cycle; two operations queue up.
2. **API server timeout during rollout** — `controller.repo.server.timeout.seconds = 300` (5 min); if manifest generation takes longer, the repo-server request times out but the operation remains in `.status.operationState`.
3. **ArgoCD application controller pod restart** — controller is a StatefulSet (`argocd-application-controller-0`). On restart it re-reads application state from etcd. If the in-memory goroutine tracking the operation was lost, the persisted `.operation` field is orphaned.
4. **Self-heal storm** — `mereka-lms-dev` runs `autoHealAttemptsCount: 21` (observed in live state). When the image digest changes rapidly across multiple promotion PRs merging quickly, the controller queues multiple operations faster than it can process them.

---

## Symptoms

| Symptom | `kubectl` evidence |
|---|---|
| App stuck in "Syncing" in ArgoCD UI for > 5 min with no pod activity | `kubectl get app mereka-lms-dev -n argocd -o jsonpath='{.status.operationState.phase}'` → `Running` |
| Promotion PR merged but dev pods haven't rolled | `.status.operationState.startedAt` is old (> 10 min ago) with no `finishedAt` |
| `.operation` field present with no matching active reconciliation | `.operation.sync.revision` exists but `.status.operationState` has a different or missing `finishedAt` |
| ArgoCD UI shows "SYNCING" badge that never clears | UI reads `.status.operationState.phase` directly |
| `argocd app get` reports `Operation: Running` indefinitely | CLI reads same field |

---

## Diagnosis Commands

Run these in order. Stop when you have identified the root cause.

### Step 1: Confirm the Phase Is Actually Stuck

```bash
kubectl get app mereka-lms-dev -n argocd \
  -o jsonpath='phase={.status.operationState.phase} started={.status.operationState.startedAt} finished={.status.operationState.finishedAt}{"\n"}'
```

**Expected when stuck**: `phase=Running` + `started=<old timestamp>` + `finished=` (empty).

**Not stuck if**: `phase=Succeeded` or `phase=Failed` and `finished=` is recent.

### Step 2: Check Controller Liveness

> From `platform-debugging.md`: prove the running config before editing.

```bash
# Is the controller pod running?
kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Has it restarted recently?
kubectl get pod argocd-application-controller-0 -n argocd \
  -o jsonpath='restarts={.status.containerStatuses[0].restartCount} reason={.status.containerStatuses[0].lastState.terminated.reason}{"\n"}'

# Controller logs for this app — look for "Attempting to sync" or "operation in progress"
kubectl logs argocd-application-controller-0 -n argocd --since=10m \
  | grep -iE 'mereka-lms-dev|operation|sync|error' | tail -30
```

### Step 3: Inspect the Full Operation Object

```bash
kubectl get app mereka-lms-dev -n argocd -o yaml \
  | grep -A 60 "operationState:"
```

**RED FLAGS** — see Escalation section below:
- `message: admission webhook denied the request` — Kyverno blocked the sync
- `message: repository not found` or `message: authentication required` — git auth failure
- `message: context deadline exceeded` — repo server timeout (expected if manifests are large; wait for retry)

### Step 4: Check Auto-Heal Attempt Count

```bash
kubectl get app mereka-lms-dev -n argocd \
  -o jsonpath='{.status.operationState.operation.sync.autoHealAttemptsCount}{"\n"}'
```

If this equals the retry limit (configured as `limit: 5` in `syncPolicy.retry`), the app has exhausted retries and will NOT self-recover.

### Step 5: Confirm Refresh Interval and Last Refresh

```bash
# Our cluster: timeout.reconciliation=30s in argocd-cm (unusually fast — this is the git poll interval, not operation timeout)
kubectl get cm argocd-cm -n argocd -o jsonpath='{.data.timeout\.reconciliation}{"\n"}'

# When did ArgoCD last compare git state?
kubectl get app mereka-lms-dev -n argocd \
  -o jsonpath='{.status.reconciledAt}{"\n"}'
```

---

## Recovery Decision Tree

```
Is .status.operationState.phase == "Running" AND started > 10 min ago?
│
├─ NO → App is not stuck. Normal state. Stop.
│
└─ YES
    │
    ├─ Has the retry limit been hit? (autoHealAttemptsCount == 5 or limit exhausted?)
    │   ├─ NO → Wait up to 5 min for the built-in retry backoff to self-heal.
    │   │        Retry policy: 10s initial, factor=2, maxDuration=5m.
    │   │        The controller will attempt up to 5 retries automatically.
    │   │
    │   └─ YES → Proceed to Option A below.
    │
    └─ Is it a RED FLAG error (Kyverno denial, git auth, etc.)?
        ├─ YES → ESCALATE (do not attempt recovery — see Escalation section)
        └─ NO  → Proceed through Options A → B → C in order
```

---

## Recovery Options (Least to Most Invasive)

### Option A — Hard Refresh via Annotation (Preferred; Non-Destructive)

Triggers ArgoCD to re-fetch git state without touching `.operation`. Kyverno-safe because Application resources are managed by ArgoCD, but the annotation write is done via the SA impersonation path (see `gitops-enforcement.md` emergency bypass).

> **Rule**: Never directly `kubectl patch` an ArgoCD-managed resource. See `gitops-enforcement.md`.
> The Application object itself has `argocd.argoproj.io/tracking-id: argocd-config-dev:...`
> BUT Application objects are a special case — the ArgoCD controller owns the Application CRD,
> and the `argocd.argoproj.io/refresh` annotation is the sanctioned recovery mechanism.

```bash
# Trigger a hard refresh (forces git re-fetch)
kubectl annotate app mereka-lms-dev -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

Wait 30–60 seconds. Re-check `.status.operationState.phase`. If it transitions to `Succeeded` or `Failed`, recovery is complete.

**Why this works**: The controller watches for this annotation and enqueues a forced reconciliation, which can interrupt the stuck operation.

**Why it's safe**: It writes only to an annotation on the Application object, not to any managed K8s resource in `mereka-lms-dev` namespace.

### Option B — ArgoCD CLI Terminate (Preferred When CLI Is Accessible)

This is the cleanest path. It calls the ArgoCD API to terminate the running operation — equivalent to clicking "Terminate" in the UI.

```bash
# Option B-1: If you have a valid ArgoCD session token
export ARGOCD_AUTH_TOKEN="<token-from-argocd-ui-or-infisical>"
argocd app terminate-op mereka-lms-dev \
  --server argocd.mereka.dev \
  --grpc-web

# Option B-2: Verify the operation is gone
argocd app get mereka-lms-dev \
  --server argocd.mereka.dev \
  --grpc-web
```

After termination, ArgoCD's automated sync policy (`selfHeal: true`) will schedule a fresh sync within one reconciliation cycle (≈30 s on this cluster, `timeout.reconciliation=30s`).

**Note on auth**: The ArgoCD CLI session on this host was expired as of 2026-04-18. Use `argocd login argocd.mereka.dev --sso` or retrieve a token from the Authentik-backed UI at `https://argocd.mereka.dev`.

### Option C — kubectl patch via ArgoCD SA Impersonation (Last Resort)

Only use this when:
- Option A had no effect after 2 minutes
- Option B is unavailable (CLI unreachable, auth token expired, server degraded)
- The situation is blocking a production-critical promotion

> This is the "Emergency Bypass" from `gitops-enforcement.md`. Document the reason.
> After using this, raise a PR to git so ArgoCD reconciles to a clean state.

```bash
# Clear the .operation field via ArgoCD application controller SA
# This impersonates the controller's own service account — Kyverno does not block
# mutations that the controller itself would make.
kubectl --as=system:serviceaccount:argocd:argocd-application-controller \
  patch app mereka-lms-dev -n argocd \
  --type merge \
  -p '{"operation": null}'
```

**IMPORTANT**: After this:
1. Verify the app begins a fresh sync: `kubectl get app mereka-lms-dev -n argocd -o jsonpath='{.status.operationState.phase}'`
2. Confirm pods rolled to expected digest: `kubectl get pods -n mereka-lms-dev -o jsonpath='{.items[*].spec.containers[0].image}'`
3. Document the bypass in the incident channel with the timestamp and reason.

---

## What NOT to Do

| Temptation | Why It's Wrong |
|---|---|
| `kubectl patch app ... --type merge -p '{"status": ...}'` without SA impersonation | Blocked by K8s RBAC (`status` subresource requires controller-level perms) |
| Restarting `argocd-application-controller-0` | From `platform-debugging.md`: never restart infrastructure to fix symptoms. Controller restart causes all apps to re-reconcile simultaneously and can trigger a cascade. |
| `kubectl delete pod -n mereka-lms-dev` to force a rollout | Does not help if the operation is stuck at the Application level — the pod restart will be undone by the existing Deployment spec. |
| Patching `mereka-lms-dev` Deployments directly with new image tags | Violates `gitops-enforcement.md`. ArgoCD `selfHeal: true` will revert it within 30 s. |
| Running `argocd app sync --force` without terminating the stuck op | Will queue a second operation behind the stuck one, compounding the problem. |

---

## Escalation Criteria

Escalate to senior infra if any of the following are true:

| Condition | How to Detect | Meaning |
|---|---|---|
| `.status.operationState.message` contains `admission webhook denied` | `kubectl get app mereka-lms-dev -n argocd -o jsonpath='{.status.operationState.message}'` | A Kyverno policy blocked the sync. The policy must be investigated — do not attempt to bypass it. |
| `.status.operationState.message` contains `repository not found` or `authentication required` | Same as above | GitHub App token for ArgoCD → bbi-infrastructure access has expired or been revoked. Check `argocd-repo-server` logs. |
| `.status.operationState.phase` is `Failed` AND `finishedAt` is recent | Phase settled but app is degraded | Normal failure — read the message, fix in git. Not a stuck operation. |
| `kubectl get pod argocd-application-controller-0 -n argocd` shows `CrashLoopBackOff` | Pod status | Controller is down. All app reconciliation is halted cluster-wide. |
| Options A + B + C all fail and app remains in `Running` for > 30 min | Elapsed time + phase unchanged | Possible etcd corruption or controller-level bug. File a GitHub issue on ArgoCD. |

---

## ArgoCD Timeout Reference (This Cluster)

| Config Key | Value | Location | Meaning |
|---|---|---|---|
| `timeout.reconciliation` | `30s` | `argocd-cm` | Git poll interval — how often ArgoCD checks for new commits |
| `controller.repo.server.timeout.seconds` | `300` (5 min) | `argocd-cmd-params-cm` | Max time ArgoCD waits for repo-server to generate manifests |
| `reposerver.git.request.timeout` | `5m` | `argocd-cmd-params-cm` | Max time for individual git operations (clone, fetch) |
| Operation timeout (default) | **None** | ArgoCD built-in | ArgoCD v2+ has no built-in operation timeout by default. A stuck `Running` operation will not self-clear without intervention. |

**Key implication**: There is no automatic 2-hour timeout. A stale operation is permanent until explicitly terminated (Option B) or the controller restarts.

---

## Quick Reference Card

```bash
# 1. Diagnose
kubectl get app mereka-lms-dev -n argocd \
  -o jsonpath='phase={.status.operationState.phase} started={.status.operationState.startedAt}{"\n"}'

# 2. Hard refresh (Option A — try first)
kubectl annotate app mereka-lms-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite

# 3. CLI terminate (Option B — if A fails after 2 min)
ARGOCD_AUTH_TOKEN=<token> argocd app terminate-op mereka-lms-dev \
  --server argocd.mereka.dev --grpc-web

# 4. SA impersonation patch (Option C — last resort, document it)
kubectl --as=system:serviceaccount:argocd:argocd-application-controller \
  patch app mereka-lms-dev -n argocd --type merge -p '{"operation": null}'

# 5. Verify recovery
kubectl get app mereka-lms-dev -n argocd \
  -o jsonpath='phase={.status.operationState.phase} finished={.status.operationState.finishedAt}{"\n"}'
```

---

## Related Reading

- `gitops-enforcement.md` — absolute rule on ArgoCD-managed resources, emergency bypass procedure
- `platform-debugging.md` — prove running config before editing; never restart infra to fix symptoms
- `docs/status/active/evidence/rc02-102a56a07d/OG-03-PROMOTE-AUDIT.md` — promote chain pain points that motivated this runbook
- ArgoCD v3 docs: `argocd app terminate-op` — https://argo-cd.readthedocs.io/en/stable/user-guide/app_deletion/
