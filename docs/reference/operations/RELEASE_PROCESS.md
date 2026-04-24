# Release Process

<!-- Last verified: 2026-03-09 -->

This document defines the canonical release lifecycle for `mereka-lms`.
The authoritative operator path is the canonical entrypoint map in
`scripts/governance/canonical-entrypoints.yaml`.

Use this document for the release sequence and validation order.
Do not treat legacy summaries or local agent notes as release authority.

---

## Semantic Versioning

Releases follow [Semantic Versioning 2.0.0](https://semver.org/): `MAJOR.MINOR.PATCH`

| Segment | When to increment |
|---------|-------------------|
| **MAJOR** | Breaking change to deployment contract, DB schema incompatible with rollback, or Open edX major version upgrade |
| **MINOR** | New feature, new service, new spec milestone, new MFE deployed — backward-compatible |
| **PATCH** | Bug fix, config correction, hotfix — no new behaviour |

Tags are prefixed with `v`: `v1.0.0`, `v1.2.3`, `v2.0.0`.

### Examples

| Change | Version bump |
|--------|-------------|
| Open edX Ulmo → Sumac upgrade | MAJOR |
| Purchase Gateway dark-launch enabled | MINOR |
| WCAG contrast fix | PATCH |
| Caddy config typo fix | PATCH |
| New tenant onboarded | MINOR |
| Stripe webhook endpoint added | MINOR |

---

## Release Cadence

| Type | Frequency | Trigger |
|------|-----------|---------|
| **Minor** | Weekly (Friday) | Accumulated features/specs since last tag |
| **Patch** | Ad-hoc | Production incident, urgent bug, config correction |
| **Major** | As needed | Breaking changes only — requires explicit planning |

---

## Release Checklist

Run these steps in order. Do not skip steps.

### 1. Structural verification

```bash
./scripts/qa/verify-release-automation.sh
./scripts/qa/verify-release-workflow-invocation.sh
./scripts/qa/verify-build-workflow-contract.sh
./scripts/qa/verify-no-latest-prod-tags.sh
```

All scripts must exit 0. Fix any failures before proceeding.

### 2. Review and standing orders

- Open a PR if unreleased commits have not been reviewed
- Follow current standing orders under `docs/meta/standing-orders/`
- Check for any uncommitted changes: `git status`
- Confirm you are on `main` and up to date: `git pull --ff-only`

### 3. Canonical preflight

The canonical preflight front door remains:

```bash
./scripts/infra/canonical-release.sh --check-only
```

This wrapper enforces branch/worktree expectations and validates that the repo is in a safe state before any publish/promotion run.

### 4. Optional tag creation

If you need a semver Git tag and GitHub Release record, use the helper:

```bash
./scripts/infra/create-release.sh v1.2.0
```

This script:
- Validate semver format
- Generate a changelog from conventional commits since the previous tag
- Create an annotated git tag
- Push the tag to origin (this triggers `.github/workflows/release.yml`)
- Print the rollback command for reference

Tag creation is part of release bookkeeping. It is not the canonical deployment step.

### 5. Publish the canonical release inputs

Production release truth comes from the governed image workflow, not local Tutor image tags.

```bash
APP_SHA="$(git rev-parse origin/main)"
gh workflow run build-tutor-images.yml \
  --ref main \
  -f build_openedx=true \
  -f build_mfe=true \
  -f update_gitops=false \
  -f target_environment=production \
  -f image_tag="${APP_SHA}"

RUN_ID="<build-tutor-images run id>"
gh run watch "${RUN_ID}"
gh run download "${RUN_ID}" --name release-bundle --dir "var/release-artifacts/${RUN_ID}"
gh run download "${RUN_ID}" --name build-provenance --dir "var/release-artifacts/${RUN_ID}"
```

Treat the workflow-emitted immutable tags/digests plus the `release-bundle` and `build-provenance` artifacts as the authoritative release inputs.
The release object distinguishes:
- `build_origin_environment` — where the build-side artifact was produced from
- `promotion_target_environment` — where GitOps has actually linked it, when known

### 6. Apply the canonical release

```bash
APP_SHA="$(git rev-parse origin/main)"
CONFIRM_RELEASE_OPENEDX_GITOPS=RELEASE_OPENEDX_GITOPS \
CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS=PUSH_RELEASE_OPENEDX_GITOPS \
ALLOW_PROD_APPLY=1 \
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag "${APP_SHA}" --mfe-tag "${APP_SHA}" \
  --openedx-digest "sha256:<openedx_digest>" \
  --mfe-digest "sha256:<mfe_digest>" \
  --require-digests --apply --commit --push --verify-runtime
```

This is the canonical production release path.

### 7. GitHub Release metadata

The `release.yml` workflow fires automatically on tag push and creates the GitHub Release metadata.
Monitor the workflow in GitHub Actions if you used `create-release.sh`.

### 8. ArgoCD Sync

ArgoCD reconciles automatically within ~3 minutes of the GitOps repo updating.
Do **not** patch resources directly.

Verify sync:

```bash
kubectl -n argocd get application mereka-lms-production
kubectl -n mereka-lms rollout status deployment/lms
kubectl -n mereka-lms rollout status deployment/cms
kubectl -n mereka-lms rollout status deployment/mfe
```

### 9. Seed SiteConfiguration (after any DB reset or fresh install)

Skip this step on routine image-tag rollouts. Run it whenever the LMS MySQL
database was reset, restored from backup, or newly provisioned — the
migration job alone will NOT repopulate Site/SiteConfiguration rows, and
without them the MFE config API returns main-tenant data to every tenant
(SOF, BijiBiji, etc. all resolve to Mereka primary).

```bash
# Pick the script for the env
./scripts/tenants/seed-dev-sites.sh       # dev
./scripts/tenants/seed-staging-sites.sh   # staging
./scripts/tenants/seed-prod-sites.sh      # prod
```

Verify seeding:

```bash
# Each tenant should have TWO SiteConfiguration rows (LMS host + apps host)
kubectl -n mereka-lms-dev exec deploy/lms -- python manage.py lms shell -c \
  "from django.contrib.sites.models import Site; \
   from openedx.core.djangoapps.site_configuration.models import SiteConfiguration; \
   [print(s.domain, bool(getattr(s, 'configuration', None))) for s in Site.objects.all()]"
```

Expected: one row per tenant's LMS domain and one per the tenant's `apps.`
domain, both with `configuration=True`. Missing rows cause the cross-tenant
MFE redirect bug.

**Follow-up**: Making this a post-migrate Kubernetes Job is tracked in
the open-ended backlog; the checklist step above is the safety net.

### 10. Post-Deploy Smoke Test

```bash
# Branding and public health
./scripts/branding/run-branding-gates.sh prod
./scripts/qa/public-health-check.sh prod
```

Both must pass. These checks catch silent regressions (no pod crashes, no logs).

---

## Rollback Procedure

If production is unhealthy after a release:

### Quick Rollback (GitOps)

Re-run the release orchestrator with the **previous known-good tags and digests**:

```bash
PREV_TAG="v1.1.3"   # replace with actual previous tag

./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag "${PREV_TAG}" \
  --mfe-tag "${PREV_TAG}" \
  --openedx-digest "sha256:<previous_openedx_digest>" \
  --mfe-digest "sha256:<previous_mfe_digest>" \
  --require-digests --apply --commit --push --verify-runtime
```

### Tag-Based Rollback

To revert the Git tag (removes the release, does not delete code):

```bash
# Delete the bad tag locally and remotely
git tag -d v1.2.0
git push origin :refs/tags/v1.2.0
```

ArgoCD will reconcile to whatever the GitOps repo declares — the tag is metadata only.
The actual rollback is done by pointing the GitOps overlay back to the previous image tag.

### Verify Rollback

```bash
kubectl -n mereka-lms rollout status deployment/lms
./scripts/qa/public-health-check.sh prod
```

Document the incident in `docs/status/incidents/`.

---

## Hotfix Process

Use this process for urgent patches that cannot wait for the next weekly minor.

### 1. Branch from the release tag

```bash
git fetch --tags
git checkout -b hotfix/v1.2.1 v1.2.0
```

### 2. Apply the fix

Make the minimal change required. Follow conventional commit format:

```
fix(lms): correct ALLOWED_HOSTS for academyv2.mereka.io
```

### 3. Tag the patch release

```bash
./scripts/infra/create-release.sh v1.2.1
```

### 4. Merge back to main

```bash
git checkout main
git merge --no-ff hotfix/v1.2.1
git push origin main
git branch -d hotfix/v1.2.1
```

### 5. Follow the standard post-deploy checklist

Steps 4–6 of the Release Checklist above.

---

## Conventional Commit Format

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

| Type | Purpose |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `chore` | Build process, dependency updates, tooling |
| `test` | Adding or correcting tests |
| `perf` | Performance improvement |
| `ci` | CI/CD configuration |

Scope is the affected component: `lms`, `cms`, `mfe`, `forum`, `k8s`, `branding`, `purchase-gateway`, etc.

Breaking changes are indicated by `!` after the type/scope: `feat(k8s)!: migrate to Sumac`.

---

## References

- Canonical entrypoint map: `scripts/governance/canonical-entrypoints.yaml`
- Canonical deploy contract: `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
- Existing release checklist: `docs/ops/runbooks/RELEASE_CHECKLIST.md`
- Standing orders: `docs/meta/standing-orders/README.md`
- Canonical release wrapper: `scripts/infra/canonical-release.sh`
- GitOps release orchestrator: `scripts/infra/release-openedx-gitops.sh`
- CI pipeline spec: `specs/ci-cd-pipeline_spec.md`
- ADR-012: `docs/adr/historical/012-no-runtime-css-overlay.md`
