# Open edX Monitoring Resources

This directory contains Prometheus Operator resources for monitoring Open edX services in GKE.

## Status

**IMPORTANT**: Open edX does not expose Prometheus metrics by default.

The LMS service currently returns HTTP 400 when accessing `/metrics`. This is expected behavior as:
- Django's `prometheus_client` is not installed or configured
- Open edX uses its own metrics system (tracking logs, datadog integration)
- Enabling Prometheus metrics would require custom Django middleware

## Resources Created

1. **servicemonitor-lms.yaml**: ServiceMonitor for LMS pods (currently non-functional)
2. **prometheusrule-lms.yaml**: Alert rules based on standard uWSGI/HTTP metrics

## Next Steps

To enable Prometheus metrics in Open edX:

1. Install `django-prometheus` in the openedx image
2. Add `django_prometheus` to INSTALLED_APPS in settings
3. Add `django_prometheus.middleware.PrometheusBeforeMiddleware` and `PrometheusAfterMiddleware`
4. Mount `/metrics` endpoint in URL configuration
5. Update ServiceMonitor to target the correct port

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
