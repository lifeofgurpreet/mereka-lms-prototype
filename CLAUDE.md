# CLAUDE.md

> Summary surface only. Do not use this file as the canonical starting point for release,
> governance, or architecture truth.
>
> Read first instead:
> - `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`
> - `docs/meta/standing-orders/README.md`
> - `scripts/governance/canonical-entrypoints.yaml`
> - `docs/reference/operations/RELEASE_PROCESS.md`

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Mereka Academy Open edX** deployment repository. It tracks infrastructure-as-code, configuration, and automation for running Open edX (an open-source learning management system) on Google Cloud Platform. The stack is managed via **Tutor** (an Open edX deployment tool) and includes custom theming, data migrations from Kajabi and MCT, and analytics integration.

**Critical**: Docker Desktop requires **≥12 GB RAM and 2–4 GB swap** before building images. The Ulmo asset pipeline uses 6–8 GB during webpack builds.

**Production URLs**:
- LMS: `https://academyv2.mereka.io`
- Studio: `https://studio.academyv2.mereka.io`
- MFE: `https://apps.academyv2.mereka.io`
- Alternative domain: `https://academy.biji-biji.com`

## Architecture

### Technology Stack
- **Open edX Platform**: LMS (learner-facing) + Studio (CMS for course authoring)
- **Deployment Tool**: Tutor 21.0.0 (Ulmo) - wraps Open edX in Docker/K8s
- **Databases**:
  - MySQL 8 (course data, user data)
  - MongoDB Atlas for deployed environments; local bootstrap uses the repo-scoped Tutor MongoDB service
  - Redis (caching, Celery)
- **Infrastructure**:
  - Local: Docker Compose
  - Dev/Staging/Production: RKE2 on Contabo VPS (rke2-nonprod cluster)
  - GKE: **DECOMMISSIONED** — all workloads migrated to RKE2. GKE namespace frozen at 0 replicas.
- **Frontend**: Micro-frontends (MFEs) built on React, served via Caddy reverse proxy
- **Services**:
  - Discovery (course catalog)
  - Forum (Python openedx-forum v0.3.8, integrated into LMS)
  - Notes
  - Ecommerce (legacy Oscar — deprecated, being replaced by Purchase Gateway)
  - Purchase Gateway (custom FastAPI + PostgreSQL + Stripe — canonical ecommerce replacement)
  - XQueue
  - Meilisearch (forum search)

### Repository Structure

> **Deployment boundary (ADR-025)**: Not everything in `deploy/k8s/` is meant to stay here.
> `base/arc/`, `base/logging/`, `base/policies/`, `overlays/production/`, `overlays/rke2-nonprod/`,
> and `overlays/staging/` are classified for migration to `bbi-infrastructure`. Only `base/` app
> resources and `overlays/local/` permanently belong in this repo. See
> `docs/reference/architecture/DEPLOYMENT_CONTRACT.md` for the authoritative classification.

