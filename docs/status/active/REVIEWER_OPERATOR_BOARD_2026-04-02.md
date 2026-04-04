# Reviewer Operator Board — 2026-04-02

> Scope: LMS-D, LMS-F, LMS-I, LMS-A
>
> Closure labels are strict:
> - `repo-complete`: git/PR state supports the claim
> - `runtime_validated`: live cluster or public/runtime probes support the claim
> - `operationally_closed`: reconciled, durable, and no known live blocker remains

## Current Board

| Lane | Priority | Verified state | repo-complete | runtime_validated | operationally_closed | Notes |
|------|----------|----------------|---------------|-------------------|----------------------|-------|
| LMS-D | P1 | `mereka-lms-prod` is still `OutOfSync` / `Progressing` | Partial | Yes | No | The corrected proof is now on real PR `mereka-lms#1286` from `docs/prod-realization-proof`. Live state supports `runtime_validated`, but not `operationally_closed`. |
| LMS-F | P2 | `mereka-lms-dev` is still `OutOfSync` / `Degraded` | Partial | No | No | `mereka-lms#1282` is merged. The latest OpenEdX image build on `main` succeeded, but dev is still pinned to `f8838910750a9581875ccc4aba3b9e5f6e563792`, there is no visible infra promotion PR, and live `/courses/.../about` still returns HTTP 500. Auth guard is green. |
| LMS-I | P3 | import fixes partly landed on `main`, but follow-up PR is contaminated and not canonical import closure | Partial | Partial | No | `run_full_import.sh` fixes are on `main`, but `mereka-lms#1287` is not import-only: it includes aspects proof and shared migration-file changes beyond the stated scope. |
| LMS-A | P4 | proof exists on branch/PR, not on main, and is stale as live-state proof | Partial | Partial | No | `mereka-lms#1283` is open. Core aspects pods look healthy, but the proof doc does not match current revision or staging `lms-worker` reality. |

## Verified Evidence

### LMS-D

- Live prod Argo at `2026-04-02T03:13:47Z`:
  - app: `mereka-lms-prod`
  - sync: `OutOfSync`
  - health: `Progressing`
  - revision: `1eca5200d1cf174fcff1438bb716ea05dad53987`
  - operationState.phase: `Failed`
  - reconciledAt: `2026-04-02T04:42:25Z`
- Live prod namespace is `mereka-lms`, not `mereka-lms-prod`.
- `enterprise-catalog-worker` live state:
  - deployment: `1/1 Ready`, `1 available`
  - pod: `enterprise-catalog-worker-55b8f8f588-xknsj` `Running` `READY=true`
- `enterprise-access-worker` live state:
  - deployment: `1/1 Ready`, `1 available`
  - pod: `enterprise-access-worker-854fc5c8c6-sc2qr` `Running` `READY=true`
- `bbi-infrastructure#2356` is merged at `2026-04-02T03:05:20Z`.
- Current prod deploy set:
  - `29/29` non-zero deployments are healthy
  - only `notes` and `payments-gateway` are parked at `0/0`
- Current prod non-synced set claimed by the new proof is materially consistent with live state:
  - live Argo resource list currently shows `ExternalSecret/mereka-lms/ghcr-registry` as `OutOfSync`
  - proof additionally classifies `Job/clickhouse-init` and `Job/superset-init` as non-synced/init artifacts
  - current `.status.conditions` is empty, while `.status.operationState.phase` remains `Failed`
- Current canonical proof path is now on a real branch/PR, though still not merged:
  - PR: `mereka-lms#1286`
  - branch: `docs/prod-realization-proof`
  - file: `docs/status/active/PROD_REALIZATION_PROOF_2026-04-02.md`
- Live public host check remains consistent with the corrected proof:
  - `credentials.academy.biji-biji.com` returns `302 -> /health/`
- Prod remains non-closed because Argo is still `OutOfSync / Progressing` and the failed operation state has not been cleared.

### LMS-F

- PR truth:
  - `mereka-lms#1279` merged at `2026-04-01T21:42:53Z`
  - `bbi-infrastructure#2329` merged at `2026-04-01T22:29:35Z`
  - `bbi-infrastructure#2337` merged at `2026-04-01T22:53:18Z`
  - `mereka-lms#1282` merged at `2026-04-02T00:55:14Z`
  - `mereka-lms#1280` is still open
- Current app-repo build state:
  - GitHub Actions run `23882614649` on `main` / commit `254273ec9ab1bbf63e83bf524c74f05e9c5f8d30`
  - `Build OpenEdX Image` completed `success`
  - current workflow is still in `Post-push OpenEdX Scan`
  - this workflow does **not** auto-promote dev on a normal push to `main`
- Auth regression guard:
  - `./scripts/qa/verify-tenant-auth-runtime.sh`
  - verified `PASS` on `2026-04-02T03:17:39Z`
- Dev Argo:
  - app: `mereka-lms-dev`
  - sync: `OutOfSync`
  - health: `Degraded`
  - revision: `1eca5200d1cf174fcff1438bb716ea05dad53987`
  - operation state: `Failed`
