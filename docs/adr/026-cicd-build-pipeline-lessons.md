---
title: "CI/CD Build Pipeline Lessons Learned (ARC Migration, March 2026)"
type: "adr"
status: "accepted"
owner: "engineering"
last_updated: "2026-03-05"
links:
  related_adrs:
    - "docs/adr/003-image-build-pipeline.md"
    - "docs/adr/023-enterprise-images-ghcr-migration.md"
  related_docs:
    - "docs/ops/ci-cd/CI_CD_RUNNERS.md"
    - "docs/ops/ci-cd/CI_OPTIMIZATION_TRACKER.md"
---

# ADR-026: CI/CD Build Pipeline Lessons Learned (ARC Migration, March 2026)

**Status**: Accepted
**Date**: 2026-03-05
**Deciders**: Gurpreet Singh (Founder / Platform Owner)

<!-- Last verified: 2026-03-05 -->

## Context

During March 2026, the mereka-lms CI/CD pipeline underwent a major overhaul: migrating image
builds from GitHub-hosted runners to Actions Runner Controller (ARC) self-hosted runners on
`rke2-nonprod`, and migrating image storage from GCP Artifact Registry (GAR) to GitHub Container
Registry (GHCR). Eight distinct failure modes were discovered, diagnosed, and fixed during this
migration. This ADR records each failure so future operators and agents do not repeat the same
mistakes.

The eight lessons are grouped into four categories:
- **Registry** (Lessons 1): image registry must match deployment target
- **Docker / BuildKit** (Lessons 2, 8): buildx driver and MTU constraints
- **GitHub / ARC operational** (Lessons 3, 4, 5): runner lifecycle, API reliability, log access
- **Version management** (Lessons 6, 7): Python runtime and dependency version drift

---

## Lessons

### Lesson 1: Registry Must Match Deployment Target

**Context**: Six enterprise service images were stored in GCP Artifact Registry under
`asia-southeast1-docker.pkg.dev/mereka-lms/openedx/`. The `rke2-nonprod` cluster has no GCP
Workload Identity configured and no `imagePullSecret` for GAR.

**Problem**: Every enterprise pod scheduled on `rke2-nonprod` failed with `ImagePullBackOff`.
The error was not immediately obvious because GAR returns 403, not a DNS failure — the pod
event log showed `failed to pull image ... 403 Forbidden` rather than a registry connectivity
problem.

**Fix**: Migrated all six images to `ghcr.io/biji-biji-initiative/` (ADR-023). The
`ghcr-registry` secret already exists in the `mereka-lms` namespace on both GKE and
`rke2-nonprod`, so no new secret provisioning was required.

**Prevention rule**: Before building or referencing any image in CI, verify that the registry
is reachable from every target cluster. GAR requires GCP Workload Identity or an explicit
service-account `imagePullSecret`. GHCR requires only the `ghcr-registry` secret, which is
already provisioned in all Mereka namespaces. Default to GHCR for all new images.

---

### Lesson 2: `--load` with `docker-container` BuildKit Driver Fails in DinD

**Context**: The initial `build-tutor-images.yml` used `docker/setup-buildx-action` which
creates a `docker-container` driver (a separate BuildKit container). The workflow then called
`docker buildx build --load` to load the built image into the local Docker daemon for
subsequent steps (tagging, scanning, pushing).

**Problem**: `--load` with the `docker-container` driver copies the image back from the
BuildKit container to the local Docker daemon over a Unix socket. Inside DinD, the
`docker-container` BuildKit container runs as a sibling container. The socket path diverges
from what the runner expects, and the image transfer silently fails or produces a corrupt image.
The workflow appeared to succeed but subsequent `docker push` steps failed with "manifest not
found."

**Fix**: Removed `--load: true` from the `docker/build-push-action` invocation. Images are
pushed directly to GHCR with `--push` inside the build step. The local Docker daemon is not
used as an intermediate store. The Tutor build wrapper (`tutor images build`) uses the default
`docker` driver (not `docker-container`), which does not have this issue.

**Prevention rule**: Do not use `--load` with the `docker-container` BuildKit driver in DinD
environments. Use `--push` to push directly to the registry, or use the `docker` driver
(default when `docker/setup-buildx-action` is not invoked). When a local image reference is
needed (e.g., for `trivy image` scanning), pull the image back from the registry after push
rather than relying on the daemon cache from a `--load` step.

