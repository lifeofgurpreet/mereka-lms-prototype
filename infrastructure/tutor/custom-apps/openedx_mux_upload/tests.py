"""
Baseline tests for openedx_mux_upload.

Covers:
- Import smoke tests for every module
- AppConfig (name, verbose_name)
- Model fields (MuxUpload)
- Model methods (__str__, mark_ready, mark_errored, get_upload_stats)
- Serializer fields + validation (create, model, webhook)
- Utility functions (validate_video_format, verify_mux_webhook_signature,
  get_mux_auth_header)
- Webhook handler event dispatch logic
- URL patterns
- Admin registration + permissions

Runs without Mux credentials or external services.
"""

import base64
import hashlib
import hmac
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

# Stub opaque_keys
_opaque_keys = types.ModuleType('opaque_keys')
_opaque_keys.InvalidKeyError = type('InvalidKeyError', (Exception,), {})
sys.modules['opaque_keys'] = _opaque_keys

_opaque_keys_edx = types.ModuleType('opaque_keys.edx')
sys.modules['opaque_keys.edx'] = _opaque_keys_edx

_opaque_keys_edx_keys = types.ModuleType('opaque_keys.edx.keys')


class _FakeCourseKey:
    def __init__(self, org='TestOrg', course='C101', run='2024'):
        self.org = org
        self.course = course
        self.run = run

    @classmethod
    def from_string(cls, key_str):
        if not key_str or 'invalid' in key_str.lower():
            raise _opaque_keys.InvalidKeyError(f'Invalid: {key_str}')
        parts = key_str.split('+') if '+' in key_str else ['Org', 'Course', 'Run']
        org = parts[0].split(':')[-1] if ':' in parts[0] else parts[0]
        return cls(org=org,
                   course=parts[1] if len(parts) > 1 else 'C101',
                   run=parts[2] if len(parts) > 2 else '2024')

    def __str__(self):
        return f'course-v1:{self.org}+{self.course}+{self.run}'


_opaque_keys_edx_keys.CourseKey = _FakeCourseKey
sys.modules['opaque_keys.edx.keys'] = _opaque_keys_edx_keys

# Stub opaque_keys.edx.django.models
_opaque_keys_edx_django = types.ModuleType('opaque_keys.edx.django')
sys.modules['opaque_keys.edx.django'] = _opaque_keys_edx_django

_opaque_keys_edx_django_models = types.ModuleType('opaque_keys.edx.django.models')
from django.db import models as _dj_models
_opaque_keys_edx_django_models.CourseKeyField = lambda *a, **kw: _dj_models.CharField(
    *a, **{k: v for k, v in kw.items() if k in ('max_length', 'db_index', 'help_text', 'default')}
)
sys.modules['opaque_keys.edx.django.models'] = _opaque_keys_edx_django_models

# Stub openedx plugin constants
_openedx = types.ModuleType('openedx')
sys.modules['openedx'] = _openedx
_openedx_core = types.ModuleType('openedx.core')
sys.modules['openedx.core'] = _openedx_core
_openedx_core_djangoapps = types.ModuleType('openedx.core.djangoapps')
sys.modules['openedx.core.djangoapps'] = _openedx_core_djangoapps
_openedx_plugins = types.ModuleType('openedx.core.djangoapps.plugins')
sys.modules['openedx.core.djangoapps.plugins'] = _openedx_plugins
_openedx_plugins_constants = types.ModuleType('openedx.core.djangoapps.plugins.constants')
_openedx_plugins_constants.PluginURLs = None
_openedx_plugins_constants.ProjectType = None
sys.modules['openedx.core.djangoapps.plugins.constants'] = _openedx_plugins_constants

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_mux_upload._test_settings')

_settings = types.ModuleType('openedx_mux_upload._test_settings')
_settings.SECRET_KEY = 'test-secret-key-mux-upload'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'rest_framework',
    'openedx_mux_upload',
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
_settings.ENABLE_MUX_STUDIO_UPLOAD = False
_settings.REST_FRAMEWORK = {}

