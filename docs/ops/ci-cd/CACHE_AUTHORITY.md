---
id: CACHE-AUTHORITY-001
status: draft
created: 2026-04-16
epic: mereka-lms-jj97
spec: specs/build-authority-deterministic-builds_spec.md
rfc: docs/rfcs/RFC-BUILD-AUTHORITY-001.md
---

# Cache Authority — Operator Runbook

## TL;DR

Three cache levels exist for Mereka LMS image builds. L2 — shared GHCR registry refs
`ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64` and
`ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64` — is the authoritative
shared cache. Only trusted main-branch push builds write to L2; all other contexts
(PRs, forks, developer laptops, ARC runners) read from it. L1 (runner-local buildx
daemon cache) is an ephemeral best-effort accelerator and is never authoritative.
L3 (the `OPENEDX_CACHE_REF` / `MFE_CACHE_REF` final-image fallback, currently pointing
at the `mereka-brand` tag) is a transitional fallback during the migration period and
will be retired in Phase 5 after 30 consecutive days of stable L2 imports. When cache
breaks: (1) run `crane manifest <ref>` to check the manifest exists; (2) grep the latest
trusted-main build log for `importing cache manifest` and `exporting cache manifest`;
(3) if neither has run on main within 24 hours, trigger a refresh with
`gh workflow run build-tutor-images.yml --ref main`.

---

## Cache Reference Inventory

| Level | Name | Ref | Write | Read | Notes |
|-------|------|-----|-------|------|-------|
| **L1** | Runner-local | `type=local,src=.buildx-cache/...` | Per-runner job | Same runner only | Ephemeral; wiped on ARC pod recycle or fastlane daemon reset. Best-effort only. |
| **L2** | Shared GHCR — OpenEdX | `ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64` | Trusted main push only | All contexts | **Authoritative.** Written with `mode=max`. Primary import for all builds. |
| **L2** | Shared GHCR — MFE | `ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64` | Trusted main push only | All contexts | **Authoritative.** Written with `mode=max`. Primary import for MFE builds. |
| **L3** | Final-image fallback — OpenEdX | `${OPENEDX_CACHE_REF}` (currently `docker.io/overhangio/openedx:21.0.0-cache`) | CI only | All contexts | **Transitional.** Secondary `cache-from` source. Mark for retirement at Phase 5. |
| **L3** | Final-image fallback — MFE | `${MFE_CACHE_REF}` (currently `docker.io/overhangio/openedx-mfe:21.0.0-cache`) | CI only | All contexts | **Transitional.** Secondary `cache-from` source. Mark for retirement at Phase 5. |

### Optional future refs (not in scope for PR 1)

```
ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:release-amd64
ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:release-amd64
ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:pr-<number>-amd64
ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:pr-<number>-amd64
```

These are defined in the RFC but are out of scope until Phase 1 (L2 main) proves stable
over 30 days. Do not implement or reference them in CI until the RFC is updated.

---

## Write Policy

The golden rule: **only trusted writes, everything else reads.**

A build context is "trusted" when ALL three conditions hold simultaneously:

```
github.ref == 'refs/heads/main'
  && github.event_name == 'push'
  && the job has packages:write permission and valid GITHUB_TOKEN
```

### By context

| Context | `cache-from` | `cache-to` | Notes |
|---------|-------------|-----------|-------|
| Trusted main push | L2 + L3 (both) | L2 `mode=max` | Writes the shared authority. |
| PR (same repo) | L2 + L3 (both) | None | Reads shared cache; cannot pollute it. |
| Fork PR | L2 public read only | None | GitHub fork-secret policy enforces: `GITHUB_TOKEN` for a fork has no `packages:write` on the upstream org. |
| `workflow_dispatch` on main | L2 + L3 (both) | None | `event_name` is `workflow_dispatch`, not `push`. Reads only. If you need to force a cache refresh, use an empty commit to main instead. |
| `workflow_dispatch` on branch | L2 + L3 (both) | None | Branch is not `refs/heads/main`. Reads only. |
| ARC runner (any event) | L2 + L3 (both) | Depends on triggering event | ARC runners have no special trust. The guard is in the workflow, not in the runner identity. |
| Developer laptop | L2 (read via `docker login`) | None | Local builds should never set `cache-to` against a shared ref. |
| Branch caches (future) | L2 main + branch-scoped | Branch ref only | PR-scoped `pr-<n>-amd64` refs are isolated; TTL-cleaned after 30 days. Not implemented in PR 1. |

