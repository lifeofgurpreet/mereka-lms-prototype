# Infrastructure Scripts

Scripts for managing infrastructure: GKE clusters, Cloudflare, MongoDB Atlas, backups, etc.

## Key Scripts

- `ensure-platform-admins.sh` - Ensure Gurpreet + Malasari have full admin permissions across LMS/CMS/Discovery/Credentials/Ecommerce (prod + dev)
- `ensure-authentik-admin.sh` - Ensure Gurpreet is the only Authentik admin (superuser) (prod)
- `backup-db.sh` - Database backup automation
- `check-cluster-status.sh` - GKE cluster health check
- `fix-service-selectors.sh` - **🚨 SITE DOWN?** Quick fix for service selector mismatches
- `repair-routing.sh` - Fix selector drift **and** add HTTPS (443) to caddy service (wrapper)
- `repair-staging-routing.sh` - Legacy routing entrypoint (kept for backwards compatibility)
- `check-cert-sans.sh` - Verify TLS SANs and detect fake ingress certs
- `check-atlas-allowlist.sh` - Validate Atlas IP allowlist matches cluster egress
- `check-atlas-allowlist-vps.sh` - Validate Atlas allowlist for VPS egress IP
- `ensure-atlas-allowlist-vps.sh` - Add VPS egress IP to Atlas allowlist if missing
- `atlas-config-from-infisical.sh` - Configure Atlas CLI profile from Infisical API keys
- `cron-public-health-check.sh` - Cron entrypoint for public health + branding checks
- `setup-vps-health-cron.sh` - Install VPS cron entry for public health checks
- `setup-vps-atlas-allowlist-cron.sh` - Install VPS cron entry to keep Atlas allowlist updated
- `refresh-i18n-static.sh` - Rebuild LMS/CMS i18n JS bundles (fixes missing gettext)
- `infisical-validate-mereka-lms.sh` - Verify Infisical has all MEREKA_LMS secrets
- `infisical-sync-mereka-lms.sh` - Sync MEREKA_LMS secrets into `/k8s/mereka-lms`
- `normalize-mysql-secrets.sh` - Strip trailing CR/LF for MySQL password secrets (Infisical + GCP SM + K8s ESO target)
- `provision-mysql-app-dbs.sh` - Create Notes/XQueue MySQL DBs + users (idempotent, non-destructive)
- `argocd-refresh.sh` - Force ArgoCD refresh for remote base updates
- `apply-monitoring-configs.sh` - Apply uptime checks, log metrics, and alert policies
- `validate-telemetry-connectivity.sh` - **📊 MONITORING** Validate Grafana datasource connectivity to GKE and VPS Prometheus
- `cloudflare-sync.sh` - Cloudflare DNS sync
- `mongodb-to-atlas.sh` - MongoDB migration to Atlas
- `deploy-aspects-k8s.sh` - Deploy Aspects analytics to Kubernetes

## Usage

```bash
# Check cluster status
./scripts/infra/check-cluster-status.sh

# Backup database
./scripts/infra/backup-db.sh

# Fix service selectors (if site is down)
./scripts/infra/fix-service-selectors.sh

# Full routing repair (selectors + HTTPS port 443)
./scripts/infra/repair-routing.sh

# Force ArgoCD refresh for remote bases
ARGO_APPS="mereka-lms-production mereka-lms-local" ./scripts/infra/argocd-refresh.sh

# Apply monitoring configs
./scripts/infra/apply-monitoring-configs.sh plan

# Validate Atlas allowlist for VPS egress (dev forum)
./scripts/infra/check-atlas-allowlist-vps.sh

# Add VPS egress IP to Atlas allowlist if missing
./scripts/infra/ensure-atlas-allowlist-vps.sh

# Configure Atlas CLI from Infisical (API keys)
./scripts/infra/atlas-config-from-infisical.sh

# Run public health checks (prod + dev) with branding + certs
./scripts/infra/cron-public-health-check.sh

# Install VPS cron (optional, local logs)
./scripts/infra/setup-vps-health-cron.sh

# Install VPS cron for Atlas allowlist auto-updates
./scripts/infra/setup-vps-atlas-allowlist-cron.sh

# Rebuild LMS/CMS gettext bundles (account settings/profile blank)
./scripts/infra/refresh-i18n-static.sh

# Ensure platform admins have full permissions (prod + dev)
./scripts/infra/ensure-platform-admins.sh

# Validate Infisical secrets for Mereka LMS
./scripts/infra/infisical-validate-mereka-lms.sh

# Sync MEREKA_LMS secrets into /k8s/mereka-lms (fixes sprawl)
./scripts/infra/infisical-sync-mereka-lms.sh prod
./scripts/infra/infisical-sync-mereka-lms.sh dev

# Normalize MySQL password secrets (strip trailing CR/LF in Infisical + GCP SM + K8s)
./scripts/infra/normalize-mysql-secrets.sh
APPLY=1 ./scripts/infra/normalize-mysql-secrets.sh

# Provision Notes/XQueue MySQL DBs/users (idempotent)
./scripts/infra/provision-mysql-app-dbs.sh

# Sync Infisical -> GCP Secret Manager (ExternalSecrets source of truth)
# NOTE: By default this is create-if-missing for safety. If you are fixing a bad
# MongoDB Atlas secret already present in GCP SM (e.g. trailing newline), opt-in:
ALLOW_OVERWRITE_MONGODB_KEYS=1 ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh

# Validate telemetry connectivity (Grafana → Prometheus)
./scripts/infra/validate-telemetry-connectivity.sh
```

## Scheduled Checks

Primary automation lives in CI (`.github/workflows/public-health-check.yml`).
Run these locally only when you need extra signal or on-demand logs:

```
./scripts/infra/check-atlas-allowlist.sh
./scripts/infra/check-atlas-allowlist-vps.sh
./scripts/infra/ensure-atlas-allowlist-vps.sh
./scripts/infra/cron-public-health-check.sh
```

If you *explicitly* want VPS cron logs, you can still wire them up, but CI
is the default source of truth for health checks.

To install the cron entry with logs under `var/`, run:
```
./scripts/infra/setup-vps-health-cron.sh
```
