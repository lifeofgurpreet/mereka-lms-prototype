---
title: RC-05 Live Closure Evidence (2026-04-18)
type: evidence
status: closed
owner: platform-runtime
observed_at: 2026-04-18T06:26:57Z
last_verified_or_updated: 2026-04-18
---

# RC-05 Live Closure Evidence — 2026-04-18

This memo records the live on-cluster proof that RC-05 (Open edX Celery
worker readiness probe broadcasting cluster-wide via Redis and timing out
under load) is operationally closed, along with one important operational
defect that surfaced during closure.

## Evidence Packet Cross-Reference

- Source fix PR: `bbi-infrastructure#3202` — merged 2026-04-18T06:01:02Z at `a1f7936b84577ad6439bfca4012e39e3c4f77309`
- Diagnosis memo: `docs/status/active/evidence/rc02-102a56a07d/RC-05-PROBE-DIAGNOSIS.md`
- This memo supplements: `05-EVIDENCE-LEDGER.md` Tranche Completion Checklist
- Follow-up operational defect recorded below

## Live-State Proof (2026-04-18T06:26:57Z, ssh mereka / rke2-nonprod / mereka-lms-dev)

### Argo app state

```
$ kubectl -n argocd get application mereka-lms-dev -o jsonpath='sync={.status.sync.status} health={.status.health.status} rev={.status.sync.revision} op={.status.operationState.phase}'
sync=Synced health=Healthy rev=5f84789cf5c39912c7097bc33debda7b5156617a op=Succeeded
```

Argo `health=Healthy` flipped from `Progressing` once the new probe
cleared the rolling update. `rev=5f84789c` exactly matches
`bbi-infrastructure origin/main` HEAD at capture time — realization truth.

### Deployment readiness

```
$ kubectl -n mereka-lms-dev get deploy lms cms mfe lms-worker cms-worker caddy
lms          1/1   Ready
cms          1/1   Ready
mfe          1/1   Ready
lms-worker   1/1   Ready (on new probe + new RS lms-worker-794b9dcd6d)
cms-worker   1/1   Ready (on new probe + new RS cms-worker-8589dfc4dd)
caddy        1/1   Ready
```

All 6 deploys healthy. Both worker deployments are on NEW ReplicaSets
created at 2026-04-18T06:16:03Z (after Argo reconciled the probe change).

### Live probe spec confirmation

```
$ kubectl -n mereka-lms-dev get deploy cms-worker -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.exec.command}'
["/bin/sh","-c","ps -o comm= -p 1 | grep -qE 'celery|python'"]
```

This is the local PID-1 check introduced by `bbi-infrastructure#3202`.
The previous probe (`celery -A cms inspect ping -t 15`) is no longer
present.

### Image digest chain

- Live pod image (cms-worker, lms-worker): `ghcr.io/biji-biji-initiative/mereka-lms/openedx:9211c5479a9beebe38f13c051b4227a4f0f4a79c@sha256:edc9cb3302e27979191796cc6db4ca7ddea10ea92bc663f43fb5e937726b95a1`
- Live pod image (mfe): `ghcr.io/biji-biji-initiative/mereka-lms/mfe:9211c5479a9beebe38f13c051b4227a4f0f4a79c@sha256:fab90db6a4e99c5b34a6aae89d168970acc719a6e3357cbb327cd89d8c805d0c`

Digests match current promoted line from `mereka-lms@9211c5479a`.

### Product-surface proofs (from the same capture window)

| env | tenant | url | status |
|---|---|---|---|
| dev | shared-mereka | `https://apps.academyv2.mereka.dev/api/mfe_config/v1` | 200 |
| dev | skillourfuture | `https://apps.skillourfuture.academyv2.mereka.dev/api/mfe_config/v1` | 200 |
| dev | biji-biji | `https://apps.biji-biji.academyv2.mereka.dev/api/mfe_config/v1` | 200 |
| production | biji-biji | `https://apps.academy.biji-biji.com/api/mfe_config/v1` | 200 |
| dev | shared-mereka | `https://apps.academyv2.mereka.dev/theme/core.min.css` | 200 |

