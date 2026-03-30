"""
Baseline tests for openedx_content_libraries.

Covers:
- Import smoke tests for every module
- Model field existence
- Serializer field existence
- URL pattern registration
- Admin registration
- AppConfig metadata
- Management command existence

Runs without a live database or Open edX installation.
Use:
    python -m pytest infrastructure/tutor/custom-apps/openedx_content_libraries/tests.py
"""

import importlib
import os
import sys
import types
import unittest
from unittest.mock import MagicMock

# ---------------------------------------------------------------------------
# Platform stubs
# ---------------------------------------------------------------------------

def _make_stub(name, **attrs):
    mod = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(mod, k, v)
    return mod


# opaque_keys stubs
_opaque_edx_django_models = _make_stub('opaque_keys.edx.django.models')
_opaque_edx_django_models.UsageKeyField = MagicMock(return_value=MagicMock())
_opaque_edx_django_models.CourseKeyField = MagicMock(return_value=MagicMock())
for _name, _mod in [
    ('opaque_keys', _make_stub('opaque_keys')),
    ('opaque_keys.edx', _make_stub('opaque_keys.edx')),
    ('opaque_keys.edx.django', _make_stub('opaque_keys.edx.django')),
    ('opaque_keys.edx.django.models', _opaque_edx_django_models),
]:
    sys.modules.setdefault(_name, _mod)

# blockstore / openedx stubs (imported by some modules)
for _mod_name in [
    'openedx', 'openedx.core', 'openedx.core.djangoapps',
    'openedx.core.djangoapps.content_libraries',
    'openedx.core.djangoapps.content_libraries.api',
    'openedx.core.djangoapps.plugins',
    'openedx.core.djangoapps.plugins.constants',
    'blockstore', 'blockstore.apps', 'blockstore.apps.bundles',
    'edx_django_utils', 'edx_django_utils.cache',
    'meilisearch',
]:
    sys.modules.setdefault(_mod_name, _make_stub(_mod_name))

# xapi stubs
for _mod_name in [
    'tincan', 'tincan.statement', 'tincan.verb', 'tincan.activity',
    'tincan.agent', 'tincan.context',
]:
    sys.modules.setdefault(_mod_name, _make_stub(_mod_name))

# ---------------------------------------------------------------------------
# Minimal Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault(
    'DJANGO_SETTINGS_MODULE', 'openedx_content_libraries._test_settings'
)

_settings = types.ModuleType('openedx_content_libraries._test_settings')
_settings.SECRET_KEY = 'test-secret-key'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'django.contrib.sites',
    'rest_framework',
    'openedx_content_libraries',
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
_settings.SITE_ID = 1
_settings.CONTENT_LIBRARIES_MEILISEARCH_URL = ''
_settings.CONTENT_LIBRARIES_MEILISEARCH_API_KEY = ''
_settings.CONTENT_LIBRARIES_MAX_COMPONENTS_PER_LIBRARY = 10000
_settings.CONTENT_LIBRARIES_BACKUP_BUCKET = ''
_settings.XAPI_SERVICE_URL = ''

sys.modules['openedx_content_libraries._test_settings'] = _settings

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
        self._assert_importable('openedx_content_libraries.apps')

    def test_import_models(self):
        self._assert_importable('openedx_content_libraries.models')

    def test_import_admin(self):
        self._assert_importable('openedx_content_libraries.admin')

    def test_import_serializers(self):
        self._assert_importable('openedx_content_libraries.serializers')

    def test_import_urls(self):
        self._assert_importable('openedx_content_libraries.urls')

    def test_import_views(self):
        self._assert_importable('openedx_content_libraries.views')

    def test_import_signals(self):
        self._assert_importable('openedx_content_libraries.signals')

    def test_import_api(self):
        self._assert_importable('openedx_content_libraries.api')

    def test_import_analytics(self):
        self._assert_importable('openedx_content_libraries.analytics')

    def test_import_backup(self):
        self._assert_importable('openedx_content_libraries.backup')

    def test_import_export_import(self):
        self._assert_importable('openedx_content_libraries.export_import')

    def test_import_quotas(self):
        self._assert_importable('openedx_content_libraries.quotas')

    def test_import_sanitize(self):
        self._assert_importable('openedx_content_libraries.sanitize')

    def test_import_search(self):
        self._assert_importable('openedx_content_libraries.search')

    def test_import_xapi(self):
        self._assert_importable('openedx_content_libraries.xapi')