```
deploy/k8s/               # Kubernetes manifests
  ├── base/               # Base Kustomize resources
  │   ├── secrets/        # ExternalSecrets (synced from Infisical/GCP SM)
  │   ├── apps/           # App-specific configs (lms, cms, enterprise, multi-tenancy, etc.)
  │   ├── arc/            # ARC runners — PLATFORM_SHARED, will move to bbi-infrastructure
  │   ├── logging/        # Promtail DaemonSet — PLATFORM_SHARED, will move to bbi-infrastructure
  │   ├── monitoring/     # ServiceMonitors + PrometheusRules (app-owned)
  │   ├── policies/       # Kyverno ClusterPolicies — PLATFORM_SHARED, will move to bbi-infrastructure
  │   └── plugins/        # Plugin configs (discovery, mfe, credentials, aspects, etc.)
  └── overlays/           # Environment-specific overlays
      ├── local/          # Local Kind/Minikube (stays in app repo)
      ├── rke2-nonprod/   # Dev RKE2 cluster (active dev target — will move to bbi-infrastructure)
      ├── staging/        # Staging overlay — shares rke2-nonprod cluster, consolidation pending
      └── production/     # Production overlay — GKE DECOMMISSIONED, production is on RKE2

.github/
  ├── actions/            # Composite actions (DRY building blocks)
  │   ├── gcp-gke-auth/   # GCP auth + GKE credentials (used by 9 workflows)
  │   ├── setup-python-env/ # Python + pip cache + base QA deps
  │   └── setup-playwright/ # Node + Playwright + browser cache
  ├── workflows/          # GitHub Actions workflows
  ├── run-scripts-parallel.sh  # xargs -P parallel script runner
  ├── ci-scripts-static.txt    # Generated static-validation inventory (derivative)
  └── ci-scripts-runtime.txt   # Generated runtime-validation inventory (derivative)

infrastructure/           # Infrastructure-as-code
  ├── tutor/              # Tutor configs, patches, themes
  ├── cloudflare/         # DNS records
  ├── terraform/          # Terraform configs
  └── monitoring/         # Monitoring configs

scripts/                  # Automation organized by domain
  ├── shared/             # Common utilities (config.sh, setup-local.sh)
  ├── infra/              # GCP (legacy), MongoDB Atlas, backups
  ├── migrations/         # Kajabi/MCT data migration
  ├── branding/           # Theme sync scripts
  ├── analytics/          # Analytics exports
  └── qa/                 # Smoke tests + 200+ verification scripts

specs/                    # Specifications (machine-checkable intent)
  ├── secrets-management.md
  ├── repository-structure.md
  └── k8s-deployment.md

docs/                     # Documentation by category
  ├── adr/                # Architecture Decision Records
  ├── concepts/           # Architecture and system references
  ├── guides/             # How-to guides (onboarding, admin, branding, etc.)
  ├── ops/                # Operational and runbook docs (authoritative)
  ├── operations/         # Legacy transitional docs (compatibility path)
  ├── migrations/         # Migration playbooks
  ├── architecture/       # Legacy transitional path to concepts/architecture
  └── archive/            # Historical session reports

services/                 # Microservices (HubSpot webhooks)
var/                      # Runtime artifacts (gitignored)
tutor_env/                # Generated Tutor state (gitignored)
```

**Deprecated directories** (contain only README.md):
- `tools/` → moved to `scripts/`
- `ops/` → moved to `infrastructure/` and `scripts/`

### Key Architectural Patterns

**Tutor Configuration Flow**:
1. Source config changes go through `./scripts/infra/tutor-config-save.sh`
2. The wrapper renders Tutor state, refreshes the plugin mirror, applies the governed patch manifest, and verifies the result
3. Local image builds use the Bake-backed helpers, not raw Tutor image commands
4. Restart only the relevant local services after the wrapper succeeds

**Local vs Cloud Configuration**:
- **Local**: Service names are Docker Compose service names (`mysql`, `mongodb`, `redis`)
- **Cloud**: Service names are K8s internal DNS or Cloud SQL proxy addresses
- **Common mistake**: Config accidentally contains cloud IPs in local setup → services fail to connect

**Image Build Pipeline**:
- `./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast` builds LMS/CMS/workers for local development
- `./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast` builds micro-frontends for local development
- CI promotion builds push immutable images to `ghcr.io/biji-biji-initiative/mereka-lms` through the release-object/GitOps path
- App-cache-cold proof uses `.github/workflows/build-benchmark.yml` with `benchmark_class=app-cache-cold`; it is not a pristine-daemon claim

**CI/CD Pipeline Architecture**:
- `ci.yml` is the main workflow — **4 consolidated jobs** (was 74 micro-jobs)
  - `static-validation`: generated CI static inventory via `run-release-verification-gates.sh`
  - `tutor-config-tests`: Tutor rendering + idempotency checks
  - `security-scans`: TruffleHog (HEAD only) + pip-audit
- `test-coverage`: Python tests with coverage
- Static inventory authority lives in `scripts/governance/script-registry.yaml` under `ci_static_inventory`
- Runtime inventory authority lives in `scripts/governance/script-registry.yaml` under `ci_runtime_inventory` for manual/runtime validation paths
- `.github/ci-scripts-static.txt` is a generated derivative
- `.github/ci-scripts-runtime.txt` is a generated derivative
- Only `ci_static_inventory` is executed by the offline static-validation CI runner
- `.github/run-scripts-parallel.sh` runs scripts via `xargs -P` with PASS/FAIL/TIMEOUT tracking
- 3 composite actions in `.github/actions/` eliminate boilerplate across workflows
- `daily-infrastructure-audit.yml` merges observability + alert routing + parity checks

