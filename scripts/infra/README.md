# Infrastructure Scripts

Scripts for managing infrastructure: GKE clusters, Cloudflare, MongoDB Atlas, backups, etc.

## Key Scripts

- `backup-db.sh` - Database backup automation
- `check-cluster-status.sh` - GKE cluster health check
- `fix-service-selectors.sh` - **🚨 SITE DOWN?** Quick fix for service selector mismatches
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
```

