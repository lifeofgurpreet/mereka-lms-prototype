# GKE to VPS Loki Log Forwarding

## Overview

This document describes the log forwarding setup that sends logs from the GKE `mereka-lms` namespace to the VPS Loki instance for unified search and monitoring.

## Architecture Decision

After evaluating three options for log forwarding from GKE to VPS Loki:

| Option | Pros | Cons | Resource Usage |
|--------|------|------|----------------|
| **Promtail DaemonSet** | Native Loki integration, battle-tested, minimal config | Additional component | ~50-100MB RAM per node |
| Grafana Alloy | Modern, multi-purpose | Overkill for logs-only, less documentation | ~100-200MB RAM per node |
| Fluent Bit | Ultra-lightweight | Complex Loki output config, not native | ~20-50MB RAM per node |

**Decision**: Promtail DaemonSet (Option A)

**Rationale**:
- Native Loki integration with minimal configuration
- Battle-tested and well-documented
- Automatic Kubernetes service discovery
- Built-in retry logic and batching
- Acceptable resource overhead (200m CPU, 128Mi RAM per pod)

## Implementation

### Components Deployed

Located in `/home/gurpreet/projects/k8s/mereka-lms/deploy/k8s/base/logging/`:

1. **promtail-daemonset.yaml** - Runs one Promtail pod per GKE node
2. **promtail-configmap.yaml** - Scrape config with JSON parsing and label extraction
3. **promtail-rbac.yaml** - ServiceAccount, ClusterRole, ClusterRoleBinding for K8s API access
4. **promtail-service.yaml** - ClusterIP service exposing metrics on port 9080
5. **kustomization.yaml** - Kustomize bundle for all resources

### Log Flow

```
GKE Pods (mereka-lms namespace)
  ↓
/var/log/pods/*.log (container logs)
  ↓
Promtail DaemonSet (reads logs, parses JSON, adds labels)
  ↓
HTTPS POST to https://loki.mereka.dev/loki/api/v1/push
  ↓
VPS Loki (194.233.84.55:3102)
  ↓
Stored in /loki (14 day retention)
  ↓
Queryable via Loki API or Grafana
```

### Labels Applied

All logs are enriched with these labels:

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

### Log Parsing

Promtail automatically:
- Extracts JSON fields (`level`, `logger`, `module`, `request_id`, `message`, `timestamp`)
- Parses log levels from various formats (INFO, ERROR, DEBUG, WARNING, etc.)
- Adds Kubernetes metadata as labels
- Preserves original message content

## Deployment

### Initial Deployment

```bash
cd /home/gurpreet/projects/k8s/mereka-lms
kubectl apply -k deploy/k8s/base/logging
```

Deployed on: 2026-02-04

### Verification

```bash
# Check Promtail pods
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=promtail

# Expected: 3 pods (one per node), all Running

# Query logs in Loki
curl -s -G "https://loki.mereka.dev/loki/api/v1/query" \
  --data-urlencode 'query={namespace="mereka-lms"}' \
  --data-urlencode 'limit=5' | jq
```

See [TESTING.md](../../deploy/k8s/base/logging/TESTING.md) for comprehensive testing instructions.

## Configuration

### Loki Push Endpoint

- **URL**: `https://loki.mereka.dev/loki/api/v1/push`
- **Port**: 3102 (internal), 443 (HTTPS via Cloudflare)
- **TLS**: Enabled (Cloudflare-provided certificate)
- **Authentication**: None (VPS behind Cloudflare firewall)

### Batch Configuration

To optimize network usage and reduce load on Loki:

- **Batch size**: 1MB (1048576 bytes)
- **Batch wait**: 1 second
- **Timeout**: 10 seconds per batch
- **Retry**: Exponential backoff (500ms to 5m, max 10 retries)

### Resource Limits

Per Promtail pod (3 pods total):

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

Total cluster overhead: ~600m CPU, ~384Mi RAM

## Network Requirements

### Connectivity

- **Source**: GKE cluster NAT IP (egress)
- **Destination**: VPS `194.233.84.55` (loki.mereka.dev)
- **Protocol**: HTTPS (TCP port 443)
- **DNS**: Resolved via Cloudflare

### Firewall Rules

VPS firewall must allow HTTPS (port 443) from GKE:

```bash
# On VPS (already configured)
sudo ufw allow 443/tcp
```

GKE has no egress restrictions (default allow all).

### Alternative: Cloudflare Tunnel

If direct access to VPS is ever blocked, consider using Cloudflare Tunnel:

1. Create tunnel on VPS: `cloudflared tunnel create mereka-loki`
2. Expose Loki: `cloudflared tunnel route dns mereka-loki loki-internal.mereka.dev`
3. Update Promtail config URL to tunnel endpoint

## Security

### Encryption

- **In-transit**: All logs encrypted via HTTPS (TLS 1.3)
- **At-rest**: VPS storage encrypted (LUKS)

### Authentication

- **Loki**: Currently no authentication (`auth_enabled: false` in Loki config)
- **Rationale**: VPS is behind Cloudflare firewall, access controlled by Cloudflare Access
- **Future**: Consider adding basic auth or token-based auth if exposing publicly

### Access Control

- **Promtail RBAC**: Read-only access to pods, nodes, services in GKE cluster
- **ServiceAccount**: `promtail` in `mereka-lms` namespace
- **ClusterRole**: `promtail-mereka-lms` with minimal permissions

### Sensitive Data

Logs may contain:
- User IDs and email addresses
- IP addresses
- Request paths (may include query params)
- Error messages (may include sensitive debug info)

**Recommendations**:
1. Add redaction pipeline stages if needed (e.g., mask email addresses)
2. Ensure VPS access is restricted to authorized personnel
3. Monitor Loki access logs for unauthorized queries

