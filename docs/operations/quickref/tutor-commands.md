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

### Start/Stop

```bash
# Start all services (background)
tutor local start

# Start with logs (foreground)
tutor local start -d

# Stop all services
tutor local stop

# Restart all services
tutor local restart

# Restart specific service
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
# Use wrapper script (auto-applies patches)
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
tutor local restart
```

### Manual Config Workflow (Advanced)

```bash
# 1. Save config changes
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save --set KEY=value

# 2. CRITICAL: Apply patches (NEVER skip this)
./infrastructure/tutor/apply-patches.sh

# 3. Verify patches applied correctly
./scripts/infra/verify-tutor-config.sh

# 4. Restart services
tutor local restart
```

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

## What apply-patches.sh Fixes

**CRITICAL**: `tutor config save` regenerates templates from scratch. Always run `apply-patches.sh` after.

Patches applied:
- MySQL 8 authentication plugin (`mysql_native_password`)
- MFE Node 18 build toolchain (g++, python3)
- Extra domains (biji-biji.com, skillourfuture)
- Webpack memory limit (`NODE_OPTIONS=--max-old-space-size=6144`)
- CSRF trusted origins and allowed hosts
- Custom Mereka footer component
- Prometheus metrics integration
- MongoDB Atlas SRV support
- Build optimizations and retry logic

---

## Image Building

### Build Commands

```bash
# Build Open edX platform (LMS/CMS/workers)
# Requires: 12GB+ RAM, 30-45 min
tutor images build openedx

# Build micro-frontends (MFEs)
# Requires: 15-20 min
tutor images build mfe

# Build specific service
tutor images build discovery
tutor images build forum
tutor images build ecommerce
tutor images build notes
```

### Build with Custom Args

```bash
# Use pip instead of uv pip (for compatibility)
tutor images build openedx -a PIP_COMMAND=pip

# Skip cache (fresh build)
tutor images build openedx --no-cache

# Build multiple in parallel
tutor images build openedx mfe discovery
```

### Push to Registry

```bash
# Push to Artifact Registry
tutor images push openedx
tutor images push mfe

# Tag and push manually
docker tag openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:$(date +%Y%m%d)-ulmo-$(git rev-parse --short HEAD)
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:$(date +%Y%m%d)-ulmo-$(git rev-parse --short HEAD)
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
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor local restart
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

```bash
# Sync assets to Tutor themes
make branding-sync

# Rebuild Open edX with new theme
tutor images build openedx

# Restart to apply theme changes
tutor local restart lms cms
```

### MFE Branding

```bash
# Set up MFE branding for dev mode
./scripts/branding/setup-mfe-branding.sh

# Rebuild MFE with branding
tutor images build mfe
tutor local restart mfe
```

---

## Initial Setup (First Time)

```bash
# Full interactive setup (1+ hour)
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor local launch -I

# This runs:
# 1. tutor config save --interactive
# 2. tutor local do init (migrations, static assets, superuser)
# 3. tutor local start -d

# Then apply patches (CRITICAL)
./infrastructure/tutor/apply-patches.sh
tutor local restart
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

```bash
# Initialize (first time)
tutor k8s init

# Apply manifests
tutor k8s apply

# Start/stop (doesn't exist in k8s - use kubectl)
kubectl scale deployment/lms --replicas=0 -n mereka-lms  # Stop
kubectl scale deployment/lms --replicas=2 -n mereka-lms  # Start

# Run migrations
tutor k8s do migrate

# Create superuser
tutor k8s do createuser --staff --superuser admin admin@example.com
```

---

## Environment Comparison

| Environment | Command Prefix | Service Names | Image Tags |
|-------------|----------------|---------------|------------|
| **Local** | `tutor local` | mysql, mongodb, redis | latest |
| **Kubernetes** | `tutor k8s` | Cloud SQL proxy, Atlas | production/staging |

**Critical**: Local uses Docker Compose service names. K8s uses Cloud SQL/Atlas.

---

## Common Config Keys

```bash
# Domains
tutor config save --set LMS_HOST=localhost
tutor config save --set CMS_HOST=studio.localhost
tutor config save --set PREVIEW_LMS_HOST=preview.localhost

# Databases
tutor config save --set MYSQL_HOST=mysql
tutor config save --set MONGODB_HOST=mongodb
tutor config save --set REDIS_HOST=redis

# Open edX version
tutor config save --set OPENEDX_COMMON_VERSION=open-release/ulmo.master

# Language
tutor config save --set LANGUAGE_CODE=en

# Contact email
tutor config save --set CONTACT_EMAIL=admin@example.com
```

**REMEMBER**: Always run `./infrastructure/tutor/apply-patches.sh` after `tutor config save`!

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
tutor local restart
```

### Build Fails with "loremipsum" Error

```bash
# Tutor v21 (Ulmo) uses `uv pip` which breaks loremipsum package
# Fix: use `pip` instead
tutor images build openedx -a PIP_COMMAND=pip
```

### Forgot to Run apply-patches.sh

```bash
# Symptoms: MySQL auth fails, MFE build breaks, missing domains
# Verify:
./scripts/infra/verify-tutor-config.sh

# Fix:
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

---

## See Also

- [Kubectl Cheatsheet](./kubectl-cheatsheet.md) - Kubernetes operations
- [Verification Scripts](./verification-scripts.md) - Automated checks
- [Common Troubleshooting](./common-troubleshooting.md) - 1-page debug guide
- [Tutor Config Safety](../TUTOR_CONFIG_SAFETY.md) - Config best practices
