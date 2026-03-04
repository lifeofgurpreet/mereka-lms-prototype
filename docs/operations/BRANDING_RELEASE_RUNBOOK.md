# Branding & MFE Release Runbook

_Last updated: 2026-02-27_

> Deterministic rollout path for LMS/MFE branding changes. Covers build, push, GitOps deploy,
> verify, and rollback.
>
> AC-DEP-001, AC-DEP-002, AC-DEP-003, AC-DEP-004, AC-DEP-201, AC-DEP-202, AC-DEP-204, AC-DEP-205

---

## Quick Reference: One-Shot Deploy (AC-DEP-201)

For UI/UX branding changes already merged to `main`, use this single command sequence:

```bash
# 1. Build + tag + push (one-shot)
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh
tutor images build openedx -a PIP_COMMAND=pip && tutor images build mfe

TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
GAR="ghcr.io/biji-biji-initiative/mereka-lms"
docker tag docker.io/overhangio/openedx:latest "${GAR}/openedx:${TAG}"
docker tag docker.io/overhangio/openedx-mfe:latest "${GAR}/openedx-mfe:${TAG}"
docker push "${GAR}/openedx:${TAG}" && docker push "${GAR}/openedx-mfe:${TAG}"

# 2. GitOps rollout + verify (one-shot)
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" --mfe-tag "${TAG}" \
  --apply --commit --push --verify-runtime \
  --purge-frontend-cache

# 3. Post-deploy smoke matrix (mandatory)
./scripts/qa/verify-post-deploy-smoke.sh --env prod \
  --evidence-dir "var/evidence/release-$(date +%Y%m%d)"
```

---

## Pre-Flight Checklist

- [ ] All verification scripts pass: `./scripts/qa/run-branding-evidence-pipeline.sh --env prod`
- [ ] Branch is clean: `git status` shows no uncommitted changes
- [ ] On canonical main: `git branch --show-current` → `main`
- [ ] Docker has ≥12 GB RAM and 2–4 GB swap configured (required for openedx webpack build)

---

## Step 1: Build Images

```bash
# Set environment
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Build LMS/CMS image (30-45 min, needs 12GB+ Docker RAM)
# -a PIP_COMMAND=pip avoids uv build isolation issues with loremipsum==1.0.5
tutor images build openedx -a PIP_COMMAND=pip

# Build MFE image (15-20 min)
tutor images build mfe

# Verify build completed
docker images | grep -E "openedx|mfe"
```

---

## Step 2: Tag and Push to Artifact Registry

```bash
# Tag with git SHA + timestamp  (AC-DEP-001: exact image tag tied to commit SHA)
TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
GAR="ghcr.io/biji-biji-initiative/mereka-lms"

# Tag images
docker tag docker.io/overhangio/openedx:latest "${GAR}/openedx:${TAG}"
docker tag docker.io/overhangio/openedx-mfe:latest "${GAR}/openedx-mfe:${TAG}"

# Push to Artifact Registry
docker push "${GAR}/openedx:${TAG}"
docker push "${GAR}/openedx-mfe:${TAG}"

# Record digests (AC-DEP-001: exact image digests in release notes)
OPENEDX_DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "${GAR}/openedx:${TAG}" 2>/dev/null || docker inspect --format='{{.Id}}' "${GAR}/openedx:${TAG}")"
MFE_DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "${GAR}/openedx-mfe:${TAG}" 2>/dev/null || docker inspect --format='{{.Id}}' "${GAR}/openedx-mfe:${TAG}")"

echo "TAG:           ${TAG}"
echo "COMMIT_SHA:    $(git rev-parse HEAD)"
echo "openedx:       ${GAR}/openedx:${TAG}"
echo "openedx digest: ${OPENEDX_DIGEST}"
echo "openedx-mfe:   ${GAR}/openedx-mfe:${TAG}"
echo "mfe digest:    ${MFE_DIGEST}"
```

---

## Step 3: GitOps Rollout via release-openedx-gitops.sh

Use the canonical release orchestrator (AC-DEP-002: exact commands for gitops rollout):

```bash
# Dry-run first (always)
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" \
  --mfe-tag "${TAG}" \
  --openedx-digest "${OPENEDX_DIGEST}" \
  --mfe-digest "${MFE_DIGEST}" \
  --require-digests

# Apply, commit, push, and verify runtime convergence
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" \
  --mfe-tag "${TAG}" \
  --openedx-digest "${OPENEDX_DIGEST}" \
  --mfe-digest "${MFE_DIGEST}" \
  --require-digests \
  --apply --commit --push --verify-runtime \
  --purge-frontend-cache
```

`release-openedx-gitops.sh` now enforces runtime PARAGON theme readiness by default during production postflights:

