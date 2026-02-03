# Infrastructure Scripts

Scripts for managing infrastructure: GKE clusters, Cloudflare, MongoDB Atlas, backups, etc.

## Key Scripts

- `backup-db.sh` - Database backup automation
- `check-cluster-status.sh` - GKE cluster health check
- `fix-service-selectors.sh` - **🚨 SITE DOWN?** Quick fix for service selector mismatches
- `repair-routing.sh` - Fix selector drift **and** add HTTPS (443) to caddy service (wrapper)
- `repair-staging-routing.sh` - Legacy entrypoint (kept for backwards compatibility)
- `check-cert-sans.sh` - Verify TLS SANs and detect fake ingress certs
- `apply-monitoring-configs.sh` - Apply uptime checks, log metrics, and alert policies
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

# Apply monitoring configs
./scripts/infra/apply-monitoring-configs.sh plan
```

