# ARC Heavy Builder Failure Taxonomy

> Lane F artifact. Decision-grade diagnosis of ARC runner queueing and availability issues.
>
> Date: 2026-03-12

## Architecture

| Property | Standard (`mereka-k8s-runners`) | Heavy (`mereka-k8s-heavy-builders`) |
|----------|--------------------------------|-------------------------------------|
| **Config source** | `bbi-infrastructure/clusters/dev/rke2/apps/arc-runners-standard.yaml` | `bbi-infrastructure/clusters/dev/rke2/apps/arc-runners-heavy.yaml` |
| **Image** | `ghcr.io/biji-biji-initiative/arc-runner-general:2026-03-11-192c475` | `ghcr.io/biji-biji-initiative/arc-runner-heavy:2026-03-11-192c475` |
| **Registration** | Org-level (`Biji-Biji-Initiative`) | Org-level (`Biji-Biji-Initiative`) |
| **Runner group** | `default` | `heavy-builders` |
| **minRunners** | 2 (warm) | 1 (warm) |
| **maxRunners** | 10 | 4 |
| **Max lifetime** | 1800s (30 min) | 2700s (45 min) |
| **DinD** | No | Yes (privileged sidecar) |
| **Caches** | None (ephemeral) | emptyDir for Docker + deps (ephemeral) |
| **CPU/RAM** | 250m-2 / 1-4Gi | 750m-4 / 4-12Gi (runner) + 500m-2 / 1-4Gi (DinD) |

## Stale Local Reference

The file `deploy/k8s/base/arc/runner-scale-set-*.yaml` in mereka-lms is **NOT deployed**. The actual config lives in `bbi-infrastructure`. Key differences:

| Property | Local Reference (stale) | Actual Deployed |
|----------|------------------------|-----------------|
| Image | `ghcr.io/actions/actions-runner:2.332.0` | Custom `arc-runner-general`/`arc-runner-heavy` |
| minRunners | 0 | 2 (standard), 1 (heavy) |
| maxRunners | 10 / 1 | 10 / 4 |
| Caches | PVCs (RWO) | emptyDir |
| githubConfigUrl | Repo-level (standard) | Org-level (both) |

## False Diagnosis: "0 Runners Available"

**Symptom**: `gh api repos/.../actions/runners` returned `total_count: 0`.

**Root cause**: Runners are registered at **org level**, not repo level. The correct API:
```bash
gh api orgs/Biji-Biji-Initiative/actions/runners  # → 15 runners
```

This was NOT a runner availability issue. The queueing was caused by:
1. Concurrency group scheduling (cancel-in-progress queues replacement runs)
2. Runner pod provisioning latency (even with warm runners, scale-up takes 10-30s)
3. Multiple repos competing for the same org-level runner pool

## Failure Modes

### 1. LISTENER_LIVENESS — Listener pod hangs

**Detection**: Jobs queue indefinitely despite runner pods existing.
**Cause**: ARC listener loses GitHub webhook connection. Without liveness probe, it never restarts.
**Status**: MITIGATED — `livenessProbe` added on `:8080` (failureThreshold=3, period=30s). Listener restarts after ~90s of unresponsiveness.

### 2. STORAGE_PRESSURE — Longhorn PVC accumulation (HISTORICAL)

**Detection**: All new volume creation blocked, DiskPressure on nodes.
**Cause**: Longhorn ephemeral PVCs from crashed runners accumulated `storageScheduled` budget.
**Status**: FIXED — Switched to `emptyDir` for all caches. No Longhorn dependency.
**Trade-off**: No cross-run cache persistence, but warm runner (minRunners=1) keeps cache alive.

### 3. CAPACITY_SATURATION — All runner slots consumed

**Detection**: Jobs queued, `gh api orgs/.../actions/runners` shows all busy.
**Cause**: maxRunners=4 (heavy) or 10 (standard) consumed by concurrent workflows.
**Status**: BOUNDED — maxRunnerLifetime prevents runaway jobs from holding slots.

### 4. RUNNER_GROUP_MISMATCH — Job targets wrong runner group

**Detection**: Job queues indefinitely, runners available but idle.
**Cause**: `runs-on:` label doesn't match any runner's labels.
**Status**: LOW RISK — Both runner sets use matching labels (scale set name = runs-on label).

### 5. IMAGE_PULL_FAILURE — Custom runner image unavailable

**Detection**: Runner pod stuck in `ImagePullBackOff`.
**Cause**: GHCR rate limit, expired token, or image not pushed.
**Status**: LOW RISK — `imagePullSecrets` configured, images pinned by tag.

### 6. CONCURRENCY_CANCEL — New push cancels queued run

**Detection**: Run shows "cancelled" despite no user action.
**Cause**: ci.yml `cancel-in-progress: true` cancels queued/in-progress runs when new push arrives.
**Status**: BY DESIGN — but can cause confusion when CI appears "stuck" then "cancelled".

## Recommendations

1. **Fix the API check**: Use `gh api orgs/.../actions/runners` not `repos/.../actions/runners` in any runner health scripts.
2. **Update stale local reference**: Add a prominent banner to `deploy/k8s/base/arc/` files noting they are NOT deployed.
3. **Monitor listener restarts**: The liveness probe is already in place; add a Prometheus alert for frequent listener restarts.
4. **No infrastructure changes needed**: The current config is sound. The "runners down" observation was a false diagnosis from querying the wrong API endpoint.

## Conclusion

The heavy-builder issue is **BOUNDED**. The primary observed symptom (jobs queued for hours, "0 runners") was caused by:
- Querying repo-level runner API instead of org-level (false "0 runners")
- Normal concurrency group cancellation behavior
- Scheduling latency under concurrent load

No infrastructure changes required. The listener liveness probe and emptyDir migration already address the historical failure modes.
