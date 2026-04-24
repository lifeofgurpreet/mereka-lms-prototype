# Workload Identity Federation (WIF) Migration Guide
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

## Why WIF Instead of JSON SA Keys

| JSON SA Key | Workload Identity Federation |
|-------------|------------------------------|
| Long-lived credential (never expires unless rotated) | Short-lived OIDC token (valid ~1 hour) |
| Key can be leaked and reused indefinitely | Token bound to specific GitHub repo/branch/actor |
| Manual rotation required | Auto-rotates on every CI run |
| Revocation requires deleting/regenerating key | Revocation by removing IAM binding |
| Secret stored in GitHub Secrets vault | No secret stored — Google verifies GitHub OIDC token directly |
| Audit log shows SA, not the workflow | Audit log includes subject claim (repo + ref + actor) |

**Security model**: GitHub OIDC token contains claims like `repository`, `ref`, `actor`. GCP WIF verifies the token signature against GitHub's JWKS endpoint, then grants SA impersonation only if the claims match the configured attribute condition. Nothing is stored in GitHub Secrets after migration.

## Architecture

```
GitHub Actions Runner
        |
        | (1) Request OIDC token from GitHub
        v
GitHub OIDC Provider (https://token.actions.githubusercontent.com)
        |
        | (2) Returns signed JWT with claims:
        |     sub = repo:Biji-Biji-Initiative/mereka-lms:ref:refs/heads/main
        |     repository = Biji-Biji-Initiative/mereka-lms
        |     iss = https://token.actions.githubusercontent.com
        v
GCP Workload Identity Pool (mereka-lms-github-pool)
        |
        | (3) WIF verifies JWT signature via GitHub JWKS
        | (4) Checks attribute condition (repository claim matches)
        v
GCP Workload Identity Provider (github-oidc-provider)
        |
        | (5) Maps external identity to GCP principal
        v
Service Account Impersonation (ci-deployer@bbi-k8.iam.gserviceaccount.com)
        |
        | (6) Issues short-lived access token (~1 hour)
        v
GCP APIs (Artifact Registry, GKE, Secret Manager, Cloud SQL)
```

## Prerequisites

- GCP project: `bbi-k8` (where the CI SA lives and secrets are stored)
- GitHub org: `Biji-Biji-Initiative`
- GitHub repo: `Biji-Biji-Initiative/mereka-lms`
- Existing SA for CI: the SA that currently receives the JSON key (`GCP_SA_KEY`)
- `gcloud` CLI with `roles/iam.workloadIdentityPoolAdmin` and `roles/iam.serviceAccountAdmin`

Identify the current CI service account:

```bash
# Decode current GCP_SA_KEY to find the SA email
echo "$GCP_SA_KEY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['client_email'])"
```

## Step-by-Step GCP Setup

All commands run against the `bbi-k8` project.

### 1. Enable Required APIs

```bash
gcloud services enable iamcredentials.googleapis.com \
  --project=bbi-k8

gcloud services enable sts.googleapis.com \
  --project=bbi-k8
```

### 2. Create Workload Identity Pool

```bash
gcloud iam workload-identity-pools create mereka-lms-github-pool \
  --project=bbi-k8 \
  --location=global \
  --display-name="Mereka LMS GitHub Actions Pool" \
  --description="WIF pool for mereka-lms GitHub Actions CI/CD"
```

Retrieve the pool resource name:

```bash
gcloud iam workload-identity-pools describe mereka-lms-github-pool \
  --project=bbi-k8 \
  --location=global \
  --format="value(name)"
# Output: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/mereka-lms-github-pool
```

### 3. Create OIDC Provider

```bash
gcloud iam workload-identity-pools providers create-oidc github-oidc-provider \
  --project=bbi-k8 \
  --location=global \
  --workload-identity-pool=mereka-lms-github-pool \
  --display-name="GitHub OIDC Provider" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository == 'Biji-Biji-Initiative/mereka-lms'"
```

The `attribute-condition` restricts impersonation to only tokens from this specific repository. Tokens from forks or other repos are rejected.

Retrieve the provider resource name:

```bash
PROVIDER_NAME=$(gcloud iam workload-identity-pools providers describe github-oidc-provider \
  --project=bbi-k8 \
  --location=global \
  --workload-identity-pool=mereka-lms-github-pool \
  --format="value(name)")
echo "$PROVIDER_NAME"
# projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/mereka-lms-github-pool/providers/github-oidc-provider
```

