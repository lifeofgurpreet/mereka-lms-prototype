"""
Baseline tests for openedx_tenant_cache.

Covers:
- Import smoke tests for every module
- AppConfig name and verbose_name
- Model fields, __str__, classmethods (TenantSiteMapping, TenantSiteConfiguration)
- TenantSiteConfiguration.get_merged_config() merge priority
- Serializer field existence (TenantSiteMappingSerializer, TenantSiteConfigurationSerializer)
- URL patterns (names, paths)
- Admin registrations
- Cache key formatting and TenantCacheNamespace context manager
- RLS policy SQL generation and Superset config generation
- xAPI event tagging and ClickHouse schema extension
- Isolation logic: check_tenant_access, get_request_tenant_uuid
- Metrics lazy initialization
- Middleware request/response handling
- Branding fallback chain and inject_mfe_branding feature flag
"""

import importlib
import os
import sys
import types
import unittest
import uuid
from datetime import datetime
from unittest.mock import MagicMock, patch, PropertyMock

# ---------------------------------------------------------------------------
# Stub Open edX deps before Django bootstrap
# ---------------------------------------------------------------------------

# openedx plugin constants
_plugin_mod = types.ModuleType('openedx')
_core_mod = types.ModuleType('openedx.core')
_djangoapps_mod = types.ModuleType('openedx.core.djangoapps')
_plugins_mod = types.ModuleType('openedx.core.djangoapps.plugins')
_constants_mod = types.ModuleType('openedx.core.djangoapps.plugins.constants')
_constants_mod.PluginURLs = MagicMock()
_constants_mod.ProjectType = MagicMock()
_plugin_mod.core = _core_mod
_core_mod.djangoapps = _djangoapps_mod
_djangoapps_mod.plugins = _plugins_mod
_plugins_mod.constants = _constants_mod

sys.modules.setdefault('openedx', _plugin_mod)
sys.modules.setdefault('openedx.core', _core_mod)
sys.modules.setdefault('openedx.core.djangoapps', _djangoapps_mod)
sys.modules.setdefault('openedx.core.djangoapps.plugins', _plugins_mod)
sys.modules.setdefault('openedx.core.djangoapps.plugins.constants', _constants_mod)

# enterprise models (for isolation.py)
_enterprise_mod = types.ModuleType('enterprise')
_enterprise_models = types.ModuleType('enterprise.models')
_enterprise_mod.models = _enterprise_models
sys.modules.setdefault('enterprise', _enterprise_mod)
sys.modules.setdefault('enterprise.models', _enterprise_models)

# event_sink_clickhouse (for views.py analytics)
_event_sink_mod = types.ModuleType('event_sink_clickhouse')
_event_sink_sinks = types.ModuleType('event_sink_clickhouse.sinks')
_event_sink_mod.sinks = _event_sink_sinks
sys.modules.setdefault('event_sink_clickhouse', _event_sink_mod)
sys.modules.setdefault('event_sink_clickhouse.sinks', _event_sink_sinks)

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_tenant_cache._test_settings')

_settings = types.ModuleType('openedx_tenant_cache._test_settings')
_settings.SECRET_KEY = 'test-secret-key'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'django.contrib.sites',
    'rest_framework',
    'openedx_tenant_cache',
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
_settings.SITE_ID = 1
_settings.ROOT_URLCONF = 'openedx_tenant_cache.urls'
_settings.CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}
_settings.ENABLE_MULTI_TENANT_BRANDING = False
_settings.DEFAULT_ORG_LOGO_URL = 'https://example.com/logo.png'
_settings.DEFAULT_ORG_DISPLAY_NAME = 'Test Academy'
_settings.DEFAULT_ORG_PRIMARY_COLOR = '#111111'
_settings.DEFAULT_ORG_ACCENT_COLOR = '#222222'
_settings.MEREKA_PUBLIC_FOOTER = {
    'navLinks': [{'label': 'About', 'url': 'https://example.com/about'}],
}
_settings.MFE_CONFIG = {
    'MEREKA_PUBLIC_FOOTER': _settings.MEREKA_PUBLIC_FOOTER,
}

