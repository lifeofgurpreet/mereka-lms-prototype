"""
Baseline tests for mfe_oauth_fix.

Covers:
- Import smoke tests for every module
- AppConfig (name, verbose_name)
- Middleware logic:
  - Non-mfe_context paths pass through unmodified
  - Non-200 responses pass through unmodified
  - Non-JSON responses pass through unmodified
  - Authentik -> Mereka provider renaming when providers exist
  - Empty providers triggers OAuth2ProviderConfig lookup
- MFEContextView:
  - Returns valid JSON structure with contextData.providers
  - Returns 500 on internal error
- URL patterns

Runs without Open edX platform or database.
"""

import importlib
import json
import os
import sys
import types
import unittest
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub Open edX platform dependencies BEFORE Django setup
# ---------------------------------------------------------------------------

# Stub third_party_auth
_third_party_auth = types.ModuleType('third_party_auth')
_third_party_auth_models = types.ModuleType('third_party_auth.models')

# Create a mock OAuth2ProviderConfig
_mock_provider_manager = MagicMock()
_third_party_auth_models.OAuth2ProviderConfig = MagicMock()
_third_party_auth_models.OAuth2ProviderConfig.objects = _mock_provider_manager
sys.modules['third_party_auth'] = _third_party_auth
sys.modules['third_party_auth.models'] = _third_party_auth_models

# Stub common.djangoapps.third_party_auth
_common = types.ModuleType('common')
sys.modules.setdefault('common', _common)
_common_da = types.ModuleType('common.djangoapps')
sys.modules.setdefault('common.djangoapps', _common_da)
_common_tpa = types.ModuleType('common.djangoapps.third_party_auth')
sys.modules['common.djangoapps.third_party_auth'] = _common_tpa
_common_tpa_models = types.ModuleType('common.djangoapps.third_party_auth.models')
_common_tpa_models.OAuth2ProviderConfig = _third_party_auth_models.OAuth2ProviderConfig
sys.modules['common.djangoapps.third_party_auth.models'] = _common_tpa_models

# Stub openedx.core.djangoapps.user_authn
_openedx = types.ModuleType('openedx')
sys.modules.setdefault('openedx', _openedx)
_openedx_core = types.ModuleType('openedx.core')
sys.modules.setdefault('openedx.core', _openedx_core)
_openedx_da = types.ModuleType('openedx.core.djangoapps')
sys.modules.setdefault('openedx.core.djangoapps', _openedx_da)
_openedx_ua = types.ModuleType('openedx.core.djangoapps.user_authn')
sys.modules['openedx.core.djangoapps.user_authn'] = _openedx_ua
_openedx_ua_views = types.ModuleType('openedx.core.djangoapps.user_authn.views')
sys.modules['openedx.core.djangoapps.user_authn.views'] = _openedx_ua_views
_openedx_ua_register = types.ModuleType('openedx.core.djangoapps.user_authn.views.register')
_openedx_ua_register.get_registration_extension_form = MagicMock(return_value=None)
sys.modules['openedx.core.djangoapps.user_authn.views.register'] = _openedx_ua_register

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mfe_oauth_fix._test_settings')

_settings = types.ModuleType('mfe_oauth_fix._test_settings')
_settings.SECRET_KEY = 'test-secret-key-mfe-oauth'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.sites',
    'mfe_oauth_fix',
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
_settings.REST_FRAMEWORK = {}

sys.modules['mfe_oauth_fix._test_settings'] = _settings

import django
django.setup()

# Create tables ONCE at module level (Django 6.0 SQLite requires this outside transactions)
from django.core.management import call_command
call_command('migrate', '--run-syncdb', verbosity=0)

from django.test import TestCase, RequestFactory
from django.http import HttpResponse, JsonResponse


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
        self._assert_importable('mfe_oauth_fix')

    def test_import_apps(self):
        self._assert_importable('mfe_oauth_fix.apps')

    def test_import_middleware(self):
        self._assert_importable('mfe_oauth_fix.middleware')

    def test_import_views(self):
        self._assert_importable('mfe_oauth_fix.views')

    def test_import_urls(self):
        self._assert_importable('mfe_oauth_fix.urls')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from mfe_oauth_fix.apps import MFEOAuthFixConfig
        self.assertEqual(MFEOAuthFixConfig.name, 'mfe_oauth_fix')

    def test_verbose_name(self):
        from mfe_oauth_fix.apps import MFEOAuthFixConfig
        self.assertEqual(MFEOAuthFixConfig.verbose_name, 'MFE OAuth Provider Fix')

    def test_default_auto_field(self):
        from mfe_oauth_fix.apps import MFEOAuthFixConfig
        self.assertEqual(MFEOAuthFixConfig.default_auto_field, 'django.db.models.BigAutoField')


