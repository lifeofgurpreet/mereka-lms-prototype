# Infrastructure Scripts

Scripts for managing infrastructure: GKE clusters, Cloudflare, MongoDB Atlas, backups, etc.

## Key Scripts

- `backup-db.sh` - Database backup automation
- `check-cluster-status.sh` - GKE cluster health check
- `fix-service-selectors.sh` - **🚨 SITE DOWN?** Quick fix for service selector mismatches
- `repair-routing.sh` - Fix selector drift **and** add HTTPS (443) to caddy service (wrapper)
- `repair-staging-routing.sh` - Legacy entrypoint (kept for backwards compatibility)
- `check-cert-sans.sh` - Verify TLS SANs and detect fake ingress certs
- `check-atlas-allowlist.sh` - Validate Atlas IP allowlist matches cluster egress
- `check-atlas-allowlist-vps.sh` - Validate Atlas allowlist for VPS egress IP
- `refresh-i18n-static.sh` - Rebuild LMS/CMS i18n JS bundles (fixes missing gettext)
- `infisical-validate-mereka-lms.sh` - Verify Infisical has all MEREKA_LMS secrets
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

# Rebuild LMS/CMS gettext bundles (account settings/profile blank)
./scripts/infra/refresh-i18n-static.sh

# Validate Infisical secrets for Mereka LMS
./scripts/infra/infisical-validate-mereka-lms.sh

# Validate telemetry connectivity (Grafana → Prometheus)
./scripts/infra/validate-telemetry-connectivity.sh
```

## Scheduled Checks

VPS cron runs the Atlas allowlist check every 30 minutes:

```
*/30 * * * * /home/gurpreet/projects/k8s/mereka-lms/scripts/infra/check-atlas-allowlist-vps.sh >> /home/gurpreet/projects/k8s/mereka-lms/var/atlas-allowlist.log 2>&1
```
