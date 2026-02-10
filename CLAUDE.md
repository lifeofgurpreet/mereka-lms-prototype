# CLAUDE.md

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
  - MongoDB Atlas (forum, modulestore) - **Atlas only, no local MongoDB**
  - Redis (caching, Celery)
- **Infrastructure**:
  - Local: Docker Compose
  - Production: Google Kubernetes Engine (GKE), Cloud SQL, Artifact Registry
- **Frontend**: Micro-frontends (MFEs) built on React, served via Caddy reverse proxy
- **Services**: Discovery (course catalog), Forum (Python openedx-forum v0.3.8, integrated into LMS), Notes, Ecommerce, XQueue, Meilisearch (forum search)

### Repository Structure
```
deploy/k8s/               # Kubernetes manifests
  ├── base/               # Base Kustomize resources
  │   ├── secrets/        # ExternalSecrets (synced from Infisical)
  │   ├── apps/           # App-specific configs
  │   └── plugins/        # Plugin configs (discovery, ecommerce, etc.)
  └── overlays/           # Environment-specific overlays
      ├── local/          # Local Kind/Minikube
      ├── staging/        # Legacy (reference only)
      └── production/     # Production GKE

infrastructure/           # Infrastructure-as-code
  ├── tutor/              # Tutor configs, patches, themes
  ├── cloudflare/         # DNS records
  ├── terraform/          # Terraform configs
  └── monitoring/         # Monitoring configs

scripts/                  # Automation organized by domain
  ├── shared/             # Common utilities (config.sh, setup-local.sh)
  ├── infra/              # GCP, GKE, MongoDB, backups
  ├── migrations/         # Kajabi/MCT data migration
  ├── branding/           # Theme sync scripts
  ├── analytics/          # Analytics exports
  └── qa/                 # Smoke tests

specs/                    # Specifications (machine-checkable intent)
  ├── secrets-management.md
  ├── repository-structure.md
  └── k8s-deployment.md

docs/                     # Documentation by category
  ├── adr/                # Architecture Decision Records
  ├── onboarding/         # Setup guides (start here)
  ├── operations/         # Runbooks, troubleshooting
  ├── migrations/         # Migration playbooks
  ├── architecture/       # System design docs
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
1. `tutor config save` regenerates templates from config.yml
2. **ALWAYS run `./infrastructure/tutor/apply-patches.sh`** after config changes
3. Patches fix MySQL authentication plugin, MFE Node version, service configs
4. Restart services: `tutor local restart` or `tutor k8s restart`

**Local vs Cloud Configuration**:
- **Local**: Service names are Docker Compose service names (`mysql`, `mongodb`, `redis`)
- **Cloud**: Service names are K8s internal DNS or Cloud SQL proxy addresses
- **Common mistake**: Config accidentally contains cloud IPs in local setup → services fail to connect

**Image Build Pipeline**:
- `tutor images build openedx` → builds LMS/CMS/workers (30+ min)
- `tutor images build mfe` → builds micro-frontends with Node 18 patch
- Images pushed to `asia-southeast1-docker.pkg.dev/mereka-lms/openedx`
- Local builds tag as `latest`, cloud builds tag with git SHA

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
pip install "tutor[full]==18.2.2" tutor-mfe==18.1.0

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

# After config changes
make tutor-apply                  # Saves config, applies patches, restarts
```

### Building Images
```bash
# Build Open edX platform (LMS/CMS/workers)
tutor images build openedx        # Takes 30-45 min, needs 12GB+ RAM

# Build micro-frontends
tutor images build mfe            # Takes 15-20 min

# Build specific service
tutor images build discovery
tutor images build forum
```

### Diagnostics (Local)
```bash
# Check container status
docker ps --filter "name=tutor_local"
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

### Diagnostics (Kubernetes/Production)
```bash
# Quick site-down diagnostic (run in order)
kubectl get pods -n mereka-lms                          # 1. Are pods running?
kubectl get endpoints -n mereka-lms                     # 2. CRITICAL: Empty = no traffic
kubectl get svc caddy -n mereka-lms                     # 3. LoadBalancer status

# Fix service selector mismatches (most common issue)
./scripts/infra/fix-service-selectors.sh

# View logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50
kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=50
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
tutor local stop && docker system prune -a  # Deep clean (removes all images)
```

## Critical Workflows

### After Modifying Tutor Config
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh    # CRITICAL!
tutor local restart
```