- `verify-paragon-runtime.sh --require-runtime`
- Runtime origin default: `https://apps.academyv2.mereka.io`

Emergency-only overrides:

```bash
# Override runtime theme origin for validation
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" \
  --mfe-tag "${TAG}" \
  --apply --commit --push --verify-runtime \
  --paragon-runtime-url "https://apps.academyv2.mereka.io"

# Skip PARAGON runtime guard only for controlled emergency releases
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" \
  --mfe-tag "${TAG}" \
  --apply --commit --push --verify-runtime \
  --skip-paragon-runtime-guard
```

### Manual GitOps update (if release-openedx-gitops.sh is unavailable)

```bash
# AC-DEP-004: update BOTH app repo overlay AND GitOps repo overlay to prevent drift
APP_KUST="deploy/k8s/overlays/production/kustomization.yaml"

# Update app repo overlay
sed -i "s/newTag: .*/newTag: ${TAG}/g" "$APP_KUST"
git add "$APP_KUST"
git commit -m "release: branding ${TAG}

Image tag: ${TAG}
Commit: $(git rev-parse HEAD)
openedx digest: ${OPENEDX_DIGEST}
mfe digest: ${MFE_DIGEST}"
git push origin main

# Update GitOps repo (bbi-infrastructure)
cd /home/gurpreet/projects/k8s/bbi-infrastructure
git checkout main && git pull
INFRA_KUST="apps/mereka-lms/overlays/prod/kustomization.yaml"
sed -i "s/newTag: .*/newTag: ${TAG}/g" "$INFRA_KUST"
git add "$INFRA_KUST"
git commit -m "release: branding ${TAG}"
git push origin main
```

---

## Step 4: Verify Deployment

```bash
# Check ArgoCD sync status (AC-DEP-002: verification commands)
kubectl -n argocd get application mereka-lms-local

# Wait for rollout convergence (up to 5 min)
kubectl -n mereka-lms rollout status deployment/lms --timeout=300s
kubectl -n mereka-lms rollout status deployment/cms --timeout=300s
kubectl -n mereka-lms rollout status deployment/mfe --timeout=300s

# Confirm running image tags match what was deployed
kubectl get deploy lms cms mfe -n mereka-lms \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}'

# Run post-deploy branding gates (MANDATORY per 2026-02-10 incident — see ADR-012)
./scripts/branding/run-branding-gates.sh prod
./scripts/qa/public-health-check.sh prod

# Full branding evidence pipeline
./scripts/qa/run-branding-evidence-pipeline.sh --env prod

# Purge frontend/theme cache entries (dry-run first, then apply)
# Note: this is also integrated via release-openedx-gitops.sh --purge-frontend-cache.
./scripts/infra/purge-frontend-theme-cache.sh --env prod
./scripts/infra/purge-frontend-theme-cache.sh --env prod --apply

# Frontend closure lane (cross-browser + a11y + performance, skips multisite baseline gates)
./scripts/qa/run-branding-evidence-pipeline.sh \
  --env prod \
  --frontend-only \
  --cross-browser
# To enforce Safari/WebKit availability in CI (no fallback disable):
#   set STRICT_WEBKIT=1 (or workflow input require_webkit=true)
# To force release-blocking runtime-theme readiness in this lane:
#   set REQUIRE_RUNTIME_THEME=1 and keep RUN_RUNTIME_THEME_CONTRACT=1 (default)

# Single-browser smoke + screenshots lane (authn/learning/account/profile surfaces)
./scripts/qa/verify-npm-start-mfe-smoke.sh \
  --base-url https://academyv2.mereka.io \
  --learning-path /learning

# GitHub Actions equivalent (manual dispatch):
# .github/workflows/npm-start-mfe-smoke.yml
# Enable strict runtime mode only after PARAGON_THEME_URLS rollout is active.

# Optional: release evidence workflow (dry-run + runtime contract + optional npm-start smoke)
# .github/workflows/release-evidence.yml inputs:
#   - require_runtime_theme=true|false
#   - runtime_theme_url=<optional override>
#   - run_npm_start_smoke=true|false
#   - learning_path=/learning
#   - npm_start_project=chromium|firefox|mobile-chrome

# Check all tenant domains return HTTP 200
for domain in academyv2.mereka.io academy.biji-biji.com; do
  echo "$domain: $(curl -s -o /dev/null -w '%{http_code}' "https://${domain}/")"
done

# Drift check: confirm source and GitOps overlays are aligned (AC-DEP-004)
./scripts/qa/verify-gitops-drift.sh
./scripts/qa/verify-gitops-image-overrides.sh
```

---

## Step 5: Rollback (if needed)

> AC-DEP-003: Rollback path validated and documented

