# CI Tokens for Developers

> For Hira, Eugene, and anyone working on CI/CD across BBI org repos.
> Last updated: 2026-04-16 (v4 — corrected three-plane auth model, Infisical paths, retirement table)

## TL;DR — What Token Do I Use?

| I want to... | Use this | How to get it |
|---|---|---|
| **Push a Docker image to GHCR** | `GITHUB_TOKEN` (automatic) | Just declare `permissions: packages: write` in your workflow. Zero config. |
| **Pull images from GHCR in K8s** | ESO syncs `GHCR_DOCKER_CONFIG_JSON` → K8s imagePullSecret | Already wired via ClusterExternalSecret. Source in Infisical: `/k8s/shared/GHCR_DOCKER_CONFIG_JSON` (all envs). No action required. |
| **Create a PR or commit in another repo** (e.g., bbi-infrastructure) | GitHub App (`GITOPS_GITHUB_APP_*`) | GitHub org secrets, visibility "all" repos. No Infisical path — consume directly via `${{ secrets.GITOPS_* }}`. |
| **Read PR status across repos** (mergeStateStatus, checks) | GitHub App (`GITOPS_GITHUB_APP_*`) | Same as above. Mint a token with `actions/create-github-app-token`. |
| **Dispatch a workflow in another repo** | GitHub App (`GITOPS_GITHUB_APP_*`) | Same as above. |

## The Three Auth Planes

There are exactly three auth planes in BBI. Do not mix them.

### Plane 1 — GHCR Push from Actions

**Credential**: `GITHUB_TOKEN` (ephemeral, auto-minted per workflow run)
**Scope**: Same repo only. Token expires when the run ends.
**Why**: GitHub explicitly supports `GITHUB_TOKEN` for packages associated with the workflow repo. No PAT rotation, no expiry drama.

```yaml
permissions:
  contents: read
  packages: write  # This is all you need

steps:
  - name: Login to GHCR
    uses: docker/login-action@v3
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}
```

**Never use** `ORG_GHCR_TOKEN` here. Using a PAT for push was a mistake — it's been retired from all push workflows.

### Plane 2 — Cross-Repo Automation

**Credential**: `GITOPS_GITHUB_APP_*` (GitHub App installation token, minted per API call)
**Scope**: Cross-repo commits, PRs, workflow dispatch. Short-lived.
**Why**: GitHub App tokens are repo-scoped, short-lived, and auditable. PATs are user-scoped and long-lived — wrong shape for cross-repo CI automation.

```yaml
steps:
  - name: Generate GitHub App token
    id: app-token
    uses: actions/create-github-app-token@v2
    with:
      app-id: ${{ secrets.GITOPS_GITHUB_APP_ID }}
      private-key: ${{ secrets.GITOPS_GITHUB_APP_PRIVATE_KEY }}
      owner: Biji-Biji-Initiative
      repositories: bbi-infrastructure  # comma-separated list of repos you need

  - name: Do cross-repo thing
    env:
      GH_TOKEN: ${{ steps.app-token.outputs.token }}
    run: |
      gh pr list --repo Biji-Biji-Initiative/bbi-infrastructure
```

**When to use:**
- Creating PRs in bbi-infrastructure (promotion, GitOps updates)
- Dispatching workflows to other repos (`workflow_dispatch` API)
- Reading PR merge status (`mergeStateStatus`)
- Any GitHub API call that needs cross-repo access

### Plane 3 — Cluster Pull-Secret Sync

**Credential**: `GHCR_PULL_CLASSIC_PAT` — classic PAT, permanently required for this plane.
(Renamed from `ORG_GHCR_TOKEN` on 2026-04-17 in bbi-infrastructure. Both names may exist at
the org level during the transition window; the new name documents the PULL scope + CLASSIC
credential type. If you see `ORG_GHCR_TOKEN` referenced in older code or docs, it refers to
the same token type and usage.)

**Scope**: Produces a long-lived dockerconfigjson stored in Infisical, synced to K8s via ESO.
**Why this must be a classic PAT (not GITHUB_TOKEN, not a GitHub App token)**:
- Fine-grained PATs **cannot** access org-level packages scope (GitHub limitation, still true as of 2026)
- GitHub App installation tokens expire after **1 hour** — the K8s dockerconfigjson must survive until the next sync run (schedule: every 6h). Pods scheduled between runs would fail with 401s if the token expired.
- Classic PAT with `read:packages` scope is the only viable option.

The classic PAT is **retired for GHCR push** (those use `GITHUB_TOKEN` per ADR-004) but is **permanently active for pull-secret sync**. This is intentional, not a gap.