### Intended bake config shape (target state — not yet in `docker-bake.hcl`)

This is what `docker-bake.hcl` will look like after PR 2 lands. Do not edit the file
now — this is the documented target for operator reference only.

```hcl
target "openedx-proof" {
  cache-from = [
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64",
    "type=registry,ref=${OPENEDX_CACHE_REF}",  # L3 fallback, transitional
  ]
  cache-to = [
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64,mode=max",
  ]
}

target "mfe-proof" {
  cache-from = [
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64",
    "type=registry,ref=${MFE_CACHE_REF}",  # L3 fallback, transitional
  ]
  cache-to = [
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64,mode=max",
  ]
}
```

### Current state (before PR 2)

Today `docker-bake.hcl` uses `type=gha` as the primary cache authority for the proof
targets, with `OPENEDX_CACHE_REF` / `MFE_CACHE_REF` as a secondary `cache-from`. The
`type=gha` backend is per-runner and fragile. After PR 2 lands, `type=gha` will be
removed from the heavy build targets (`openedx-proof`, `mfe-proof`) and replaced by the
L2 GHCR registry refs above.

### Workflow-level write guard (target state)

The workflow must gate `cache-to` using:

```yaml
env:
  # Only write to shared cache on trusted main push builds.
  CACHE_TO_ARG: >-
    ${{
      github.ref == 'refs/heads/main' &&
      github.event_name == 'push' &&
      format(
        '--cache-to=type=registry,ref={0}/cache/openedx:main-amd64,mode=max',
        env.REGISTRY
      ) || ''
    }}
```

An equivalent guard exists for the MFE target. The verifier script
`scripts/qa/verify-build-workflow-contract.sh` asserts this guard is present in the
workflow YAML and fails CI if the guard is removed or loosened.

---

## Read Policy

All contexts read L2. Authentication is via `docker login ghcr.io`.

| Consumer | Auth mechanism | Who sets it up |
|----------|---------------|----------------|
| CI jobs (all) | `secrets.GITHUB_TOKEN` — always available in any GitHub-hosted or ARC runner | Automatic; no configuration needed |
| Fastlane VPS runner | `secrets.GITHUB_TOKEN` passed to `docker login` step in workflow | Automatic via workflow |
| Developer laptop | Personal access token or GitHub CLI token with `read:packages` scope | Self-service; see `docs/guides/CI_TOKENS_FOR_DEVELOPERS.md` |

### Developer laptop login

```bash
# Option A: GitHub CLI (recommended)
gh auth token | docker login ghcr.io -u <your-github-username> --password-stdin

# Option B: Personal access token with read:packages scope
echo "<your-PAT>" | docker login ghcr.io -u <your-github-username> --password-stdin
```

See `docs/guides/CI_TOKENS_FOR_DEVELOPERS.md` for full token setup guidance.

---

## Verification

### Check that the L2 cache manifest exists

Use `crane` (install: `go install github.com/google/go-containerregistry/cmd/crane@latest`):

```bash
crane manifest ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64 \
  | jq '{mediaType, layers: (.layers | length), created: .annotations["org.opencontainers.image.created"]}'
```

Or with `skopeo`:

```bash
skopeo inspect --raw \
  docker://ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64 \
  | jq '{mediaType, layers: (.layers | length)}'
```