### 4. Bind Service Account

Replace `CI_SA_EMAIL` with the actual CI service account email found in step 0.

```bash
CI_SA_EMAIL="ci-deployer@bbi-k8.iam.gserviceaccount.com"  # adjust if different

# Allow the WIF pool to impersonate this SA
gcloud iam service-accounts add-iam-policy-binding "${CI_SA_EMAIL}" \
  --project=bbi-k8 \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/${PROVIDER_NAME%/providers/*}/attribute.repository/Biji-Biji-Initiative/mereka-lms"
```

The `principalSet` member grants impersonation to any token from the repository, regardless of branch. To restrict to `main` only:

```bash
# Restrict to main branch only (stronger, recommended for production deployments)
gcloud iam service-accounts add-iam-policy-binding "${CI_SA_EMAIL}" \
  --project=bbi-k8 \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/${PROVIDER_NAME%/providers/*}/attribute.ref/refs/heads/main"
```

### 5. Collect Values for GitHub Secrets/Variables

```bash
PROJECT_NUMBER=$(gcloud projects describe bbi-k8 --format="value(projectNumber)")

WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/mereka-lms-github-pool/providers/github-oidc-provider"
WIF_SA="${CI_SA_EMAIL}"

echo "WIF_PROVIDER: ${WIF_PROVIDER}"
echo "WIF_SA: ${WIF_SA}"
```

Store these in GitHub repository variables (not secrets — they are not sensitive):
- `GCP_WIF_PROVIDER` = the `WIF_PROVIDER` value above
- `GCP_WIF_SA` = the `WIF_SA` value above

## GitHub Actions Workflow Changes

### Before (JSON SA key)

```yaml
permissions: {}

jobs:
  deploy:
    permissions:
      contents: read
    steps:
      - uses: google-github-actions/auth@c200f3691d83b41bf9bbd8638997a462592937ed  # v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
```

### After (Workload Identity Federation)

```yaml
permissions: {}

jobs:
  deploy:
    permissions:
      contents: read
      id-token: write   # REQUIRED: allows requesting GitHub OIDC token
    steps:
      - uses: google-github-actions/auth@c200f3691d83b41bf9bbd8638997a462592937ed  # v2
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ vars.GCP_WIF_SA }}
```

Key differences:
1. Add `id-token: write` to job permissions (GitHub needs this to issue OIDC tokens)
2. Replace `credentials_json: ${{ secrets.GCP_SA_KEY }}` with `workload_identity_provider` + `service_account`
3. `GCP_WIF_PROVIDER` and `GCP_WIF_SA` are variables (not secrets) — they contain no sensitive data

### Composite Action Pattern (Current Repo Standard)

This repo uses `./.github/actions/gcp-gke-auth` as the canonical auth entrypoint.
It now supports WIF-first with key fallback:

```yaml
- name: Authenticate to GCP
  uses: ./.github/actions/gcp-gke-auth
  with:
    workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
    wif_service_account: ${{ vars.GCP_WIF_SA }}
    gcp_sa_key: ${{ secrets.GCP_SA_KEY }} # optional fallback during migration window
    auth_mode: auto                        # prefer WIF when vars are present
    skip_gke: 'true'
```

For long-running jobs, authenticate as late as possible (immediately before `docker push`, `gcloud` publish, or `kubectl` apply) to avoid short-lived token expiry during long build phases.

## Migration Status

Workflows using the `./.github/actions/gcp-gke-auth` composite action with `auth_mode: auto` and the skip-on-missing-creds condition:

```yaml
if: ${{ (vars.GCP_WIF_PROVIDER != '' && vars.GCP_WIF_SA != '') || vars.HAS_GCP_SA_KEY == 'true' }}
```

