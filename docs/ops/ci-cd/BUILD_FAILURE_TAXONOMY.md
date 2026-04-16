# Build Failure Taxonomy

> When a build fails, you should be able to say in one sentence which bucket it falls in.
> This taxonomy exists so operators stop misclassifying runner infra failures as code defects.

## The Four Buckets

### 1. Source Defect

**Definition**: The code or configuration committed to the repository is wrong.

**Signals**:
- Build fails at a deterministic step (same step fails on re-run)
- Error references a file path, import, or syntax from the repo
- The same commit fails on both fastlane and ARC runners
- Error is in a `RUN` step that executes repo code (pip install from requirements, npm build, collectstatic)

**Examples**:
- `ModuleNotFoundError: No module named 'mereka_lms'` in plugin import
- `SyntaxError` in `apply-patches.sh` or plugin Python
- Jinja2 template rendering failure in Tutor config
- `npm run build` fails on MFE source code error
- Release object schema validation failure (`verify-release-object.sh` exits non-zero)

**Resolution path**: Fix the code, push a new commit.

---

### 2. Workflow Contract Defect

**Definition**: The GitHub Actions workflow YAML, composite actions, or CI scripts have a logic error — the build infrastructure is correct but the workflow wires things wrong.

**Signals**:
- Build fails at a workflow orchestration step (not inside Docker build)
- Error is in `actions/download-artifact`, `actions/create-github-app-token`, conditional logic
- The failure is in job dependency gates, `if:` conditions, or output passing
- Artifact not found, token missing, permission denied on GitHub API
- PR authorship wrong (github-actions[bot] instead of App identity)

**Examples**:
- `Artifact not found: release-bundle` (job ordering or conditional skip bug)
- `HttpError: Resource not accessible by integration` (token scope too narrow)
- Dispatch to bbi-infrastructure returns HTTP 422 (envelope schema mismatch)
- SLSA provenance step fails on missing `id-token: write` permission
- PR checks don't attach because event type is `push` not `pull_request`

**Resolution path**: Fix the workflow YAML or CI script, push a new commit.

---

### 3. Runner / Daemon / Buildx Infrastructure Defect

**Definition**: The build host (VPS fastlane runner or ARC runner pod) has a broken environment — Docker daemon, buildx state, disk, network, or permissions.

**Signals**:
- Build fails at "Set up Docker Buildx" or early in `docker buildx build`
- Error references Docker socket, daemon, or buildx builder
- `apt update` or `pip install` fails with network timeouts (DNS, connection refused)
- `permission denied` on `/var/run/docker.sock`
- Disk full errors (`no space left on device`)
- The same commit succeeded before (proves it's not source)
- Re-running on a different runner (or after cleanup) succeeds

**Examples**:
- `permission denied while trying to connect to the Docker daemon socket` (socket permissions drift)
- `W: Failed to fetch http://archive.ubuntu.com/ubuntu/dists/jammy/InRelease Connection failed` (network outage on runner)
- `ERROR: failed to solve: process "/bin/sh -c apt update" did not complete successfully: exit code: 100` (network-caused)
- `no space left on device` during layer extraction
- 29 stale buildx builder containers exhausting Docker resources
- `error: failed to receive status: connection reset by peer` (broken pipe from daemon overload)

**Resolution path**: SSH to runner, diagnose daemon/disk/network, clean up. Re-run the build. File an issue for long-term fix (automated cleanup, monitoring).

**Diagnostic commands**:
```bash
# SSH to fastlane runner (as root via Tailscale)
ssh -o StrictHostKeyChecking=no root@100.68.111.80

# Check Docker health
docker info 2>&1 | grep -E "Server Version|Running|Images|Storage"
docker buildx ls
df -h /var/lib/docker

# Check network
curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" http://archive.ubuntu.com/ubuntu/dists/jammy/InRelease

# Check runner user permissions
su - gha-lms-build-2 -c "docker buildx ls" 2>&1

# Clean stale buildx builders
docker ps -a --filter "name=buildx_buildkit" -q | xargs -r docker rm -f
docker buildx prune -f

# Fix socket permissions (if needed)
chmod 666 /var/run/docker.sock
```

---

### 4. External Platform Defect (GitHub / Registry / CDN)

**Definition**: GitHub Actions platform, GHCR registry, or external dependency services are degraded — nothing we control is broken.

**Signals**:
- GitHub Actions status page shows degradation
- `GHCR push` fails with 5xx errors
- `actions/download-artifact` fails with "unexpected status 503"
- Runner provisioning fails (ARC controller can't scale)
- Rate limiting on GitHub API (`HTTP 403: API rate limit exceeded`)
- Cosign/SLSA attestation fails on Sigstore/Rekor outage

**Examples**:
- `error pushing to ghcr.io: received unexpected HTTP status: 503 Service Unavailable`
- `Error: HttpError: secondary rate limit` during cross-repo dispatch
- `Failed to create artifact: unexpected status 503` on upload
- ARC runner pod stuck in `Pending` (cluster resource pressure, not our code)

**Resolution path**: Wait for platform recovery. Check https://www.githubstatus.com/. Re-run when green. No code change needed.

---

## Quick Classification Decision Tree

```
Build failed
  │
  ├── Did the SAME commit succeed on a previous run?
  │     YES → Bucket 3 (runner infra) or 4 (platform)
  │     │
  │     ├── Does the error reference Docker/buildx/socket/disk/network?
  │     │     YES → Bucket 3: Runner Infra
  │     │     NO  → Bucket 4: External Platform
  │     │
  │
  ├── Does the error come from INSIDE a Docker RUN step?
  │     YES → Is it a network error (apt, pip, npm registry)?
  │     │       YES → Bucket 3: Runner Infra (network)
  │     │       NO  → Bucket 1: Source Defect
  │     │
  │
  ├── Does the error come from workflow orchestration (actions, tokens, artifacts)?
  │     YES → Bucket 2: Workflow Contract
  │     │
  │
  └── Does the error reference GitHub API, GHCR, or external service?
        YES → Bucket 4: External Platform
        NO  → Re-examine — likely Bucket 1 or 2
```

## Recent Failure History (for calibration)

| Date | Run | Bucket | Root Cause |
|------|-----|--------|------------|
| 2026-04-16 | 24491141960 | **3 (Runner Infra)** | Docker socket permissions drift + 29 stale buildx containers + transient network outage to archive.ubuntu.com on vmi3220759 |
| 2026-04-14 | 24419232252 | Check | Unknown — investigate |
| 2026-04-14 | 24400318736 | Check | Unknown — investigate |
| 2026-04-10 | Various | **2 (Workflow)** | PR authorship (github-actions[bot]) caused checks not to attach; buildkitd invalid flag |

## Standing Rules

1. **Never re-run blindly**. Classify first, then act.
2. **Same commit, different result** = infrastructure or platform, not source.
3. **Network errors inside Docker build** = runner infra (the runner's network is broken, not the code).
4. **Token/permission errors** = workflow contract (token scope, app permissions, or event type mismatch).
5. **File an issue** for every Bucket 3 failure — transient infra problems recur if not fixed structurally.