sys.modules['openedx_mux_upload._test_settings'] = _settings

import django
django.setup()

# Create tables ONCE at module level.
from django.core.management import call_command
call_command('migrate', '--run-syncdb', verbosity=0)

from django.db import connection
from openedx_mux_upload.models import MuxUpload
with connection.schema_editor() as editor:
    try:
        editor.create_model(MuxUpload)
    except Exception:
        pass

from django.contrib.auth import get_user_model
from django.test import TestCase, RequestFactory
from django.utils import timezone


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
        self._assert_importable('openedx_mux_upload')

    def test_import_apps(self):
        self._assert_importable('openedx_mux_upload.apps')

    def test_import_models(self):
        self._assert_importable('openedx_mux_upload.models')

    def test_import_serializers(self):
        self._assert_importable('openedx_mux_upload.serializers')

    def test_import_utils(self):
        self._assert_importable('openedx_mux_upload.utils')

    def test_import_views(self):
        self._assert_importable('openedx_mux_upload.views')

    def test_import_urls(self):
        self._assert_importable('openedx_mux_upload.urls')

    def test_import_admin(self):
        self._assert_importable('openedx_mux_upload.admin')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from openedx_mux_upload.apps import MuxUploadConfig
        self.assertEqual(MuxUploadConfig.name, 'openedx_mux_upload')

    def test_verbose_name(self):
        from openedx_mux_upload.apps import MuxUploadConfig
        self.assertEqual(MuxUploadConfig.verbose_name, 'Mux Video Upload')

    def test_default_auto_field(self):
        from openedx_mux_upload.apps import MuxUploadConfig
        self.assertEqual(MuxUploadConfig.default_auto_field, 'django.db.models.BigAutoField')


# ===========================================================================
# 3. Model fields: MuxUpload
# ===========================================================================

class TestMuxUploadFields(unittest.TestCase):

    def setUp(self):
        from openedx_mux_upload.models import MuxUpload
        self.model = MuxUpload

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_user_field(self):
        self.assertIn('user', self._field_names())

    def test_course_key_field(self):
        self.assertIn('course_key', self._field_names())

    def test_upload_id_field(self):
        self.assertIn('upload_id', self._field_names())

    def test_asset_id_field(self):
        self.assertIn('asset_id', self._field_names())

    def test_playback_id_field(self):
        self.assertIn('playback_id', self._field_names())

    def test_status_field(self):
        self.assertIn('status', self._field_names())

    def test_error_message_field(self):
        self.assertIn('error_message', self._field_names())

    def test_filename_field(self):
        self.assertIn('filename', self._field_names())

    def test_filesize_bytes_field(self):
        self.assertIn('filesize_bytes', self._field_names())

    def test_video_title_field(self):
        self.assertIn('video_title', self._field_names())

    def test_created_at_field(self):
        self.assertIn('created_at', self._field_names())

    def test_updated_at_field(self):
        self.assertIn('updated_at', self._field_names())

    def test_completed_at_field(self):
        self.assertIn('completed_at', self._field_names())

    def test_webhook_payload_field(self):
        self.assertIn('webhook_payload', self._field_names())

    def test_upload_id_is_unique(self):
        field = self.model._meta.get_field('upload_id')
        self.assertTrue(field.unique)

    def test_ordering(self):
        self.assertEqual(self.model._meta.ordering, ['-created_at'])

    def test_verbose_name(self):
        self.assertEqual(self.model._meta.verbose_name, 'Mux Video Upload')

    def test_status_default(self):
        field = self.model._meta.get_field('status')
        self.assertEqual(field.default, 'pending')


# ===========================================================================
# 4. Model methods: MuxUpload
# ===========================================================================