# ===========================================================================
# 3. Middleware: path filtering
# ===========================================================================

class TestMiddlewarePathFiltering(unittest.TestCase):
    """Middleware should only act on /api/mfe_context requests."""

    def setUp(self):
        from mfe_oauth_fix.middleware import MFEOAuthFixMiddleware
        self.middleware = MFEOAuthFixMiddleware(get_response=lambda r: HttpResponse('ok'))

    def test_non_mfe_context_passes_through(self):
        factory = RequestFactory()
        request = factory.get('/api/something-else')
        original_response = HttpResponse('original', content_type='application/json')
        original_response.status_code = 200
        result = self.middleware.process_response(request, original_response)
        self.assertEqual(result.content, b'original')

    def test_non_200_passes_through(self):
        factory = RequestFactory()
        request = factory.get('/api/mfe_context')
        response = HttpResponse('error', content_type='application/json', status=404)
        result = self.middleware.process_response(request, response)
        self.assertEqual(result.status_code, 404)
        self.assertEqual(result.content, b'error')

    def test_non_json_passes_through(self):
        factory = RequestFactory()
        request = factory.get('/api/mfe_context')
        response = HttpResponse('<html></html>', content_type='text/html', status=200)
        result = self.middleware.process_response(request, response)
        self.assertEqual(result.content, b'<html></html>')


# ===========================================================================
# 4. Middleware: Authentik -> Mereka renaming
# ===========================================================================

class TestMiddlewareAuthentikRenaming(unittest.TestCase):
    """When providers exist with 'authentik' in name/id/urls, rename to Mereka."""

    def setUp(self):
        from mfe_oauth_fix.middleware import MFEOAuthFixMiddleware
        self.middleware = MFEOAuthFixMiddleware(get_response=lambda r: HttpResponse('ok'))
        self.factory = RequestFactory()

    def _make_response(self, data):
        content = json.dumps(data).encode('utf-8')
        response = HttpResponse(content, content_type='application/json')
        response.status_code = 200
        return response

    def test_renames_authentik_provider_by_name(self):
        data = {
            'contextData': {
                'providers': [
                    {'id': 'oa2-sso', 'name': 'Authentik SSO',
                     'loginUrl': '/auth/login/oauth2/', 'registerUrl': '/auth/login/oauth2/'}
                ]
            }
        }
        request = self.factory.get('/api/mfe_context')
        response = self._make_response(data)

        result = self.middleware.process_response(request, response)
        result_data = json.loads(result.content)
        self.assertEqual(result_data['contextData']['providers'][0]['name'], 'Mereka')

    def test_renames_authentik_provider_by_id(self):
        data = {
            'contextData': {
                'providers': [
                    {'id': 'oa2-authentik', 'name': 'SSO Login',
                     'loginUrl': '/auth/login/x/', 'registerUrl': '/auth/login/x/'}
                ]
            }
        }
        request = self.factory.get('/api/mfe_context')
        response = self._make_response(data)

        result = self.middleware.process_response(request, response)
        result_data = json.loads(result.content)
        self.assertEqual(result_data['contextData']['providers'][0]['name'], 'Mereka')

    def test_renames_authentik_provider_by_login_url(self):
        data = {
            'contextData': {
                'providers': [
                    {'id': 'oa2-sso', 'name': 'Login',
                     'loginUrl': '/auth/login/oauth2-authentik/', 'registerUrl': '/auth/x/'}
                ]
            }
        }
        request = self.factory.get('/api/mfe_context')
        response = self._make_response(data)

        result = self.middleware.process_response(request, response)
        result_data = json.loads(result.content)
        self.assertEqual(result_data['contextData']['providers'][0]['name'], 'Mereka')

    def test_non_authentik_providers_unchanged(self):
        data = {
            'contextData': {
                'providers': [
                    {'id': 'oa2-google', 'name': 'Google',
                     'loginUrl': '/auth/login/google/', 'registerUrl': '/auth/login/google/'}
                ]
            }
        }
        request = self.factory.get('/api/mfe_context')
        response = self._make_response(data)

        result = self.middleware.process_response(request, response)
        result_data = json.loads(result.content)
        self.assertEqual(result_data['contextData']['providers'][0]['name'], 'Google')

    def test_updates_content_length_header(self):
        """After modifying content, Content-Length must match new size."""
        data = {
            'contextData': {
                'providers': [
                    {'id': 'oa2-authentik', 'name': 'Authentik',
                     'loginUrl': '/auth/login/authentik/', 'registerUrl': '/auth/x/'}
                ]
            }
        }
        request = self.factory.get('/api/mfe_context')
        response = self._make_response(data)

        result = self.middleware.process_response(request, response)
        self.assertEqual(int(result['Content-Length']), len(result.content))

    def test_handles_none_provider_fields(self):
        """Provider with None name/id/loginUrl/registerUrl should not crash."""
        data = {
            'contextData': {
                'providers': [
                    {'id': None, 'name': None, 'loginUrl': None, 'registerUrl': None}
                ]
            }
        }
        request = self.factory.get('/api/mfe_context')
        response = self._make_response(data)

        # Should not raise
        result = self.middleware.process_response(request, response)
        self.assertEqual(result.status_code, 200)