**Actions Runner Controller (ARC)**:
- Manifests: `deploy/k8s/base/arc/` (namespaces, Helm values, RunnerScaleSets, PVCs)
- Two runner pools: `mereka-k8s-runners` (2CPU/4GB, lightweight) and `mereka-k8s-heavy-builders` (4CPU/12GB + DinD sidecar)
- Deployed separately from main overlay (`kubectl apply -k deploy/k8s/base/arc/`) because the overlay's namespace transformer would override ARC's `arc-systems`/`arc-runners` namespaces
- Authenticates via GitHub App (secret `arc-github-app-secret` in `arc-runners` namespace)
- Heavy runners have persistent PVC caches: `arc-docker-cache` (50Gi) and `arc-dep-cache` (10Gi)
- Full setup guide: `docs/ops/ci-cd/CI_CD_RUNNERS.md`
- Optimization tracker: `docs/status/active/CI_OPTIMIZATION_TRACKER.md`

**MongoDB Atlas (No Local MongoDB)**:
- **Cluster**: `cluster-mereka-lms.2pjex4s.mongodb.net`
- **Databases**: `openedx` (modulestore), `cs_comments_service` (forum)
- **Why Atlas**: Zero maintenance overhead, automatic backups, managed scaling
- **Local MongoDB disabled**: Deployments reference only Atlas connection
- **Password**: Stored in Infisical as `MEREKA_LMS_MONGODB_PASSWORD`, synced to K8s secrets
- See `docs/adr/001-mongodb-atlas.md` for full rationale

## Common Development Commands

### Initial Setup
```bash
# Bootstrap development environment
make bootstrap                    # Creates venv, installs pre-commit hooks

# Initialize submodules (required for frontend-app-authn)
git submodule update --init --recursive

# OR manual setup
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip uv
pip install -r requirements-tutor.txt

# Set Tutor environment (REQUIRED before any tutor command)
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
```

### Tutor Lifecycle
```bash
# First-time setup
tutor local launch -I             # Interactive setup, takes 1+ hour

# Daily usage
make tutor-start                  # Start all services in background
make tutor-stop                   # Stop all services
make tutor-restart                # Restart all services

# Modifying configuration (SAFE WORKFLOW)
./scripts/infra/tutor-config-save.sh --set KEY=value  # Saves config, applies patches, verifies
make tutor-restart                                   # Apply rendered config to the running stack

# Quick verification
./scripts/infra/verify-tutor-config.sh  # Check all patches are present
```

### Building Images
```bash
# Build Open edX platform locally (LMS/CMS/workers)
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# Build micro-frontends locally
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast

# Strict cache-disabled proof belongs in CI, not ad hoc local commands
gh workflow run build-benchmark.yml \
  -f benchmark_class=app-cache-cold \
  -f image_family=both
```

### Diagnostics (Local)
```bash
# Low-level runtime inspection (after setup)
tutor local dc ps

# View logs
tutor local logs --tail=100 lms
tutor local logs --tail=100 mfe
tutor local logs --tail=50       # All services

# Verify config uses local service names (NOT cloud IPs)
grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
# Should show: mysql, mongodb, redis (NOT 10.97.x.x IPs)

# Test services
curl -I http://localhost                   # LMS
curl -I http://studio.localhost            # Studio
curl -I http://apps.localhost/authn/login  # MFE login
```

### Diagnostics (Kubernetes — RKE2)
```bash
# Context: kubectl config use-context rke2-nonprod
# Namespaces: mereka-lms-dev (dev), stg-mereka-lms (staging)
# GKE mereka-lms namespace is DECOMMISSIONED (frozen at 0 replicas)

# Quick site-down diagnostic (run in order)
kubectl get pods -n mereka-lms-dev                      # 1. Are pods running?
kubectl get endpoints -n mereka-lms-dev                 # 2. CRITICAL: Empty = no traffic
kubectl get svc caddy -n mereka-lms-dev                 # 3. Service status

# Fix service selector mismatches (most common issue)
./scripts/infra/fix-service-selectors.sh

# View logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50
kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=50
```

