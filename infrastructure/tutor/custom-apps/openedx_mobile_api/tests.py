"""
Baseline tests for openedx_mobile_api.

Covers:
- Import smoke tests for every module
- Model field existence (MobileDevice, MobileBrandingConfig, MobileAppVersion)
- Serializer field existence
- View class existence
- URL pattern registration
- Admin registration
- AppConfig metadata

Runs without a live database or Open edX installation.
Use:
    python -m pytest infrastructure/tutor/custom-apps/openedx_mobile_api/tests.py
"""

import importlib
import os
import sys
import types
import unittest
from unittest.mock import MagicMock

# ---------------------------------------------------------------------------
# Minimal platform stubs so models/serializers import cleanly
# ---------------------------------------------------------------------------

def _make_stub(name, **attrs):
    mod = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(mod, k, v)
    return mod


# social_django / social_core aren't installed; stub them out
for _mod in [
    'social_django', 'social_django.models',
    'social_core', 'social_core.backends', 'social_core.backends.oauth',
]:
    sys.modules.setdefault(_mod, _make_stub(_mod))

_social_oauth = sys.modules['social_core.backends.oauth']
_social_oauth.BaseOAuth2 = object

# opaque_keys stubs
_opaque = _make_stub('opaque_keys')
_opaque_edx = _make_stub('opaque_keys.edx')
_opaque_edx_django = _make_stub('opaque_keys.edx.django')
_opaque_edx_django_models = _make_stub('opaque_keys.edx.django.models')
_opaque_edx_django_models.UsageKeyField = MagicMock(return_value=MagicMock())
_opaque_edx_django_models.CourseKeyField = MagicMock(return_value=MagicMock())
for _name, _mod in [
    ('opaque_keys', _opaque),
    ('opaque_keys.edx', _opaque_edx),
    ('opaque_keys.edx.django', _opaque_edx_django),
    ('opaque_keys.edx.django.models', _opaque_edx_django_models),
]:
    sys.modules.setdefault(_name, _mod)

# ---------------------------------------------------------------------------
# Minimal Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_mobile_api._test_settings')

_settings = types.ModuleType('openedx_mobile_api._test_settings')
_settings.SECRET_KEY = 'test-secret-key'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'django.contrib.sites',
    'rest_framework',
    'openedx_mobile_api',
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
_settings.CACHES = {
    'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}
}
_settings.ROOT_URLCONF = 'openedx_mobile_api.urls'
_settings.SITE_ID = 1
_settings.APNS_PUSH_CERTIFICATE = ''
_settings.APNS_PUSH_KEY = ''
_settings.IOS_BUNDLE_ID = 'com.mereka.academy'
_settings.KAJABI_SSO_ENABLED = False

sys.modules['openedx_mobile_api._test_settings'] = _settings

import django
django.setup()


# ---------------------------------------------------------------------------
# 1. Import smoke tests
# ---------------------------------------------------------------------------

class TestModuleImports(unittest.TestCase):
    """Every module must be importable without raising."""

    def _assert_importable(self, module_name):
        try:
            mod = importlib.import_module(module_name)
        except ImportError as exc:
            self.fail(f"Failed to import {module_name}: {exc}")
        return mod

    def test_import_apps(self):
        self._assert_importable('openedx_mobile_api.apps')

    def test_import_models(self):
        self._assert_importable('openedx_mobile_api.models')

    def test_import_serializers(self):
        self._assert_importable('openedx_mobile_api.serializers')

    def test_import_views(self):
        self._assert_importable('openedx_mobile_api.views')

    def test_import_urls(self):
        self._assert_importable('openedx_mobile_api.urls')

    def test_import_admin(self):
        self._assert_importable('openedx_mobile_api.admin')

    def test_import_ios_auth(self):
        self._assert_importable('openedx_mobile_api.ios_auth')

    def test_import_ios_offline(self):
        self._assert_importable('openedx_mobile_api.ios_offline')

    def test_import_ios_offline_serializers(self):
        self._assert_importable('openedx_mobile_api.ios_offline_serializers')

    def test_import_ios_offline_views(self):
        self._assert_importable('openedx_mobile_api.ios_offline_views')

    def test_import_ios_offline_urls(self):
        self._assert_importable('openedx_mobile_api.ios_offline_urls')

    def test_import_ios_release(self):
        self._assert_importable('openedx_mobile_api.ios_release')

    def test_import_ios_release_serializers(self):
        self._assert_importable('openedx_mobile_api.ios_release_serializers')

    def test_import_ios_release_views(self):
        self._assert_importable('openedx_mobile_api.ios_release_views')

    def test_import_ios_release_urls(self):
        self._assert_importable('openedx_mobile_api.ios_release_urls')

    def test_import_ios_serializers(self):
        self._assert_importable('openedx_mobile_api.ios_serializers')

    def test_import_ios_views(self):
        self._assert_importable('openedx_mobile_api.ios_views')

    def test_import_ios_urls(self):
        self._assert_importable('openedx_mobile_api.ios_urls')


