# Runner Hygiene — Buildx Cleanup & Health Monitoring

_Audience: Platform operators · Owner: Platform Team · Status: canonical_

This runbook covers the buildx cleanup and health-monitor automation for the
fastlane VPS runner (`vmi3220759`, Tailscale `100.68.111.80`).  Install once;
cron handles the rest.

---

## Background

The fastlane runner is a long-lived VPS (not ephemeral like ARC pods).  Every
`docker buildx build` invocation with the `docker-container` driver spawns a
`buildx_buildkit_*` container.  Under normal load these accumulate because:

- BuildKit containers are not removed automatically when a job exits.
- Interrupted or timed-out CI runs can leave containers in a running-but-idle
  state indefinitely.
- Interrupted cleanup can also leave `buildx_buildkit_*_state` Docker volumes
  behind after the matching BuildKit container is gone.
- Repeated `docker/setup-buildx-action` calls create a new named builder per
  run when the previous one was not torn down.

Left unattended, the runner can accumulate 20–30 containers and tens of stale
state volumes, consuming memory and disk before application build code runs.
Each idle BuildKit worker uses ~100–200 MB, and orphan state volumes have caused
fastlane root disk exhaustion during app-cache-cold benchmark proofs.

The benchmark workflow also pre-cleans repo-scoped Tutor/build directories
before `actions/checkout` on persistent self-hosted jobs. That cleanup is
intentionally separate from `buildx-cleanup.sh`: Buildx cleanup owns Docker
builders, orphan BuildKit containers, and orphan BuildKit state volumes; the
workflow pre-checkout cleanup owns stale workspace paths such as `tutor_env`,
`var/ci`, `var/bootstrap-readiness`, and `.buildx-cache`. This avoids checkout
failures when previous Tutor or containerized build steps left root-owned files
inside the worktree.

---

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/runner/buildx-cleanup.sh` | Prune stale buildx builders; exit 0/1/2 |
| `scripts/runner/buildx-monitor.sh` | Quick health check; exit 0/1/2 |

Install path on the runner: `/opt/runner/` (see [Manual Install](#manual-install)).

---

## Exit Codes

### `buildx-cleanup.sh`

| Code | Meaning |
|------|---------|
| `0` | All requested removals succeeded, dry-run completed, or destructive cleanup was deferred because active Docker/BuildKit substrate work was present |
| `1` | Docker daemon unavailable |
| `2` | Partial failure — some removed, some failed |

### `buildx-monitor.sh`

| Code | Meaning |
|------|---------|
| `0` | Healthy — all checks passed |
| `1` | Degraded — at least one warning |
| `2` | Critical — docker unavailable or builder count > 10 |

---

## Cron Schedule (recommended)

Add the following entries to root's crontab on the VPS runner
(`crontab -e` as root, or drop a file in `/etc/cron.d/buildx-runner`):

```cron
# buildx cleanup — prune stale builders every 30 minutes
*/30 * * * * root /opt/runner/buildx-cleanup.sh >> /var/log/buildx-cleanup.log 2>&1

# buildx health monitor — alert via syslog on degraded/critical
*/5 * * * * root /opt/runner/buildx-monitor.sh || echo "CRITICAL: buildx unhealthy on $(hostname)" | logger -t buildx-monitor
```

**Log rotation**: add `/etc/logrotate.d/buildx-cleanup` to rotate
`/var/log/buildx-cleanup.log` weekly:

```
/var/log/buildx-cleanup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
```

---

## Systemd Timer (alternative to cron)

If the runner uses systemd, prefer timer units for better observability:

```ini
# /etc/systemd/system/buildx-cleanup.service
[Unit]
Description=Prune stale buildx builders
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/opt/runner/buildx-cleanup.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=buildx-cleanup
```

```ini
# /etc/systemd/system/buildx-cleanup.timer
[Unit]
Description=Run buildx-cleanup every 30 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
Unit=buildx-cleanup.service

[Install]
WantedBy=timers.target
```

Enable:

```bash
systemctl daemon-reload
systemctl enable --now buildx-cleanup.timer
systemctl list-timers buildx-cleanup.timer
```

---

## Manual Install

Run once to install scripts to `/opt/runner/` on the VPS runner.

### Step 1 — Copy scripts from this repo

From a machine with SSH access to the runner (Tailscale: `100.68.111.80`):

```bash
RUNNER_IP="100.68.111.80"
REPO_ROOT="$(git rev-parse --show-toplevel)"