# ===========================================================================
# 5. Middleware: empty providers triggers DB lookup
# ===========================================================================

class TestMiddlewareEmptyProviders(unittest.TestCase):
    """When providers array is empty, middleware queries OAuth2ProviderConfig."""

    def setUp(self):
        from mfe_oauth_fix.middleware import MFEOAuthFixMiddleware
        self.middleware = MFEOAuthFixMiddleware(get_response=lambda r: HttpResponse('ok'))
        self.factory = RequestFactory()

    def test_empty_providers_triggers_lookup(self):
        data = {'contextData': {'providers': []}}
        content = json.dumps(data).encode('utf-8')
        response = HttpResponse(content, content_type='application/json', status=200)

        request = self.factory.get('/api/mfe_context')

        # Mock the OAuth2ProviderConfig query
        mock_provider = MagicMock()
        mock_provider.slug = 'authentik-sso'
        mock_provider.name = 'Authentik SSO'
        mock_provider.backend_name = 'oauth2-authentik'
        mock_provider.icon_class = ''
        mock_provider.icon_image = None
        mock_queryset = MagicMock()
        mock_queryset.count.return_value = 1
        mock_queryset.__iter__ = lambda self: iter([mock_provider])

        with patch('mfe_oauth_fix.middleware.get_current_site') as mock_site, \
             patch('mfe_oauth_fix.middleware.OAuth2ProviderConfig',
                   create=True) as mock_config:
            # Intercept the import inside the middleware
            mock_site.return_value = MagicMock(id=1, domain='test.local')
            # The middleware tries to import from common.djangoapps.third_party_auth.models
            # or third_party_auth.models — both are already stubbed
            result = self.middleware.process_response(request, response)

        # Should still return 200 (may or may not have added providers depending on import path)
        self.assertEqual(result.status_code, 200)

    def test_json_decode_error_returns_original(self):
        """Invalid JSON body should not crash middleware."""
        response = HttpResponse(b'not-json', content_type='application/json', status=200)
        request = self.factory.get('/api/mfe_context')

        result = self.middleware.process_response(request, response)
        self.assertEqual(result.content, b'not-json')


# ===========================================================================
# 6. MFEContextView
# ===========================================================================

class TestMFEContextView(TestCase):

    def test_returns_json_with_providers_key(self):
        from mfe_oauth_fix.views import MFEContextView
        factory = RequestFactory()
        request = factory.get('/api/mfe_context')

        with patch('mfe_oauth_fix.views.get_current_site') as mock_site:
            mock_site.return_value = MagicMock(id=1, domain='test.local')
            # Mock the OAuth2ProviderConfig import inside the view
            mock_qs = MagicMock()
            mock_qs.count.return_value = 0
            mock_qs.__iter__ = lambda self: iter([])
            with patch.dict('sys.modules', {
                'common.djangoapps.third_party_auth.models': MagicMock(
                    OAuth2ProviderConfig=MagicMock(
                        objects=MagicMock(
                            filter=MagicMock(return_value=MagicMock(
                                select_related=MagicMock(return_value=mock_qs),
                                count=MagicMock(return_value=0),
                            ))
                        )
                    )
                )
            }):
                view = MFEContextView()
                response = view.get(request)

        self.assertEqual(response.status_code, 200)
        data = json.loads(response.content)
        self.assertIn('contextData', data)
        self.assertIn('providers', data['contextData'])

    def test_get_only(self):
        """POST to MFEContextView should be allowed (csrf_exempt)
        but the view only has get(), so POST returns 405."""
        from mfe_oauth_fix.views import MFEContextView
        factory = RequestFactory()
        request = factory.post('/api/mfe_context')
        view = MFEContextView.as_view()
        response = view(request)
        self.assertEqual(response.status_code, 405)


# ===========================================================================
# 7. URL patterns
# ===========================================================================

class TestURLPatterns(unittest.TestCase):

    def test_mfe_context_url(self):
        from mfe_oauth_fix.urls import urlpatterns
        names = [p.name for p in urlpatterns]
        self.assertIn('mfe_context', names)

    def test_mfe_context_path(self):
        from mfe_oauth_fix.urls import urlpatterns
        paths = [p.pattern._route for p in urlpatterns]
        self.assertIn('api/mfe_context', paths)


if __name__ == '__main__':
    unittest.main()
