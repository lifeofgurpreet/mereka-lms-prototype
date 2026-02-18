# Release Deployment Template

<!-- bead: 8jao.29 | Last updated: 2026-02-18 -->

Use this template for every production rollout of `mereka-lms`. Copy the
**Rollout Attempt** table section for each attempt and fill it in as you go.
All sections are mandatory. Do not skip post-deploy validation.

---

## 0. Release Metadata

| Field | Value |
|-------|-------|
| Bead / ticket | <!-- e.g. 8jao.29 --> |
| Release name | <!-- e.g. v2026-02-18-branding --> |
| Operator | <!-- name / agent ID --> |
| Target environment | `production` |
| Source branch | `main` |
| Start time (UTC) | <!-- ISO-8601 --> |
| End time (UTC) | <!-- ISO-8601 --> |

---

## 1. Pre-Deploy Checklist

Complete **every** item before running any build or deploy command.

### 1.1 Source parity

- [ ] Current branch is `main`: `git branch --show-current`
- [ ] Branch is up-to-date: `git fetch origin && git status`
- [ ] No uncommitted changes in `deploy/`, `infrastructure/`, `scripts/`
- [ ] Worktree freshness gate passes:
  ```bash
  ./scripts/infra/check-worktree-freshness.sh --max-behind 5
  ```

### 1.2 Patch and config parity

- [ ] `apply-patches.sh` has been run after the last `tutor config save`:
  ```bash
  ./scripts/infra/verify-tutor-config.sh
  ```
- [ ] Config uses local service names (not cloud IPs) if doing a local dry-run:
  ```bash
  grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
  ```

### 1.3 Image tags

- [ ] Target `OPENEDX_TAG` is immutable and final (not `latest`)
- [ ] Target `MFE_TAG` is immutable and final (not `latest`)
- [ ] Production kustomization has no `latest` tags:
  ```bash
  ./scripts/qa/verify-no-latest-prod-tags.sh
  ```

### 1.4 Preflight gate (mandatory)

Run and capture output:
```bash
./scripts/infra/verify-release-preflight.sh 2>&1 | tee var/evidence/release-$(date +%Y%m%d)/preflight.log
```
- [ ] Preflight gate exits 0 (all PASS or WARN, zero FAIL)

### 1.5 Branding gate (source-time)

```bash
RUN_LIVE_GATE=0 BRANDING_LEVEL=deep ./scripts/branding/run-branding-gates.sh prod
```
- [ ] Branding gate passes

### 1.6 Policy checks

```bash
./scripts/qa/verify-release-automation.sh
./scripts/qa/verify-build-workflow-contract.sh
./scripts/qa/verify-release-workflow-invocation.sh
./scripts/qa/verify-release-dry-run-contract.sh
./scripts/qa/verify-no-latest-prod-tags.sh
```
- [ ] All policy checks pass

---

## 2. Deploy Steps

### 2.1 Image build (skip if tags already pushed)

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"

# Backend / LMS (if changed)
tutor images build openedx -a PIP_COMMAND=pip   # ~30 min, requires 12 GB RAM
tutor images push openedx

# MFE (if changed)
tutor images build mfe                           # ~15 min
tutor images push mfe
```

Record pushed digests:
```bash
docker inspect --format='{{index .RepoDigests 0}}' \
  asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${OPENEDX_TAG}
docker inspect --format='{{index .RepoDigests 0}}' \
  asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:${MFE_TAG}
```

| Image | Tag | Digest (sha256:…) |
|-------|-----|-------------------|
| openedx | | |
| openedx-mfe | | |

### 2.2 GitOps overlay update and rollout

```bash
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --openedx-digest "sha256:<openedx-digest>" \
  --mfe-digest "sha256:<mfe-digest>" \
  --require-digests \
  --apply --commit --push --verify-runtime
```

- [ ] GitOps script exits 0
- [ ] PR merged to `main` (no direct push)
- [ ] ArgoCD sync confirmed: `kubectl -n argocd get application mereka-lms-local`

### 2.3 Rollout status

```bash
kubectl -n mereka-lms rollout status deployment/lms
kubectl -n mereka-lms rollout status deployment/cms
kubectl -n mereka-lms rollout status deployment/mfe
```

- [ ] All deployments healthy
- [ ] Endpoints populated: `kubectl get endpoints -n mereka-lms`

---

## 3. Post-Deploy Validation

Run **all** checks even if nothing appears broken. Silent regressions are real
(see ADR-012).

### 3.1 Smoke and health

```bash
./scripts/qa/verify-post-deploy-smoke.sh --env prod
./scripts/infra/cron-public-health-check.sh
```

- [ ] Smoke passes
- [ ] Health check passes

### 3.2 Branding gates (live)

```bash
./scripts/branding/run-branding-gates.sh prod
```

- [ ] Branding gates pass

### 3.3 Evidence package (mandatory)

```bash
./scripts/qa/verify-release-readiness.sh \
  --env prod \
  --evidence-dir "var/evidence/release-$(date +%Y%m%d)"
```

Evidence directory must contain:
- `git-state.log` — HEAD SHA, branch, commit log
- `image-tags.log` — production overlay image pins
- `argocd-status.log` — Argo application sync state
- `post-deploy-smoke.log` — smoke gate output
- `tenant-branding-runtime.log` — branding gate output
- `release-readiness-summary.md` — aggregated PASS/FAIL/WARN summary

- [ ] Evidence directory created and non-empty
- [ ] Evidence committed or uploaded as CI artifact

---

## 4. Rollback Procedure

If post-deploy validation fails, rollback immediately.

```bash
# Roll back to last known-good tags
PREV_OPENEDX_TAG="<prior-tag>"
PREV_MFE_TAG="<prior-tag>"