ssh root@"${RUNNER_IP}" mkdir -p /opt/runner

scp "${REPO_ROOT}/scripts/runner/buildx-cleanup.sh"  root@"${RUNNER_IP}":/opt/runner/buildx-cleanup.sh
scp "${REPO_ROOT}/scripts/runner/buildx-monitor.sh"  root@"${RUNNER_IP}":/opt/runner/buildx-monitor.sh

ssh root@"${RUNNER_IP}" chmod +x /opt/runner/buildx-cleanup.sh /opt/runner/buildx-monitor.sh
```

### Step 2 — Verify scripts work

```bash
ssh root@"${RUNNER_IP}" /opt/runner/buildx-monitor.sh
ssh root@"${RUNNER_IP}" /opt/runner/buildx-cleanup.sh --dry-run
```

Expected output:

```
[2026-...] [buildx-monitor] docker daemon: OK (Server Version: ...)
[2026-...] [buildx-monitor] docker socket permissions: 660 (OK)
[2026-...] [buildx-monitor] buildx_buildkit containers: 3
[2026-...] [buildx-monitor] STATUS=healthy
```

```
[2026-...] [buildx-cleanup] Starting buildx cleanup (dry_run=1, max_keep=2, ...)
[2026-...] [buildx-cleanup] Found 5 buildx builder(s): ...
[2026-...] [buildx-cleanup] DRY RUN — would remove 3 builder(s), 0 orphan container(s), and 4 orphan state volume(s)
```

### Step 3 — Install crontab entries

```bash
ssh root@"${RUNNER_IP}" bash -s <<'EOF'
# Append to crontab (idempotent via marker check)
if ! crontab -l 2>/dev/null | grep -q buildx-cleanup; then
  ( crontab -l 2>/dev/null; echo "*/30 * * * * /opt/runner/buildx-cleanup.sh >> /var/log/buildx-cleanup.log 2>&1" ) | crontab -
fi
if ! crontab -l 2>/dev/null | grep -q buildx-monitor; then
  ( crontab -l 2>/dev/null; echo "*/5 * * * * /opt/runner/buildx-monitor.sh || echo \"CRITICAL: buildx unhealthy on \$(hostname)\" | logger -t buildx-monitor" ) | crontab -