sys.modules['openedx_tenant_cache._test_settings'] = _settings

import django
django.setup()

# Create tables once before any test runs.
# Cannot use --run-syncdb because migrations/ dir exists (empty).
# Create tables directly via schema_editor.
from django.db import connection
from django.core.management import call_command
call_command('migrate', verbosity=0)  # core apps (auth, sites, contenttypes)

from openedx_tenant_cache.models import TenantSiteMapping, TenantSiteConfiguration
with connection.schema_editor() as editor:
    for model in [TenantSiteMapping, TenantSiteConfiguration]:
        try:
            editor.create_model(model)
        except Exception:
            pass  # table already exists

from django.contrib.auth import get_user_model
from django.contrib.sites.models import Site
from django.test import TestCase, RequestFactory

User = get_user_model()


# ===========================================================================
# 1. Import smoke tests
# ===========================================================================

class TestModuleImports(unittest.TestCase):
    """Every module must be importable."""

    def _assert_importable(self, name):
        try:
            importlib.import_module(name)
        except ImportError as exc:
            self.fail(f"Cannot import {name}: {exc}")

    def test_import_apps(self):
        self._assert_importable('openedx_tenant_cache.apps')

    def test_import_models(self):
        self._assert_importable('openedx_tenant_cache.models')

    def test_import_views(self):
        self._assert_importable('openedx_tenant_cache.views')

    def test_import_signals(self):
        self._assert_importable('openedx_tenant_cache.signals')

    def test_import_middleware(self):
        self._assert_importable('openedx_tenant_cache.middleware')

    def test_import_cache(self):
        self._assert_importable('openedx_tenant_cache.cache')

    def test_import_branding(self):
        self._assert_importable('openedx_tenant_cache.branding')

    def test_import_isolation(self):
        self._assert_importable('openedx_tenant_cache.isolation')

    def test_import_metrics(self):
        self._assert_importable('openedx_tenant_cache.metrics')

    def test_import_runtime_urls(self):
        self._assert_importable('openedx_tenant_cache.runtime_urls')

    def test_import_rls(self):
        self._assert_importable('openedx_tenant_cache.rls')

    def test_import_xapi(self):
        self._assert_importable('openedx_tenant_cache.xapi')

    def test_import_serializers(self):
        self._assert_importable('openedx_tenant_cache.serializers')

    def test_import_urls(self):
        self._assert_importable('openedx_tenant_cache.urls')

    def test_import_admin(self):
        self._assert_importable('openedx_tenant_cache.admin')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):
    def test_app_name(self):
        from openedx_tenant_cache.apps import OpenedxTenantCacheConfig
        self.assertEqual(OpenedxTenantCacheConfig.name, 'openedx_tenant_cache')

    def test_verbose_name(self):
        from openedx_tenant_cache.apps import OpenedxTenantCacheConfig
        self.assertEqual(OpenedxTenantCacheConfig.verbose_name, 'Tenant Cache & Foundation')