./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${PREV_OPENEDX_TAG}" \
  --mfe-tag "${PREV_MFE_TAG}" \
  --apply --commit --push --verify-runtime

# Confirm rollback
kubectl -n mereka-lms rollout status deployment/lms
./scripts/qa/verify-post-deploy-smoke.sh --env prod
```

- [ ] Prior tags documented above in image table
- [ ] Rollback verified with smoke test
- [ ] Incident documented in `docs/operations/`

---

## 5. Dry-Run (Lower Environment Validation)

Before any production deploy, validate the full sequence in a lower/local
environment. This ensures no manual cherry-pick or ad-hoc worktree path is
required.

### 5.1 Local dry-run

```bash
# Ensure local config uses Docker Compose service names
export TUTOR_ROOT="$(pwd)/tutor_env"
grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
# Expected: mysql, mongodb, redis (NOT 10.x.x.x)

# Start services
tutor local start

# Run release script in dry-run mode (no --apply)
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}"

# Verify overlay changes look correct before committing
git diff deploy/k8s/overlays/production/kustomization.yaml

# Run smoke against local
./scripts/qa/verify-post-deploy-smoke.sh --env dev
```

### 5.2 Dry-run policy

- **No cherry-picks**: All changes must come from `main` via PR merge.
- **No ad-hoc worktrees**: Deploy only from the canonical worktree at
  `/home/gurpreet/projects/k8s/mereka-lms` on branch `main`.
- **Single source branch**: Only one branch (`main`) is the deployment source.
  Feature branches are merged before deploy, never deployed directly.
- **Dry-run passes = production-deploy approved**: If the dry-run smoke test
  passes, production deploy may proceed without additional manual steps.

- [ ] Dry-run completed in local or lower env
- [ ] No cherry-picks or manual worktree operations were required
- [ ] Smoke passed in lower env

---

## 6. Worktree Policy

| Rule | Rationale |
|------|-----------|
| Deploy only from `main` | ArgoCD reverts any out-of-band patches |
| One canonical worktree | Prevents conflicting edits across agents |
| Feature branches deleted after merge | Avoids stale-branch confusion |
| No direct `kubectl apply` in prod | Overwritten on next ArgoCD sync |
| No `git commit --amend` on published commits | Destroys history, breaks agents |

---

## 7. Rollout Attempt Tracking

Copy one block per attempt. Retain all attempts (including failed ones) for
post-incident review.

---

### Attempt 1

| Field | Value |
|-------|-------|
| Date (UTC) | |
| Operator | |
| OPENEDX_TAG | |
| MFE_TAG | |
| GitOps commit SHA | |
| ArgoCD sync status | |
| Preflight gate | PASS / FAIL |
| Branding gate | PASS / FAIL |
| Smoke gate | PASS / FAIL |
| Evidence dir | |
| Outcome | SUCCESS / ROLLED BACK / ABORTED |
| Notes | |

---

### Attempt 2

| Field | Value |
|-------|-------|
| Date (UTC) | |
| Operator | |
| OPENEDX_TAG | |
| MFE_TAG | |
| GitOps commit SHA | |
| ArgoCD sync status | |
| Preflight gate | PASS / FAIL |
| Branding gate | PASS / FAIL |
| Smoke gate | PASS / FAIL |
| Evidence dir | |
| Outcome | SUCCESS / ROLLED BACK / ABORTED |
| Notes | |

---

### Attempt 3

| Field | Value |
|-------|-------|
| Date (UTC) | |
| Operator | |
| OPENEDX_TAG | |
| MFE_TAG | |
| GitOps commit SHA | |
| ArgoCD sync status | |
| Preflight gate | PASS / FAIL |
| Branding gate | PASS / FAIL |
| Smoke gate | PASS / FAIL |
| Evidence dir | |
| Outcome | SUCCESS / ROLLED BACK / ABORTED |
| Notes | |

---

## 8. Evidence Package Format

The evidence package produced by `verify-release-readiness.sh` must include:

| File | Contents |
|------|----------|
| `git-state.log` | HEAD SHA, branch name, remote URL, dirty file count, recent commit log |
| `image-tags.log` | Image newName / newTag / digest from production kustomization |
| `argocd-status.log` | Output of `kubectl get application -n argocd` |
| `post-deploy-smoke.log` | Full smoke gate output (PASS/FAIL/WARN lines) |
| `tenant-branding-runtime.log` | Branding runtime gate output |
| `preflight.log` | Output of `verify-release-preflight.sh` |
| `release-readiness-summary.md` | Aggregated summary: date, env, HEAD, gates |

Archive or upload the evidence directory as a CI artifact after every
production rollout.

---

## Related

- `docs/operations/RELEASE_CHECKLIST.md` — Condensed release checklist
- `docs/operations/MERGE_FIRST_DEPLOYMENT_PROTOCOL.md` — Merge-first rules
- `docs/operations/BRANDING_RELEASE_RUNBOOK.md` — Branding-specific rollout
- `scripts/infra/verify-release-preflight.sh` — Pre-deploy gating script
- `scripts/infra/release-openedx-gitops.sh` — Canonical release orchestrator
- `scripts/qa/verify-release-readiness.sh` — Evidence package generator
- `scripts/infra/check-worktree-freshness.sh` — Worktree stale-check gate