---

### Lesson 3: ARC `minRunners: 0` Causes Queue Delays on Cold Start

**Context**: Both ARC runner scale sets (`mereka-k8s-runners` and `mereka-k8s-heavy-builders`)
are configured with `minRunners: 0`. No runner pod is pre-provisioned; pods spawn only when a
queued job is detected.

**Problem**: ARC's controller polls GitHub for queued jobs on a 30-second interval. After a
workflow is triggered, the job can sit in GitHub's queue for up to 30 seconds before the ARC
controller detects it and begins pod scheduling. Pod startup (image pull + init containers) adds
another 30–90 seconds for standard runners and 60–120 seconds for heavy runners (DinD init,
PVC mount). Total cold-start overhead: **1–3 minutes per job**.

For the `build-tutor-images.yml` workflow (Tutor image build takes 30–45 minutes), this
overhead is negligible. For lightweight `ci.yml` jobs (total runtime ~5 minutes), the cold
start represents 20–60% of total job time.

**Fix applied (heavy runners)**: No change. The heavy runner set keeps `minRunners: 0` because
the `arc-docker-cache` and `arc-dep-cache` PVCs use `ReadWriteOnce` access mode — only one pod
can mount them at a time. Keeping a warm runner idle would block other builds from using the
cache.

**Mitigation (standard runners)**: The standard runner set (`mereka-k8s-runners`) can be set to
`minRunners: 1` if the cold-start penalty becomes unacceptable. This keeps one pod permanently
alive at the cost of 2 CPU / 4 GB RAM held idle. Decision deferred until observed queue delay
exceeds 3 minutes on a consistent basis.

**Prevention rule**: Design workflows to tolerate 2–3 minute cold starts on ARC self-hosted
runners. Do not set job `timeout-minutes` values that assume instant runner availability.
Log the job queue time (GitHub provides `queued_at` and `started_at` timestamps via the
Actions API) if investigating cold-start regressions.

---

### Lesson 4: GitHub API 502s Break `gh run watch`

**Context**: During CI debugging, operators used `gh run watch <run-id>` to monitor live
workflow progress from the command line. GitHub's Actions API intermittently returns 502
during peak load.

**Problem**: `gh run watch` exits with a non-zero code when it receives a 502, even if the
underlying workflow is still running. This causes the monitoring session to drop, and the
operator has no indication whether the workflow is still progressing or has failed.

**Fix**: Use `gh run view <run-id>` (poll-based, single snapshot) instead of `gh run watch`
for long-running jobs. Alternatively, watch the GitHub Actions web UI, which handles 502s
transparently via browser retry.

**Prevention rule**: Do not rely on `gh run watch` in automated scripts or CI-within-CI
patterns. Use `gh run view --exit-status` in a polling loop with exponential backoff if
programmatic status polling is required:

```bash
until gh run view "$RUN_ID" --exit-status 2>/dev/null; do
  sleep 30
done
```

---

### Lesson 5: Build Logs Are Not Readable from CLI During Active Runs

**Context**: `gh run view --log <run-id>` streams workflow logs, but only for completed jobs.
During an active build run, the API returns an empty response or 404 for in-progress job logs.

**Problem**: When debugging a hanging Tutor build (~40 minutes), there was no CLI mechanism
to tail live logs from the ARC runner. The GitHub web UI streams logs in real time, but the
API does not expose this stream.

**Fix**: Implemented artifact-based log collection. The `build-tutor-images.yml` workflow
uploads a `tutor-build-progress.log` artifact every 5 minutes during the build using a
background loop:

```bash
while sleep 300; do
  gh api "repos/$REPO/actions/runs/$GITHUB_RUN_ID/artifacts" | \
    jq -r '.artifacts[] | .name' &
done &
# actual build command
tutor images build openedx
```

The artifact is downloadable mid-run via `gh run download`. After build completion, the full
log is available via `gh run view --log`.

**Prevention rule**: For builds exceeding 10 minutes, always implement progress artifacts or
heartbeat log uploads. Do not rely on streaming CLI log access during active ARC runs. Add a
`gh run list --workflow=<name> --limit=1` command to confirm the run is active before
troubleshooting log availability.

---