You do not need to interact with this plane directly. The sync runs automatically via `sync-ghcr-shared-pull-secrets.yml`.

## Where to Find Secrets

### GitHub Org Secrets (primary for CI)

| Secret | Visibility | Purpose |
|--------|-----------|---------|
| `GITOPS_GITHUB_APP_ID` | All repos | GitHub App client ID (Plane 2) |
| `GITOPS_GITHUB_APP_INSTALLATION_ID` | All repos | App installation ID (Plane 2) |
| `GITOPS_GITHUB_APP_PRIVATE_KEY` | All repos | App private key (Plane 2) |
| `GHCR_PULL_CLASSIC_PAT` (legacy: `ORG_GHCR_TOKEN`) | bbi-infrastructure only | Classic PAT for cluster pull-secret sync (Plane 3). Renamed 2026-04-17 — `ORG_GHCR_TOKEN` kept as alias during transition. Do not use in other workflows. |

**Rule**: For CI workflows, consume GitHub org secrets directly. Do not try to fetch them from Infisical — the CI credentials are not synced there.

### Infisical (https://secrets.mereka.io)

Infisical is for **runtime secrets** (DB passwords, API keys, third-party credentials, and the generated GHCR dockerconfigjson).

| Path | Environment | What's There |
|------|------------|--------------|
| `/k8s/shared/GHCR_DOCKER_CONFIG_JSON` | dev, staging, prod | Base64 dockerconfigjson, synced to K8s imagePullSecrets |
| `/k8s/shared/GHCR_PULL_USERNAME` | dev, staging, prod | Fixed machine identity username that owns `GHCR_PULL_CLASSIC_PAT` (legacy name: `ORG_GHCR_TOKEN`) |
| `/k8s/shared/GITOPS_GITHUB_APP_*` | dev, staging, prod | GitHub App creds for ARC runners and CI dispatch |
| `/k8s/{app}/` | dev, staging, prod | Per-app runtime secrets (DB, Redis, JWT, etc.) |

**Deleted paths** (do not reference in new work — these no longer exist):
- `/shared/github/` — orphan path accidentally created 2026-04-16, deleted same day
- `/k8s/arc-runners/` — legacy ARC runner path, migrated to `/k8s/shared/GITOPS_GITHUB_APP_*` in Phase 2, deleted Phase 4

## Common Mistakes

### 1. Using `ORG_GHCR_TOKEN` for GHCR push
**Wrong**: `password: ${{ secrets.ORG_GHCR_TOKEN }}`
**Right**: `password: ${{ secrets.GITHUB_TOKEN }}`

`GITHUB_TOKEN` is automatic, never expires, is scoped to your repo. `ORG_GHCR_TOKEN` is retired for push workflows.

### 2. Using `GITHUB_TOKEN` for cross-repo operations
**Wrong**: `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` then calling another repo's API
**Right**: Mint a GitHub App token (see Plane 2 above)

`GITHUB_TOKEN` cannot see other repos. You get silent failures (empty results, 404s) instead of explicit permission errors.

### 3. Using `BBI_ARC_GITHUB_APP_*`
These were repo-level secrets used by the old `build-tutor-images.yml` dispatch logic. They have been superseded by `GITOPS_GITHUB_APP_*` which is org-wide. Use `GITOPS_*` in new code.

### 4. Using `FASTLANE_GITHUB_APP_*`
These org secrets were **deleted** on 2026-04-16. Any workflow still referencing them will silently receive empty strings and fail at runtime. If you see `FASTLANE_GITHUB_APP_*` in a workflow, replace it with `GITOPS_GITHUB_APP_*`.

### 5. Using `GITOPS_TOKEN_BBI_KUBERNATE`
Legacy org PAT being retired. If you see it, replace with the GitHub App pattern (Plane 2).

### 6. Referencing Infisical path `/shared/github/` or `/k8s/arc-runners/`
Both paths were **deleted** on 2026-04-16. If you see these in ESO or workflow references, remove them. The correct paths are `/k8s/shared/GITOPS_GITHUB_APP_*` and `/k8s/shared/GHCR_DOCKER_CONFIG_JSON`.

## Quick Reference: Workflow Patterns

### Pattern A: Build and Push Image (single repo)
```yaml
permissions:
  contents: read
  packages: write

steps:
  - uses: docker/login-action@v3
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}
  - uses: docker/build-push-action@v6
    with:
      push: true
      tags: ghcr.io/biji-biji-initiative/${{ github.event.repository.name }}:${{ github.sha }}
```