# ---------------------------------------------------------------------------
# 2. AppConfig
# ---------------------------------------------------------------------------

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from openedx_content_libraries.apps import OpenedxContentLibrariesConfig
        self.assertEqual(OpenedxContentLibrariesConfig.name, 'openedx_content_libraries')

    def test_verbose_name_contains_libraries(self):
        from openedx_content_libraries.apps import OpenedxContentLibrariesConfig
        self.assertIn('Libraries', OpenedxContentLibrariesConfig.verbose_name)

    def test_default_auto_field(self):
        from openedx_content_libraries.apps import OpenedxContentLibrariesConfig
        self.assertEqual(
            OpenedxContentLibrariesConfig.default_auto_field,
            'django.db.models.BigAutoField',
        )


# ---------------------------------------------------------------------------
# 3. Model field existence
# ---------------------------------------------------------------------------

class TestLibraryMetadataFields(unittest.TestCase):

    def setUp(self):
        from openedx_content_libraries.models import LibraryMetadata
        self.model = LibraryMetadata

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_id_field(self):
        self.assertIn('id', self._field_names())

    def test_library_key_field(self):
        self.assertIn('library_key', self._field_names())

    def test_org_field(self):
        self.assertIn('org', self._field_names())

    def test_tenant_uuid_field(self):
        self.assertIn('tenant_uuid', self._field_names())

    def test_title_field(self):
        self.assertIn('title', self._field_names())

    def test_description_field(self):
        self.assertIn('description', self._field_names())

    def test_allow_public_read_field(self):
        self.assertIn('allow_public_read', self._field_names())

    def test_is_deleted_field(self):
        self.assertIn('is_deleted', self._field_names())

    def test_deleted_at_field(self):
        self.assertIn('deleted_at', self._field_names())

    def test_created_at_field(self):
        self.assertIn('created_at', self._field_names())

    def test_updated_at_field(self):
        self.assertIn('updated_at', self._field_names())


class TestLibraryVersionFields(unittest.TestCase):

    def setUp(self):
        from openedx_content_libraries.models import LibraryVersion
        self.model = LibraryVersion

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_library_field(self):
        self.assertIn('library', self._field_names())

    def test_version_number_field(self):
        self.assertIn('version_number', self._field_names())

    def test_publish_status_field(self):
        self.assertIn('publish_status', self._field_names())

    def test_component_count_field(self):
        self.assertIn('component_count', self._field_names())

    def test_published_at_field(self):
        self.assertIn('published_at', self._field_names())


class TestLibraryComponentFields(unittest.TestCase):

    def setUp(self):
        from openedx_content_libraries.models import LibraryComponent
        self.model = LibraryComponent

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_library_field(self):
        self.assertIn('library', self._field_names())

    def test_usage_key_field(self):
        self.assertIn('usage_key', self._field_names())

    def test_block_type_field(self):
        self.assertIn('block_type', self._field_names())

    def test_display_name_field(self):
        self.assertIn('display_name', self._field_names())

    def test_has_unpublished_changes_field(self):
        self.assertIn('has_unpublished_changes', self._field_names())

    def test_is_deleted_field(self):
        self.assertIn('is_deleted', self._field_names())


class TestLibraryRoleFields(unittest.TestCase):

    def setUp(self):
        from openedx_content_libraries.models import LibraryRole
        self.model = LibraryRole

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_library_field(self):
        self.assertIn('library', self._field_names())

    def test_user_field(self):
        self.assertIn('user', self._field_names())

    def test_role_field(self):
        self.assertIn('role', self._field_names())


# ---------------------------------------------------------------------------
# 4. Serializer field existence
# ---------------------------------------------------------------------------