class TestRuntimeUrls(unittest.TestCase):
    def test_candidate_site_domains_strips_service_prefix(self):
        from openedx_tenant_cache.runtime_urls import candidate_site_domains

        self.assertEqual(
            candidate_site_domains('apps.academyv2.mereka.io'),
            ['apps.academyv2.mereka.io', 'academyv2.mereka.io'],
        )

    def test_candidate_site_domains_strips_environment_service_prefix(self):
        from openedx_tenant_cache.runtime_urls import candidate_site_domains

        self.assertEqual(
            candidate_site_domains('staging.apps.academyv2.mereka.io'),
            ['staging.apps.academyv2.mereka.io', 'staging.academyv2.mereka.io'],
        )

    def test_tenant_authn_microfrontend_url_uses_tenant_base(self):
        from openedx_tenant_cache import runtime_urls

        with patch.object(runtime_urls, 'mfe_base_url_for_host', return_value='https://apps.tenant.example'):
            self.assertEqual(
                runtime_urls.tenant_authn_microfrontend_url_for_host(
                    'tenant.example',
                    'https://apps.default.example/authn',
                ),
                'https://apps.tenant.example/authn',
            )

    def test_tenant_authn_microfrontend_url_falls_back_to_default(self):
        from openedx_tenant_cache import runtime_urls

        with patch.object(runtime_urls, 'mfe_base_url_for_host', return_value=None):
            self.assertEqual(
                runtime_urls.tenant_authn_microfrontend_url_for_host(
                    'tenant.example',
                    'https://apps.default.example/authn/',
                ),
                'https://apps.default.example/authn',
            )

    def test_tenant_authn_microfrontend_url_falls_back_without_traceback(self):
        from openedx_tenant_cache import runtime_urls

        with patch.object(runtime_urls, 'tenant_mfe_url', side_effect=RuntimeError('django not ready')):
            with self.assertLogs('openedx_tenant_cache.runtime_urls', level='WARNING') as logs:
                self.assertEqual(
                    runtime_urls.tenant_authn_microfrontend_url_for_host(
                        'tenant.example',
                        'https://apps.default.example/authn/',
                    ),
                    'https://apps.default.example/authn',
                )
        self.assertEqual(len(logs.output), 1)
        self.assertIn('Falling back to default authn MFE URL for host tenant.example', logs.output[0])
        self.assertNotIn('Traceback', logs.output[0])


# ===========================================================================
# 3. Models — TenantSiteMapping
# ===========================================================================

class TestTenantSiteMappingModel(TestCase):
    """Test TenantSiteMapping fields, __str__, and classmethods."""

    def setUp(self):
        self.site = Site.objects.get_or_create(
            domain='acme.example.com', defaults={'name': 'Acme'}
        )[0]
        self.tenant_uuid = uuid.uuid4()

    def _create_mapping(self, **overrides):
        from openedx_tenant_cache.models import TenantSiteMapping
        defaults = dict(
            enterprise_customer_uuid=self.tenant_uuid,
            site=self.site,
            slug='acme-corp',
            name='Acme Corp',
            is_active=True,
        )
        defaults.update(overrides)
        return TenantSiteMapping.objects.create(**defaults)

    def test_str_representation(self):
        m = self._create_mapping()
        self.assertIn('Acme Corp', str(m))
        self.assertIn('acme-corp', str(m))
        self.assertIn('acme.example.com', str(m))

    def test_uuid_primary_key(self):
        m = self._create_mapping()
        self.assertIsInstance(m.pk, uuid.UUID)

    def test_get_by_uuid_active(self):
        from openedx_tenant_cache.models import TenantSiteMapping
        self._create_mapping()
        found = TenantSiteMapping.get_by_uuid(self.tenant_uuid)
        self.assertIsNotNone(found)
        self.assertEqual(found.slug, 'acme-corp')

    def test_get_by_uuid_inactive_returns_none(self):
        from openedx_tenant_cache.models import TenantSiteMapping
        self._create_mapping(is_active=False)
        self.assertIsNone(TenantSiteMapping.get_by_uuid(self.tenant_uuid))

    def test_get_by_site(self):
        from openedx_tenant_cache.models import TenantSiteMapping
        self._create_mapping()
        found = TenantSiteMapping.get_by_site(self.site)
        self.assertIsNotNone(found)
        self.assertEqual(str(found.enterprise_customer_uuid), str(self.tenant_uuid))

    def test_get_by_slug(self):
        from openedx_tenant_cache.models import TenantSiteMapping
        self._create_mapping()
        found = TenantSiteMapping.get_by_slug('acme-corp')
        self.assertIsNotNone(found)

    def test_get_by_slug_nonexistent(self):
        from openedx_tenant_cache.models import TenantSiteMapping
        self.assertIsNone(TenantSiteMapping.get_by_slug('does-not-exist'))

    def test_branding_config_defaults_to_empty_dict(self):
        m = self._create_mapping()
        self.assertEqual(m.branding_config, {})