fi
crontab -l
EOF
```

### Step 4 — Verify crontab installed

```bash
ssh root@"${RUNNER_IP}" crontab -l | grep buildx
```

---

## Manual Operations

### Force-clean all stale builders now

```bash
ssh root@"${RUNNER_IP}" /opt/runner/buildx-cleanup.sh
```

If `docker build`, `docker buildx build`, `docker buildx bake`, `docker pull`,
or `buildctl build` is still active, the cleanup script exits 0 without
removing builders, orphan containers, or orphan state volumes. Wait for the
active substrate work to finish, then rerun cleanup.

### Preview what would be removed

```bash
ssh root@"${RUNNER_IP}" /opt/runner/buildx-cleanup.sh --dry-run
```

### Keep more builders (for debugging parallel builds)

```bash
ssh root@"${RUNNER_IP}" /opt/runner/buildx-cleanup.sh --max-keep 5
```

### Check raw builder list

```bash
ssh root@"${RUNNER_IP}" docker buildx ls
ssh root@"${RUNNER_IP}" docker ps -a --filter name=buildx_buildkit
```

---

## GitHub Runner Workspace Hygiene

The fastlane runner uses persistent workspaces. Containerized Tutor and Docker
steps can leave generated files owned by `root` under the checkout. If the next
GitHub Actions job starts as an unprivileged runner user, `actions/checkout` or
pre-clean can fail before any build code runs.

PR #1979 added bounded pre-checkout cleanup in the local bootstrap and image
build workflows. The allowlist is intentionally narrow:

- `tutor_env`
- `var/bootstrap-readiness`
- `var/ci`
- `.buildx-cache`

When Docker is available, the cleanup runs a short-lived Docker-root helper with
`--network none` so it can remove root-owned generated state without granting
the runner passwordless sudo. If Docker is unavailable, the workflow falls back
to normal user cleanup and then sudo only when the runner already has it.

This cleanup is runner hygiene only. Do not add source files, docs, plugins,
workflow YAML, or any non-generated path to the cleanup allowlist. If another
path needs cleanup, first classify why generated state is being written there.

### Root-owned checkout cleanup failure

**Symptom**:

```text
EACCES: permission denied, rmdir .../tutor_env/data/...
```

**Classification**: runner / workspace hygiene, not source, render, or build
authority.

**Fix path**:

1. Confirm the failure happens before checkout or before Dockerfile render.
2. Confirm the path is generated state, not source.
3. If the path is one of the allowlisted generated paths, re-run after the
   #1979 cleanup is present on the branch.
4. If the path is not allowlisted, do not widen the cleanup list casually. Add a
   failure-taxonomy entry and decide whether the writer should move or the path
   should become explicit generated state.

### Runner diagnostic disk pressure

**Symptom**:

```text
No space left on device : '/srv/github-runner-.../_diag/Worker_...log'
```

This can happen before checkout, which means the repository never had a chance
to run its cleanup scripts. Treat it as host capacity pressure.

**Fix path**:

```bash
ssh root@"${RUNNER_IP}" df -h / /srv /var/lib/docker
ssh root@"${RUNNER_IP}" du -xh /srv/github-runner-lms-ci/_diag 2>/dev/null | sort -h | tail -20
ssh root@"${RUNNER_IP}" journalctl --disk-usage
ssh root@"${RUNNER_IP}" docker system df
```

After classifying the pressure source, clean the host-level offender. Do not
change repository build semantics to work around runner `_diag` exhaustion.

### Containerd snapshot/content-store pull failures

**Symptom**:

```text
failed to extract layer ... failed to Lchown
/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/...:
no such file or directory
```

or:

```text
failed commit on ref ... /var/lib/containerd/io.containerd.content.v1.content/ingest/.../data:
no such file or directory
```

**Classification**: runner Docker/containerd substrate, not Tutor source,
render, verifier, or local-guide authority.

**Important boundary**: `scripts/runner/buildx-cleanup.sh` owns stale Buildx
builder/container cleanup and unused orphan `buildx_buildkit_*_state` volume
cleanup from this repo. It must never remove mounted volumes or non-Buildx
volumes. The GitHub runner job-completed hook at
`/usr/local/lib/gha-fastlane/cleanup.sh` is owned by `bbi-infrastructure` under
`scripts/ops/fastlane/runner-cleanup/cleanup.sh`.

Developer laptops use a narrower guard in
`scripts/infra/buildx-builder-health.sh`, reached through
`scripts/infra/ensure-buildx-dependency-mirror.sh`. That local guard owns only
the repo-named `mereka-dependency-mirror` builder and must not be used as a
runner cleanup substitute.

If the job-completed hook logs a high-disk prune while other `Runner.Worker`,
`docker pull`, `docker build`, `docker buildx build`, `docker buildx bake`, or
`buildctl build` processes are active, treat that as host-hook debt. Do not
accommodate it by weakening LMS build verifiers. The hook must skip
Docker/containerd prune while runner workers are active and ask operators to
drain or clean the host during maintenance.

If CI annotates a shared prune-lock fallback for
`/tmp/fastlane-docker-prune.lock`, treat that the same way: the host-wide prune
lock belongs to the runner provisioning layer. A per-job fallback lock may keep
one job moving, but it does not prove cross-runner prune serialization. Track
and fix that in the runner provisioning source, not in LMS build or verifier
code.

**Triage**:

```bash
ssh root@"${RUNNER_IP}" df -h / /srv
ssh root@"${RUNNER_IP}" 'pgrep -af "Runner.Worker|docker pull|docker build|docker buildx (build|bake)|buildctl build" | sed -n "1,120p"'
ssh root@"${RUNNER_IP}" /opt/runner/buildx-cleanup.sh --dry-run
ssh root@"${RUNNER_IP}" 'docker volume ls --format "{{.Name}}" | grep "^buildx_buildkit_.*_state$" | wc -l'
ssh root@"${RUNNER_IP}" 'grep -n "forcing prune\\|skipping prune to avoid containerd race" /usr/local/lib/gha-fastlane/cleanup.sh || true'
ssh root@"${RUNNER_IP}" 'ls -ld /tmp /var/lock && \
  ls -l /tmp/fastlane-docker-prune.lock /var/lock/fastlane-docker-prune.lock 2>/dev/null || true'