### CI/CD & ARC
```bash
# Check ARC controller and runners
kubectl get pods -n arc-systems                        # ARC controller
kubectl get autoscalingrunnersets -n arc-runners        # Runner scale sets
kubectl get pods -n arc-runners                        # Active runner pods (empty when idle)
kubectl get pvc -n arc-runners                         # Cache PVCs

# Inspect the authoritative CI static inventory
bin/lms-ops inventory ci-static

# Inspect the authoritative CI runtime inventory
bin/lms-ops inventory ci-runtime

# Regenerate the CI static inventory derivative
python3 scripts/governance/generate-ci-static-inventory.py --write

# Regenerate the CI runtime inventory derivative
python3 scripts/governance/generate-ci-runtime-inventory.py --write

# Run the parallel script runner locally (tests CI logic)
.github/run-scripts-parallel.sh .github/ci-scripts-static.txt 4 120

# Adding a new verification script to CI:
# 1. Add the entry in scripts/governance/script-registry.yaml ci_static_inventory
#    for offline/static CI execution, or ci_runtime_inventory for source-owned
#    manual/runtime inventory only
# 2. Regenerate the corresponding .github/ci-scripts-*.txt derivative
# 3. Scripts must exit 0 on success, non-zero on failure
# 4. Scripts get 120s timeout by default

# Workflow changes — use composite actions, don't duplicate:
#   GCP auth:    uses: ./.github/actions/gcp-gke-auth
#   Python env:  uses: ./.github/actions/setup-python-env
#   Playwright:  uses: ./.github/actions/setup-playwright
```

### Code Quality
```bash
make lint                         # Lint Python (ruff), Shell (shellcheck), JS (eslint)
make format                       # Format all code
make test                         # Run tests (currently minimal)
make qa-smoke                     # Smoke tests for critical paths
```

### Branding
```bash
make branding-sync                # Sync assets to Tutor themes
./scripts/branding/setup-mfe-branding.sh  # Set up MFE branding for dev mode
```

### Migrations
```bash
make migrations-prepare           # Prepare Kajabi imports
make migrations-verify            # Verify Kajabi data sync
```

### Cleaning Up
```bash
make clean                        # Remove logs, exports, Python cache
make tutor-stop && docker system prune -a   # Deep clean (removes all images)
```

## Critical Workflows

### After Modifying Tutor Config (RECOMMENDED WORKFLOW)

**Use the safe wrapper script** (handles everything automatically):
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
make tutor-restart
```

**Why**: Tutor render output is generated state. The wrapper script (`tutor-config-save.sh`) automatically:
1. Backs up existing config
2. Renders Tutor config into the repo-scoped `TUTOR_ROOT`
3. Refreshes the Tutor plugin mirror
4. Applies the governed patch manifest
5. Verifies configuration
6. Provides clear next steps

### Fixing "Cloud IPs in Local Config" Issue
If services fail to connect and config shows `MYSQL_HOST: "10.97.0.2"`:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017
make tutor-restart
```

### Site Down Troubleshooting
1. Check `docs/ops/runbooks/TROUBLESHOOTING.md` (5-command diagnostic)
2. Most common issue: service selector mismatches after pod restarts
3. Quick fix: `./scripts/infra/fix-service-selectors.sh`
4. Verify endpoints: `kubectl get endpoints -n mereka-lms`
   - Empty endpoints (`<none>`) = services can't route traffic

## Development Rules

1. **Always develop locally first** before touching cloud instances
2. **Always set `TUTOR_ROOT`** before running Tutor commands: `export TUTOR_ROOT="$(pwd)/tutor_env"`
3. **Always use `./scripts/infra/tutor-config-save.sh`** for Tutor config changes
4. **Always verify config uses local service names** (`mysql`, `mongodb`, `redis`), not cloud IPs (`10.97.x.x`)
5. **Always check endpoints after K8s operations**: `kubectl get endpoints -n mereka-lms` (empty = site down)
6. Test with `make qa-smoke` before committing infrastructure changes

### Methodology (ADR-021)

The full methodology is in `docs/adr/021-openedx-tutor-methodology.md`. Every agent must read it before starting Open edX customization work. The six binding decisions, summarized:

