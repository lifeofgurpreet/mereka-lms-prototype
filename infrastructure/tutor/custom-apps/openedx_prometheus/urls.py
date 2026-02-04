"""
URL configuration for Prometheus metrics endpoint.
"""

from django.urls import path

try:
    from django_prometheus import exports as prometheus_exports

    urlpatterns = [
        path('', prometheus_exports.ExportToDjangoView, name='prometheus-metrics'),
    ]
except ImportError:
    # django-prometheus not installed, provide empty urlpatterns
    urlpatterns = []