# ---------------------------------------------------------------------------
# 2. AppConfig
# ---------------------------------------------------------------------------

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from openedx_mobile_api.apps import MobileAPIConfig
        self.assertEqual(MobileAPIConfig.name, 'openedx_mobile_api')

    def test_verbose_name_contains_mobile(self):
        from openedx_mobile_api.apps import MobileAPIConfig
        self.assertIn('Mobile', MobileAPIConfig.verbose_name)


# ---------------------------------------------------------------------------
# 3. Model field existence
# ---------------------------------------------------------------------------

class TestMobileDeviceFields(unittest.TestCase):

    def setUp(self):
        from openedx_mobile_api.models import MobileDevice
        self.model = MobileDevice

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_user_field(self):
        self.assertIn('user', self._field_names())

    def test_device_token_field(self):
        self.assertIn('device_token', self._field_names())

    def test_platform_field(self):
        self.assertIn('platform', self._field_names())

    def test_app_version_field(self):
        self.assertIn('app_version', self._field_names())

    def test_os_version_field(self):
        self.assertIn('os_version', self._field_names())

    def test_device_name_field(self):
        self.assertIn('device_name', self._field_names())

    def test_is_active_field(self):
        self.assertIn('is_active', self._field_names())

    def test_last_active_field(self):
        self.assertIn('last_active', self._field_names())

    def test_created_at_field(self):
        self.assertIn('created_at', self._field_names())

    def test_updated_at_field(self):
        self.assertIn('updated_at', self._field_names())

    def test_platform_choices_contains_ios(self):
        choices = dict(self.model.PLATFORM_CHOICES)
        self.assertIn('ios', choices)

    def test_platform_choices_contains_android(self):
        choices = dict(self.model.PLATFORM_CHOICES)
        self.assertIn('android', choices)

    def test_db_table(self):
        self.assertEqual(self.model._meta.db_table, 'mobile_device')


class TestMobileBrandingConfigFields(unittest.TestCase):

    def setUp(self):
        from openedx_mobile_api.models import MobileBrandingConfig
        self.model = MobileBrandingConfig

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_org_slug_field(self):
        self.assertIn('org_slug', self._field_names())

    def test_org_name_field(self):
        self.assertIn('org_name', self._field_names())

    def test_primary_color_field(self):
        self.assertIn('primary_color', self._field_names())

    def test_secondary_color_field(self):
        self.assertIn('secondary_color', self._field_names())

    def test_logo_url_field(self):
        self.assertIn('logo_url', self._field_names())

    def test_logo_square_url_field(self):
        self.assertIn('logo_square_url', self._field_names())

    def test_enable_dark_mode_field(self):
        self.assertIn('enable_dark_mode', self._field_names())

    def test_enable_push_notifications_field(self):
        self.assertIn('enable_push_notifications', self._field_names())

    def test_enable_offline_mode_field(self):
        self.assertIn('enable_offline_mode', self._field_names())

    def test_min_ios_version_field(self):
        self.assertIn('min_ios_version', self._field_names())

    def test_min_android_version_field(self):
        self.assertIn('min_android_version', self._field_names())

    def test_custom_config_field(self):
        self.assertIn('custom_config', self._field_names())

    def test_db_table(self):
        self.assertEqual(self.model._meta.db_table, 'mobile_branding_config')


