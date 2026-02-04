# Open edX Monitoring Resources

This directory contains Prometheus Operator resources for monitoring Open edX services in GKE.

## Status

**UPDATED (2026-02-04)**: Prometheus metrics integration has been implemented via **Bead mereka-lms-2s8**.

The `/metrics` endpoint will be functional after rebuilding the Open edX image with django-prometheus integration.

## Resources Created

1. **servicemonitor-lms.yaml**: ServiceMonitor for LMS pods
2. **servicemonitor-cms.yaml**: ServiceMonitor for CMS pods
3. **prometheusrule-lms.yaml**: Alert rules based on kubelet and application metrics

## Metrics Integration

### Implementation (Bead mereka-lms-2s8)

Django-prometheus has been integrated into the Open edX image:

1. **Custom app created**: `infrastructure/tutor/custom-apps/openedx_prometheus/`
2. **Package installed**: `django-prometheus==2.3.1` added to Open edX requirements
3. **Configuration**: Middleware and INSTALLED_APPS configured via `apply-patches.sh`
4. **Endpoint exposed**: `/metrics` accessible via nginx configuration
5. **Documentation**: See `infrastructure/tutor/README.md` and custom app README

### Activating Metrics

**Rebuild the Open edX image** (required to include django-prometheus):

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

## Alternative Monitoring

Until native Prometheus metrics are enabled, consider:

1. **Container metrics**: CPU, memory, disk from kubelet (already collected by kube-state-metrics)
2. **MySQL metrics**: Use mysqld-exporter sidecar
3. **Redis metrics**: Use redis-exporter sidecar
4. **Application logs**: Ship to Loki via Promtail (already configured)
5. **Traces**: OpenTelemetry integration (future work)

## References

- [Django Prometheus](https://github.com/korfuri/django-prometheus)
- [Open edX Monitoring](https://docs.tutor.edly.io/tutorials/monitoring.html)