class TestLibraryMetadataSerializerFields(unittest.TestCase):

    def test_library_key_field(self):
        from openedx_content_libraries.serializers import LibraryMetadataSerializer
        fields = LibraryMetadataSerializer().fields
        self.assertIn('library_key', fields)

    def test_org_field(self):
        from openedx_content_libraries.serializers import LibraryMetadataSerializer
        fields = LibraryMetadataSerializer().fields
        self.assertIn('org', fields)

    def test_is_deleted_field(self):
        from openedx_content_libraries.serializers import LibraryMetadataSerializer
        fields = LibraryMetadataSerializer().fields
        self.assertIn('is_deleted', fields)

    def test_tenant_uuid_field(self):
        from openedx_content_libraries.serializers import LibraryMetadataSerializer
        fields = LibraryMetadataSerializer().fields
        self.assertIn('tenant_uuid', fields)


class TestLibraryVersionSerializerFields(unittest.TestCase):

    def test_library_key_field(self):
        from openedx_content_libraries.serializers import LibraryVersionSerializer
        fields = LibraryVersionSerializer().fields
        self.assertIn('library_key', fields)

    def test_version_number_field(self):
        from openedx_content_libraries.serializers import LibraryVersionSerializer
        fields = LibraryVersionSerializer().fields
        self.assertIn('version_number', fields)

    def test_publish_status_field(self):
        from openedx_content_libraries.serializers import LibraryVersionSerializer
        fields = LibraryVersionSerializer().fields
        self.assertIn('publish_status', fields)


# ---------------------------------------------------------------------------
# 5. URL patterns
# ---------------------------------------------------------------------------

class TestURLPatterns(unittest.TestCase):

    def test_urlpatterns_is_non_empty(self):
        from openedx_content_libraries.urls import urlpatterns
        self.assertGreater(len(urlpatterns), 0)

    def test_library_list_url_exists(self):
        from openedx_content_libraries.urls import urlpatterns
        names = {p.name for p in urlpatterns if hasattr(p, 'name')}
        self.assertIn('library-list', names)

    def test_library_publish_url_exists(self):
        from openedx_content_libraries.urls import urlpatterns
        names = {p.name for p in urlpatterns if hasattr(p, 'name')}
        self.assertIn('library-publish', names)

    def test_library_search_url_exists(self):
        from openedx_content_libraries.urls import urlpatterns
        names = {p.name for p in urlpatterns if hasattr(p, 'name')}
        self.assertIn('library-search', names)


# ---------------------------------------------------------------------------
# 6. Admin registration
# ---------------------------------------------------------------------------

class TestAdminRegistration(unittest.TestCase):

    def test_library_metadata_admin_registered(self):
        from django.contrib import admin
        from openedx_content_libraries.models import LibraryMetadata
        self.assertIn(LibraryMetadata, admin.site._registry)

    def test_library_version_admin_registered(self):
        from django.contrib import admin
        from openedx_content_libraries.models import LibraryVersion
        self.assertIn(LibraryVersion, admin.site._registry)

    def test_library_component_admin_registered(self):
        from django.contrib import admin
        from openedx_content_libraries.models import LibraryComponent
        self.assertIn(LibraryComponent, admin.site._registry)

    def test_library_role_admin_registered(self):
        from django.contrib import admin
        from openedx_content_libraries.models import LibraryRole
        self.assertIn(LibraryRole, admin.site._registry)


# ---------------------------------------------------------------------------
# 7. Management command existence
# ---------------------------------------------------------------------------

class TestManagementCommands(unittest.TestCase):

    def _assert_command_importable(self, command_name):
        mod_path = f'openedx_content_libraries.management.commands.{command_name}'
        try:
            mod = importlib.import_module(mod_path)
        except ImportError as exc:
            self.fail(f"Failed to import management command {command_name}: {exc}")
        return mod

    def test_create_platform_library_command(self):
        mod = self._assert_command_importable('create_platform_library')
        self.assertTrue(hasattr(mod, 'Command'))

    def test_reindex_libraries_command(self):
        mod = self._assert_command_importable('reindex_libraries')
        self.assertTrue(hasattr(mod, 'Command'))

    def test_backup_libraries_command(self):
        mod = self._assert_command_importable('backup_libraries')
        self.assertTrue(hasattr(mod, 'Command'))

    def test_restore_libraries_command(self):
        mod = self._assert_command_importable('restore_libraries')
        self.assertTrue(hasattr(mod, 'Command'))

    def test_audit_library_security_command(self):
        mod = self._assert_command_importable('audit_library_security')
        self.assertTrue(hasattr(mod, 'Command'))


if __name__ == '__main__':
    unittest.main()