## Monitoring

### Promtail Metrics

Exposed on each Promtail pod at `:9080/metrics`:

- `promtail_sent_entries_total` - Total log entries sent to Loki
- `promtail_sent_bytes_total` - Total bytes sent to Loki
- `promtail_dropped_entries_total` - Dropped entries (should be 0)
- `promtail_targets_active_total` - Number of active log targets (should match pod count)

### Loki Metrics

Exposed on VPS Loki at `http://localhost:3101/metrics`:

- `loki_ingester_streams_created_total` - Total log streams created
- `loki_distributor_bytes_received_total` - Total bytes received
- `loki_request_duration_seconds` - Query latency

### Alerting

Consider setting up alerts for:

1. **Promtail pod crashes**: `kube_pod_status_phase{namespace="mereka-lms",pod=~"promtail.*"} != 1`
2. **Log ingestion stopped**: `rate(loki_distributor_bytes_received_total[5m]) == 0`
3. **High error rate**: `count_over_time({namespace="mereka-lms"} |~ "ERROR" [5m]) > 100`
4. **Loki disk full**: `(node_filesystem_avail_bytes{mountpoint="/loki"} / node_filesystem_size_bytes{mountpoint="/loki"}) < 0.1`

## Troubleshooting

### Logs Not Appearing in Loki

1. **Check Promtail pods are running**:
   ```bash
   kubectl get pods -n mereka-lms -l app.kubernetes.io/name=promtail
   ```

2. **Check Promtail logs for errors**:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=promtail --tail=100 | grep -i error
   ```

3. **Test network connectivity from GKE**:
   ```bash
   kubectl run -n mereka-lms curl-test --image=curlimages/curl --rm -it -- \
     curl -v https://loki.mereka.dev/ready
   ```

4. **Verify Loki is receiving logs (on VPS)**:
   ```bash
   docker logs loki --tail=100 | grep "POST /loki/api/v1/push"
   ```

### High Resource Usage

If Promtail uses too much CPU/memory:

1. **Check current usage**:
   ```bash
   kubectl top pods -n mereka-lms -l app.kubernetes.io/name=promtail
   ```

2. **Reduce batch frequency**: Edit ConfigMap, increase `batchwait` from 1s to 5s
3. **Reduce batch size**: Lower `batchsize` from 1MB to 512KB
4. **Add log filtering**: Exclude verbose debug logs via pipeline stages

### Missing Labels

If logs are missing expected labels:

1. **Check relabel config** in ConfigMap `promtail-config`
2. **Verify pod labels** are set correctly:
   ```bash
   kubectl get pods -n mereka-lms --show-labels
   ```
3. **Test with specific label query**:
   ```bash
   curl -s "https://loki.mereka.dev/loki/api/v1/label/app/values" | jq
   ```

## Maintenance

### Update Promtail Version

1. Edit `deploy/k8s/base/logging/promtail-daemonset.yaml`
2. Change image tag: `grafana/promtail:2.9.6` → `grafana/promtail:2.x.x`
3. Apply: `kubectl apply -k deploy/k8s/base/logging`
4. Monitor rollout: `kubectl rollout status daemonset/promtail -n mereka-lms`

### Adjust Log Retention

Retention is configured on VPS Loki (currently 14 days).

Edit `/home/gurpreet/projects/vps/infrastructure/loki/loki-config.yaml`:

```yaml
limits_config:
  retention_period: 336h  # 14 days (change as needed)
```

Then restart Loki:
```bash
cd /home/gurpreet/projects/vps/infrastructure
docker compose restart loki
```

### Scale Promtail

Promtail runs as a DaemonSet, automatically scaling with cluster nodes. To adjust:

1. **CPU/memory limits**: Edit `promtail-daemonset.yaml` resources section
2. **Node selection**: Add `nodeSelector` or `tolerations` to DaemonSet spec

## Costs

### GKE

- **CPU**: ~600m total (3 nodes × 200m limit) = negligible cost (~$0.01/day)
- **Memory**: ~384Mi total (3 nodes × 128Mi limit) = negligible cost
- **Network egress**: ~5-10GB/day to VPS (within GCP → Internet free tier)

Estimated cost: **< $1/month**

### VPS

- **Storage**: ~2-5GB/day, 14 day retention = ~70GB total
- **Already provisioned**: 1TB SSD, plenty of headroom
- **Network**: Ingress free on Contabo

Estimated incremental cost: **$0/month** (within existing VPS plan)

## Future Enhancements

1. **Authentication**: Add basic auth or token-based auth to Loki push endpoint
2. **Compression**: Enable gzip compression for log batches (reduce network usage)
3. **Multi-region**: If deploying GKE in multiple regions, consider regional Loki instances
4. **Log sampling**: For high-volume services, implement probabilistic sampling
5. **Structured logging**: Enforce JSON logging format across all services for better parsing
6. **Alert rules**: Deploy Loki alerting rules to VPS Alertmanager
7. **Grafana dashboards**: Create pre-built dashboards for common queries

## References

- **Promtail documentation**: https://grafana.com/docs/loki/latest/send-data/promtail/
- **Loki API**: https://grafana.com/docs/loki/latest/reference/api/
- **LogQL query language**: https://grafana.com/docs/loki/latest/query/
- **Kubernetes service discovery**: https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#kubernetes_sd_config
- **Deployment manifests**: `/home/gurpreet/projects/k8s/mereka-lms/deploy/k8s/base/logging/`
- **Testing guide**: [deploy/k8s/base/logging/TESTING.md](../../deploy/k8s/base/logging/TESTING.md)

---

**Last Updated**: 2026-02-04
**Deployed By**: Claude Sonnet 4.5 (Agent implementor)
**Status**: Production (mereka-lms namespace)
