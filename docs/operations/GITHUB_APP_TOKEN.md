# GitHub App Token for GitOps Commits

<!-- Last verified: 2026-02-24 -->

This document covers why PAT-based GitOps is a security liability, how to
replace it with a scoped GitHub App token, and how to track migration progress.

The current `GITOPS_PAT` secret used in `.github/workflows/build-tutor-images.yml`
is a classic Personal Access Token tied to an individual account. This document
is the migration guide to retire it.

---

## Why PATs Are Problematic

| Problem | Impact |
|---------|--------|
| **Tied to an individual** | If the account is suspended, offboarded, or changes its password, all workflows break immediately. |
| **No auto-rotation** | PATs must be rotated manually. They silently accumulate age and risk. |
| **Broad scope** | Classic PATs grant `repo` scope across all repositories the user can access — far beyond what GitOps commits need. |
| **Audit trail** | Commits appear as the individual user, not as a bot — making automated vs human changes indistinguishable in the log. |
| **Revocation blast radius** | Revoking a stale PAT breaks every workflow that references it simultaneously. |

---

## Recommended Approach: GitHub App Token

A GitHub App is an org-level identity. It generates short-lived installation
tokens (1-hour TTL) scoped to specific repositories and permissions. No
individual account is involved.

### Security Comparison

| Property | Classic PAT | Fine-grained PAT | GitHub App |
|----------|-------------|------------------|------------|
| Tied to individual | Yes | Yes | No (org-level) |
| Auto-rotation | No | No | Yes (1-hour TTL) |
| Per-repo scope | No | Yes | Yes |
| Minimum permissions | No | Partial | Yes |
| Audit identity | User account | User account | `app[bot]` |
| Onboarding risk | High | Medium | None |
| Offboarding risk | High | Medium | None |
| Setup complexity | Low | Low | Medium |

---

## Step-by-Step: Create and Install the GitHub App

### 1. Create the App