# ===========================================================================
# 4. Models — TenantSiteConfiguration merge logic
# ===========================================================================

class TestTenantSiteConfigurationModel(TestCase):
    """Test TenantSiteConfiguration get_merged_config priority."""

    def setUp(self):
        from openedx_tenant_cache.models import TenantSiteMapping, TenantSiteConfiguration
        self.site = Site.objects.get_or_create(
            domain='test.example.com', defaults={'name': 'Test'}
        )[0]
        self.mapping = TenantSiteMapping.objects.create(
            enterprise_customer_uuid=uuid.uuid4(),
            site=self.site,
            slug='test-tenant',
            name='Test Tenant',
            branding_config={
                'logo_url': 'tenant-logo.png',
                'primary_color': '#ff0000',
            },
        )
        self.config = TenantSiteConfiguration.objects.create(
            tenant=self.mapping,
            values={
                'primary_color': '#00ff00',
                'footer_text': 'Custom Footer',
            },
            mfe_config={'LOGO_URL': 'mfe-logo.png'},
        )

    def test_str_representation(self):
        self.assertIn('Test Tenant', str(self.config))

    def test_merge_priority_values_over_branding(self):
        """values (highest priority) beats tenant.branding_config."""
        merged = self.config.get_merged_config()
        # values has primary_color=#00ff00, tenant branding has #ff0000
        self.assertEqual(merged['primary_color'], '#00ff00')

    def test_merge_branding_over_defaults(self):
        """tenant.branding_config beats defaults."""
        merged = self.config.get_merged_config()
        # logo_url from branding_config (values doesn't set it)
        self.assertEqual(merged['logo_url'], 'tenant-logo.png')

    def test_merge_defaults_fill_gaps(self):
        """Defaults fill in when neither values nor branding set a key."""
        merged = self.config.get_merged_config()
        # secondary_color not in either → default #4285f4
        self.assertEqual(merged['secondary_color'], '#4285f4')

    def test_merge_footer_from_values(self):
        merged = self.config.get_merged_config()
        self.assertEqual(merged['footer_text'], 'Custom Footer')

    def test_empty_branding_and_values(self):
        """When both are empty, only defaults remain."""
        from openedx_tenant_cache.models import TenantSiteMapping, TenantSiteConfiguration
        site2 = Site.objects.get_or_create(
            domain='empty.example.com', defaults={'name': 'Empty'}
        )[0]
        mapping2 = TenantSiteMapping.objects.create(
            enterprise_customer_uuid=uuid.uuid4(),
            site=site2,
            slug='empty-tenant',
            name='Empty',
            branding_config={},
        )
        config2 = TenantSiteConfiguration.objects.create(
            tenant=mapping2,
            values={},
            mfe_config={},
        )
        merged = config2.get_merged_config()
        self.assertEqual(merged['primary_color'], '#1a73e8')
        self.assertEqual(merged['secondary_color'], '#4285f4')


# ===========================================================================
# 5. Cache module
# ===========================================================================