class TestMuxUploadMethods(TestCase):

    def _create_user(self, username='uploader'):
        User = get_user_model()
        user, _ = User.objects.get_or_create(username=username, defaults={'password': 'x'})
        return user

    def _create_upload(self, user=None, upload_id='upload-001', status='pending', **kwargs):
        from openedx_mux_upload.models import MuxUpload
        if user is None:
            user = self._create_user()
        return MuxUpload.objects.create(
            user=user, course_key='course-v1:T+C+R', upload_id=upload_id,
            status=status, **kwargs,
        )

    def test_str_representation(self):
        upload = self._create_upload(upload_id='up-str-test')
        result = str(upload)
        self.assertIn('up-str-test', result)
        self.assertIn('pending', result)
        self.assertIn('course', result.lower())

    def test_mark_ready(self):
        upload = self._create_upload(upload_id='up-ready', status='processing')
        upload.mark_ready(asset_id='asset-123', playback_id='play-456')
        upload.refresh_from_db()
        self.assertEqual(upload.status, 'ready')
        self.assertEqual(upload.asset_id, 'asset-123')
        self.assertEqual(upload.playback_id, 'play-456')
        self.assertIsNotNone(upload.completed_at)

    def test_mark_errored(self):
        upload = self._create_upload(upload_id='up-err', status='processing')
        upload.mark_errored(error_message='Transcode failed')
        upload.refresh_from_db()
        self.assertEqual(upload.status, 'errored')
        self.assertEqual(upload.error_message, 'Transcode failed')
        self.assertIsNotNone(upload.completed_at)

    def test_get_upload_stats_all(self):
        from openedx_mux_upload.models import MuxUpload
        user = self._create_user('stats-user')
        self._create_upload(user=user, upload_id='s1', status='pending')
        self._create_upload(user=user, upload_id='s2', status='ready')
        self._create_upload(user=user, upload_id='s3', status='errored')
        stats = MuxUpload.get_upload_stats()
        self.assertGreaterEqual(stats['total'], 3)
        self.assertGreaterEqual(stats['pending'], 1)
        self.assertGreaterEqual(stats['ready'], 1)
        self.assertGreaterEqual(stats['errored'], 1)

    def test_get_upload_stats_by_course(self):
        from openedx_mux_upload.models import MuxUpload
        user = self._create_user('stats-course')
        self._create_upload(user=user, upload_id='cs1', status='ready')
        stats = MuxUpload.get_upload_stats(course_key='course-v1:T+C+R')
        self.assertGreaterEqual(stats['ready'], 1)

    def test_mark_ready_idempotent_status(self):
        """Calling mark_ready twice should not error."""
        upload = self._create_upload(upload_id='up-idem', status='processing')
        upload.mark_ready(asset_id='a1', playback_id='p1')
        first_completed = upload.completed_at
        upload.mark_ready(asset_id='a2', playback_id='p2')
        upload.refresh_from_db()
        self.assertEqual(upload.asset_id, 'a2')


# ===========================================================================
# 5. Serializer validation
# ===========================================================================

class TestCreateDirectUploadSerializer(unittest.TestCase):

    def test_valid_minimal(self):
        from openedx_mux_upload.serializers import CreateDirectUploadSerializer
        s = CreateDirectUploadSerializer(data={'course_key': 'course-v1:T+C+R'})
        self.assertTrue(s.is_valid(), s.errors)

    def test_missing_course_key(self):
        from openedx_mux_upload.serializers import CreateDirectUploadSerializer
        s = CreateDirectUploadSerializer(data={})
        self.assertFalse(s.is_valid())
        self.assertIn('course_key', s.errors)

    def test_optional_fields_accepted(self):
        from openedx_mux_upload.serializers import CreateDirectUploadSerializer
        data = {
            'course_key': 'course-v1:T+C+R',
            'filename': 'lesson.mp4',
            'filesize_bytes': 1024000,
            'video_title': 'My Lesson',
        }
        s = CreateDirectUploadSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)
        self.assertEqual(s.validated_data['filename'], 'lesson.mp4')


