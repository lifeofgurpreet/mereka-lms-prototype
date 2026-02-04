"""
Custom Django app to enable Prometheus metrics in Open edX.

This app integrates django-prometheus to expose /metrics endpoint
for Prometheus monitoring.
"""

default_app_config = 'openedx_prometheus.apps.OpenEdxPrometheusConfig'