class TestCacheModule(TestCase):
    """Test cache key formatting and TenantCacheNamespace."""

    def test_tenant_cache_key_format(self):
        from openedx_tenant_cache.cache import tenant_cache_key
        key = tenant_cache_key('uuid-123', 'catalog', 'course-v1:Test+101')
        self.assertEqual(key, 'enterprise:uuid-123:catalog:course-v1:Test+101')

    def test_cache_set_and_get(self):
        from openedx_tenant_cache.cache import tenant_cache_set, tenant_cache_get
        tenant_cache_set('uuid-abc', 'config', 'theme', {'color': 'red'})
        result = tenant_cache_get('uuid-abc', 'config', 'theme')
        self.assertEqual(result, {'color': 'red'})

    def test_cache_get_default(self):
        from openedx_tenant_cache.cache import tenant_cache_get
        result = tenant_cache_get('nonexistent', 'type', 'id', default='fallback')
        self.assertEqual(result, 'fallback')

    def test_cache_delete(self):
        from openedx_tenant_cache.cache import (
            tenant_cache_set, tenant_cache_get, tenant_cache_delete,
        )
        tenant_cache_set('uuid-del', 'config', 'x', 'val')
        tenant_cache_delete('uuid-del', 'config', 'x')
        self.assertIsNone(tenant_cache_get('uuid-del', 'config', 'x'))

    def test_namespace_context_manager(self):
        from openedx_tenant_cache.cache import TenantCacheNamespace
        with TenantCacheNamespace('ns-uuid') as ns:
            ns.set('config', 'theme', {'bg': 'blue'})
            result = ns.get('config', 'theme')
        self.assertEqual(result, {'bg': 'blue'})

    def test_namespace_key(self):
        from openedx_tenant_cache.cache import TenantCacheNamespace
        ns = TenantCacheNamespace('key-uuid')
        self.assertEqual(ns.key('cat', 'item'), 'enterprise:key-uuid:cat:item')


# ===========================================================================
# 6. RLS module
# ===========================================================================

class TestRLSModule(unittest.TestCase):
    """Test Superset RLS policy generation."""

    def test_get_rls_policy_sql_xapi(self):
        from openedx_tenant_cache.rls import get_rls_policy_sql
        sql = get_rls_policy_sql('xapi_events_all', 'abc-123')
        self.assertIn("enterprise_customer_uuid = 'abc-123'", sql)

    def test_get_rls_policy_sql_unknown_table(self):
        from openedx_tenant_cache.rls import get_rls_policy_sql
        self.assertIsNone(get_rls_policy_sql('nonexistent_table', 'uuid'))

    def test_get_all_rls_policies_has_expected_tables(self):
        from openedx_tenant_cache.rls import get_all_rls_policies
        policies = get_all_rls_policies()
        self.assertIn('xapi_events_all', policies)
        self.assertIn('course_enrollments', policies)
        self.assertIn('grades', policies)
        self.assertIn('certificates', policies)

    def test_generate_superset_rls_config_structure(self):
        from openedx_tenant_cache.rls import generate_superset_rls_config
        rules = generate_superset_rls_config('test-uuid', 'Test Tenant')
        self.assertIsInstance(rules, list)
        self.assertEqual(len(rules), 4)  # 4 policy groups
        for rule in rules:
            self.assertIn('name', rule)
            self.assertIn('clause', rule)
            self.assertIn('tables', rule)
            self.assertIn('Test Tenant', rule['name'])
            self.assertNotIn('{{ tenant_uuid }}', rule['clause'])

    def test_rls_config_substitutes_uuid(self):
        from openedx_tenant_cache.rls import generate_superset_rls_config
        rules = generate_superset_rls_config('my-uuid-here', 'Acme')
        for rule in rules:
            self.assertIn('my-uuid-here', rule['clause'])


# ===========================================================================
# 7. xAPI module
# ===========================================================================