class TestMuxWebhookEventSerializer(unittest.TestCase):

    def test_valid_event(self):
        from openedx_mux_upload.serializers import MuxWebhookEventSerializer
        data = {'type': 'video.asset.ready', 'data': {'id': 'asset123', 'status': 'ready'}}
        s = MuxWebhookEventSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)

    def test_missing_type(self):
        from openedx_mux_upload.serializers import MuxWebhookEventSerializer
        s = MuxWebhookEventSerializer(data={'data': {}})
        self.assertFalse(s.is_valid())
        self.assertIn('type', s.errors)

    def test_missing_data(self):
        from openedx_mux_upload.serializers import MuxWebhookEventSerializer
        s = MuxWebhookEventSerializer(data={'type': 'video.asset.ready'})
        self.assertFalse(s.is_valid())
        self.assertIn('data', s.errors)


class TestMuxUploadSerializer(unittest.TestCase):

    def test_read_only_fields(self):
        from openedx_mux_upload.serializers import MuxUploadSerializer
        ro = MuxUploadSerializer.Meta.read_only_fields
        for field in ('id', 'user', 'upload_id', 'asset_id', 'playback_id', 'status',
                      'error_message', 'created_at', 'updated_at', 'completed_at'):
            self.assertIn(field, ro)

    def test_fields_include_user_username(self):
        from openedx_mux_upload.serializers import MuxUploadSerializer
        self.assertIn('user_username', MuxUploadSerializer.Meta.fields)


# ===========================================================================
# 6. Utility functions
# ===========================================================================

class TestValidateVideoFormat(unittest.TestCase):

    def test_mp4_valid(self):
        from openedx_mux_upload.utils import validate_video_format
        self.assertTrue(validate_video_format('lesson.mp4'))

    def test_mov_valid(self):
        from openedx_mux_upload.utils import validate_video_format
        self.assertTrue(validate_video_format('video.MOV'))

    def test_webm_valid(self):
        from openedx_mux_upload.utils import validate_video_format
        self.assertTrue(validate_video_format('clip.webm'))

    def test_mkv_valid(self):
        from openedx_mux_upload.utils import validate_video_format
        self.assertTrue(validate_video_format('file.mkv'))

    def test_avi_invalid(self):
        from openedx_mux_upload.utils import validate_video_format
        with self.assertRaises(ValueError) as ctx:
            validate_video_format('bad.avi')
        self.assertIn('avi', str(ctx.exception).lower())
        self.assertIn('Supported formats', str(ctx.exception))

    def test_no_extension_invalid(self):
        from openedx_mux_upload.utils import validate_video_format
        with self.assertRaises(ValueError):
            validate_video_format('noextension')

    def test_custom_formats(self):
        from openedx_mux_upload.utils import validate_video_format
        self.assertTrue(validate_video_format('clip.flv', supported_formats=['flv', 'avi']))

    def test_custom_formats_rejects_mp4(self):
        from openedx_mux_upload.utils import validate_video_format
        with self.assertRaises(ValueError):
            validate_video_format('clip.mp4', supported_formats=['flv'])


class TestGetMuxAuthHeader(unittest.TestCase):

    def test_missing_credentials_raises(self):
        from openedx_mux_upload.utils import get_mux_auth_header
        with patch.dict(os.environ, {}, clear=True), \
             patch('openedx_mux_upload.utils.MUX_TOKEN_ID', None), \
             patch('openedx_mux_upload.utils.MUX_TOKEN_SECRET', None):
            with self.assertRaises(ValueError) as ctx:
                get_mux_auth_header()
            self.assertIn('MUX_TOKEN_ID', str(ctx.exception))

    def test_returns_basic_auth(self):
        from openedx_mux_upload.utils import get_mux_auth_header
        with patch('openedx_mux_upload.utils.MUX_TOKEN_ID', 'test-id'), \
             patch('openedx_mux_upload.utils.MUX_TOKEN_SECRET', 'test-secret'):
            headers = get_mux_auth_header()
        expected = base64.b64encode(b'test-id:test-secret').decode()
        self.assertEqual(headers['Authorization'], f'Basic {expected}')
        self.assertEqual(headers['Content-Type'], 'application/json')


