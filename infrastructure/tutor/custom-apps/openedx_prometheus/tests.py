"""
Baseline tests for openedx_prometheus.

Covers:
- Import smoke tests for every module
- AppConfig (name, verbose_name, default_auto_field)
- URL patterns: metrics endpoint exposure (with and without django-prometheus)
- Graceful degradation when django_prometheus is not installed

Runs without external services.
"""

import importlib
import os
import sys
import types
import unittest
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub Open edX platform dependencies BEFORE Django setup
# ---------------------------------------------------------------------------

# Stub openedx plugin constants (apps.py imports these)
_openedx = types.ModuleType('openedx')
sys.modules.setdefault('openedx', _openedx)
_openedx_core = types.ModuleType('openedx.core')
sys.modules.setdefault('openedx.core', _openedx_core)
_openedx_da = types.ModuleType('openedx.core.djangoapps')
sys.modules.setdefault('openedx.core.djangoapps', _openedx_da)
_openedx_plugins = types.ModuleType('openedx.core.djangoapps.plugins')
sys.modules.setdefault('openedx.core.djangoapps.plugins', _openedx_plugins)
_openedx_plugins_constants = types.ModuleType('openedx.core.djangoapps.plugins.constants')
_openedx_plugins_constants.PluginURLs = None
_openedx_plugins_constants.ProjectType = None
sys.modules['openedx.core.djangoapps.plugins.constants'] = _openedx_plugins_constants

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_prometheus._test_settings')

_settings = types.ModuleType('openedx_prometheus._test_settings')
_settings.SECRET_KEY = 'test-secret-key-prometheus'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'openedx_prometheus',
]
_settings.DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}
_settings.DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
_settings.USE_TZ = True
_settings.TIME_ZONE = 'UTC'
_settings.AUTH_USER_MODEL = 'auth.User'
_settings.REST_FRAMEWORK = {}

sys.modules['openedx_prometheus._test_settings'] = _settings

import django
django.setup()


# ===========================================================================
# 1. Import smoke tests
# ===========================================================================

class TestModuleImports(unittest.TestCase):

    def _assert_importable(self, name):
        try:
            return importlib.import_module(name)
        except ImportError as exc:
            self.fail(f'Failed to import {name}: {exc}')

    def test_import_init(self):
        self._assert_importable('openedx_prometheus')

    def test_import_apps(self):
        self._assert_importable('openedx_prometheus.apps')

    def test_import_urls(self):
        self._assert_importable('openedx_prometheus.urls')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from openedx_prometheus.apps import OpenEdxPrometheusConfig
        self.assertEqual(OpenEdxPrometheusConfig.name, 'openedx_prometheus')

    def test_verbose_name(self):
        from openedx_prometheus.apps import OpenEdxPrometheusConfig
        self.assertEqual(OpenEdxPrometheusConfig.verbose_name, 'Open edX Prometheus Metrics')

    def test_default_auto_field(self):
        from openedx_prometheus.apps import OpenEdxPrometheusConfig
        self.assertEqual(OpenEdxPrometheusConfig.default_auto_field,
                         'django.db.models.BigAutoField')


# ===========================================================================
# 3. URL patterns: with django_prometheus available
# ===========================================================================

class TestURLPatternsWithPrometheus(unittest.TestCase):
    """When django_prometheus is installed, metrics URLs should be present."""

    def test_metrics_urls_when_django_prometheus_available(self):
        """Stub django_prometheus and re-import urls to test the happy path."""
        mock_exports = MagicMock()
        mock_exports.ExportToDjangoView = MagicMock()

        fake_dp = types.ModuleType('django_prometheus')
        fake_dp_exports = types.ModuleType('django_prometheus.exports')
        fake_dp_exports.ExportToDjangoView = mock_exports.ExportToDjangoView
        fake_dp.exports = fake_dp_exports

        with patch.dict('sys.modules', {
            'django_prometheus': fake_dp,
            'django_prometheus.exports': fake_dp_exports,
        }):
            # Force re-import of urls module
            import openedx_prometheus.urls
            importlib.reload(openedx_prometheus.urls)
            patterns = openedx_prometheus.urls.urlpatterns

        names = [p.name for p in patterns]
        self.assertIn('prometheus-metrics', names)
        self.assertIn('prometheus-metrics-slash', names)
        self.assertEqual(len(patterns), 2)


# ===========================================================================
# 4. URL patterns: graceful degradation without django_prometheus
# ===========================================================================

class TestURLPatternsWithoutPrometheus(unittest.TestCase):
    """When django_prometheus is NOT installed, urls should be empty."""

    def test_empty_urlpatterns_when_django_prometheus_missing(self):
        # Remove django_prometheus from sys.modules if present
        saved = {}
        for key in list(sys.modules.keys()):
            if key.startswith('django_prometheus'):
                saved[key] = sys.modules.pop(key)

        try:
            import openedx_prometheus.urls
            importlib.reload(openedx_prometheus.urls)
            self.assertEqual(openedx_prometheus.urls.urlpatterns, [])
        finally:
            # Restore
            sys.modules.update(saved)


# ===========================================================================
# 5. Version
# ===========================================================================

class TestVersion(unittest.TestCase):

    def test_default_app_config(self):
        import openedx_prometheus
        self.assertEqual(openedx_prometheus.default_app_config,
                         'openedx_prometheus.apps.OpenEdxPrometheusConfig')


# ===========================================================================
# 6. AppConfig ready() — implicitly tested by django.setup() above.
#    Direct instantiation skipped: synthetic module lacks filesystem path.
# ===========================================================================


if __name__ == '__main__':
    unittest.main()