class TestXApiModule(unittest.TestCase):
    """Test xAPI event tagging and ClickHouse schema."""

    def test_tag_xapi_event_with_uuid(self):
        from openedx_tenant_cache.xapi import tag_xapi_event
        event = {'verb': 'completed'}
        result = tag_xapi_event(event, enterprise_uuid='ent-uuid')
        self.assertEqual(result['enterprise_customer_uuid'], 'ent-uuid')
        self.assertEqual(result['verb'], 'completed')

    def test_tag_xapi_event_none_uuid(self):
        from openedx_tenant_cache.xapi import tag_xapi_event
        event = {'verb': 'started'}
        result = tag_xapi_event(event)
        self.assertIsNone(result['enterprise_customer_uuid'])

    def test_tag_xapi_event_resolves_from_user(self):
        """When uuid not given, tries to resolve from user."""
        from openedx_tenant_cache.xapi import tag_xapi_event
        mock_user = MagicMock()
        mock_user.is_authenticated = True
        # enterprise.models not importable in test env → falls back to None
        event = {'verb': 'played'}
        result = tag_xapi_event(event, user=mock_user)
        # Should not crash, uuid will be None since enterprise isn't real
        self.assertIn('enterprise_customer_uuid', result)

    def test_clickhouse_schema_extension(self):
        from openedx_tenant_cache.xapi import get_clickhouse_schema_extension
        sql = get_clickhouse_schema_extension()
        self.assertIn('ALTER TABLE xapi_events_all', sql)
        self.assertIn('enterprise_customer_uuid', sql)
        self.assertIn('Nullable(UUID)', sql)


# ===========================================================================
# 8. Isolation module
# ===========================================================================

class TestIsolationModule(unittest.TestCase):
    """Test tenant isolation enforcement."""

    def test_get_request_tenant_uuid_from_public_attr(self):
        from openedx_tenant_cache.isolation import get_request_tenant_uuid
        request = MagicMock()
        request.tenant_uuid = 'uuid-from-public'
        request._tenant_uuid = None
        self.assertEqual(get_request_tenant_uuid(request), 'uuid-from-public')

    def test_get_request_tenant_uuid_from_private_attr(self):
        from openedx_tenant_cache.isolation import get_request_tenant_uuid
        request = MagicMock(spec=[])
        request.tenant_uuid = None
        request._tenant_uuid = 'uuid-from-private'
        self.assertEqual(get_request_tenant_uuid(request), 'uuid-from-private')

    def test_check_tenant_access_superuser_bypass(self):
        from openedx_tenant_cache.isolation import check_tenant_access
        request = MagicMock()
        request.user.is_superuser = True
        self.assertTrue(check_tenant_access(request, 'any-uuid'))

    def test_check_tenant_access_none_target(self):
        from openedx_tenant_cache.isolation import check_tenant_access
        request = MagicMock()
        self.assertTrue(check_tenant_access(request, None))

    def test_check_tenant_access_same_tenant(self):
        from openedx_tenant_cache.isolation import check_tenant_access
        request = MagicMock()
        request.user.is_superuser = False
        request.user.is_authenticated = True
        request.tenant_uuid = 'tenant-A'
        request._tenant_uuid = 'tenant-A'
        self.assertTrue(check_tenant_access(request, 'tenant-A'))

    def test_check_tenant_access_cross_tenant_blocked(self):
        from openedx_tenant_cache.isolation import check_tenant_access
        from rest_framework.exceptions import PermissionDenied
        request = MagicMock()
        request.user.is_superuser = False
        request.user.is_authenticated = True
        request.user.id = 42
        request.tenant_uuid = 'tenant-A'
        request._tenant_uuid = 'tenant-A'
        with self.assertRaises(PermissionDenied):
            check_tenant_access(request, 'tenant-B')

    def test_enforce_tenant_isolation_decorator(self):
        from openedx_tenant_cache.isolation import enforce_tenant_isolation
        from rest_framework.exceptions import PermissionDenied

        @enforce_tenant_isolation
        def my_view(request, tenant_uuid=None):
            return 'ok'

        # Superuser passes
        request = MagicMock()
        request.user.is_superuser = True
        self.assertEqual(my_view(request, tenant_uuid='any'), 'ok')


# ===========================================================================
# 9. Metrics module
# ===========================================================================

