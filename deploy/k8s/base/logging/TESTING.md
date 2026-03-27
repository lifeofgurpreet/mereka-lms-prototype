# Testing GKE to VPS Loki Log Forwarding

## Quick Health Check

```bash
# 1. Check Promtail pods are running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=promtail

# Expected: 3 pods (one per node), all READY 1/1, STATUS Running
```

## Verify Log Flow

### 1. Query Logs via Loki API

```bash
# Get recent logs from any mereka-lms pod
curl -s -G "https://loki.mereka.dev/loki/api/v1/query" \
  --data-urlencode 'query={namespace="mereka-lms"}' \
  --data-urlencode 'limit=5' | jq

# Get LMS logs specifically
curl -s -G "https://loki.mereka.dev/loki/api/v1/query" \
  --data-urlencode 'query={namespace="mereka-lms", app="lms"}' \
  --data-urlencode 'limit=5' | jq -r '.data.result[0].values[0][1]'

# Get error logs only
curl -s -G "https://loki.mereka.dev/loki/api/v1/query" \
  --data-urlencode 'query={namespace="mereka-lms"} |~ "(?i)error"' \
  --data-urlencode 'limit=10' | jq -r '.data.result[].values[][1]'
```

### 2. Check Available Labels

```bash
# List all label names
curl -s "https://loki.mereka.dev/loki/api/v1/label" | jq -r '.data[]'

# Should include: namespace, app, cluster, environment, pod, container, node, instance

# List all apps
curl -s "https://loki.mereka.dev/loki/api/v1/label/app/values" | jq -r '.data[]'

# Should include: lms, cms, mfe, caddy, discovery, notes, etc.
```

### 3. Query by Time Range

```bash
# Last 5 minutes
curl -s -G "https://loki.mereka.dev/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="mereka-lms"}' \
  --data-urlencode "start=$(date -u -d '5 minutes ago' +%s)000000000" \
  --data-urlencode "end=$(date -u +%s)000000000" \
  --data-urlencode 'limit=100' | jq -r '.data.result[0].values[][1]' | head -20
```

### 4. Check Specific Pod Logs

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

# Query logs for that pod
curl -s -G "https://loki.mereka.dev/loki/api/v1/query" \
  --data-urlencode "query={namespace=\"mereka-lms\", pod=\"$POD_NAME\"}" \
  --data-urlencode 'limit=10' | jq -r '.data.result[0].values[][1]'
```

## Debugging

### Check Promtail Status

```bash
# View Promtail logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=promtail --tail=100

# Look for:
# - "Adding target" messages (discovering pods)
# - "tail routine: started" (reading logs)
# - No errors about connection failures to Loki

# Check Promtail metrics
kubectl port-forward -n mereka-lms svc/promtail 9080:9080 &
curl http://localhost:9080/metrics | grep promtail_sent_entries_total
kill %1  # Stop port-forward
```

### Verify Network Connectivity

```bash
# Test Loki endpoint from GKE
kubectl run -n mereka-lms curl-test --image=curlimages/curl --rm -it -- \
  curl -v https://loki.mereka.dev/ready

# Expected: "ready" response

# Test Loki push endpoint
kubectl run -n mereka-lms curl-test --image=curlimages/curl --rm -it -- \
  curl -v -X POST https://loki.mereka.dev/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{"streams":[{"stream":{"test":"value"},"values":[["'$(date +%s)000000000'","test message"]]}]}'

# Expected: HTTP 204 No Content (success) or 400 (malformed but endpoint works)
```

### Check Promtail Configuration

```bash
# View Promtail config
kubectl get configmap -n mereka-lms promtail-config -o yaml

# Verify:
# - clients[0].url: https://loki.mereka.dev/loki/api/v1/push
# - scrape_configs includes kubernetes-pods job
# - relabel_configs filters namespace=mereka-lms
```

### Check for Errors in Loki (VPS)

```bash
# On VPS, check Loki container logs
docker logs loki --tail=100 | grep -i error