class TestVerifyMuxWebhookSignature(unittest.TestCase):

    def test_valid_signature(self):
        from openedx_mux_upload.utils import verify_mux_webhook_signature
        secret = 'my-webhook-secret'
        body = b'{"type":"video.asset.ready"}'
        sig = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
        header = f't=1234567890,v1={sig}'
        self.assertTrue(verify_mux_webhook_signature(body, header, secret))

    def test_invalid_signature(self):
        from openedx_mux_upload.utils import verify_mux_webhook_signature
        self.assertFalse(verify_mux_webhook_signature(b'body', 't=1,v1=bad', 'secret'))

    def test_malformed_header(self):
        from openedx_mux_upload.utils import verify_mux_webhook_signature
        self.assertFalse(verify_mux_webhook_signature(b'body', 'garbage', 'secret'))


# ===========================================================================
# 7. URL patterns
# ===========================================================================

class TestURLPatterns(unittest.TestCase):

    def test_url_names_exist(self):
        from openedx_mux_upload.urls import urlpatterns
        names = [p.name for p in urlpatterns]
        self.assertIn('create-direct-upload', names)
        self.assertIn('get-upload-status', names)
        self.assertIn('list-uploads', names)
        self.assertIn('mux-webhook', names)

    def test_app_name(self):
        from openedx_mux_upload import urls
        self.assertEqual(urls.app_name, 'openedx_mux_upload')


# ===========================================================================
# 8. Admin registration
# ===========================================================================

class TestAdminRegistration(unittest.TestCase):

    def test_mux_upload_admin(self):
        from django.contrib import admin
        from openedx_mux_upload.models import MuxUpload
        self.assertIn(MuxUpload, admin.site._registry)

    def test_admin_no_add(self):
        from django.contrib import admin
        from openedx_mux_upload.models import MuxUpload
        model_admin = admin.site._registry[MuxUpload]
        request = MagicMock()
        self.assertFalse(model_admin.has_add_permission(request))

    def test_admin_allows_delete(self):
        from django.contrib import admin
        from openedx_mux_upload.models import MuxUpload
        model_admin = admin.site._registry[MuxUpload]
        request = MagicMock()
        self.assertTrue(model_admin.has_delete_permission(request))


# ===========================================================================
# 9. View feature flag gating
# ===========================================================================

class TestCreateDirectUploadViewGating(TestCase):

    def _create_user(self, username='viewuser'):
        User = get_user_model()
        user, _ = User.objects.get_or_create(username=username, defaults={'password': 'x'})
        return user

    def test_returns_503_when_feature_disabled(self):
        from rest_framework.test import APIRequestFactory, force_authenticate
        from openedx_mux_upload.views import create_direct_upload_view

        user = self._create_user('mux-503')
        factory = APIRequestFactory()
        request = factory.post('/api/mux/upload/create/',
                               {'course_key': 'course-v1:T+C+R'}, format='json')
        force_authenticate(request, user=user)

        with patch('openedx_mux_upload.views.settings') as mock_settings:
            mock_settings.ENABLE_MUX_STUDIO_UPLOAD = False
            response = create_direct_upload_view(request)

        self.assertEqual(response.status_code, 503)

    def test_invalid_course_key_returns_400(self):
        from rest_framework.test import APIRequestFactory, force_authenticate
        from openedx_mux_upload.views import create_direct_upload_view

        user = self._create_user('mux-400')
        factory = APIRequestFactory()
        request = factory.post('/api/mux/upload/create/',
                               {'course_key': 'invalid-key'}, format='json')
        force_authenticate(request, user=user)

        with patch('openedx_mux_upload.views.settings') as mock_settings:
            mock_settings.ENABLE_MUX_STUDIO_UPLOAD = True
            response = create_direct_upload_view(request)

        self.assertEqual(response.status_code, 400)