1. Go to **GitHub Organization Settings → Developer Settings → GitHub Apps**.
2. Click **New GitHub App**.
3. Fill in:
   - **GitHub App name**: `mereka-lms-gitops` (or your org's naming convention)
   - **Homepage URL**: `https://github.com/Biji-Biji-Initiative/mereka-lms`
   - **Webhook**: uncheck **Active** (not needed for token generation)
4. Set **Repository permissions**:
   - `Contents`: **Read and write** (to push GitOps commits)
   - `Pull requests`: **Read and write** (optional; needed if the bot opens PRs)
   - All other permissions: **No access**
5. Under **Where can this GitHub App be installed?**: select **Only on this account**.
6. Click **Create GitHub App**.

### 2. Generate a Private Key

1. On the App settings page, scroll to **Private keys**.
2. Click **Generate a private key**.
3. Save the downloaded `.pem` file securely — you will store it as a repo secret.

### 3. Install the App on Required Repositories

1. Go to **GitHub App settings → Install App**.
2. Click **Install** on your organization.
3. Choose **Only select repositories** and add:
   - `Biji-Biji-Initiative/mereka-lms`
   - `Biji-Biji-Initiative/infrastructure` (the GitOps target repo)
4. Click **Install**.
5. Note the **App ID** from the App settings page (a numeric value, e.g. `123456`).

### 4. Store Secrets in the Repository

In `mereka-lms` repository settings (**Settings → Secrets and variables → Actions**):

| Secret name | Value |
|-------------|-------|
| `GH_APP_ID` | The App ID (numeric, e.g. `123456`) |
| `GH_APP_PRIVATE_KEY` | The full contents of the downloaded `.pem` file |

Do **not** store the private key in Infisical or GCP Secret Manager — it is a
GitHub-only credential and belongs in GitHub Actions secrets.

### 5. Use the Token in Workflows

Replace every occurrence of `secrets.GITOPS_PAT` with a two-step pattern:

```yaml
# Step 1 — generate a short-lived token
- name: Generate GitHub App token
  id: app-token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.GH_APP_ID }}
    private-key: ${{ secrets.GH_APP_PRIVATE_KEY }}
    repositories: infrastructure

# Step 2 — use the token wherever GITOPS_PAT was used
- name: Checkout infrastructure
  uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4
  with:
    repository: Biji-Biji-Initiative/infrastructure
    path: infrastructure
    token: ${{ steps.app-token.outputs.token }}
```

For inline git operations that previously used `GITOPS_PAT` as an env var:

```yaml
- name: Configure git remote with App token
  env:
    APP_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    git -C infrastructure remote set-url origin \
      "https://x-access-token:${APP_TOKEN}@github.com/Biji-Biji-Initiative/infrastructure.git"
```

Pin the action SHA before merging to main (find the current SHA at
`https://github.com/actions/create-github-app-token/releases`):

```yaml
uses: actions/create-github-app-token@3ff1caabb62bef8dc1c6046f68f0df98d3f98b52  # v1
```

---

## Alternative: Fine-grained PAT with 90-day Rotation

If creating a GitHub App is not feasible, use a fine-grained PAT as a
lower-risk interim measure.

### Setup

1. Log in as the **machine account** (a dedicated GitHub user, not a personal
   account — create `mereka-lms-bot` if one does not exist).
2. Go to **Settings → Developer Settings → Personal access tokens → Fine-grained tokens**.
3. Click **Generate new token**.
4. Configure:
   - **Token name**: `mereka-lms-gitops-<YYYY-MM>`
   - **Expiration**: 90 days (maximum for fine-grained PATs)
   - **Resource owner**: `Biji-Biji-Initiative`
   - **Repository access**: Only `infrastructure`
   - **Permissions → Repository**:
     - `Contents`: Read and write
     - All others: No access
5. Store the token as `GITOPS_PAT` in repository secrets (replacing the current value).

### Rotation Schedule

Rotate every **90 days**. Add a calendar reminder:

| Rotation date | Token suffix | Action |
|---------------|--------------|--------|
| Day 0 | `-YYYY-MM` | Create and store new token |
| Day 80 | — | Reminder: rotate within 10 days |
| Day 90 | — | Old token expires; new one must be in place |

Record each rotation in `docs/ops/security/SECRET_ROTATION_CHECKLIST.md`.

---

## Migration Plan

Identify all PAT references, migrate one workflow at a time, and verify before
removing the old secret.

### Step 1: Audit Current PAT Usage

```bash
./scripts/qa/verify-github-app-token.sh
```

This script scans all `.github/workflows/*.yml` files and reports PAT
references, App token references, and migration percentage.

### Step 2: Migrate Workflows One at a Time

Priority order based on blast radius:

| Workflow | File | PAT Usage | Priority |
|----------|------|-----------|----------|
| Build Tutor images + GitOps | `build-tutor-images.yml` | `GITOPS_PAT` (checkout + push) | High |

For each workflow:
1. Add the `Generate GitHub App token` step (Step 1 above).
2. Replace `secrets.GITOPS_PAT` references with `steps.app-token.outputs.token`.
3. Remove the `Validate GitOps token` step that checks `GITOPS_PAT`.
4. Open a PR, run the workflow in `workflow_dispatch` mode, verify the GitOps
   commit lands in `infrastructure`.
5. Merge.

### Step 3: Verify Migration

Re-run the verification script. When PAT references reach zero:

```
RESULT: PASS — migration complete, no PAT references remain
```

### Step 4: Remove the Old Secret

After all workflows are migrated and have run successfully at least once:

1. Go to **Settings → Secrets and variables → Actions**.
2. Delete `GITOPS_PAT`.
3. Revoke the PAT on the user account (GitHub → Settings → Developer settings → PATs).

---

## Verification

```bash
./scripts/qa/verify-github-app-token.sh
```

The script exits `0` if all references use the App token pattern, `1` if PAT
references remain. During migration it exits `0` with WARNs (via
`continue-on-error: true` in CI).

---

## Related Documents

- `docs/ops/ci-cd/BRANCH_PROTECTION.md` — Branch protection policy
- `docs/ops/security/ALLOWED_ACTIONS_POLICY.md` — SHA-pinning policy for Actions
- `docs/ops/security/SECRET_ROTATION_CHECKLIST.md` — Secret rotation log
- `scripts/qa/verify-github-app-token.sh` — Verification script
- `.github/workflows/ci.yml` — GitHub App token checks in CI
- `.github/workflows/build-tutor-images.yml` — Primary migration target