If the command returns a manifest with a non-zero layer count, L2 is populated. If it
returns a 404 or an empty manifest, the trusted-main write has never succeeded —
trigger a refresh (see Operator Commands).

Repeat with `cache/mfe:main-amd64` for the MFE ref.

### Check a build log for cache activity

From the GitHub Actions workflow log for any `build-openedx` or `build-mfe` job, grep
for these patterns:

```bash
# Cache was imported (warm build):
grep 'importing cache manifest from' var/ci/build-openedx.log

# Cache was exported (trusted main, after PR 2):
grep 'exporting cache manifest' var/ci/build-openedx.log

# Layer reuse summary (count CACHED vs total):
grep -cE '^\#[0-9]+ \[' var/ci/build-openedx.log   # total layers
grep -c 'CACHED' var/ci/build-openedx.log            # cached layers
```

The "Verify OpenEdX build cache health" step in the workflow already surfaces these in
the job summary. A layer-reuse ratio below 20% on a run that showed a manifest import
usually indicates the base image (Tutor upstream) changed and the cache is self-healing
— this is expected, not a bug.

### Prometheus query (after Phase 2 — CI_METRICS.md)

Once the telemetry pipeline (jj97.2 / jj97.11) is live, the authoritative cache signal
lives in Prometheus:

```promql
# Cache hit ratio by image family over the last 24 hours
sum(ci_cache_source_found{source="registry"}) by (image_family)
  /
sum(ci_cache_source_found) by (image_family)
```

See `docs/ops/ci-cd/CI_METRICS.md` for the full metric and label schema. That document
is also produced in bead `jj97.15` and should be consulted as the authoritative name
source before writing any new queries.

---

## Failure Modes and Recovery

Each row below maps to a failure bucket from `BUILD_FAILURE_TAXONOMY.md`:
B2 = Workflow Contract Defect, B3 = Runner/Daemon Defect, B4 = External Platform Defect.

| Failure | Bucket | Detection | First action | Escalation |
|---------|--------|-----------|-------------|------------|
| **Cache import 404** — `crane manifest` returns 404; build log shows no `importing cache manifest` line | B2 or B4 | `crane manifest ghcr.io/.../cache/openedx:main-amd64` fails | Verify the trusted-main job has run at least once (check `gh run list --workflow=build-tutor-images.yml --branch=main --limit=5`). If yes, check the job log for `exporting cache manifest` — if absent, the write guard may be blocking export on all builds. | Confirm `GITHUB_TOKEN` has `packages:write` in the trusted-main job's `permissions:` block. If the write guard is wrong (blocking trusted main), file a Bucket B2 issue and fix `verify-build-workflow-contract.sh`. |
| **Cache export 401** — build log shows `unauthorized` or `denied` during `exporting cache manifest` | B2 | Workflow log grep: `unauthorized` near `exporting` | Verify the `build-openedx` job has `permissions: packages: write` in the workflow YAML. Verify `docker login ghcr.io` step ran before the build step. | If permissions are correct but 401 persists, check if GHCR package visibility is set to `private` and the token lacks access. Escalate to bbi-infrastructure token owner (see `docs/ops/ci-cd/AUTOMATION_AUTHORSHIP_AUDIT.md`). |
| **Cache import succeeds but layer reuse <20%** — manifest imported, `CACHED` count is very low | Expected self-heal | Build log: `importing cache manifest from` present but `CACHED` count low | Check if a Tutor or base image upstream changed recently. Docker content-addresses layers; if the base changed, all downstream layers are invalidated. This is correct behavior — the cache self-heals on the next trusted-main run. No manual action needed. | If this persists for 3+ consecutive main builds without a known upstream change, investigate whether the rendered Dockerfile changed (patch drift). File a Bucket B1 or B2 issue. |
| **GHCR rate limit** — build log or step shows `429 Too Many Requests` from `ghcr.io` | B4 | Workflow log: `429` or `rate limit` near cache import/export | Exponential backoff is built into buildkit — the build should self-recover within the job timeout. The L3 fallback (`OPENEDX_CACHE_REF`) remains available as a secondary import source. | If rate limiting persists across 3 consecutive builds, check GHCR status (`https://www.githubstatus.com/`). File a B4 issue. Do not remove the L2 ref; let L3 carry load temporarily. |
| **Cache manifest stale (>24h without a write)** — `crane manifest` succeeds but the manifest creation timestamp is old | B2 or B3 | `crane manifest ... \| jq '.annotations["org.opencontainers.image.created"]'` shows a timestamp older than 24h, AND recent main builds exist | Check whether the `build-openedx` job is being triggered on main push. Verify `resolve-build-scope` is not short-circuiting (scope may have evaluated to "no change"). | If builds are being skipped and the cache is stale, trigger a manual refresh: `gh workflow run build-tutor-images.yml --ref main`. After PR 3 lands, the dashboard alert fires automatically at 24h stale. |
| **PR accidentally wrote shared cache (write policy violated)** | B2 | Check `cache-to` flag in the PR build log — if `cache-to=type=registry` appears, the guard failed | Immediately check `scripts/qa/verify-build-workflow-contract.sh` to confirm the guard is still in place. If the guard was bypassed or is absent, the shared cache ref may now carry PR-sourced layers. | Rotate the ref by triggering a trusted-main push build — this overwrites the ref with `mode=max` from a clean source. File a B2 issue. Reinstate the guard before the next PR build. |

