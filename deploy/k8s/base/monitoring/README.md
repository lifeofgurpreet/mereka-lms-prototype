# Open edX Monitoring Resources

This directory contains Prometheus Operator resources for monitoring Open edX services in GKE.

## Status

**UPDATED (2026-02-25)**: Prometheus metrics integration is present in repo and enforced as a runtime contract.

Runtime contract for observability readiness:
- LMS `/metrics` MUST return `HTTP 200`
- CMS `/metrics` MUST return `HTTP 200`

## Resources Created

1. **servicemonitor-lms.yaml**: ServiceMonitor for LMS pods
2. **servicemonitor-cms.yaml**: ServiceMonitor for CMS pods
3. **servicemonitor-mysql.yaml**: ServiceMonitor for mysqld-exporter sidecar metrics
4. **servicemonitor-redis.yaml**: ServiceMonitor for redis-exporter sidecar metrics
5. **prometheusrule-lms.yaml**: Alert rules based on kubelet, app, and data-store exporter metrics
   - LMS/CMS availability and saturation
   - data service availability (MySQL/Redis/MongoDB/Elasticsearch)
   - MySQL deep telemetry (`threads_connected/max_connections`, slow query spike)
   - Redis deep telemetry (rejected connections, evictions)
   - critical deployment unavailable replicas
   - pods stuck pending / CrashLoopBackOff
   - synthetic/backup job failures (`auth-verify-prod`, `cert-verify-prod`, `backup-verification`, `restore-test`)

## Metrics Integration

### Implementation (Bead mereka-lms-2s8)

Django-prometheus has been integrated into the Open edX image:

1. **Custom app created**: `infrastructure/tutor/custom-apps/openedx_prometheus/`
2. **Package installed**: `django-prometheus==2.3.1` added to Open edX requirements
3. **Configuration**: Middleware and INSTALLED_APPS configured via `apply-patches.sh`
4. **Endpoint exposed**: `/metrics` accessible via nginx configuration
5. **Documentation**: See `infrastructure/tutor/README.md` and custom app README

### Activating Metrics (when rollout image is stale)

If runtime does not expose `/metrics` as expected, rebuild and roll out Open edX image:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Apply patches (includes prometheus integration)
./infrastructure/tutor/apply-patches.sh

# Rebuild Open edX image (takes 30-45 min, needs 12GB+ RAM)
tutor images build openedx

# For production
docker tag local/openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:latest
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:latest

# Restart pods
kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
```

### Verification

After image rebuild:

```bash
# Test /metrics endpoint
kubectl exec -n mereka-lms deploy/lms -- curl -s localhost:8000/metrics | head -20

# Check Prometheus is scraping
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090/targets (search for "lms-metrics")
```

Alert/rule validation:

```bash
# YAML/schema sanity
kubectl apply --dry-run=client -f deploy/k8s/base/monitoring/prometheusrule-lms.yaml

# Runtime dashboard + datasource + contract check
./scripts/infra/validate-telemetry-connectivity.sh --strict
REQUIRE_GRAFANA_RECOMMENDED=1 ./scripts/infra/validate-telemetry-connectivity.sh --strict
```

## Data-store Exporter Telemetry

Deep data-store telemetry is now baked into base manifests:
- `deploy/k8s/base/deployments.yml`: `mysqld-exporter` and `redis-exporter` sidecars
- `deploy/k8s/base/services.yml`: metrics service ports (9104/9121)
- `deploy/k8s/base/monitoring/servicemonitor-*.yaml`: scrape wiring

Read-only contract audit:
```bash
./scripts/qa/audit-db-exporter-telemetry.sh --mode local
```

Runtime verification (after GitOps/apply rollout):
```bash
STRICT_RUNTIME=1 ./scripts/qa/audit-db-exporter-telemetry.sh --mode runtime
```

Full gate (includes exporter contract in local mode by default):
```bash
CHECK_TIMEOUT_SECONDS=1200 ./scripts/qa/run-operations-gates.sh --env both
```

## References

- [Django Prometheus](https://github.com/korfuri/django-prometheus)
- [Open edX Monitoring](https://docs.tutor.edly.io/tutorials/monitoring.html)