- Live dev promoted image:
  - `lms`, `cms`, `cms-worker`, `lms-worker` are running `ghcr.io/biji-biji-initiative/mereka-lms/openedx:f8838910750a9581875ccc4aba3b9e5f6e563792`
  - infra git records that tag in `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml`
- Promotion-path review:
  - `.github/workflows/build-tutor-images.yml` explicitly says push-to-main builds images and proof only
  - the `update-gitops` job is manual `workflow_dispatch` only and is described as a guarded bridge, not the standard dev promotion path
  - no open `bbi-infrastructure` PR was found that appears to promote a newer OpenEdX tag for `mereka-lms` dev
- Branch hygiene concern:
  - local branch `fix/course-about-language-code` is not clean reviewer evidence
  - relative to `origin/main`, it includes the intended course-about template fix **plus** unrelated import-lane edits in `scripts/migrations/run_full_import.sh` and `scripts/qa/verify-import-dedup.sh`
- Live course-about runtime failure:
  - `GET /courses/course-v1:MEREKA+MCT31-EN+course/about` -> HTTP 500
  - response body: `Encountered error while rendering error page.`
  - LMS logs show Mako failure on `seo_description` with `NameError: Undefined`

### LMS-I

- Branch truth:
  - old branch `feat/import-lane-closure` still exists and its original PR `mereka-lms#1275` was already merged on `2026-04-01T08:27:20Z`
  - new branch `feat/import-lane-closure-v2` exists and backs open PR `mereka-lms#1287`
- PR truth:
  - open PR `mereka-lms#1287` exists, but it is **not** a clean import-only PR
  - `#1287` is `OPEN`, `BLOCKED`, `REVIEW_REQUIRED`
  - `#1287` changes 6 files, not 1:
    - `docs/status/active/IMPORT_STATUS_2026-04-01.md`
    - `docs/status/active/ASPECTS_FORENSIC_PROOF_2026-04-01.md`
    - `scripts/migrations/drive/upload_drive_videos_to_mux.py`
    - `scripts/migrations/kajabi/map_kajabi_users_to_openedx.py`
    - `scripts/migrations/post_import_enterprise_catalogs.py`
    - `scripts/migrations/post_import_metadata.py`
- Mainline truth:
  - the import pipeline fixes below are already on `origin/main`:
    - `c6728c5e4` `fix(import): production pipeline — RKE2 context, UPAI tarball paths, enrollment count`
    - `3da97b890` `fix(import): stop mutating global kubectl context during dry-run`
    - `eb4a66da1` `docs(import): add staging parity findings + production readiness gates`
- Phase-0 import audit:
  - earlier reviewer verification still stands: with `EXPORTS_ROOT=$REPO_ROOT/exports`, `phase-0-verify --dry-run` passes
  - `personal-branding-en` remains a cosmetic warning that still needs explicit, durable documentation
- Process concern:
  - useful import fixes were pushed directly to `main`, reducing the amount of clean branch-backed evidence left to review
  - the new `feat/import-lane-closure-v2` PR is contaminated by unrelated aspects/shared-debt payload, so it does not yet serve as canonical import-lane closure evidence

### LMS-A

- Branch truth:
  - local + remote branch `fix/aspects-closure-phase1` exists
  - divergence vs `origin/main`: `3` behind / `2` ahead
- PR truth:
  - open PR `mereka-lms#1283`
- Remote PR diff is only:
  - `deploy/k8s/base/plugins/aspects/configmaps.yml`
  - `docs/status/active/ASPECTS_FORENSIC_PROOF_2026-04-01.md`
- PR health:
  - review decision: `REVIEW_REQUIRED`
  - CI failing through `Static Validation Precheck` -> `Lint Python files`
- Branch payload includes:
  - `docs/status/active/ASPECTS_FORENSIC_PROOF_2026-04-01.md`
  - `deploy/k8s/base/plugins/aspects/configmaps.yml`
- Live freshness check shows the proof document is stale as a runtime-truth artifact:
  - current dev Argo revision is `1eca5200d1cf174fcff1438bb716ea05dad53987`, not `326d485`
  - current staging Argo revision is `1eca5200d1cf174fcff1438bb716ea05dad53987`, not `326d485`
  - staging `lms-worker` is no longer `0`; live deployment is `1/2 Ready` and one pending pod is blocked by scheduler CPU pressure
  - dev aspects pods are currently healthy: `clickhouse`, `ralph`, `superset`, `superset-worker`, `superset-worker-beat`
  - staging aspects pods are currently healthy: `clickhouse`, `ralph`, `superset`, `superset-worker`

## Reviewer Verdicts

- LMS-D: `runtime_validated` is now supportable from live state and PR `#1286`, but `operationally_closed` is still not supportable.
- LMS-F: the merged fix and successful image build are not enough. Until a newer image is actually promoted to dev and `/courses/.../about` is re-proved live, this lane is not `runtime_validated`.
- LMS-I: keep as branch-backed evidence until PR/merge is real.
- LMS-A: keep as branch/PR-backed evidence until proof lands canonically and is rewritten against current live state.
