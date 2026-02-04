# GKE to VPS Loki Log Forwarding

This directory contains the Kubernetes manifests for forwarding logs from the GKE `mereka-lms` namespace to the VPS Loki instance at `https://loki.mereka.dev`.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GKE Cluster (bbi-k8-cluster)            │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │        mereka-lms Namespace                        │    │
│  │                                                     │    │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐           │    │
│  │  │ LMS  │  │ CMS  │  │ MFE  │  │Worker│           │    │
│  │  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘           │    │
│  │     │         │         │         │                │    │
│  │     └─────────┴─────────┴─────────┘                │    │
│  │                   │                                 │    │
│  │                   ▼                                 │    │
│  │        /var/log/pods/*.log                         │    │
│  │                   │                                 │    │
│  │                   ▼                                 │    │
│  │  ┌────────────────────────────────────────┐        │    │
│  │  │   Promtail DaemonSet (on each node)    │        │    │
│  │  │   - Discovers pods via K8s API         │        │    │
│  │  │   - Parses JSON logs                   │        │    │
│  │  │   - Extracts labels (pod, app, level)  │        │    │
│  │  └────────────────┬───────────────────────┘        │    │
│  │                   │                                 │    │
│  └───────────────────┼─────────────────────────────────┘    │
│                      │                                      │
└──────────────────────┼──────────────────────────────────────┘
                       │
                       │ HTTPS (TLS via Cloudflare)
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              VPS (194.233.84.55 - acfs)                     │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Loki (https://loki.mereka.dev:3102)             │      │
│  │  - Receives logs via /loki/api/v1/push           │      │
│  │  - Stores in /loki (14 day retention)            │      │
│  │  - Indexed for search: {namespace="mereka-lms"}  │      │
│  └──────────────────────────────────────────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Promtail DaemonSet
- **Image**: `grafana/promtail:2.9.6`
- **Deployment**: One pod per GKE node
- **Resource Limits**: 200m CPU, 128Mi RAM per pod
- **Function**:
  - Watches `/var/log/pods/` for container logs
  - Filters for `mereka-lms` namespace only
  - Parses JSON logs and extracts metadata
  - Batches and forwards to VPS Loki

### 2. ConfigMap
- **Name**: `promtail-config`
- **Contains**: Promtail scrape configuration
- **Features**:
  - JSON log parsing (extracts `level`, `logger`, `module`, `request_id`)
  - Automatic label extraction from K8s metadata
  - Retry logic for network failures
  - Batching for efficiency (1MB batches, 1s wait)

### 3. RBAC
- **ServiceAccount**: `promtail`
- **ClusterRole**: `promtail-mereka-lms`
- **Permissions**: Read-only access to pods, nodes, services in cluster

### 4. Service
- **Name**: `promtail`
- **Port**: 9080 (metrics endpoint)
- **Type**: ClusterIP
- **Prometheus**: Auto-scraped via annotations

## Labels Applied to Logs

All logs forwarded to Loki will have these labels:

| Label | Source | Example |
|-------|--------|---------|
| `namespace` | K8s namespace | `mereka-lms` |
| `pod` | K8s pod name | `lms-7f76f7fc87-2czkd` |
| `container` | Container name | `lms` |
| `app` | K8s app label | `lms`, `cms`, `mfe` |
| `component` | K8s component label | `web`, `worker` |
| `node` | K8s node name | `gke-bbi-k8-cluster-...` |
| `instance` | Pod IP | `10.100.0.124` |
| `environment` | Static | `gke-production` |
| `cluster` | Static | `bbi-k8-cluster` |
| `level` | Parsed from log | `INFO`, `ERROR`, `DEBUG` |
| `logger` | Parsed from JSON | (if present) |
| `module` | Parsed from JSON | (if present) |

## Deployment

### Deploy to GKE

```bash
# From repository root
cd /home/gurpreet/projects/k8s/mereka-lms

# Preview changes
kubectl kustomize deploy/k8s/base/logging

# Apply to cluster
kubectl apply -k deploy/k8s/base/logging

# Verify deployment
kubectl get daemonset -n mereka-lms promtail
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=promtail
```

### Verify Logs are Forwarding

```bash
# Check Promtail pod logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=promtail --tail=50

# Should see messages like:
# level=info msg="Successfully sent batch" ...
```

### Query Logs in Loki

```bash
# Via LogCLI (if installed on VPS)
logcli query '{namespace="mereka-lms"}' --limit=10 --since=1h

# Via Loki HTTP API
curl -G -s "https://loki.mereka.dev/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="mereka-lms"}' \
  --data-urlencode 'limit=10' | jq

# Via Grafana Explore UI
# Navigate to: https://grafana.mereka.dev/explore
# Select Loki datasource
# Query: {namespace="mereka-lms"}
```

## Troubleshooting

### Promtail pods not starting

```bash
# Check pod status
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=promtail

# Check events
kubectl describe daemonset -n mereka-lms promtail

# Check RBAC
kubectl auth can-i list pods --as=system:serviceaccount:mereka-lms:promtail
```

### Logs not appearing in Loki

```bash
# 1. Check Promtail is sending logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=promtail --tail=100 | grep -i error

# 2. Test Loki endpoint from GKE pod
kubectl run -n mereka-lms curl-test --image=curlimages/curl --rm -it -- \
  curl -v https://loki.mereka.dev/ready

# 3. Check Promtail metrics
kubectl port-forward -n mereka-lms svc/promtail 9080:9080
curl http://localhost:9080/metrics | grep promtail_sent_entries_total

# 4. Verify Loki received logs (on VPS)
docker logs loki --tail=100 | grep "POST /loki/api/v1/push"
```

### Network connectivity issues

If GKE cannot reach `https://loki.mereka.dev`:

1. **Verify DNS**:
   ```bash
   kubectl run -n mereka-lms dns-test --image=busybox --rm -it -- nslookup loki.mereka.dev
   ```

2. **Verify TLS**:
   ```bash
   kubectl run -n mereka-lms tls-test --image=curlimages/curl --rm -it -- \
     curl -vI https://loki.mereka.dev
   ```

3. **Check firewall rules**: Ensure VPS firewall allows HTTPS from GKE cluster IPs
   ```bash
   # On VPS
   sudo ufw status | grep 443
   ```

4. **Alternative: Use Cloudflare Tunnel** (if direct access blocked):
   - Create a Cloudflare Tunnel on VPS
   - Expose Loki through tunnel
   - Update Promtail config to use tunnel URL

### High resource usage

If Promtail uses too much memory/CPU:

1. **Reduce batch size**: Edit `promtail-configmap.yaml`, reduce `batchsize` from 1MB to 512KB
2. **Increase batch wait**: Change `batchwait` from 1s to 5s
3. **Add log filtering**: Exclude verbose debug logs via pipeline stages

## Maintenance

### Update Promtail version

```bash
# Edit promtail-daemonset.yaml, update image tag
# Then apply
kubectl apply -k deploy/k8s/base/logging

# Promtail will rolling update (one node at a time)
kubectl rollout status daemonset/promtail -n mereka-lms
```

### Adjust log retention

Retention is configured on VPS Loki (currently 14 days). Edit `/home/gurpreet/projects/vps/infrastructure/loki/loki-config.yaml`:

```yaml
limits_config:
  retention_period: 336h  # Change this value
```

Then restart Loki:
```bash
cd /home/gurpreet/projects/vps/infrastructure
docker compose restart loki
```

## Security Notes

1. **TLS encryption**: All logs are encrypted in transit via HTTPS (Cloudflare-provided cert)
2. **Authentication**: Currently disabled on Loki (auth_enabled: false)
   - VPS is behind Cloudflare firewall
   - Consider adding basic auth if exposing publicly
3. **RBAC**: Promtail has minimal permissions (read-only pods/nodes)
4. **Log content**: Logs may contain sensitive data (user IDs, IPs, etc.)
   - Consider adding redaction pipeline stages if needed
   - Ensure VPS storage is encrypted

## Resources

- **Promtail docs**: https://grafana.com/docs/loki/latest/send-data/promtail/
- **Loki docs**: https://grafana.com/docs/loki/latest/
- **K8s scraping**: https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#kubernetes_sd_config
- **Pipeline stages**: https://grafana.com/docs/loki/latest/send-data/promtail/stages/

## Example Queries

```logql
# All logs from LMS pods
{namespace="mereka-lms", app="lms"}

# Error logs only
{namespace="mereka-lms"} |~ "(?i)error"

# Logs from specific pod
{namespace="mereka-lms", pod="lms-7f76f7fc87-2czkd"}

# Rate of errors per minute
rate({namespace="mereka-lms"} |~ "ERROR" [1m])

# Logs with request_id (for tracing)
{namespace="mereka-lms"} | json | request_id != ""
```
