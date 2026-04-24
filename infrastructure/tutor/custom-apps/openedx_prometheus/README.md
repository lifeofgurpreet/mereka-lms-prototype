# Open edX Prometheus Integration

This custom Django app enables Prometheus metrics collection for Open edX LMS and CMS.

## What It Does

1. Installs `django-prometheus` package
2. Adds Django middleware to track request metrics
3. Exposes `/metrics` endpoint in Prometheus format
4. Tracks database query metrics
5. Tracks cache operations

## Metrics Exposed

### HTTP Metrics
- `django_http_requests_total_by_method` - Request count by HTTP method
- `django_http_requests_total_by_view` - Request count by view name
- `django_http_responses_total_by_status` - Response count by status code
- `django_http_requests_latency_seconds` - Request latency histogram

### Database Metrics
- `django_db_query_duration_seconds` - Database query duration
- `django_db_execute_total` - Total number of database queries

### Cache Metrics
- `django_cache_get_total` - Cache get operations
- `django_cache_hits_total` - Cache hit count
- `django_cache_misses_total` - Cache miss count

### Django Metrics
- `django_migrations_applied_total` - Number of applied migrations
- `django_model_inserts_total` - Model insert operations
- `django_model_updates_total` - Model update operations
- `django_model_deletes_total` - Model delete operations

## Integration

This app is automatically installed via `apply-patches.sh`:

1. **Dockerfile patch**: Copies app to `/openedx/openedx_prometheus` and installs django-prometheus
2. **Settings patch**: Adds app to INSTALLED_APPS and middleware configuration
3. **URL patch**: Mounts `/metrics` endpoint for both LMS and CMS

## Configuration in Open edX

### INSTALLED_APPS
```python
INSTALLED_APPS = [
    'django_prometheus',  # Must be first
    # ... other apps ...
    'openedx_prometheus',  # Our custom app
]
```

### MIDDLEWARE
```python
MIDDLEWARE = [
    'django_prometheus.middleware.PrometheusBeforeMiddleware',  # Must be first
    # ... other middleware ...
    'django_prometheus.middleware.PrometheusAfterMiddleware',  # Must be last
]
```

### URL Configuration
```python
# In lms/urls.py and cms/urls.py
urlpatterns += [
    path('metrics', include('openedx_prometheus.urls')),
]
```

## Verification

Test that metrics are exposed:

```bash
# Local development
curl http://localhost/metrics | head -20

# Kubernetes
kubectl exec -n mereka-lms deploy/lms -- curl -s localhost:8000/metrics | head -20
```

Expected output:
```
# HELP django_http_requests_total_by_method Count of requests by method
# TYPE django_http_requests_total_by_method counter
django_http_requests_total_by_method{method="GET"} 42
...
```

## Performance Impact

django-prometheus has minimal performance impact:
- ~1-2ms overhead per request
- Memory overhead: ~10-20MB for metrics storage
- No external dependencies
- All metrics stored in-memory

## Security Considerations

The `/metrics` endpoint is accessible without authentication. In production:

1. **Kubernetes**: Metrics are only accessible within the cluster (ServiceMonitor scrapes internal port)
2. **Public LMS**: Metrics endpoint should be blocked by Caddy/nginx for external traffic
3. **Sensitive data**: Metrics do not contain user data, only aggregate counters

## Troubleshooting

### Metrics endpoint returns 400
- Check that django-prometheus is installed: `pip list | grep django-prometheus`
- Verify INSTALLED_APPS includes 'django_prometheus'
- Check middleware is configured correctly

### Metrics endpoint returns 404
- Verify URL configuration includes openedx_prometheus.urls
- Check that the app is in INSTALLED_APPS

### High memory usage
- Default metrics retention is in-memory only
- Prometheus scrapes every 30s, so no long-term storage in Django
- If memory is a concern, consider disabling per-view metrics

## References

- [django-prometheus Documentation](https://github.com/korfuri/django-prometheus)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [Open edX Monitoring](https://docs.tutor.edly.io/tutorials/monitoring.html)