# Check for incoming POST requests
docker logs loki --tail=100 | grep "POST /loki/api/v1/push"

# Should see regular POST requests from GKE Promtail instances
```

## Performance Monitoring

### Promtail Resource Usage

```bash
# Check CPU and memory usage
kubectl top pods -n mereka-lms -l app.kubernetes.io/name=promtail

# Expected: < 100m CPU, < 100Mi memory per pod
```

### Log Volume Stats

```bash
# Count logs by app
curl -s -G "https://loki.mereka.dev/loki/api/v1/query" \
  --data-urlencode 'query=count_over_time({namespace="mereka-lms"}[1h])' | \
  jq -r '.data.result[] | "\(.metric.app): \(.value[1])"'

# Check ingestion rate (on VPS)
docker exec loki wget -qO- http://localhost:3101/metrics | grep loki_ingester_streams_created_total
```

## Example Queries for Common Use Cases

### Find All Errors in Last Hour

```bash
curl -s -G "https://loki.mereka.dev/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="mereka-lms"} |~ "(?i)(error|exception|failed)"' \
  --data-urlencode "start=$(date -u -d '1 hour ago' +%s)000000000" \
  --data-urlencode "end=$(date -u +%s)000000000" \
  --data-urlencode 'limit=100' | \
  jq -r '.data.result[].values[][1]' | grep -i error
```

### Trace a Request by ID

```bash
# If logs contain request_id field
curl -s -G "https://loki.mereka.dev/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="mereka-lms"} | json | request_id="abc123"' \
  --data-urlencode "start=$(date -u -d '1 hour ago' +%s)000000000" \
  --data-urlencode "end=$(date -u +%s)000000000" | \
  jq -r '.data.result[].values[][1]'
```

### Monitor Specific Service Health

```bash
# Check CMS worker errors
curl -s -G "https://loki.mereka.dev/loki/api/v1/query" \
  --data-urlencode 'query={namespace="mereka-lms", app="cms-worker"} |~ "(?i)error"' \
  --data-urlencode 'limit=20' | \
  jq -r '.data.result[].values[][1]'
```

### Compare Log Rates Across Services

```bash
# Get log rate per service (last 5 minutes)
curl -s -G "https://loki.mereka.dev/loki/api/v1/query" \
  --data-urlencode 'query=rate({namespace="mereka-lms"}[5m])' | \
  jq -r '.data.result[] | "\(.metric.app): \(.value[1])"' | sort -t: -k2 -rn
```

## Integration with Grafana

If you have Grafana connected to VPS Loki:

1. **Add Loki datasource** (if not already added):
   - URL: `https://loki.mereka.dev`
   - Access: Server (default)
   - No auth required (already behind Cloudflare)

2. **Explore logs**:
   - Navigate to Explore → Select Loki datasource
   - Use LogQL queries:
     ```logql
     {namespace="mereka-lms"}
     {namespace="mereka-lms", app="lms"}
     {namespace="mereka-lms"} |~ "error"
     ```

3. **Create dashboards**:
   - Add Log panel
   - Query: `{namespace="mereka-lms", app="$app"}`
   - Add variable `$app` from label values

4. **Set up alerts**:
   - Create alert rule based on LogQL query
   - Example: `count_over_time({namespace="mereka-lms"} |~ "ERROR" [5m]) > 10`
   - Route to Alertmanager on VPS

## Expected Results

After successful deployment, you should see:

- **3 Promtail pods** running (one per GKE node)
- **Logs appearing in Loki** within 1-2 minutes
- **Labels correctly applied**: namespace, app, pod, container, node, cluster, environment
- **No errors** in Promtail logs about connection failures
- **Steady log ingestion** visible in Loki metrics

## Rollback

If you need to remove the log forwarder:

```bash
kubectl delete -k deploy/k8s/base/logging

# This will delete:
# - Promtail DaemonSet
# - Promtail ConfigMap
# - Promtail Service
# - Promtail ServiceAccount
# - ClusterRole and ClusterRoleBinding
```

Existing logs in VPS Loki will remain (14 day retention).