| Decision | Rule |
|---|---|
| **Release line** | Tutor 21.x (Ulmo). No Tutor `main`/`master`. No mixed releases. |
| **Customization** | Tutor plugin API only (`infrastructure/tutor/plugins/mereka_lms.py`). No new Dockerfile surgery. |
| **Frontend** | Plugin slots + design tokens + `@edx/brand`. Do not edit `env.config.jsx` at Dockerfile level. |
| **edx-platform fork** | Base on the current Ulmo release branch (`release/ulmo`). Not `master`, not obsolete `open-release/ulmo.*` refs. |
| **CI** | Local preflight first (<5 min), then CI validates. One hypothesis per PR. Never debug on `main`. |
| **Heavy builds** | CI image builds run through the Bake-backed helpers on governed runner lanes with explicit cache policy. |

**Current debt** (do not add to; migrate away from):
- `infrastructure/tutor/patches/mfe-node.sh` — Dockerfile surgery, migrating to plugin hooks
- `infrastructure/tutor/patches/brand-package.sh` — sed/Python brand injection, migrating to `@edx/brand`

**Migration closed** (plugin-first path landed; patch retained only for asset sync):
- `infrastructure/tutor/patches/sync-footer-assets.sh` — renamed from
  `footer-component.sh`. Footer v2 is registered via the
  `org.openedx.frontend.layout.footer.v1` MFE plugin slot in
  `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` (closed bead
  `115d.21`). This script now only syncs SCSS/font assets into the MFE
  build; it no longer performs JSX injection.

## Code Style

### Python
- Use **ruff** for linting and formatting (line length: 100)
- Python ≥3.10 required
- Type hints encouraged

### Shell Scripts
- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -euo pipefail`
- Lint with **shellcheck**, format with **shfmt**
- 2-space indentation

### JavaScript
- ES modules (`.mjs` extension for scripts)
- Node ≥18 required
- Format with **Prettier** (config in package.json)

### Commits
- Follow [Conventional Commits](https://www.conventionalcommits.org/)
- Examples: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`

## Testing

- `make qa-smoke` runs smoke tests for critical paths
- `./scripts/shared/setup-local.sh` is the local acceptance path for major onboarding/build changes
- `.github/workflows/bootstrap-local-readiness.yml` is the branch proof lane for the same bootstrap contract
- Verify all containers report `Up` via `tutor local dc ps`
- Capture screenshots after theme changes

## Secrets Management

Secrets flow through a secure pipeline:
```
Infisical (source of truth) → GCP Secret Manager → ExternalSecrets → K8s Secrets → Pods
```

**Key points**:
- All secrets prefixed with `MEREKA_LMS_` in Infisical/GCP SM
- ExternalSecrets automatically sync to K8s every 1 hour
- Python code uses `os.environ.get()` pattern
- **NEVER hardcode secrets** - use environment variables

**Managing secrets**:
```bash
# Add secret to Infisical (use canonical wrapper; do not depend on app repos for context)
INFISICAL=/home/gurpreet/projects/vps/infrastructure/scripts/infisical
${INFISICAL} secrets set MEREKA_LMS_NEW_SECRET="value" \
  --domain https://secrets.mereka.io/api --env prod --path /

# Sync to GCP Secret Manager
gcloud secrets create MEREKA_LMS_NEW_SECRET --data-file=- <<< "value"

# Update ExternalSecret mapping in deploy/k8s/base/secrets/external-secrets.yaml
# Then apply: kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml
```

See `specs/secrets-management.md` for full specification.

**Test & Operational Credentials (ALL in Infisical)**:
- **INVARIANT**: Everything you need to test, deploy, or operate is already in Infisical. Do NOT create new tokens or ask for credentials. Do NOT hardcode credential values in this file or in evidence bundles.
- **Test user password**: fetch from Infisical at `MEREKA_LMS_TEST_USER_PASSWORD` (dev env; staging/prod may differ after per-env rotation). Was previously hardcoded here; redacted 2026-04-19 per bead `mereka-lms-m0u5.10.7` rotation. If you need the value, pull from Infisical; don't read it from git history.
- **Test users**: `testadmin` (staff+super), `lanea-platform-admin` (staff+super), `lanea-enterprise-learner` (enterprise), `synthetic-learner-01` (basic learner)
- **GitHub App (cross-repo dispatch)**: `BBI_ARC_GITHUB_APP_ID` + `BBI_ARC_GITHUB_APP_PRIVATE_KEY` + `BBI_ARC_GITHUB_APP_INSTALLATION_ID` in Infisical root path
- **GHCR image push/pull**: `CIE_{DEV,STAGING,PROD}_GHCR_DOCKERCONFIGJSON`
- **Cloudflare**: `CLOUDFLARE_TOKEN_MEREKA_IO` (with `--recursive`), `CLOUDFLARE_TOKEN_MEREKA_DEV` (NO `--recursive`)
- **SSO canary**: `SSO_CANARY_EMAIL_*`, `SSO_CANARY_PASSWORD_*`
- **`ORG_GHCR_TOKEN`**: Currently a GitHub repo secret ONLY (not in Infisical). Used for GHCR image push in CI. Should be mirrored to Infisical at `/shared/github`. For cross-repo dispatch, use the GitHub App instead.