class TestWebhookHandler(TestCase):

    def test_asset_ready_marks_upload_ready(self):
        """Webhook video.asset.ready should transition upload to ready."""
        from openedx_mux_upload.models import MuxUpload
        from openedx_mux_upload.views import mux_webhook_handler

        user = get_user_model().objects.create_user('wh-user', password='x')
        upload = MuxUpload.objects.create(
            user=user, course_key='course-v1:T+C+R', upload_id='wh-up-1',
            status='processing', asset_id='asset-ready-1',
        )

        factory = RequestFactory()
        payload = {
            'type': 'video.asset.ready',
            'data': {
                'id': 'asset-ready-1',
                'playback_ids': [{'id': 'play-ready-1', 'policy': 'public'}],
            },
        }
        request = factory.post('/api/mux/upload/webhook/',
                               data=json.dumps(payload),
                               content_type='application/json')
        # Webhook has no auth
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop('MUX_WEBHOOK_SECRET', None)
            response = mux_webhook_handler(request)

        self.assertEqual(response.status_code, 200)
        upload.refresh_from_db()
        self.assertEqual(upload.status, 'ready')
        self.assertEqual(upload.playback_id, 'play-ready-1')

    def test_asset_errored_marks_upload_errored(self):
        """Webhook video.asset.errored should transition upload to errored."""
        from openedx_mux_upload.models import MuxUpload
        from openedx_mux_upload.views import mux_webhook_handler

        user = get_user_model().objects.create_user('wh-user2', password='x')
        upload = MuxUpload.objects.create(
            user=user, course_key='course-v1:T+C+R', upload_id='wh-up-2',
            status='processing', asset_id='asset-err-1',
        )

        factory = RequestFactory()
        payload = {
            'type': 'video.asset.errored',
            'data': {
                'id': 'asset-err-1',
                'errors': {'messages': ['Corrupt file', 'Bad codec']},
            },
        }
        request = factory.post('/api/mux/upload/webhook/',
                               data=json.dumps(payload),
                               content_type='application/json')
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop('MUX_WEBHOOK_SECRET', None)
            response = mux_webhook_handler(request)

        self.assertEqual(response.status_code, 200)
        upload.refresh_from_db()
        self.assertEqual(upload.status, 'errored')
        self.assertIn('Corrupt file', upload.error_message)
        self.assertIn('Bad codec', upload.error_message)

    def test_unknown_event_returns_200(self):
        """Unhandled event types should return 200 (no failure)."""
        from openedx_mux_upload.views import mux_webhook_handler
        factory = RequestFactory()
        payload = {'type': 'video.unknown.event', 'data': {'id': 'x'}}
        request = factory.post('/api/mux/upload/webhook/',
                               data=json.dumps(payload),
                               content_type='application/json')
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop('MUX_WEBHOOK_SECRET', None)
            response = mux_webhook_handler(request)
        self.assertEqual(response.status_code, 200)

    def test_missing_asset_returns_404(self):
        """Webhook for non-existent asset should return 404."""
        from openedx_mux_upload.views import mux_webhook_handler
        factory = RequestFactory()
        payload = {
            'type': 'video.asset.ready',
            'data': {'id': 'nonexistent-asset', 'playback_ids': [{'id': 'p'}]},
        }
        request = factory.post('/api/mux/upload/webhook/',
                               data=json.dumps(payload),
                               content_type='application/json')
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop('MUX_WEBHOOK_SECRET', None)
            response = mux_webhook_handler(request)
        self.assertEqual(response.status_code, 404)


# ===========================================================================
# 10. Upload status choices
# ===========================================================================

class TestUploadStatusChoices(unittest.TestCase):

    def test_all_expected_statuses(self):
        from openedx_mux_upload.models import UPLOAD_STATUS_CHOICES
        status_keys = [s[0] for s in UPLOAD_STATUS_CHOICES]
        for expected in ('pending', 'uploading', 'processing', 'ready', 'errored'):
            self.assertIn(expected, status_keys)


if __name__ == '__main__':
    unittest.main()
