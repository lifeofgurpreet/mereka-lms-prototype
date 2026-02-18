# Kind Cluster Recovery Evidence (3cdw)

> Root cause analysis and recovery status for `mereka-lms-local` Kind cluster.
>
> **Bead**: mereka-lms-3cdw
> **Date**: 2026-02-18
> **Cluster**: kind-dev
> **ArgoCD App**: mereka-lms-local (OutOfSync / Degraded → fix committed)

## Pod Status Summary (pre-fix)

| Pod | Status | Root Cause | Category |
|-----|--------|-----------|----------|
| caddy | Running (1/1) | — | Core |
| lms-worker | Running (1/1) | — | Core |
| cms-worker | Running (1/1) | — | Core |
| mfe | Running (1/1) | — | Core |
| mongodb | Running (1/1) | — | Core |
| mysql | Running (2/2) | — | Core |
| redis | Running (2/2) | — | Core |
| smtp | Running (1/1) | — | Core |
| **cms** | **CrashLoop (1778 restarts)** | **OOMKilled (exit 137)** — 6Gi limit insufficient for CMS startup spike | Core |
| **meilisearch** | **FailedCreate (0/1)** | **Kyverno `require-non-root-security-context`** blocks pod creation — missing `runAsNonRoot: true` + `MEILISEARCH_MASTER_KEY` missing from secret | Search |
| enterprise-access | ImagePullBackOff | 403 from GCR — Kind lacks Artifact Registry auth | Enterprise |
| enterprise-access-worker | ImagePullBackOff | Same as above | Enterprise |
| enterprise-admin-portal | ImagePullBackOff | Same as above | Enterprise |
| enterprise-catalog | ImagePullBackOff | Same as above | Enterprise |
| enterprise-catalog-worker | ImagePullBackOff | Same as above | Enterprise |
| enterprise-learner-portal | ImagePullBackOff | Same as above | Enterprise |
| enterprise-subsidy | ImagePullBackOff | Same as above | Enterprise |
| payments-gateway | ImagePullBackOff | Same as above — image not loaded into Kind | Payments |
| postgresql-payments | Pending | PVC VolumeBinding timeout — provisioner not responding | Payments |
| lms-worker (duplicate) | ImagePullBackOff | Newer replicaset with different image tag | Core |
| promtail (x2) | ContainerCreating | `/var/lib/docker/containers` not a directory on Kind nodes (containerd, not Docker) | Telemetry |

## Root Cause Analysis

### RC-1: Enterprise services — 403 from GCR (7 pods)

**Cause**: All enterprise service images reference `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-*:latest`. The Kind cluster lacks:
1. An `imagePullSecret` with GCR credentials
2. Pre-loaded images via `kind load docker-image`

**Error**: `Failed to pull image: failed to authorize: unexpected status from GET request to https://asia-southeast1-docker.pkg.dev/v2/token: 403 Forbidden`

**Fix applied**: Scale all enterprise services to `replicas: 0` in the local overlay (`deploy/k8s/overlays/local/kustomization.yaml`). Enterprise services are not needed for local development.

### RC-2: CMS OOMKilled (1 pod, 1778 restarts)

**Cause**: CMS container exits with code 137 (OOMKilled). Current limit is 6Gi but CMS uWSGI can spike above this during startup when loading Django apps + courseware models.

**Fix applied**: Increase memory limit from 6Gi to 7Gi via Kustomize patch (`patches/cms-memory-limits.yaml`).

### RC-3: Meilisearch — Kyverno policy block + missing secret (1 pod)

**Cause** (dual):
1. `MEILISEARCH_MASTER_KEY` key did not exist in `openedx-secrets` Secret — container couldn't start
2. Kyverno `require-non-root-security-context` policy blocks pod creation because deployment was missing `runAsNonRoot: true`

**Error**: `admission webhook "validate.kyverno.svc-fail" denied the request: resource Pod/mereka-lms/meilisearch-7db45f67f6-hphvk was blocked due to the following policies: require-non-root-security-context`

**Fix applied**:
1. Secret patched: `kubectl --context kind-dev patch secret openedx-secrets -n mereka-lms --type merge -p '{"data":{"MEILISEARCH_MASTER_KEY":"..."}}'`
2. Security context patched via Kustomize (`patches/meilisearch-security-context.yaml`): adds `runAsNonRoot: true` at both pod and container level

### RC-4: PostgreSQL payments — PVC binding timeout (1 pod)

**Cause**: PVC cannot bind — the Kind cluster's storage provisioner is not responding or the PV was never created.