**Why**: `tutor config save` regenerates templates from scratch, losing patches. The `apply-patches.sh` script re-applies:
- MySQL 8 authentication plugin fix (`mysql_native_password`)
- MFE Node 18 build toolchain (g++, python3)
- Extra domain names for multi-site support (biji-biji.com, skillourfuture)
- Webpack memory limit increase (`NODE_OPTIONS=--max-old-space-size=6144`)
- CSRF trusted origins and allowed hosts
- Custom Mereka footer component for MFEs

### Fixing "Cloud IPs in Local Config" Issue
If services fail to connect and config shows `MYSQL_HOST: "10.97.0.2"`:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

### Site Down Troubleshooting
1. Check `docs/operations/TROUBLESHOOTING.md` (5-command diagnostic)
2. Most common issue: service selector mismatches after pod restarts
3. Quick fix: `./scripts/infra/fix-service-selectors.sh`
4. Verify endpoints: `kubectl get endpoints -n mereka-lms`
   - Empty endpoints (`<none>`) = services can't route traffic

## Development Rules

1. **Always develop locally first** before touching cloud instances
2. **Always set `TUTOR_ROOT`** before running Tutor commands: `export TUTOR_ROOT="$(pwd)/tutor_env"`
3. **Always run `./infrastructure/tutor/apply-patches.sh`** after `tutor config save`
4. **Always verify config uses local service names** (`mysql`, `mongodb`, `redis`), not cloud IPs (`10.97.x.x`)
5. **Always check endpoints after K8s operations**: `kubectl get endpoints -n mereka-lms` (empty = site down)
6. Test with `make qa-smoke` before committing infrastructure changes

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
- `tutor local quickstart -I` is the acceptance test for major changes
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
# Add secret to Infisical (from reka-slackbot directory)
cd /home/gurpreet/projects/k8s/reka-slackbot
infisical secrets set MEREKA_LMS_NEW_SECRET="value" \
  --domain https://secrets.mereka.io/api --env prod --path /

# Sync to GCP Secret Manager
gcloud secrets create MEREKA_LMS_NEW_SECRET --data-file=- <<< "value"

# Update ExternalSecret mapping in deploy/k8s/base/secrets/external-secrets.yaml
# Then apply: kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml
```

See `specs/secrets-management.md` for full specification.

## Security Notes

- **Never commit secrets**: `tutor_env/config.yml` is gitignored
- Use `tutor_env/config.example.yml` as template
- Run `tutor local do backup-db` before upgrades
- Re-run `./infrastructure/tutor/apply-patches.sh` after every `tutor config save`

### Pre-commit Secret Scanning

A pre-commit hook automatically scans for hardcoded secrets before each commit.

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

## Key Documentation Files

- **Quick Start**: `docs/onboarding/QUICK_START_LOCAL.md` (5-min setup)
- **Full Setup**: `docs/onboarding/DEVELOPER_ONBOARDING.md`
- **Troubleshooting**: `docs/operations/TROUBLESHOOTING.md`
- **Branding**: `docs/BRANDING.md`
- **Migrations**: `docs/migrations/` (Kajabi, MCT playbooks)
- **Architecture**: `docs/architecture/`
- **ADRs**: `docs/adr/` (Architecture Decision Records)
- **Repo Guidelines**: `AGENTS.md` (complements this file)

## Specifications

Machine-checkable specifications for key systems:
- **Secrets**: `specs/secrets-management.md` - Secret naming, required keys, verification
- **Repo Structure**: `specs/repository-structure.md` - Directory layout, deprecated paths
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

1. **Forgetting to run `apply-patches.sh`** → MySQL auth fails, MFE Node 18 build breaks
2. **Cloud IPs in local config** (`MYSQL_HOST: "10.97.0.2"`) → Services can't connect
3. **Not setting `TUTOR_ROOT`** → Tutor creates configs in wrong directory
4. **Insufficient Docker RAM** (<12GB) → Image builds OOM during webpack
5. **Empty K8s endpoints** → Services can't route traffic (run `fix-service-selectors.sh`)
6. **Editing generated files in `tutor_env/`** → Lost on next `tutor config save`
7. **Using old paths** (`tools/`, `ops/`) → These are deprecated, use `scripts/` and `infrastructure/`
8. **Hardcoding secrets** → Use `os.environ.get()` and ExternalSecrets

## Getting Help

- Documentation index: `docs/README.md`
- Repository guidelines: `AGENTS.md`
- Migration checklist: `MIGRATION_CHECKLIST.md`
- Setup verification: `LOCAL_SETUP_COMPLETE.md`
