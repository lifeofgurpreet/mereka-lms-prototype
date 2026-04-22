# Tutor Commands - Mereka LMS

Quick reference for common Tutor operations in Mereka LMS.

---

## Environment Setup (ALWAYS FIRST)

```bash
# Set Tutor root (required before ANY tutor command)
export TUTOR_ROOT="$(pwd)/tutor_env"

# Verify Tutor root
echo $TUTOR_ROOT

# Load Tutor environment helper
source infrastructure/tutor/tutor-env.sh
```

**CRITICAL**: Without `TUTOR_ROOT`, Tutor creates configs in wrong directory.

---

## Service Lifecycle

### Whole-Stack Daily Control

```bash
# Start all services after first bootstrap
make tutor-start

# Stop all services
make tutor-stop

# Re-apply rendered config to the running stack
make tutor-restart
```

Use these wrappers for the normal local-development lane after the first
successful `tutor local launch -I --skip-build`. Drop to raw `tutor local ...`
subcommands only for low-level status/logs, service-targeted recovery, or
bootstrap-only operations.

### Low-Level Service Recovery

```bash
# Restart specific service during low-level debugging
tutor local restart lms
tutor local restart cms
```

### Service Status

```bash
# Check running containers
tutor local dc ps

# Docker native (shows all tutor_local containers)
docker ps --filter "name=tutor_local"

# Quick health check
tutor local status
```

---

## Configuration Management

### Safe Config Workflow (RECOMMENDED)

```bash
# Use wrapper script (auto-runs the governed refresh path)
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
make tutor-restart
```

### Manual Config Workflow (Advanced)

```bash
# Save config changes through the governed wrapper
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value

# Optional: verify the rendered context explicitly
./scripts/infra/verify-tutor-config.sh

# Restart services
make tutor-restart
```

If you are auditing raw Tutor render deltas in a disposable `TUTOR_ROOT`, `./scripts/infra/prepare-tutor-build-context.sh --target all` is the required refresh step before trusting any resulting build artifacts.

### View Config

```bash
# Print entire config
tutor config printroot
tutor config printvalue KEY

# Common keys
tutor config printvalue LMS_HOST
tutor config printvalue MYSQL_HOST
tutor config printvalue OPENEDX_COMMON_VERSION

# Edit config directly (NOT recommended - use config save)
# File: tutor_env/config.yml
```

---

## What the Governed Refresh Path Realizes

**CRITICAL**: `./scripts/infra/tutor-config-save.sh` is the normal local render path. It invokes Tutor, syncs the plugin mirror, refreshes the rendered build context, and runs the verifier. If you intentionally audit raw Tutor render output in a disposable `TUTOR_ROOT`, run `prepare-tutor-build-context.sh --target all` before trusting any resulting build artifacts.

Refresh covers:
- Tutor 21 local MySQL native-password mode plus `MYSQL_ROOT_HOST` compatibility
- MFE rendered build contract (Node 24 toolchain, local brand package, tracked snapshot parity)
- Extra domains (biji-biji.com, skillourfuture)
- Webpack memory limit (`NODE_OPTIONS=--max-old-space-size=6144`)
- CSRF trusted origins and allowed hosts
- Custom Mereka footer component
- Prometheus metrics integration
- MongoDB Atlas SRV support
- Build optimizations, mirror sync, and retry logic

---

## Image Building

### Build Commands

Use the repo helpers for local development, parity checks, and debugging.
They render through the canonical Tutor path, apply the bounded compatibility
layer, select the dependency mirror builder, and preserve build-context labels.
Production releases must publish through
`.github/workflows/build-tutor-images.yml` and promote with
`./scripts/infra/release-openedx-gitops.sh --require-digests`.

```bash
# Build Open edX platform (LMS/CMS/workers)
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# Build micro-frontends (MFEs)
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast

# Optional non-repo-owned Tutor service images are outside the canonical
# onboarding path. If one must be rebuilt during an investigation, record the
# owner layer and proof gap before teaching that command here.
```

### Build with Custom Args

