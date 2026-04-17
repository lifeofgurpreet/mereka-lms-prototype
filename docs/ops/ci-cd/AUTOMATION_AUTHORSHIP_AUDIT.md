# Automation Authorship Audit

> Every automation flow that creates PRs must use an identity that causes
> `pull_request` checks to attach. This audit maps all such flows.

## Audit Date: 2026-04-16

## Flows That Create PRs

### 1. Dependabot

| Property | Value |
|----------|-------|
| **Config** | `.github/dependabot.yml` |
| **Identity** | `@dependabot` (GitHub-managed) |
| **PR event** | `pull_request` (checks attach naturally) |
| **Auto-merge** | Not configured |
| **Branch protection** | Recognized by GitHub |
| **Status** | HEALTHY |

**Schedule**: GitHub Actions (Mon), Python (Tue), NPM (Wed), Terraform (monthly)

### 2. Dev Promotion Dispatch (build-tutor-images.yml → bbi-infrastructure)

| Property | Value |
|----------|-------|
| **Workflow** | `.github/workflows/build-tutor-images.yml` (job: `dispatch-dev-promotion`) |
| **Trigger** | `push` to `main` (after build + scan + release-bundle + SLSA succeed) |
| **Mechanism** | `workflow_dispatch` API call to `bbi-infrastructure/promote-dev-image.yml` |
| **Token** | GitHub App (`BBI_ARC_GITHUB_APP_ID` + `BBI_ARC_GITHUB_APP_PRIVATE_KEY`) |
| **PR author** | Depends on infra-side workflow — App token creates PR |
| **Status** | VERIFY — need to confirm PR author is App, not github-actions[bot] |

**Risk**: If the infra-side workflow uses `GITHUB_TOKEN` instead of the App token for PR creation, the PR will be authored by `github-actions[bot]` and required checks may not attach. This was the exact failure class in the current sprint.

### 3. Manual GitOps Bridge (build-tutor-images.yml)

| Property | Value |
|----------|-------|
| **Workflow** | `.github/workflows/build-tutor-images.yml` (job: `update-gitops`) |
| **Trigger** | `workflow_dispatch` with `update_gitops=true` |
| **Mechanism** | Direct commit + push to `bbi-infrastructure` via `release-openedx-gitops.sh` |
| **Token** | GitHub App (`FASTLANE_GITHUB_APP_ID`) |
| **Git identity** | `github-actions[bot]` (hardcoded in `release-openedx-gitops.sh`) |
| **PR created?** | NO — direct push to branch, not PR |
| **Status** | ACCEPTABLE (manual, operator-initiated, no PR checks needed) |

### 4. Release Workflow (release.yml)

| Property | Value |
|----------|-------|
| **Workflow** | `.github/workflows/release.yml` |
| **Trigger** | Tag push (`v[0-9]+.[0-9]+.[0-9]+`) |
| **Mechanism** | Direct commit + push to `bbi-infrastructure` |
| **Token** | GitHub App (`GITOPS_GITHUB_APP_ID`) |
| **Git identity** | `github-actions[bot]` |
| **PR created?** | NO — direct push |
| **Status** | ACCEPTABLE (release pipeline, environment-protected) |

## Flows That Do NOT Create PRs (Confirmed Safe)

| Workflow | Purpose | Creates PRs? |
|----------|---------|-------------|
| `ci.yml` | Static validation, tests | No |
| `daily-infrastructure-audit.yml` | Observability audit | No (read-only) |
| `codeql.yml` | Security scanning | No |
| `cross-browser-branding-smoke.yml` | Browser tests | No |
| `frontend-branding-closure.yml` | Branding checks | No |

## Action Items

### Immediate (verify in next graduation test)

1. **Confirm dev promotion PR author**: When the graduation test build completes and dispatches to bbi-infrastructure, check that the resulting PR is authored by the GitHub App identity — not `github-actions[bot]`. Run:
   ```bash
   gh pr list --repo Biji-Biji-Initiative/bbi-infrastructure --state open \
     --json number,author,title --jq '.[] | select(.title | test("mereka-lms"))'
   ```

### Next Sprint (Tranche A completion)

2. **Audit bbi-infrastructure promote-dev-image.yml**: Verify the infra-side workflow uses the App token (from the dispatch input) for PR creation, not `GITHUB_TOKEN`.

3. **Verify branch protection recognizes App**: In bbi-infrastructure branch protection settings, confirm the App is in the "allowed to bypass" or "required status checks" scope.

4. **Test auto-merge completion**: After confirming App authorship, verify auto-merge can complete without manual intervention.

## Token Inventory

| Secret Name | Type | Used By | Scope |
|-------------|------|---------|-------|
| `BBI_ARC_GITHUB_APP_ID` | GitHub App | dispatch-dev-promotion | bbi-infrastructure, platform-control-plane |
| `BBI_ARC_GITHUB_APP_PRIVATE_KEY` | GitHub App | dispatch-dev-promotion | Same |
| `FASTLANE_GITHUB_APP_ID` | GitHub App | update-gitops (manual) | bbi-infrastructure |
| `FASTLANE_GITHUB_APP_PRIVATE_KEY` | GitHub App | update-gitops (manual) | Same |
| `GITOPS_GITHUB_APP_ID` | GitHub App | release.yml | bbi-infrastructure |
| `GITOPS_GITHUB_APP_PRIVATE_KEY` | GitHub App | release.yml | Same |
| `ORG_GHCR_TOKEN` | PAT | GHCR image push | ghcr.io |
| `GITHUB_TOKEN` | Automatic | CI jobs | Current repo |