| Workflow | GCP Auth Job(s) | `id-token: write` | Skip Condition | Status |
|----------|-----------------|-------------------|----------------|--------|
| `operations-gates-runtime.yml` | `runtime-gates` | yes | yes | migrated |
| `mfe-slot-runtime-gates.yml` | `mfe-slot-gates` | yes | yes | migrated |
| `argocd-drift-check.yml` | `online-drift-check` | yes | yes | migrated (#154) |
| `cloud-sql-backup.yml` | `backup` | yes | yes | migrated (#154) |
| `daily-infrastructure-audit.yml` | `observability-audits`, `parity-check` | yes | yes | migrated (#154) |
| `dr-evidence-bundle.yml` | `dr-evidence` | yes | yes | migrated (#154) |
| `build-tutor-images.yml` | `build-and-push` | yes | — (uses late-auth) | migrated |
| `release-evidence.yml` | `release-evidence` | yes | — | migrated |

Run `scripts/qa/verify-wif-readiness.sh` to get the current count.

### Required GitHub Repository Variables

Set these in **Settings → Secrets and Variables → Variables** (not Secrets):

| Variable | Example Value | Notes |
|----------|---------------|-------|
| `GCP_WIF_PROVIDER` | `projects/123456789/locations/global/workloadIdentityPools/mereka-lms-github-pool/providers/github-oidc-provider` | Full resource name from GCP |
| `GCP_WIF_SA` | `ci-deployer@bbi-k8.iam.gserviceaccount.com` | SA to impersonate |
| `HAS_GCP_SA_KEY` | `true` | Set to `'true'` while `GCP_SA_KEY` secret is present; delete after Phase 3 |

## Migration Plan

### Phase 1: Parallel Run (Week 1)

1. Complete GCP setup (pool, provider, SA binding)
2. Add `GCP_WIF_PROVIDER` and `GCP_WIF_SA` to GitHub repository variables
3. Update **one low-risk workflow** (e.g., `daily-infrastructure-audit.yml`) to use WIF
4. Keep `GCP_SA_KEY` secret in GitHub Secrets
5. Verify the updated workflow authenticates successfully
6. Run `scripts/qa/verify-wif-readiness.sh` to track progress

### Phase 2: Rolling Migration (Week 2)

Migrate remaining workflows one at a time:

```bash
# For each workflow, replace credentials_json with WIF:
# 1. Add id-token: write to job permissions
# 2. Replace with: credentials_json → with: workload_identity_provider + service_account
# 3. Commit, push, verify CI passes
```

### Phase 3: Remove SA Key (Week 3)

After all workflows are migrated and verified:

1. Remove `GCP_SA_KEY` from GitHub Secrets
2. Run `scripts/qa/verify-wif-readiness.sh` — all workflows should show WIF, zero SA key references
3. Tag the commit: `git tag wif-migration-complete`
4. Optionally disable the JSON key in GCP (keep the SA itself)

## Rollback Plan

If WIF fails in production and you need to revert quickly:

1. `GCP_SA_KEY` remains in GitHub Secrets for 30 days post-migration (do not delete immediately)
2. Revert the `with:` block back to `credentials_json: ${{ secrets.GCP_SA_KEY }}`
3. Remove `id-token: write` from job permissions
4. Push the revert commit

After rollback, investigate the WIF failure:

```bash
# Check GCP audit logs for WIF token exchange failures
gcloud logging read \
  'protoPayload.serviceName="sts.googleapis.com" severity>=WARNING' \
  --project=bbi-k8 \
  --limit=20
```

Common failure causes:
- `attribute-condition` mismatch (wrong repository name in condition)
- `id-token: write` permission missing from job
- WIF provider issuer URI mismatch

## Verification

After migration, verify WIF is working:

```bash
# From a CI run, check the token exchange worked
# google-github-actions/auth prints the SA email it impersonated on success

# Locally verify the WIF pool configuration
gcloud iam workload-identity-pools describe mereka-lms-github-pool \
  --project=bbi-k8 \
  --location=global

gcloud iam workload-identity-pools providers describe github-oidc-provider \
  --project=bbi-k8 \
  --location=global \
  --workload-identity-pool=mereka-lms-github-pool

# Check SA IAM binding
gcloud iam service-accounts get-iam-policy "${CI_SA_EMAIL}" \
  --project=bbi-k8
```

Run the readiness script to track migration progress at any time:

```bash
./scripts/qa/verify-wif-readiness.sh
```

## Related Documentation

- `docs/reference/operations/CI_CD_SETUP.md` — CI/CD pipeline overview
- `docs/reference/operations/SECRETS_SNAPSHOT.md` — current secrets inventory
- `scripts/qa/verify-wif-readiness.sh` — readiness verification script
- [google-github-actions/auth documentation](https://github.com/google-github-actions/auth)
- [GCP WIF official docs](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)