```bash
# Use the Open edX helper instead of raw PIP_COMMAND overrides.
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# Skip cache (fresh build)
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile proof --cache-mode none

# Build Open edX and MFE sequentially; do not run parallel local image builds.
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

### Push to Registry

These commands are for local experimentation only. Do not use `tutor images push`
or manual `docker push` as the normal production release path.

```bash
# Push from a local/dev environment
tutor images push openedx
tutor images push mfe

# Local debug images are `openedx:nightly` and `openedx-mfe:nightly`.
# Production promotion uses workflow artifacts plus release digests.
```

---

## Database Operations

### Django Migrations

```bash
# Check migration status
tutor local run lms ./manage.py lms showmigrations

# Run migrations (LMS)
tutor local run lms ./manage.py lms migrate

# Run migrations (CMS/Studio)
tutor local run cms ./manage.py cms migrate

# Create new migration
tutor local run lms ./manage.py lms makemigrations

# Squash migrations (optimize)
tutor local run lms ./manage.py lms squashmigrations app_name start_migration end_migration
```

### Django Management Commands

```bash
# Open Django shell (LMS)
tutor local run lms ./manage.py lms shell

# Create superuser
tutor local run lms ./manage.py lms createsuperuser

# Run custom management command
tutor local run lms ./manage.py lms <command>

# Collect static assets
tutor local run lms ./manage.py lms collectstatic --noinput
```

### Database Backups

```bash
# Backup MySQL
tutor local do backup-db

# Backup to custom location
tutor local run -v /path/to/backup:/backup mysql mysqldump -u root -p edxapp > /backup/edxapp-$(date +%Y%m%d).sql

# Restore backup
tutor local run -v /path/to/backup:/backup mysql mysql -u root -p edxapp < /backup/edxapp-20240212.sql
```

---

## Logs & Debugging

### View Logs

```bash
# All services (last 50 lines)
tutor local logs --tail=50

# Specific service
tutor local logs --tail=100 lms
tutor local logs --tail=100 cms
tutor local logs --tail=100 mfe

# Follow logs (live stream)
tutor local logs -f lms

# Since timestamp
tutor local logs --since 2024-02-12T10:00:00
```

### Shell Access

```bash
# LMS container
tutor local run lms bash

# CMS container
tutor local run cms bash

# MySQL shell
tutor local run mysql mysql -u root -p

# Redis CLI
tutor local run redis redis-cli
```

### Common Diagnostics

```bash
# Verify config uses local service names (NOT cloud IPs)
grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
# Expected: mysql, mongodb, redis (NOT 10.97.x.x)

# Test LMS health
curl -I http://localhost

# Test Studio health
curl -I http://studio.localhost

# Test MFE login
curl -I http://apps.localhost/authn/login

# Check Caddy routing
tutor local logs caddy --tail=100 | grep -i error
```

---

## Plugin Management

### List Plugins

```bash
# List installed plugins
tutor plugins list

# Plugin details
tutor plugins info mfe
```

### Enable/Disable Plugins

```bash
# Enable plugin
tutor plugins enable mfe
tutor plugins enable discovery

# Disable plugin
tutor plugins disable ecommerce

# After plugin changes
./scripts/infra/tutor-config-save.sh
make tutor-restart
```

---

## Data Import/Export

### Course Import

```bash
# Import course archive
tutor local run cms ./manage.py cms import /openedx/data course-export.tar.gz

# Copy course archive to container first
docker cp course-export.tar.gz $(docker ps --filter "name=tutor_local-cms" --format "{{.ID}}"):/openedx/data/
```

### User Data

```bash
# Export users to CSV
tutor local run lms ./manage.py lms dump_user_data --output=/tmp/users.csv

# Import users from CSV
tutor local run lms ./manage.py lms import_users /tmp/users.csv
```

---

## Theming & Branding

### Apply Theme

Local theme workflow:
```bash
# Sync assets to Tutor themes
make branding-sync

# Rebuild Open edX with new theme
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# Restart to apply theme changes
make tutor-restart
```

Production theme rollout:
- publish updated Open edX / MFE images through `.github/workflows/build-tutor-images.yml`
- promote the resulting digests with `./scripts/infra/release-openedx-gitops.sh --require-digests`

### MFE Branding

Local MFE workflow:
```bash
# Set up MFE branding for dev mode
./scripts/branding/setup-mfe-branding.sh