### Option A: Re-run release orchestrator with known-good tags (preferred)

```bash
# Replace PREV_TAG with the last known-good tag (check git log for prior releases)
PREV_TAG="<previous-known-good-tag>"

./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${PREV_TAG}" \
  --mfe-tag "${PREV_TAG}" \
  --apply --commit --push --verify-runtime
```

### Option B: Revert GitOps overlay directly

```bash
# Revert in GitOps repo (ArgoCD auto-syncs within ~3 min after push)
cd /home/gurpreet/projects/k8s/bbi-infrastructure
git log --oneline -10 apps/mereka-lms/overlays/prod/kustomization.yaml   # find prior commit
git revert HEAD --no-edit
git push origin main

# Also revert app repo overlay to keep them in sync (AC-DEP-004)
cd /home/gurpreet/projects/k8s/mereka-lms
git revert HEAD --no-edit
git push origin main
```

### Option C: Emergency kubectl rollback

> WARNING: ArgoCD will revert within ~3 min. Only use this to buy time while Option A/B is prepared.

```bash
kubectl -n mereka-lms rollout undo deployment/lms
kubectl -n mereka-lms rollout undo deployment/cms
kubectl -n mereka-lms rollout undo deployment/mfe

# Immediately verify endpoints still serving traffic
kubectl get endpoints -n mereka-lms
```

### Post-rollback verification

```bash
# Confirm pods settled
kubectl -n mereka-lms rollout status deployment/lms --timeout=120s
kubectl -n mereka-lms rollout status deployment/cms --timeout=120s

# Re-run health checks
./scripts/qa/public-health-check.sh prod
./scripts/branding/run-branding-gates.sh prod

# Document incident
# → docs/operations/postmortems/ (create new file)
```

---

## Post-Deploy Smoke Matrix (AC-DEP-204)

After every deploy, run the post-deploy smoke matrix. All checks must PASS before marking rollout complete.

```bash
# Full smoke matrix (authn, LMS, Studio, 3+ MFEs, tenant domains, K8s pods)
./scripts/qa/verify-post-deploy-smoke.sh --env prod \
  --evidence-dir "var/evidence/release-$(date +%Y%m%d)"
```

The smoke matrix covers:

| Category | Endpoints | Expected |
|----------|-----------|----------|
| LMS Core | homepage, heartbeat, mfe_config API | HTTP 200 |
| Studio/CMS | homepage (302 → login), heartbeat | HTTP 302/200 |
| Authn MFE | /authn/login, /authn/register | HTTP 200 |
| MFE Routes (3+) | learner-dashboard, account, profile, course-about, discussions | HTTP 200 |
| Tenant Domains | academy.biji-biji.com, skillourfuture.academy.mereka.io | HTTP 200 + correct SITE_NAME |
| K8s Readiness | lms, cms, mfe deployments | ready == desired |
| Image Tags | lms, cms, mfe containers | no `latest` tag |

---

## Release Notes Template (AC-DEP-202)

```markdown
## Release: Branding <TAG>

**Date**: YYYY-MM-DD HH:MM UTC
**Commit SHA**: <full-sha>
**Short SHA**: <short-sha>

**Images**:
- LMS/CMS: `ghcr.io/biji-biji-initiative/mereka-lms/openedx:<tag>`
  - Digest: `sha256:<openedx-digest>`
- MFE: `ghcr.io/biji-biji-initiative/mereka-lms/mfe:<tag>`
  - Digest: `sha256:<mfe-digest>`

**Changes**:
- <describe branding/MFE changes>

**Verification**:
- Evidence pipeline: PASS (5/5 gates)
- Tenant domains: 3/3 HTTP 200
- Post-deploy smoke matrix: PASS (see evidence artifacts)
- GitOps drift check: PASS

**Evidence artifacts**: `var/evidence/release-<YYYYMMDD>/`
**Rollback tag**: `<previous-known-good-tag>`
```

---

## GitOps Drift Check (AC-DEP-004)

The canonical drift check script is `scripts/qa/verify-gitops-drift.sh`. It validates that the
GitOps overlay (bbi-infrastructure) reflects the same custom apps and middleware as the source repo.

```bash
./scripts/qa/verify-gitops-drift.sh

# Also check image override contract parity
./scripts/qa/verify-gitops-image-overrides.sh
```

Manual inspection if needed:

```bash
# Custom apps in source production.py
grep -o "'[a-z_]*'" deploy/k8s/base/apps/openedx/settings/lms/production.py \
  | sort | uniq

# Custom apps in GitOps overlay (path may vary)
grep -o "'[a-z_]*'" /home/gurpreet/projects/k8s/bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py \
  | sort | uniq 2>/dev/null || echo "overlay not found locally"
```

