"""
URL configuration for Prometheus metrics endpoint.
"""

# @spec platform-middleware-custom-apps AC-MPC-017: Expose /metrics endpoint for Prometheus scraping
# @spec platform-middleware-custom-apps AC-MPC-018: Return text/plain metrics in Prometheus format
# @spec observability-stack: Application metrics collection at /metrics endpoint

from django.urls import path

try:
    from django_prometheus import exports as prometheus_exports

    urlpatterns = [
        path('', prometheus_exports.ExportToDjangoView, name='prometheus-metrics'),
    ]
except ImportError:
    # django-prometheus not installed, provide empty urlpatterns
    urlpatterns = []
