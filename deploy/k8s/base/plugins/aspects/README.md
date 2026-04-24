# Aspects Analytics - Kubernetes Deployment

This directory contains K8s manifests for deploying the Aspects analytics stack:

- **ClickHouse** - Analytics data warehouse for storing learning events
- **Superset** - Apache Superset for data visualization and dashboards

## Prerequisites

1. MySQL database with a `superset` database and user
2. Redis for Superset caching and Celery
3. DNS configured for `analytics.academyv2.mereka.io` (optional)

## Quick Deploy

```bash
# 1. Create the superset database in MySQL
kubectl exec -n mereka-lms deploy/mysql -- mysql -u root -p -e "
  CREATE DATABASE IF NOT EXISTS superset;
  CREATE USER IF NOT EXISTS 'superset'@'%' IDENTIFIED BY 'YOUR_PASSWORD';
  GRANT ALL PRIVILEGES ON superset.* TO 'superset'@'%';
  FLUSH PRIVILEGES;
"

# 2. Create secrets (replace with real passwords)
kubectl create secret generic aspects-secrets -n mereka-lms \
  --from-literal=clickhouse-password='secure_clickhouse_password' \
  --from-literal=superset-secret-key="$(openssl rand -hex 32)" \
  --from-literal=superset-db-password='YOUR_SUPERSET_DB_PASSWORD' \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Deploy the stack
kubectl apply -k deploy/k8s/base/plugins/aspects/

# 4. Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=aspects -n mereka-lms --timeout=300s

# 5. Run initialization jobs
kubectl apply -f deploy/k8s/base/plugins/aspects/jobs.yml

# 6. Monitor job completion
kubectl get jobs -n mereka-lms -l app.kubernetes.io/part-of=aspects
```

## Access Superset

### Via Port Forward (Recommended for Internal Use)
```bash
kubectl port-forward -n mereka-lms svc/superset 8088:8088
# Then open: http://localhost:8088
# Default credentials: admin / admin
```

### Via Ingress (Public Access)
Requires DNS record for `analytics.academyv2.mereka.io` pointing to `34.177.83.168`.

URL: https://analytics.academyv2.mereka.io

## Connect ClickHouse to Superset

After Superset is running:

1. Login to Superset
2. Go to Settings → Database Connections → + Database
3. Select "ClickHouse Connect"
4. Use connection string:
   ```
   clickhousedb+connect://openedx:PASSWORD@clickhouse:8123/openedx
   ```
5. Test connection and save

## Resource Requirements

| Service | Memory Request | Memory Limit | CPU Request | CPU Limit |
|---------|---------------|--------------|-------------|-----------|
| ClickHouse | 2Gi | 4Gi | 500m | 2 |
| Superset | 1Gi | 2Gi | 250m | 1 |
| Superset Worker | 512Mi | 1Gi | 200m | 500m |

**Total**: ~3.5Gi memory request, 7Gi limit

## Files

- `configmaps.yml` - ClickHouse and Superset configuration
- `secrets.yml` - Template for secrets (replace before deploying)
- `volumes.yml` - Persistent storage for ClickHouse
- `services.yml` - ClusterIP services
- `deployments.yml` - ClickHouse, Superset, Superset Worker
- `jobs.yml` - Initialization jobs
- `ingress.yml` - Optional public access via NGINX Ingress

## Troubleshooting

### ClickHouse won't start
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=clickhouse
kubectl describe pod -n mereka-lms -l app.kubernetes.io/name=clickhouse
```

### Superset init job fails
```bash
kubectl logs -n mereka-lms job/superset-init
# Check if MySQL database exists and is accessible
```

### Reset Superset admin password
```bash
kubectl exec -n mereka-lms deploy/superset -- superset fab reset-password --username admin --password newpassword
```
