---
title: Fastlane Runner Containerd Race Condition — Root Cause + Durable Fix
date: 2026-04-20
author: operator-loop (post slice 81)
severity: P1-stability (intermittent CI failures, not outage)
status: shipped
---

# Fastlane Runner Containerd Race Fix (2026-04-20)

## Symptom

CI run 24641484520 / job 72048194619 (Build OpenEdX Image for PR #1906
merge SHA `9bbb5bfb6e20ca9a1a2ced3032e0286b467bcb95`) failed at the
post-push verification step on runner `mereka-lms-fastlane-build-2`:

```
Error response from daemon: failed commit on ref
"index-sha256:dacdf651d708143aa45636cb705a345648fd8385cc8a406e52bcbaaa9dd85629":
commit failed: rename
/var/lib/containerd/io.containerd.content.v1.content/ingest/b2633f2b911f08bffc64b5176aa0873c2eae16cae297b65953ae4cb006bdf9b6/data
/var/lib/containerd/io.containerd.content.v1.content/blobs/sha256/dacdf651...:
no such file or directory
```

The image itself had already been built and pushed to GHCR successfully —
only the post-push `docker pull` (inside `verify-openedx-custom-app-imports.sh`)
failed.

## Root cause

Host `vmi3220759` runs **15 concurrent GitHub Actions runner services**
across four projects (mereka-lms, mereka-agent-e, cie, zoom-rtms). Docker
on this host uses the **containerd snapshotter**:

```
Storage Driver: overlayfs
  driver-type: io.containerd.snapshotter.v1
```

Consequence: Docker images, BuildKit cache, and in-flight `docker pull`
ingest all share one content store at
`/var/lib/containerd/io.containerd.content.v1.content/`.

Every job completion invokes `/usr/local/lib/gha-fastlane/cleanup.sh`
(wired via `ACTIONS_RUNNER_HOOK_JOB_COMPLETED`) which runs:

```bash
docker container prune -f
docker image prune -f
docker builder prune -af --keep-storage 80GB
docker volume prune -f
```

With 15 concurrent runners, cleanup hooks fire constantly and uncoordinated.
The `docker builder prune -af` on runner A can wipe ingest blobs that
runner B's concurrent `docker pull` is mid-write → the rename that commits
`ingest/<hex>/data` → `blobs/sha256/<hex>` fails because the source file
was just deleted out from under the pull.

This is **not transient** — it is an architectural race that will
recur under load.

## Fix (shipped)

Wrapped the prune block with:

1. A **host-wide flock** (`/var/lock/fastlane-docker-prune.lock`) to
   serialize prune invocations against each other.
2. A **concurrency guard**: `pgrep -c -f "Runner\.Worker spawnclient"` — if
   any *other* Runner.Worker process is still active on the host, skip
   prune entirely (the current runner's own Worker has already exited by
   the time this hook fires, so a count > 0 means OTHER jobs are live).
3. A **disk-pressure override**: if `df /` shows >92% used, force the
   prune anyway — a full disk breaks every runner, while a transient pull
   race only breaks one concurrent job.

Patched files on `vmi3220759`:

- **Live**: `/usr/local/lib/gha-fastlane/cleanup.sh` (backup:
  `cleanup.sh.bak-20260420T012557Z`)
- **SOT**: `/root/scripts/ci/fastlane-build-cleanup.sh` (backup:
  `fastlane-build-cleanup.sh.bak-20260420T012746Z`)

Both files now match — re-running `bootstrap-fastlane-build-host.sh` will
preserve the fix.

## Verification

Dry-run with other jobs active:

```
$ RUNNER_HOME=/tmp/nonexistent RUNNER_WORK_ROOT=/tmp/nonexistent \
    /usr/local/lib/gha-fastlane/cleanup.sh
fastlane cleanup: 2 concurrent job(s) still active, skipping prune to avoid containerd race
```

Exit 0. The prune block correctly no-ops when other workers are busy.

Syntax check (`bash -n`) passes. Affects all 15 runners on the host:

- mereka-lms: build, build-2, ci, ci-2, ci-3
- mereka-agent-e: build, ci, fastlane-ci-2
- cie: build, build-2, ci, fastlane-ci-2
- zoom-rtms: build, ci, fastlane-ci-2
- plus base `github-runner`

All reference `ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/usr/local/lib/gha-fastlane/cleanup.sh`.

## Residual risk

- **Under sustained load**, prune may be skipped on every job completion
  because at least one Worker is always active. With `--keep-storage 80GB`
  already capping BuildKit cache and current disk at 85% with 53 GB free,
  this is acceptable; disk-pressure override kicks in at 92%.
- **If cleanup.sh gets re-derived from app-repo CI**, the fix will be lost
  unless the app-repo CI provisioner respects the SOT file. The SOT now
  carries the fix, so `bootstrap-fastlane-build-host.sh` is safe.
- **This fix is out-of-repo** (lives on a VPS not backed by git). Consider
  moving `/root/scripts/ci/` into a provisioning repo (bbi-infrastructure
  or a dedicated ops repo) for future audibility. Filed as follow-up bead
  suggestion: **OPS-001 — version-control VPS /root/scripts/ci provisioning**.

## Links

- Failed job log: run 24641484520, job 72048194619 (mereka-lms repo)
- Related PR in flight: #1906 (`getMerekaShellCopy` Authn MFE fix)
- Slice-81 update in `docs/status/active/CURRENT-OPERATOR-STATE.md`