---

## Evidence Retention Policy (AC-DEP-205)

Evidence artifacts from rollouts and rollbacks MUST be retained for **30 days minimum**.

### Directory structure

```
var/evidence/
├── release-20260218/
│   ├── post-deploy-smoke.log          # verify-post-deploy-smoke.sh output
│   ├── branding-evidence-pipeline.log  # run-branding-evidence-pipeline.sh output
│   ├── gitops-drift.log               # verify-gitops-drift.sh output
│   ├── gitops-image-overrides.log     # verify-gitops-image-overrides.sh output
│   ├── tenant-branding-runtime.log    # verify-tenant-branding-runtime.sh output
│   └── summary.md                     # Release notes (copy of template above)
└── rollback-20260218/
    ├── pre-rollback-state.log          # Image tags + pod status before rollback
    ├── rollback-commands.log           # Exact commands executed
    ├── post-rollback-smoke.log         # verify-post-deploy-smoke.sh after rollback
    └── incident-summary.md             # What broke, root cause, resolution
```

### Rollback evidence checklist

After every rollback, capture:

```bash
# 1. Pre-rollback state
EVIDENCE_DIR="var/evidence/rollback-$(date +%Y%m%d)"
mkdir -p "$EVIDENCE_DIR"

kubectl get deploy lms cms mfe -n mereka-lms \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}' \
  > "$EVIDENCE_DIR/pre-rollback-state.log"

# 2. Execute rollback (use Option A, B, or C from Step 5 above)
# Record commands in rollback-commands.log

# 3. Post-rollback verification
./scripts/qa/verify-post-deploy-smoke.sh --env prod \
  --evidence-dir "$EVIDENCE_DIR" 2>&1 | tee "$EVIDENCE_DIR/post-rollback-smoke.log"

# 4. Document incident
echo "# Rollback Incident $(date +%Y-%m-%d)" > "$EVIDENCE_DIR/incident-summary.md"
echo "Describe: what broke, root cause, resolution" >> "$EVIDENCE_DIR/incident-summary.md"
```

### Cleanup

Evidence older than 30 days MAY be archived or deleted:

```bash
find var/evidence/ -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
```

---

## Release Template (AC-DEP-001)

Copy this template for each release. Fill in values and attach to the release PR.

```markdown
# Release: <TAG>

**Date**: YYYY-MM-DD
**Operator**: <name>
**HEAD**: <sha>
**Branch**: main
**Images**: openedx:<tag>, openedx-mfe:<tag>

## Pre-Release Gates

| Gate | Result | Evidence |
|------|--------|---------|
| Worktree fresh | PASS/FAIL | `worktree-freshness.log` |
| Config parity | PASS/FAIL | `config-parity.log` |
| Forbidden overrides | PASS/FAIL | `forbidden-overrides.log` |
| GitOps drift | PASS/FAIL | `gitops-drift.log` |

## Image Build

| Image | Tag | Size | Build Time |
|-------|-----|------|------------|
| openedx | <tag> | | |
| openedx-mfe | <tag> | | |

## Post-Deploy Verification

| Gate | Result | Evidence |
|------|--------|---------|
| Post-deploy smoke | PASS/FAIL | `post-deploy-smoke.log` |
| Tenant branding | PASS/FAIL | `tenant-branding-runtime.log` |
| ArgoCD status | Synced/Degraded | `argocd-status.log` |

## Evidence Directory

`var/evidence/release-<YYYYMMDD>/`

## Sign-off

- [ ] Builder: <name>
- [ ] Verifier: <name>
```

### Generate evidence automatically

```bash
./scripts/qa/verify-release-readiness.sh --env prod
# Or dry-run mode (does not fail on branding gates):
./scripts/qa/verify-release-readiness.sh --env prod --dry-run
```

---

## Reference

- Release readiness gate: `scripts/qa/verify-release-readiness.sh`
- Canonical release orchestrator: `scripts/infra/release-openedx-gitops.sh`
- Image override contract: `scripts/qa/verify-gitops-image-overrides.sh`
- GitOps drift check: `scripts/qa/verify-gitops-drift.sh`
- Post-deploy smoke matrix: `scripts/qa/verify-post-deploy-smoke.sh`
- Branding evidence pipeline: `scripts/qa/run-branding-evidence-pipeline.sh`
- ADR-012 (no runtime CSS overlay): `docs/adr/012-no-runtime-css-overlay.md`
- General release checklist: `docs/operations/RELEASE_CHECKLIST.md`
- Tenant branding QA: `docs/operations/TENANT_BRANDING_QA_RUNBOOK.md`
- Tenant onboarding playbook: `docs/operations/TENANT_ONBOARDING_PLAYBOOK.md`