### When in doubt: classify first

Before acting, use `BUILD_FAILURE_TAXONOMY.md` to bucket the failure. Cache failures
that look like source defects (B1) are almost always B2 (guard misconfiguration) or B3
(daemon/network). Never re-run blindly.

---

## Operator Commands

All commands below are copy-pasteable. Replace `<ref>` with the specific cache ref.

### Inspect a cache manifest

```bash
# With crane (preferred)
crane manifest ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64 \
  | jq '{mediaType, layers: (.layers | length), created: .annotations["org.opencontainers.image.created"]}'

crane manifest ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64 \
  | jq '{mediaType, layers: (.layers | length), created: .annotations["org.opencontainers.image.created"]}'

# With skopeo
skopeo inspect --raw \
  docker://ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64 \
  | jq '.layers | length'
```

### Force-trigger a trusted cache refresh

```bash
# Triggers the trusted-main build, which writes to L2 on completion.
# Use this when the manifest is stale (>24h) or was never written.
gh workflow run build-tutor-images.yml --ref main

# Watch the run:
gh run watch --repo biji-biji-initiative/mereka-lms
```

Note: `workflow_dispatch` sets `event_name == 'workflow_dispatch'`, not `push`. The
write guard (`github.event_name == 'push'`) blocks the cache-to write on dispatch runs.
To force a cache write, push an empty commit to main instead:

```bash
git commit --allow-empty -m "chore(ci): force cache refresh [no-op]"
git push origin main
```

### Local warm build from L2 cache (developer laptop)

After `docker login ghcr.io` (see Read Policy above):

```bash
docker buildx build \
  --cache-from=type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64 \
  --cache-from=type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64 \
  --load \
  -t mereka-openedx:local \
  tutor_env/env/build/openedx
```

See bead `jj97.20` for the full developer local-build setup guide (produced in Phase 4).

### List all cache packages

```bash
gh api "/orgs/biji-biji-initiative/packages?package_type=container" \
  | jq '.[] | select(.name | startswith("mereka-lms/cache"))'
```

### Check latest trusted-main builds

```bash
gh run list \
  --workflow=build-tutor-images.yml \
  --branch=main \
  --limit=10 \
  --json databaseId,status,conclusion,createdAt,headSha \
  | jq '.[] | {id: .databaseId, status, conclusion, created: .createdAt, sha: .headSha}'
```

### Verify the write guard is in the workflow