# Rebuild MFE with branding
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
make tutor-restart
```

Production MFE branding rollout:
- publish the updated MFE image through `.github/workflows/build-tutor-images.yml`
- promote the resulting digests with `./scripts/infra/release-openedx-gitops.sh --require-digests`

---

## Initial Setup (First Time)

```bash
# Full repo-governed setup path
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/shared/setup-local.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

---

## Quick Start (After Initial Setup)

```bash
# Set environment
export TUTOR_ROOT="$(pwd)/tutor_env"

# Start services
make tutor-start

# Check status
tutor local dc ps

# Access:
# - LMS: http://localhost
# - Studio: http://studio.localhost
# - MFE: http://apps.localhost
```

---

## Kubernetes Commands

### Deploy to K8s

Runtime deployments are GitOps-owned on RKE2. Do not use raw `tutor k8s apply`,
`tutor k8s start`, or ad hoc `kubectl scale` as a normal release path.

Use:
- `docs/guides/admin/K8S_OPERATIONS_GUIDE.md` for operator procedures
- `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md` for release truth
- `./scripts/infra/release-openedx-gitops.sh --require-digests` for image promotion

---

## Environment Comparison

| Environment | Command Prefix | Service Names | Image Tags |
|-------------|----------------|---------------|------------|
| **Local** | `tutor local` | mysql, mongodb, redis | `openedx:nightly`, `openedx-mfe:nightly` |
| **Kubernetes** | GitOps/ArgoCD | RKE2 Services/ESO-managed secrets | GHCR release digests |

**Critical**: Local uses Docker Compose service names. Kubernetes runtime truth is source/GitOps plus ArgoCD realization; do not back-port live cluster edits into local Tutor docs.

---

## Common Config Keys

```bash
# Domains
./scripts/infra/tutor-config-save.sh --set LMS_HOST=localhost
./scripts/infra/tutor-config-save.sh --set CMS_HOST=studio.localhost
./scripts/infra/tutor-config-save.sh --set PREVIEW_LMS_HOST=preview.localhost

# Databases
./scripts/infra/tutor-config-save.sh --set MYSQL_HOST=mysql
./scripts/infra/tutor-config-save.sh --set MONGODB_HOST=mongodb
./scripts/infra/tutor-config-save.sh --set REDIS_HOST=redis

# Open edX version
./scripts/infra/tutor-config-save.sh --set OPENEDX_COMMON_VERSION=open-release/ulmo.1

# Language
./scripts/infra/tutor-config-save.sh --set LANGUAGE_CODE=en

# Contact email
./scripts/infra/tutor-config-save.sh --set CONTACT_EMAIL=admin@example.com
```

**REMEMBER**: Use `./scripts/infra/tutor-config-save.sh` for normal config edits. It owns render, build-context refresh, and verification as one path.

---

## Troubleshooting

### Config Accidentally Has Cloud IPs

```bash
# Symptoms: services can't connect, logs show "connection refused"
# Verify:
grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
# Shows: 10.97.x.x (WRONG for local)

# Fix:
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017
make tutor-restart
```

### Build Fails with "loremipsum" Error

```bash
# Tutor v21 (Ulmo) raw builds can hit the `uv pip`/loremipsum edge.
# Fix: use the repo helper, which owns the compatibility path.
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
```

### Forgot to Run the Prepare Path

```bash
# Symptoms: MySQL auth fails, MFE build breaks, missing domains
# Verify:
./scripts/infra/verify-tutor-config.sh

# Fix:
./scripts/infra/prepare-tutor-build-context.sh --target all
make tutor-restart
```

---

## See Also

- [Kubectl Cheatsheet](./kubectl-cheatsheet.md) - Kubernetes operations
- [Verification Scripts](./verification-scripts.md) - Automated checks
- [Common Troubleshooting](./common-troubleshooting.md) - 1-page debug guide
- [Tutor Config Safety](../../policies/operations/TUTOR_CONFIG_SAFETY.md) - Config best practices