### Lesson 6: Stale Version References Spread Across 27+ Files

**Context**: The Tutor version (`21.0.0`) and its plugin versions (`tutor-mfe==21.0.0`,
`tutor-indigo==21.1.0`) are the authoritative Ulmo release pinned in `requirements-tutor.txt`.
These versions are also referenced in GitHub Actions `run:` blocks, Dockerfiles, Helm values,
and documentation files.

**Problem**: When the Tutor version was bumped, `requirements-tutor.txt` was updated but 27+
other files still referenced the old version string. CI passed because the old version was
still installable, but builds produced mismatched images (different Tutor version installed in
CI vs. what was specified). The mismatch was only discovered during a Tutor config render
idempotency check that compared rendered output across environments.

**Fix**: `requirements-tutor.txt` is declared the single source of truth for all Tutor version
references. A verification script (`scripts/qa/verify-cicd-lessons-compliance.sh`) checks that
no other file references a different Tutor version string.

**Prevention rule**: When updating any pinned dependency version:
1. Update `requirements-tutor.txt` first.
2. Run `grep -r "tutor==" .` and update every match.
3. Commit all version bumps in a single atomic commit.
4. CI enforces consistency via `verify-cicd-lessons-compliance.sh`.

---

### Lesson 7: Python Path Must Match Base Image Runtime

**Context**: Tutor 21.x (Ulmo) uses Python 3.12 as its base image runtime. Several CI scripts
and Dockerfile `RUN` commands hard-coded `python3.11` (the previous Tutor release used 3.11).

**Problem**: Commands like `RUN python3.11 manage.py collectstatic` fail inside the Ulmo image
with `python3.11: command not found`. The failure appeared only inside Docker builds (not on
the CI runner host, which has both 3.11 and 3.12 installed), making it difficult to reproduce
locally without building the full image.

