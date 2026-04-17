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
- Repeated `docker/setup-buildx-action` calls create a new named builder per
  run when the previous one was not torn down.

Left unattended, the runner can accumulate 20–30 containers, consuming memory
(each idle BuildKit worker uses ~100–200 MB) and occasionally causing socket
permission drift as the Docker daemon restarts.

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
| `0` | All requested removals succeeded (or dry-run) |
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
[2026-...] [buildx-cleanup] DRY RUN — would remove 3 builder(s) and 0 orphan container(s)
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
    config-inline: |
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
