"""
URL configuration for Prometheus metrics endpoint.
"""

# @covers AC-017, AC-018, AC-020
# @spec: platform-middleware-custom-apps_spec.md

from django.urls import path

try:
    from django_prometheus import exports as prometheus_exports

    urlpatterns = [
        path('metrics/', prometheus_exports.ExportToDjangoView, name='prometheus-metrics-slash'),
        path('metrics', prometheus_exports.ExportToDjangoView, name='prometheus-metrics'),
    ]
except ImportError:
    # django-prometheus not installed, provide empty urlpatterns
    urlpatterns = []