**Fix**: Replaced all `python3.11` references with `python3` (the unversioned symlink, which
resolves to the base image's Python runtime). Where a specific version is genuinely required
(e.g., composite action `setup-python-env` defaults to `3.12` to match Ulmo), the version is
sourced from a single parameter, not scattered hard-coded strings.

**Prevention rule**: Never hard-code a specific Python minor version (`python3.11`,
`python3.12`) in CI scripts, Dockerfiles, or workflow `run:` blocks. Use the unversioned
`python3` alias inside containers. Use the `python-version` input parameter in the
`setup-python-env` composite action for host-level Python version control. When Tutor is
upgraded, check the base image Python version and update the composite action default.

---

### Lesson 8: DinD MTU Mismatch on Non-Standard CNI Networks

**Context**: The `rke2-nonprod` cluster uses Calico with WireGuard encryption on the pod
network. WireGuard adds a header overhead that reduces the effective MTU from the physical
interface MTU (1500) to 1280. Docker's default bridge MTU is 1500.

**Problem**: When Docker containers inside DinD sent packets larger than 1280 bytes, the
WireGuard kernel module dropped them silently (no ICMP fragmentation-needed message). This
manifested as:
- `git clone` hanging at 80–95% then timing out
- TLS handshakes failing intermittently (the `ClientHello` packet was fragmented and dropped)
- `apt-get install` completing successfully but subsequent `npm install` hanging

The failure was intermittent because small payloads (most `git` refs, initial TLS hellos)
passed through, while bulk data transfers (tarballs, git object packs) failed. This made the
MTU root cause difficult to identify — network debugging (`ping`, `curl`) appeared healthy.

**Fix**: Added `daemon.json` ConfigMap (`deploy/k8s/base/arc/dind-daemon-config.yaml`) with
`"mtu": 1280`. The DinD sidecar passes `--mtu=1280` to `dockerd` via args. All Docker bridge
networks created by the daemon inherit this MTU. The `dind-daemon-config` ConfigMap is mounted
into the DinD init container.

**Prevention rule**: When deploying ARC heavy runners on any cluster with a non-standard CNI
MTU:
1. Determine the pod network MTU: `kubectl exec <pod> -- ip link show eth0 | grep mtu`
2. Set Docker daemon MTU to match: add `"mtu": <value>` to `daemon.json`.
3. Pass `--mtu=<value>` to `dockerd` in the DinD sidecar args.
4. Verify: `docker run --rm busybox ping -s 1400 -M do 8.8.8.8` (should fail) vs.
   `ping -s 1200 -M do 8.8.8.8` (should succeed) — confirms the MTU threshold is as expected.

Affected CNIs: Calico+WireGuard (MTU 1280), Cilium+WireGuard (MTU 1280 by default), any
overlay network with additional encapsulation overhead. Vanilla Flannel / Calico without
WireGuard typically uses MTU 1450 — also lower than Docker's default 1500 and still requires
explicit daemon config.

---

## Decision

The eight lessons documented above are adopted as binding operational rules for all CI/CD work
on this repository. Each lesson maps to one or more prevention rules enforced by the
`verify-cicd-lessons-compliance.sh` verification script running on every PR.

The rules below are the machine-enforceable subset derived from the lessons.

## Binding Decisions

These rules derive from the eight lessons above and apply to all future CI/CD work:

| # | Rule | Lesson |
|---|------|--------|
| **B1** | Registry must match deployment target. Default to GHCR for all new images. | 1 |
| **B2** | Do not use `--load` with the `docker-container` BuildKit driver in DinD. Use `--push`. | 2 |
| **B3** | Design workflows to tolerate 2–3 minute ARC cold starts. Never set timeouts below 5 minutes for ARC jobs. | 3 |
| **B4** | Do not use `gh run watch` in automated scripts. Use `gh run view --exit-status` in a retry loop. | 4 |
| **B5** | Implement progress artifacts for any build exceeding 10 minutes. | 5 |
| **B6** | `requirements-tutor.txt` is the single source of truth for Tutor versions. All other references must match. | 6 |
| **B7** | Use `python3` (unversioned) inside containers. Use the `setup-python-env` action parameter for host-level version control. | 7 |
| **B8** | Set Docker daemon MTU to match pod network MTU on every ARC heavy runner deployment. | 8 |

---

## Consequences

### Positive

- Eight recurrence vectors eliminated with both fixes and automated verification.
- `verify-cicd-lessons-compliance.sh` runs in CI on every PR, catching regressions before merge.
- DinD MTU config is declarative in `dind-daemon-config.yaml` — no manual intervention needed on runner restarts.
- GHCR consolidation (from ADR-023) removes the dual-registry dependency that caused Lesson 1.
- Artifact-based log collection (Lesson 5) improves debuggability for all future long-running builds.

### Negative

- The `minRunners: 0` cold-start penalty (Lesson 3) remains. Accepted trade-off: idle runner cost
  vs. 2–3 minute queue delay. Revisit if delays become operationally disruptive.
- Artifact-based log collection (Lesson 5) adds ~5 MB of artifact storage per build run.
- The DinD MTU config must be updated whenever the cluster CNI MTU changes (REMOVAL CONDITION is
  documented in `dind-daemon-config.yaml`).

---

## Verification

The compliance verification script runs on every PR:

```bash
scripts/qa/verify-cicd-lessons-compliance.sh
```

Checks:
- No GAR (`asia-southeast1-docker.pkg.dev`) references in workflow files
- No `python3.11` hard-coded paths in CI/workflow files (Ulmo uses 3.12)
- Tutor version in `requirements-tutor.txt` matches any version pins in workflow files
- DinD MTU config (`dind-daemon-config.yaml`) is present in the ARC base manifests

---

## References

- [ADR-003: Image Build Pipeline](003-image-build-pipeline.md)
- [ADR-023: Enterprise Images GHCR Migration](023-enterprise-images-ghcr-migration.md)
- [docs/ops/ci-cd/CI_CD_RUNNERS.md](../ops/ci-cd/CI_CD_RUNNERS.md)
- [docs/ops/ci-cd/CI_OPTIMIZATION_TRACKER.md](../ops/ci-cd/CI_OPTIMIZATION_TRACKER.md)
- [deploy/k8s/base/arc/dind-daemon-config.yaml](../../deploy/k8s/base/arc/dind-daemon-config.yaml)
- [deploy/k8s/base/arc/runner-scale-set-heavy.yaml](../../deploy/k8s/base/arc/runner-scale-set-heavy.yaml)
- [.github/workflows/build-tutor-images.yml](../../.github/workflows/build-tutor-images.yml)
- [requirements-tutor.txt](../../requirements-tutor.txt)