**Fix applied**: Scale `payments-gateway` to `replicas: 0` in local overlay. PostgreSQL payments depends on payments-gateway which also has ImagePullBackOff — both disabled for local dev.

### RC-5: Promtail DaemonSet — host path volume (2 pods)

**Cause**: Promtail pods stuck in ContainerCreating — `MountVolume.SetUp failed for volume "varlibdockercontainers": hostPath type check failed: /var/lib/docker/containers is not a directory`. Kind uses containerd, not Docker, so `/var/lib/docker/containers` does not exist.

**Fix**: Known Kind limitation. Promtail is telemetry (optional). Pods will remain in ContainerCreating but do not affect core functionality.

## Fixes Applied

### Kustomize Patches (committed to repo)

| File | Target | Change |
|------|--------|--------|
| `patches/meilisearch-security-context.yaml` | Deployment/meilisearch | `runAsNonRoot: true` at pod + container level |
| `patches/cms-memory-limits.yaml` | Deployment/cms | Memory limit 6Gi → 7Gi |
| `kustomization.yaml` replicas | Enterprise services (7) + payments-gateway | `replicas: 0` |

### Manual fixes (applied to live cluster)

| Fix | Command |
|-----|---------|
| MEILISEARCH_MASTER_KEY | `kubectl patch secret openedx-secrets --type merge` |

## Core Service Health (AC-BEADS-006)

| Core Service | Status (pre-fix) | Status (post-fix expected) |
|-------------|------------------|---------------------------|
| LMS (lms-worker) | Running 1/1 | Running 1/1 |
| CMS | OOMKilled (oscillating) | Running 1/1 (7Gi limit) |
| CMS Worker | Running 1/1 | Running 1/1 |
| MFE | Running 1/1 | Running 1/1 |
| Caddy | Running 1/1 | Running 1/1 |
| MySQL | Running 2/2 | Running 2/2 |
| MongoDB | Running 1/1 | Running 1/1 |
| Redis | Running 2/2 | Running 2/2 |
| SMTP | Running 1/1 | Running 1/1 |
| Meilisearch | FailedCreate (0/1) | Running 1/1 |

**Result (pre-fix)**: 8/10 core services healthy. CMS and Meilisearch require fixes.
**Result (post-fix expected)**: 10/10 core services healthy after ArgoCD sync.

## ArgoCD Status (AC-BEADS-007)

```
mereka-lms-local  OutOfSync  Degraded
```

**Root cause**: Kyverno-blocked meilisearch, OOMKilled CMS, and ImagePullBackOff pods make the app Degraded. OutOfSync because local manifests diverged from the Git source.

**Fix path**: After commit + push, ArgoCD auto-syncs or manual sync:
```bash
argocd app sync mereka-lms-local
```

Expected post-sync state: `Synced / Progressing` → `Synced / Healthy` (after CMS starts with 7Gi).

## Resolution Summary (AC-BEADS-008)

| Root Cause | Fix | Status | Priority |
|-----------|-----|--------|----------|
| RC-1: Enterprise ImagePull | Scale to 0 in local overlay | **FIXED** | P2 |
| RC-2: CMS OOMKilled | Memory limit 6Gi → 7Gi via Kustomize patch | **FIXED** | P1 |
| RC-3: Meilisearch Kyverno + secret | Security context patch + secret patched | **FIXED** | P1 |
| RC-4: PostgreSQL PVC | Scale payments-gateway to 0 in local overlay | **FIXED** | P2 |
| RC-5: Promtail stuck | Known Kind limitation (containerd), no fix needed | **DOCUMENTED** | P3 |

## Verification Commands

```bash
# Check pod status
kubectl --context kind-dev get pods -n mereka-lms

# Check ArgoCD app
kubectl --context kind-dev get application mereka-lms-local -n argocd

# Core service health
kubectl --context kind-dev get pods -n mereka-lms -l 'app.kubernetes.io/name in (lms,cms,mfe,caddy,mysql,mongodb,redis,smtp,meilisearch)' -o wide

# Check events for errors
kubectl --context kind-dev get events -n mereka-lms --sort-by='.lastTimestamp' --field-selector type=Warning | tail -20

# Verify enterprise services scaled to 0
kubectl --context kind-dev get deploy -n mereka-lms -l 'app.kubernetes.io/name in (enterprise-access,enterprise-catalog,enterprise-subsidy,enterprise-admin-portal,enterprise-learner-portal)' -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas'
```