```bash
# Should print the cache-to conditional block — non-empty output means the guard exists
grep -A3 'CACHE_TO_ARG' .github/workflows/build-tutor-images.yml

# Run the contract verifier (after jj97.1 lands):
bash scripts/qa/verify-build-workflow-contract.sh
```

---

## Proof Contract

Every change that affects cache behavior must update ALL of the following files. Partial
updates are a contract violation and must be caught by the reviewer before merge.

| File | What to update |
|------|---------------|
| `docker-bake.hcl` | `cache-from` and `cache-to` for `openedx-proof` and `mfe-proof` targets |
| `scripts/qa/verify-build-workflow-contract.sh` | Assert the new cache refs are present; assert `cache-to` is gated on trusted main |
| Test fixtures (`tests/` or equivalent) | Fixture snapshots that test the bake target output and workflow guard logic |
| `docs/ops/ci-cd/CACHE_AUTHORITY.md` (this file) | Update the reference inventory table, write/read policy tables, and any operator commands that change |
| `docs/ops/ci-cd/CI_METRICS.md` | Update metric names and label schemas if the cache-source classification changes |

If you add a new cache level, retire L3, or add PR-scoped refs, the RFC
(`docs/rfcs/RFC-BUILD-AUTHORITY-001.md`) must also be updated before the implementing PR
is merged.

---

## Retirement Plan for L3

L3 (`OPENEDX_CACHE_REF` / `MFE_CACHE_REF`) is a bridge from the current `type=gha`
state to the target L2 GHCR registry state. It is not permanent.

**Retirement trigger**: 30 consecutive calendar days of successful L2 cache imports on
trusted-main builds, with a layer-reuse ratio consistently above 20% (verified from
Prometheus `ci_cache_source_found{source="registry"}` and `ci_layer_reuse_count`).

**Retirement steps** (Phase 5, coordinated by bead owner for jj97.1):

1. Remove `OPENEDX_CACHE_REF` and `MFE_CACHE_REF` variable declarations from
   `docker-bake.hcl`.
2. Remove the `type=registry,ref=${OPENEDX_CACHE_REF}` and
   `type=registry,ref=${MFE_CACHE_REF}` lines from the `cache-from` arrays in the proof
   targets.
3. Update `scripts/qa/verify-build-workflow-contract.sh` to assert that neither L3 ref
   appears in `cache-from`.
4. Update this document (set L3 row in inventory to "Retired — Phase 5") and update
   the RFC status.
5. Remove any test fixtures that reference the L3 refs.
6. Open a cleanup PR, get review, and merge on a non-Friday.

Do not retire L3 until the 30-day stability window is confirmed by the Prometheus data,
not by intuition.

---

## References

| Document | Purpose |
|----------|---------|
| `docs/rfcs/RFC-BUILD-AUTHORITY-001.md` | Authoritative design: cache model, write policy, bake config shape, risks |
| `docs/rfcs/BUILD-AUTHORITY-SPRINT-AGENT-BRIEF.md` | PR sequencing, lane boundaries, red lines |
| `docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md` | Failure bucket classification (B1–B4) |
| `docs/ops/ci-cd/CI_METRICS.md` | Authoritative metric names and label schema (forthcoming — bead jj97.15) |
| `docs/ops/ci-cd/BENCHMARK_CLASSES.md` | Benchmark class taxonomy: true-cold / registry-warm / local-hot (forthcoming — bead jj97.15) |
| `docs/guides/CI_TOKENS_FOR_DEVELOPERS.md` | Developer GHCR auth setup |
| `docs/ops/ci-cd/AUTOMATION_AUTHORSHIP_AUDIT.md` | Token identity model for CI jobs |
| `bbi-infrastructure/docs/adr/024-build-cache-authority.md` | ADR governing the L2 GHCR decision (filed as 024 because 005 was already taken by `005-auth-canonical-branch-and-ownership.md`) |
| `specs/build-authority-deterministic-builds_spec.md` | Machine-checkable requirements R1–R7 |
