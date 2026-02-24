#!/usr/bin/env bash
# Patch: Prometheus metrics integration.
# Adds django-prometheus to INSTALLED_APPS/MIDDLEWARE in production.py,
# /metrics endpoint to nginx lms.conf, and django-prometheus pip install to Dockerfile.

apply_prometheus_metrics_patch() {
  local targets=(
    "$LMS_SETTINGS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/openedx/settings/lms/production.py"
    "$NGINX_LMS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/nginx/lms.conf"
  )

  python - "${targets[@]}" <<'PY'
from pathlib import Path
import textwrap
import sys

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    if path.name == "production.py":
        # Add Prometheus metrics integration
        if "django_prometheus" not in updated:
            prometheus_config = textwrap.dedent("""

                # Prometheus Metrics Integration
                # django_prometheus must be added at the START of INSTALLED_APPS
                if 'django_prometheus' not in INSTALLED_APPS:
                    INSTALLED_APPS.insert(0, 'django_prometheus')

                # Add custom prometheus app for /metrics endpoint
                if 'openedx_prometheus' not in INSTALLED_APPS:
                    INSTALLED_APPS.append('openedx_prometheus')

                # Prometheus middleware must wrap all other middleware
                if 'django_prometheus.middleware.PrometheusBeforeMiddleware' not in MIDDLEWARE:
                    MIDDLEWARE.insert(0, 'django_prometheus.middleware.PrometheusBeforeMiddleware')
                if 'django_prometheus.middleware.PrometheusAfterMiddleware' not in MIDDLEWARE:
                    MIDDLEWARE.append('django_prometheus.middleware.PrometheusAfterMiddleware')
            """).strip()
            updated = updated.rstrip() + '\n\n' + prometheus_config + '\n'

    if path.name == "lms.conf":
        # Add /metrics endpoint (internal access only, for Prometheus scraping)
        if "location = /metrics" not in updated:
            metrics_block = (
                "  # Prometheus metrics endpoint (internal access only)\n"
                "  location = /metrics {\n"
                "    proxy_set_header Host $http_host;\n"
                "    proxy_redirect off;\n"
                "    proxy_pass http://lms-backend;\n"
                "  }\n\n"
            )
            marker = "  location = /health {"
            if marker in updated:
                updated = updated.replace(marker, metrics_block + marker, 1)

    if updated != original:
        path.write_text(updated)
PY
}