MFE configuration resolves correctly off each tenant's `apps.*`
SiteConfiguration row; Paragon core theme serves.

### Runtime health

```
$ kubectl logs -n mereka-lms-dev -l app.kubernetes.io/name=lms --tail=1000 | grep -cE "ModuleNotFoundError|ImportError"
0
$ kubectl logs -n mereka-lms-dev -l app.kubernetes.io/name=cms --tail=1000 | grep -cE "ModuleNotFoundError|ImportError"
0
```

Zero module-import failures in the last 1000 log lines for LMS and CMS.

## Closure Verdict

RC-05 is **operationally closed** on `rke2-nonprod`:

1. Source fix merged (`bbi-infrastructure#3202` → `a1f7936b`).
2. Argo pulled and realized the change (rev match after manual nudge — see follow-up below).
3. New probe is running on the live deployment (`/bin/sh -c 'ps -o comm= -p 1 | grep -qE celery|python'`).
4. New ReplicaSets created at `2026-04-18T06:16:03Z`; old pods on pre-fix probe are drained.
5. Argo `health=Healthy`.
6. Product surfaces (`/api/mfe_config/v1`, `/theme/core.min.css`) return 200 on all three dev tenants and prod biji-biji during the same capture window.

## Important Follow-up: Argo Silent-Sync-Stuck Defect

During live verification, `bbi-infrastructure#3202` merged at `06:01:02Z`
but the new probe was NOT applied to the deployment until `06:16:03Z` —
a 15-minute gap in which Argo reported:

- `sync.status=Synced`
- `health=Progressing`
- `operationState.phase=Succeeded`
- `resources_outofsync=empty`

**but** the live deployment spec still carried the OLD probe. The live
deployment's `kubectl.kubernetes.io/last-applied-configuration` annotation
showed the old probe's command/timeouts.

Additional signal: `.status.operationState.operation.sync.autoHealAttemptsCount = 29`
— Argo had attempted to auto-heal 29 times without actually applying the
spec change.

Manual nudge that unblocked the sync:

```
kubectl -n argocd annotate application mereka-lms-dev \
  argocd.argoproj.io/refresh=hard --overwrite
```

After this annotation, a new sync operation ran, a new ReplicaSet was
created with the correct probe spec, and the rollout completed within
~3 minutes.

### Why this matters

This is a separate operational defect from RC-05 itself. The source fix
worked exactly as designed; the delivery path did not. Possible causes
(not yet root-caused):

- ServerSideApply field-manager conflict silently rejecting the probe patch
  (Argo has `syncOptions: ["ServerSideApply=true", "ApplyOutOfSyncOnly=true"]`)
- A mutating webhook rewriting the probe back to a prior shape after apply
- Argo refresh cadence (3min default) + autoHeal backoff failing to compound
  into a visible error

None of these is a blocker for closing RC-05, but all three are candidates
for a follow-up investigation. Until this is understood, operators should
treat `autoHealAttemptsCount > ~5` on any Argo application as a signal that
a manual `argocd.argoproj.io/refresh=hard` nudge may be required.

### Recommended follow-up

- **Bead suggestion**: `mereka-lms-argosync-stuck-20260418` — investigate why
  selfHeal attempted 29× without applying the probe spec; write a runbook
  for the hard-refresh recovery pattern; consider adding a Prometheus alert
  on Argo `autoHealAttemptsCount > 5`.
- **Cross-repo touch**: This is an `argocd` application defect; fix lives in
  `bbi-infrastructure` (Argo Application manifest or cluster-level). File
  the bead in the `bbi-infrastructure` repo, not `mereka-lms`.

## What This Memo Does Not Prove

- It does not prove liveness against broker-connectivity failures. The new
  probe checks PID-1 is the celery/python process, not that the worker can
  reach Redis. That gap is mitigated via Prometheus alert on
  `celery_worker_last_heartbeat_seconds` (separate observability concern,
  outside this tranche).
- It does not prove the Argo sync defect is a standalone issue; a second
  occurrence on an unrelated manifest change would confirm the class.
- It does not settle the `/authn/login` SESSION_COOKIE_DOMAIN console-warning
  question — that remains an open follow-up requiring browser-session
  inspection, not static probe.