class TestMetricsModule(unittest.TestCase):
    """Test lazy-initialized Prometheus metrics."""

    def test_record_tenant_request_does_not_crash(self):
        from openedx_tenant_cache.metrics import record_tenant_request
        # Should not raise even if prometheus_client is available
        record_tenant_request('test-uuid', 0.5)

    def test_record_cache_hit_does_not_crash(self):
        from openedx_tenant_cache.metrics import record_cache_hit
        record_cache_hit('test-uuid')

    def test_record_cache_miss_does_not_crash(self):
        from openedx_tenant_cache.metrics import record_cache_miss
        record_cache_miss('test-uuid')


# ===========================================================================
# 10. Middleware
# ===========================================================================

class TestMiddleware(unittest.TestCase):
    """Test TenantCacheMiddleware request/response handling."""

    def test_process_request_sets_tenant_attrs(self):
        from openedx_tenant_cache.middleware import TenantCacheMiddleware
        mw = TenantCacheMiddleware(get_response=lambda r: r)
        request = MagicMock(spec=[])
        mw.process_request(request)
        # Attributes should be set (value may be None for non-tenant requests)
        self.assertTrue(hasattr(request, '_tenant_uuid'))
        self.assertTrue(hasattr(request, 'tenant_uuid'))
        self.assertTrue(hasattr(request, '_tenant_start_time'))

    def test_process_response_returns_response(self):
        from openedx_tenant_cache.middleware import TenantCacheMiddleware
        mw = TenantCacheMiddleware(get_response=lambda r: r)
        request = MagicMock()
        request._tenant_uuid = None
        response = MagicMock()
        result = mw.process_response(request, response)
        self.assertIs(result, response)


# ===========================================================================
# 11. Branding module
# ===========================================================================

class TestBrandingModule(TestCase):
    """Test branding lookup and MFE injection."""

    def test_get_tenant_branding_returns_defaults_for_unknown_uuid(self):
        from openedx_tenant_cache.branding import get_tenant_branding
        branding = get_tenant_branding('nonexistent-uuid')
        self.assertIn('LOGO_URL', branding)
        self.assertIn('SITE_NAME', branding)
        self.assertEqual(branding['SITE_NAME'], 'Test Academy')
        self.assertEqual(
            branding['MEREKA_PUBLIC_FOOTER'],
            _settings.MEREKA_PUBLIC_FOOTER,
        )

    def test_get_tenant_branding_uses_footer_and_brand_keys_from_site_config(self):
        from openedx_tenant_cache.branding import get_tenant_branding

        site = Site.objects.get_or_create(
            domain='branding.example.com', defaults={'name': 'Branding'}
        )[0]
        tenant_uuid = uuid.uuid4()
        mapping = TenantSiteMapping.objects.create(
            enterprise_customer_uuid=tenant_uuid,
            site=site,
            slug='branding-tenant',
            name='Branding Tenant',
            branding_config={'primary_color': '#101010'},
        )
        TenantSiteConfiguration.objects.create(
            tenant=mapping,
            values={'primary_color': '#123456', 'secondary_color': '#654321'},
            mfe_config={
                'ACCENT_COLOR': '#abcdef',
                'BRAND_PRIMARY': '#123456',
                'BRAND_SECONDARY': '#654321',
                'BRAND_ACCENT': '#abcdef',
                'MEREKA_PUBLIC_FOOTER': {'navLinks': [{'label': 'Docs', 'url': 'https://example.com/docs'}]},
            },
        )

        branding = get_tenant_branding(str(tenant_uuid))
        self.assertEqual(branding['PRIMARY_COLOR'], '#123456')
        self.assertEqual(branding['SECONDARY_COLOR'], '#654321')
        self.assertEqual(branding['ACCENT_COLOR'], '#abcdef')
        self.assertEqual(branding['BRAND_PRIMARY'], '#123456')
        self.assertEqual(branding['BRAND_SECONDARY'], '#654321')
        self.assertEqual(branding['BRAND_ACCENT'], '#abcdef')
        self.assertEqual(
            branding['MEREKA_PUBLIC_FOOTER']['navLinks'][0]['label'],
            'Docs',
        )

    def test_inject_mfe_branding_disabled_by_flag(self):
        from openedx_tenant_cache.branding import inject_mfe_branding
        request = MagicMock()
        request.tenant_uuid = 'some-uuid'
        request._tenant_uuid = 'some-uuid'
        config = {'FOO': 'bar'}
        # ENABLE_MULTI_TENANT_BRANDING is False in test settings
        result = inject_mfe_branding(request, config)
        self.assertEqual(result, {'FOO': 'bar'})

    def test_inject_mfe_branding_no_tenant_uuid(self):
        from openedx_tenant_cache.branding import inject_mfe_branding
        request = MagicMock(spec=[])
        request.tenant_uuid = None
        request._tenant_uuid = None
        config = {'X': 1}
        result = inject_mfe_branding(request, config)
        self.assertEqual(result, {'X': 1})

    @patch('openedx_tenant_cache.branding.get_tenant_branding')
    def test_inject_mfe_branding_enabled(self, mock_get):
        from openedx_tenant_cache.branding import inject_mfe_branding
        mock_get.return_value = {'LOGO_URL': 'new-logo.png', 'SITE_NAME': ''}
        request = MagicMock()
        request.tenant_uuid = 'uuid-123'
        request._tenant_uuid = 'uuid-123'
        config = {'EXISTING': 'val'}
        with self.settings(ENABLE_MULTI_TENANT_BRANDING=True):
            result = inject_mfe_branding(request, config)
        # LOGO_URL is truthy so it should be merged
        self.assertEqual(result['LOGO_URL'], 'new-logo.png')
        # SITE_NAME is '' so it should NOT override
        self.assertNotIn('SITE_NAME', result)
        self.assertEqual(result['EXISTING'], 'val')