```

**Fix path**:

1. Run the repo-owned Buildx cleanup first; it should defer if an active Docker
   or Buildx build is detected, and it should remove only unused orphan Buildx
   state volumes.
2. If disk pressure remains high, drain/idle the fastlane host before any broad
   Docker/containerd prune.
3. Patch and deploy the infra-owned fastlane cleanup hook from
   `bbi-infrastructure` if it can still prune during active runner work.
4. Rerun `Bootstrap Local Readiness` on the same commit after the host fix.

---

## Troubleshooting

### Docker socket permission drift

**Symptom**: `buildx-monitor.sh` exits 1 with `docker socket permissions are 640`.

This happens when the Docker daemon restarts (e.g. after a kernel update) and
creates the socket with a restrictive mask.

**Fix** (on the runner as root):

```bash
chmod 660 /var/run/docker.sock
# Or, if runners need world-readable access:
chmod 666 /var/run/docker.sock
```

**Durable fix**: create `/etc/docker/daemon.json` with:

```json
{
  "live-restore": true
}
```

And ensure the Docker systemd unit uses `SocketMode=0660` (or add the runner
user to the `docker` group).

---

### Builder name collisions

**Symptom**: `docker buildx create` fails with "builder name already in use".

**Cause**: A previous run created a builder but did not remove it.  The GitHub
Actions `setup-buildx-action` step generates a name derived from the runner and
job, which can collide across reruns.

**Fix**: Run cleanup immediately:

```bash
ssh root@"${RUNNER_IP}" /opt/runner/buildx-cleanup.sh --max-keep 0
```

Or from the workflow, add a pre-cleanup step:

```yaml
- name: Prune stale buildx builders
  run: /opt/runner/buildx-cleanup.sh || true
```

---

### Runaway BuildKit memory

**Symptom**: Runner OOM-kills CI processes; `docker stats` shows a
`buildx_buildkit_*` container consuming 2+ GB.

**Cause**: Large builds (e.g. MFE webpack) can balloon BuildKit's in-memory
layer cache between runs.

**Fix**: Remove the offending container:

```bash
ssh root@"${RUNNER_IP}" docker rm -f buildx_buildkit_<name>
```

**Prevention**: Set a GC policy in the BuildKit daemon config.  In the
`setup-buildx-action` step in the workflow, add:

```yaml
- uses: docker/setup-buildx-action@v3
  with:
    driver: docker-container
    buildkitd-config-inline: |
      [worker.oci]
        gc = true
        gckeepstorage = 20000  # MiB
```

---

### Cleanup exits 2 (partial failure)

**Symptom**: `buildx-cleanup.sh` reports `partial failure: N builder(s) could
not be removed`.

**Cause**: The BuildKit container may be in a crashed/restarting state that
prevents normal removal.

**Fix** (force-remove the specific container):

```bash
ssh root@"${RUNNER_IP}" docker rm -f buildx_buildkit_<name>
# Then re-run cleanup to verify.
ssh root@"${RUNNER_IP}" /opt/runner/buildx-cleanup.sh
```

---

## Update Procedure

When `scripts/runner/buildx-cleanup.sh` or `buildx-monitor.sh` change in this
repo, redeploy to the runner:

```bash
RUNNER_IP="100.68.111.80"
REPO_ROOT="$(git rev-parse --show-toplevel)"

scp "${REPO_ROOT}/scripts/runner/buildx-cleanup.sh"  root@"${RUNNER_IP}":/opt/runner/buildx-cleanup.sh
scp "${REPO_ROOT}/scripts/runner/buildx-monitor.sh"  root@"${RUNNER_IP}":/opt/runner/buildx-monitor.sh
ssh root@"${RUNNER_IP}" chmod +x /opt/runner/buildx-cleanup.sh /opt/runner/buildx-monitor.sh

# Smoke-test after deploy
ssh root@"${RUNNER_IP}" /opt/runner/buildx-monitor.sh
```

Cron entries do not need to change — they reference the fixed `/opt/runner/`
path.

---

## Related Docs

- `docs/ops/ci-cd/CI_CD_RUNNERS.md` — ARC and fastlane runner architecture
- `docs/ops/ci-cd/CACHE_AUTHORITY.md` — Shared GHCR registry cache authority
- `docs/rfcs/RFC-BUILD-AUTHORITY-001.md` — Build authority sprint RFC
- `scripts/runner/buildx-cleanup.sh` — Cleanup script (source of truth)
- `scripts/runner/buildx-monitor.sh` — Monitor script (source of truth)