### Pattern B: Build, Push, and Update GitOps (cross-repo)
```yaml
jobs:
  build:
    # ... same as Pattern A ...

  update-dev-tag:
    needs: build
    steps:
      - name: Mint App token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.GITOPS_GITHUB_APP_ID }}
          private-key: ${{ secrets.GITOPS_GITHUB_APP_PRIVATE_KEY }}
          owner: Biji-Biji-Initiative
          repositories: bbi-infrastructure

      - name: Update dev tag
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # Create PR or push to bbi-infrastructure
```

### Pattern C: Reusable Workflows (recommended for new apps)
```yaml
jobs:
  build:
    uses: Biji-Biji-Initiative/bbi-infrastructure/.github/workflows/reusable-build-push.yml@main
    with:
      app_name: "my-app"
    secrets: inherit

  update-dev:
    needs: build
    uses: Biji-Biji-Initiative/bbi-infrastructure/.github/workflows/reusable-update-dev-tag.yml@main
    with:
      app_name: "my-app"
      image_tag: ${{ needs.build.outputs.image_tag }}
      image_digest: ${{ needs.build.outputs.image_digest }}
    secrets:
      GITHUB_APP_ID: ${{ secrets.GITOPS_GITHUB_APP_ID }}
      GITHUB_APP_INSTALLATION_ID: ${{ secrets.GITOPS_GITHUB_APP_INSTALLATION_ID }}
      GITHUB_APP_PRIVATE_KEY: ${{ secrets.GITOPS_GITHUB_APP_PRIVATE_KEY }}
```

## If You Hit "failed to fetch oauth token: denied" on GHCR Push

**Cause**: Your workflow is still using PAT-based login with a retired token.

**Fix (do NOT regenerate the PAT)**:

1. Find the offending login step (grep for `ORG_GHCR_TOKEN` in your workflow)
2. Replace:
   ```yaml
   password: ${{ secrets.ORG_GHCR_TOKEN }}
   ```
   with:
   ```yaml
   password: ${{ secrets.GITHUB_TOKEN }}
   ```
3. Ensure the workflow (or job) has `permissions: packages: write`
4. Re-run — it will succeed with no further config

**Do not** regenerate `ORG_GHCR_TOKEN`. **Do not** add `write:packages` to any PAT. Both are dead ends — the PAT is retired for push workflows. The fix is on your calling workflow, not on the token.

## Credential Status Table

| Token | Plane | Status | Notes |
|---|---|---|---|
| `GITHUB_TOKEN` | 1 (GHCR push) | **Active** (use this) | Auto-minted, no config |
| `GITOPS_GITHUB_APP_*` | 2 (cross-repo) | **Active** (use this) | Org secrets, all repos |
| `GHCR_PULL_CLASSIC_PAT` | 3 (pull-secret sync) | **Active — Plane 3 only** | Classic PAT, permanently required for cluster pull secrets. Renamed from `ORG_GHCR_TOKEN` on 2026-04-17. |
| `ORG_GHCR_TOKEN` | 3 (pull-secret sync) | **Alias — transitional** | Still present at org level as alias; will be removed once all workflows reference `GHCR_PULL_CLASSIC_PAT` directly. |
| `ORG_GHCR_TOKEN` | 1 (GHCR push) | **RETIRED** 2026-04-16 | Replaced by `GITHUB_TOKEN` in all push workflows |
| `BBI_ARC_GITHUB_APP_*` | — | **RETIRED** | Consolidated into `GITOPS_GITHUB_APP_*` |
| `FASTLANE_GITHUB_APP_*` | — | **DELETED** 2026-04-16 | Same App as `GITOPS_*`, dead org secrets removed |
| `FASTLANE_RUNNER_STATUS_TOKEN` | — | **DELETED** 2026-04-16 | No live workflow references, removed in cleanup |
| `GCP_SA_KEY_BBI_KUBERNATE` | — | **DELETED** 2026-04-16 | Last touched 2025-12-18, no consumers |
| `GITOPS_TOKEN_BBI_KUBERNATE` | — | Retiring | Replace with GitHub App pattern |
| `GITOPS_PAT` | — | Retired | Replaced by GitHub App |
| `BBI_INFRA_TOKEN` | — | Investigate | Likely GitHub App candidate |

## Questions?

- **ADR-004** in bbi-infrastructure: full architectural decision on GHCR push auth
- **`docs/meta/auth/AUTH_SURFACE_CONTRACT.yaml`** in bbi-infrastructure: machine-readable authority for all auth surfaces
- **`scripts/qa/verify-auth-surface-contract.py`** in bbi-infrastructure: CI verifier (runs in `policy-guards`)
- Infra team: ask in `#platform` Slack channel