## Security Notes

- **Never commit secrets**: `tutor_env/config.yml` is gitignored
- Use `tutor_env/config.example.yml` as template
- Run `tutor local do backup-db` before upgrades
- Use `./scripts/infra/tutor-config-save.sh` for Tutor config changes so generated state is rendered, patched, and verified together

### Git Hooks

The repository includes two pre-commit hooks to prevent common mistakes:

#### 1. Secret Scanning (`.githooks/pre-commit`)
Automatically scans for hardcoded secrets before each commit.

**Setup** (one-time per clone):
```bash
git config --local include.path ../.gitconfig
```

**What it detects**:
- Hardcoded passwords (`PASSWORD = "..."`)
- API keys (`api_key`, `apikey`, `API_KEY` with values)
- Secret keys (`SECRET_KEY = "..."` with actual values)
- AWS credentials (`AKIA...`, `aws_secret_access_key`)
- Private keys (`BEGIN RSA PRIVATE KEY`, `BEGIN PRIVATE KEY`)
- JWT tokens (`eyJ...`)
- Database connection strings with embedded credentials
- GitHub/Slack/Google API tokens
- Placeholder values that should be removed (`CHANGE_ME`, `changeme`)

**What it ignores**:
- Empty values (`= ""`, `= ''`)
- Environment variable references (`os.environ.get`, `${...}`, `process.env`)
- Comments explaining secrets
- Test/mock/fixture files
- Documentation files (`.md`, `.txt`, `.rst`)

**Bypassing** (emergencies only):
```bash
git commit --no-verify
```

**False positives**: If the hook flags something incorrectly, verify it is truly safe, then use `--no-verify`. Consider updating the hook patterns in `.githooks/pre-commit` if the false positive is common.

#### 2. Tutor Config Safety (`.githooks/pre-tutor-config`)
Warns when committing Tutor-generated files and points contributors back to the governed Tutor config wrapper.

**Setup** (one-time per clone):
```bash
git config --local include.path ../.gitconfig
```

**What it does**:
- Detects commits touching `tutor_env/` files
- Warns if `config.yml` contains secrets
- Prompts to confirm the governed render path was used
- Optionally runs verification checks
- Can be bypassed with `--no-verify`

**Example flow**:
```
$ git add tutor_env/env/apps/openedx/settings/lms/production.py
$ git commit -m "feat: update LMS settings"

=== Tutor Configuration Change Detected ===

The following Tutor-generated files are being committed:
  - tutor_env/env/apps/openedx/settings/lms/production.py

IMPORTANT: Did you use tutor-config-save.sh?

Have you run the governed Tutor wrapper and verifier? [y/N] y

Running verification checks...
✓ All required patches verified successfully!

✓ Proceeding with commit
```

**Recommended workflow**:
1. Use `./scripts/infra/tutor-config-save.sh` (patches applied automatically)
2. Git hook verifies patches on commit
3. No manual intervention needed

## Key Documentation Files

- **Quick Start**: `docs/guides/onboarding/QUICK_START_LOCAL.md` (5-min setup)
- **Full Setup**: `docs/guides/onboarding/LOCAL_SETUP.md`
- **Troubleshooting**: `docs/ops/runbooks/TROUBLESHOOTING.md`
- **Branding**: `docs/guides/branding/BRANDING.md`
- **Migrations**: `docs/migrations/` (Kajabi, MCT playbooks)
- **Architecture**: `docs/concepts/architecture/`
- **ADRs**: `docs/adr/` (Architecture Decision Records)
- **CI/CD Runners**: `docs/ops/ci-cd/CI_CD_RUNNERS.md` (ARC setup, runner labels, PVC caching)
- **CI/CD Optimization**: `docs/status/active/CI_OPTIMIZATION_TRACKER.md` (phase tracker)
- **CI/CD Cost Analysis**: `reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md`
- **Repo Guidelines**: `AGENTS.md` (complements this file)