# ===========================================================================
# 12. Serializers
# ===========================================================================

class TestSerializers(unittest.TestCase):
    def test_mapping_serializer_fields(self):
        from openedx_tenant_cache.serializers import TenantSiteMappingSerializer
        fields = TenantSiteMappingSerializer().fields
        expected = {
            'id', 'enterprise_customer_uuid', 'site', 'site_domain',
            'slug', 'name', 'is_active', 'branding_config',
            'created_at', 'updated_at',
        }
        self.assertTrue(expected.issubset(set(fields.keys())))

    def test_config_serializer_fields(self):
        from openedx_tenant_cache.serializers import TenantSiteConfigurationSerializer
        fields = TenantSiteConfigurationSerializer().fields
        expected = {
            'id', 'tenant', 'tenant_name', 'values', 'mfe_config',
            'is_active', 'created_at', 'updated_at',
        }
        self.assertTrue(expected.issubset(set(fields.keys())))


# ===========================================================================
# 13. URL patterns
# ===========================================================================

class TestURLPatterns(unittest.TestCase):
    def test_url_names(self):
        from openedx_tenant_cache.urls import urlpatterns
        names = {p.name for p in urlpatterns}
        self.assertIn('tenant-list', names)
        self.assertIn('tenant-branding', names)
        self.assertIn('tenant-catalogs', names)
        self.assertIn('tenant-analytics', names)

    def test_app_name(self):
        from openedx_tenant_cache import urls
        self.assertEqual(urls.app_name, 'openedx_tenant_cache')


# ===========================================================================
# 14. Admin registrations
# ===========================================================================

class TestAdminRegistrations(unittest.TestCase):
    def test_mapping_admin_registered(self):
        from django.contrib import admin
        from openedx_tenant_cache.models import TenantSiteMapping
        self.assertIn(TenantSiteMapping, admin.site._registry)

    def test_config_admin_registered(self):
        from django.contrib import admin
        from openedx_tenant_cache.models import TenantSiteConfiguration
        self.assertIn(TenantSiteConfiguration, admin.site._registry)


if __name__ == '__main__':
    unittest.main()
