# Release Process

<!-- Last verified: 2026-02-25 -->

This document defines the end-to-end release lifecycle for `mereka-lms`: how versions are
numbered, how releases are created, how changelogs are generated, and how to roll back or
hotfix.

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

### 1. Verify

```bash
# Run full verification suite
./scripts/qa/verify-release-automation.sh
./scripts/qa/verify-build-workflow-contract.sh
./scripts/qa/verify-no-latest-prod-tags.sh
```

All scripts must exit 0. Fix any failures before proceeding.

### 2. Review

- Open a PR if unreleased commits have not been reviewed
- Reviewer must be Opus-tier (see `~/.claude/CLAUDE.md` — auto-review rule)
- Check for any uncommitted changes: `git status`
- Confirm you are on `main` and up to date: `git pull --ff-only`

### 3. Tag

Use the release helper script (validates semver, generates changelog, creates annotated tag):

```bash
./scripts/infra/create-release.sh v1.2.0
```

The script will:
- Validate semver format
- Generate a changelog from conventional commits since the previous tag
- Create an annotated git tag
- Push the tag to origin (this triggers the `release.yml` workflow)
- Print the rollback command for reference

### 4. GitHub Release

The `release.yml` workflow fires automatically on tag push and:
- Generates a changelog from conventional commits
- Creates a GitHub Release with the changelog as the body

Monitor the workflow at: `https://github.com/<org>/mereka-lms/actions`

### 5. ArgoCD Sync

ArgoCD reconciles automatically within ~3 minutes of the GitOps repo updating.
Do **not** patch resources directly — see `~/.claude/rules/gitops-enforcement.md`.

Verify sync:

```bash
kubectl -n argocd get application mereka-lms-production
kubectl -n mereka-lms rollout status deployment/lms
kubectl -n mereka-lms rollout status deployment/cms
kubectl -n mereka-lms rollout status deployment/mfe
```

### 6. Post-Deploy Smoke Test

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

Re-run the release orchestrator with the **previous known-good tags**:

```bash
PREV_TAG="v1.1.3"   # replace with actual previous tag

./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${PREV_TAG}" \
  --mfe-tag "${PREV_TAG}" \
  --apply --commit --push --verify-runtime
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

Document the incident in `docs/operations/postmortems/`.

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

- Existing release checklist: `docs/runbooks/operations/RELEASE_CHECKLIST.md`
- GitOps enforcement rules: `~/.claude/rules/gitops-enforcement.md`
- Release orchestrator: `scripts/infra/release-openedx-gitops.sh`
- CI pipeline spec: `specs/ci-cd-pipeline_spec.md`
- ADR-012: `docs/adr/012-no-runtime-css-overlay.md`