## Specifications

Machine-checkable specifications for key systems:
- **Secrets**: `specs/secrets-management.md` - Secret naming, required keys, verification
- **Repo Structure**: `specs/repository-structure_spec.md` - Directory layout, deprecated paths
- **K8s Deployment**: `specs/k8s-deployment.md` - Namespace, overlays, ExternalSecrets

## Central Configuration

Scripts should source `scripts/shared/config.sh` for common variables:
```bash
source scripts/shared/config.sh
echo "Project: $GCP_PROJECT, Region: $GCP_REGION, Domain: $LMS_DOMAIN"
```

Override with environment variables:
```bash
GCP_PROJECT=my-test-project source scripts/shared/config.sh
```

## Common Pitfalls

1. **Bypassing `tutor-config-save.sh`** → generated state can miss required patch-manifest output
   - **Fix**: Use `./scripts/infra/tutor-config-save.sh`
   - **Verify**: Run `./scripts/infra/verify-tutor-config.sh`
2. **Cloud IPs in local config** (`MYSQL_HOST: "10.97.0.2"`) → Services can't connect
3. **Not setting `TUTOR_ROOT`** → Tutor creates configs in wrong directory
4. **Insufficient Docker RAM** (<12GB) → Image builds OOM during webpack
5. **Empty K8s endpoints** → Services can't route traffic (run `fix-service-selectors.sh`)
6. **Editing generated files in `tutor_env/`** → Lost on next governed Tutor render
   - **Note**: Git hook will warn you before committing
7. **Using old paths** (`tools/`, `ops/`) → These are deprecated, use `scripts/` and `infrastructure/`
8. **Hardcoding secrets** → Use `os.environ.get()` and ExternalSecrets
   - **Note**: Pre-commit hook will block commits with hardcoded secrets
9. **Adding verification scripts without updating CI** → Script exists but never runs in CI
   - **Fix**: Add offline/static gates to `ci_static_inventory`; use `ci_runtime_inventory` only for manual/runtime inventory paths, then regenerate the corresponding `.github/ci-scripts-*.txt` derivative
10. **Duplicating GCP auth / Python setup in workflows** → Use composite actions in `.github/actions/`
11. **Including ARC manifests in rke2-nonprod overlay** → The overlay's `namespace: mereka-lms` transformer overrides ARC namespaces. Apply ARC separately: `kubectl apply -k deploy/k8s/base/arc/`

## Getting Help

- Documentation index: `docs/README.md`
- Repository guidelines: `AGENTS.md`
- Migration checklist: `MIGRATION_CHECKLIST.md`
- Setup verification: `LOCAL_SETUP_COMPLETE.md`

## Official Documentation Resources

**CRITICAL**: When stuck on Open edX concepts, always check official documentation first using the `openedx-documentation` skill.

**Quick Links**:
- [Open edX Official Documentation](https://docs.openedx.org/) - Platform architecture, development guides, site operations (6 personas: Educators, Learners, Site Operators, Developers, Documentors, Translators)
- [Tutor Documentation](https://docs.tutor.edly.io/) - Deployment tool (8 sections: Getting Started, Running, Configuration, Plugins, Reference, Tutorials, Troubleshooting, Development)
- [Open edX Community Wiki](https://openedx.atlassian.net/wiki/spaces/COMM/overview) - OEPs, working groups, architecture deep-dives
- [Developer's Guide](https://docs.openedx.org/en/latest/developers/references/developer_guide/index.html) - Architecture, contributing, extending, testing, security, i18n
- [Discussion Forums](https://discuss.openedx.org/) - Community support and troubleshooting

**Usage**: Invoke with `/openedx-docs` or natural language ("Check Open edX documentation for forum configuration")

**Pattern**: Before implementing ANY Open edX feature, search docs first to prevent reinventing existing solutions