class TestMobileAppVersionFields(unittest.TestCase):

    def setUp(self):
        from openedx_mobile_api.models import MobileAppVersion
        self.model = MobileAppVersion

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_platform_field(self):
        self.assertIn('platform', self._field_names())

    def test_version_field(self):
        self.assertIn('version', self._field_names())

    def test_min_supported_version_field(self):
        self.assertIn('min_supported_version', self._field_names())

    def test_is_deprecated_field(self):
        self.assertIn('is_deprecated', self._field_names())

    def test_force_update_field(self):
        self.assertIn('force_update', self._field_names())

    def test_release_notes_field(self):
        self.assertIn('release_notes', self._field_names())

    def test_released_at_field(self):
        self.assertIn('released_at', self._field_names())

    def test_db_table(self):
        self.assertEqual(self.model._meta.db_table, 'mobile_app_version')


# ---------------------------------------------------------------------------
# 4. ios_auth model field existence (PKCEChallenge, MobileToken, APNsNotification)
# ---------------------------------------------------------------------------

class TestPKCEChallengeFields(unittest.TestCase):

    def setUp(self):
        from openedx_mobile_api.ios_auth import PKCEChallenge
        self.model = PKCEChallenge

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_code_verifier_field(self):
        self.assertIn('code_verifier', self._field_names())

    def test_code_challenge_field(self):
        self.assertIn('code_challenge', self._field_names())

    def test_state_field(self):
        self.assertIn('state', self._field_names())

    def test_expires_at_field(self):
        self.assertIn('expires_at', self._field_names())


# ---------------------------------------------------------------------------
# 5. Serializer field existence
# ---------------------------------------------------------------------------

class TestMobileDeviceSerializerFields(unittest.TestCase):

    def test_declared_fields_include_device_token(self):
        from openedx_mobile_api.serializers import MobileDeviceSerializer
        fields = MobileDeviceSerializer().fields
        self.assertIn('device_token', fields)

    def test_declared_fields_include_platform(self):
        from openedx_mobile_api.serializers import MobileDeviceSerializer
        fields = MobileDeviceSerializer().fields
        self.assertIn('platform', fields)

    def test_declared_fields_include_is_active(self):
        from openedx_mobile_api.serializers import MobileDeviceSerializer
        fields = MobileDeviceSerializer().fields
        self.assertIn('is_active', fields)


class TestMobileBrandingConfigSerializerFields(unittest.TestCase):

    def test_declared_fields_include_org_slug(self):
        from openedx_mobile_api.serializers import MobileBrandingConfigSerializer
        fields = MobileBrandingConfigSerializer().fields
        self.assertIn('org_slug', fields)

    def test_declared_fields_include_feature_flags(self):
        from openedx_mobile_api.serializers import MobileBrandingConfigSerializer
        fields = MobileBrandingConfigSerializer().fields
        self.assertIn('feature_flags', fields)

    def test_declared_fields_include_primary_color(self):
        from openedx_mobile_api.serializers import MobileBrandingConfigSerializer
        fields = MobileBrandingConfigSerializer().fields
        self.assertIn('primary_color', fields)


# ---------------------------------------------------------------------------
# 6. View class existence
# ---------------------------------------------------------------------------

class TestViewClasses(unittest.TestCase):

    def test_mobile_branding_config_view_exists(self):
        from openedx_mobile_api.views import MobileBrandingConfigView
        self.assertTrue(callable(MobileBrandingConfigView))

    def test_branding_view_has_get_method(self):
        from openedx_mobile_api.views import MobileBrandingConfigView
        self.assertTrue(hasattr(MobileBrandingConfigView, 'get'))


# ---------------------------------------------------------------------------
# 7. URL pattern count sanity
# ---------------------------------------------------------------------------

class TestURLPatterns(unittest.TestCase):

    def test_urlpatterns_is_non_empty(self):
        from openedx_mobile_api.urls import urlpatterns
        self.assertGreater(len(urlpatterns), 0)


# ---------------------------------------------------------------------------
# 8. Admin registration
# ---------------------------------------------------------------------------

class TestAdminRegistration(unittest.TestCase):

    def test_mobile_device_admin_registered(self):
        from django.contrib import admin
        from openedx_mobile_api.models import MobileDevice
        self.assertIn(MobileDevice, admin.site._registry)

    def test_mobile_branding_config_admin_registered(self):
        from django.contrib import admin
        from openedx_mobile_api.models import MobileBrandingConfig
        self.assertIn(MobileBrandingConfig, admin.site._registry)

    def test_mobile_app_version_admin_registered(self):
        from django.contrib import admin
        from openedx_mobile_api.models import MobileAppVersion
        self.assertIn(MobileAppVersion, admin.site._registry)


if __name__ == '__main__':
    unittest.main()
