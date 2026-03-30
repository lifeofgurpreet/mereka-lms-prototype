"""
Baseline tests for openedx_video_protection.

Covers:
- Import smoke tests for every module
- AppConfig (name, verbose_name)
- Model fields (SignedPlaybackToken, VideoAccessLog)
- Model methods (__str__, is_expired, cleanup_expired_tokens, count_recent_tokens)
- Serializer fields + validation (request and response serializers)
- Utility functions (hash_ip_address, get_client_ip, extract_org_slug, is_rate_limited,
  generate_signed_playback_url)
- View function existence + feature flag gating
- URL patterns
- Admin registration + permissions

Runs without Mux credentials or external services.
"""

import importlib
import os
import sys
import types
import unittest
from datetime import timedelta
from unittest.mock import MagicMock, patch, PropertyMock

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
    """Minimal CourseKey stub."""
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

# Stub opaque_keys.edx.django.models — provides CourseKeyField as CharField
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

# Stub celery
_celery_mod = types.ModuleType('celery')
_celery_mod.shared_task = lambda *a, **kw: (lambda fn: fn) if not a else a[0]
sys.modules['celery'] = _celery_mod

# Stub common.djangoapps.student.models for enrollment check
_common = types.ModuleType('common')
sys.modules['common'] = _common
_common_djangoapps = types.ModuleType('common.djangoapps')
sys.modules['common.djangoapps'] = _common_djangoapps
_common_student = types.ModuleType('common.djangoapps.student')
sys.modules['common.djangoapps.student'] = _common_student
_common_student_models = types.ModuleType('common.djangoapps.student.models')
_mock_enrollment = MagicMock()
_mock_enrollment.is_enrolled = MagicMock(return_value=True)
_common_student_models.CourseEnrollment = _mock_enrollment
sys.modules['common.djangoapps.student.models'] = _common_student_models

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_video_protection._test_settings')

_settings = types.ModuleType('openedx_video_protection._test_settings')
_settings.SECRET_KEY = 'test-secret-key-video-protection'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'rest_framework',
    'openedx_video_protection',
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
_settings.ENABLE_MUX_SIGNED_PLAYBACK = False
_settings.MUX_SIGNING_KEY_ID = None
_settings.MUX_SIGNING_PRIVATE_KEY = None
_settings.MUX_PLAYBACK_AUDIENCE = None
_settings.REST_FRAMEWORK = {}

sys.modules['openedx_video_protection._test_settings'] = _settings

import django
django.setup()

# Create tables ONCE at module level.
# These apps have migrations/ dirs but no actual migration files, so --run-syncdb skips them.
# Use schema_editor directly to create the model tables.
from django.core.management import call_command
call_command('migrate', '--run-syncdb', verbosity=0)

from django.db import connection
from openedx_video_protection.models import SignedPlaybackToken, VideoAccessLog
with connection.schema_editor() as editor:
    for model in (SignedPlaybackToken, VideoAccessLog):
        try:
            editor.create_model(model)
        except Exception:
            pass  # Table already exists

# Now safe to import Django-dependent modules
from django.contrib.auth import get_user_model
from django.test import TestCase, RequestFactory
from django.utils import timezone


# ===========================================================================
# 1. Import smoke tests
# ===========================================================================

class TestModuleImports(unittest.TestCase):
    """Every module must be importable without raising."""

    def _assert_importable(self, name):
        try:
            return importlib.import_module(name)
        except ImportError as exc:
            self.fail(f'Failed to import {name}: {exc}')

    def test_import_init(self):
        self._assert_importable('openedx_video_protection')

    def test_import_apps(self):
        self._assert_importable('openedx_video_protection.apps')

    def test_import_models(self):
        self._assert_importable('openedx_video_protection.models')

    def test_import_serializers(self):
        self._assert_importable('openedx_video_protection.serializers')

    def test_import_utils(self):
        self._assert_importable('openedx_video_protection.utils')

    def test_import_views(self):
        self._assert_importable('openedx_video_protection.views')

    def test_import_urls(self):
        self._assert_importable('openedx_video_protection.urls')

    def test_import_admin(self):
        self._assert_importable('openedx_video_protection.admin')

    def test_import_tasks(self):
        self._assert_importable('openedx_video_protection.tasks')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from openedx_video_protection.apps import VideoProtectionConfig
        self.assertEqual(VideoProtectionConfig.name, 'openedx_video_protection')

    def test_verbose_name(self):
        from openedx_video_protection.apps import VideoProtectionConfig
        self.assertEqual(VideoProtectionConfig.verbose_name, 'Video Content Protection')

    def test_default_auto_field(self):
        from openedx_video_protection.apps import VideoProtectionConfig
        self.assertEqual(VideoProtectionConfig.default_auto_field, 'django.db.models.BigAutoField')


# ===========================================================================
# 3. Model fields: SignedPlaybackToken
# ===========================================================================

class TestSignedPlaybackTokenFields(unittest.TestCase):

    def setUp(self):
        from openedx_video_protection.models import SignedPlaybackToken
        self.model = SignedPlaybackToken

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_user_field(self):
        self.assertIn('user', self._field_names())

    def test_course_key_field(self):
        self.assertIn('course_key', self._field_names())

    def test_video_id_field(self):
        self.assertIn('video_id', self._field_names())

    def test_org_slug_field(self):
        self.assertIn('org_slug', self._field_names())

    def test_token_field(self):
        self.assertIn('token', self._field_names())

    def test_expires_at_field(self):
        self.assertIn('expires_at', self._field_names())

    def test_created_at_field(self):
        self.assertIn('created_at', self._field_names())

    def test_ip_address_hash_field(self):
        self.assertIn('ip_address_hash', self._field_names())

    def test_user_agent_field(self):
        self.assertIn('user_agent', self._field_names())

    def test_db_table(self):
        self.assertEqual(self.model._meta.db_table, 'video_signed_playback_tokens')

    def test_ordering(self):
        self.assertEqual(self.model._meta.ordering, ['-created_at'])

    def test_verbose_name(self):
        self.assertEqual(self.model._meta.verbose_name, 'Signed Playback Token')


# ===========================================================================
# 4. Model fields: VideoAccessLog
# ===========================================================================

class TestVideoAccessLogFields(unittest.TestCase):

    def setUp(self):
        from openedx_video_protection.models import VideoAccessLog
        self.model = VideoAccessLog

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_user_field(self):
        self.assertIn('user', self._field_names())

    def test_course_key_field(self):
        self.assertIn('course_key', self._field_names())

    def test_video_id_field(self):
        self.assertIn('video_id', self._field_names())

    def test_status_field(self):
        self.assertIn('status', self._field_names())

    def test_denial_reason_field(self):
        self.assertIn('denial_reason', self._field_names())

    def test_timestamp_field(self):
        self.assertIn('timestamp', self._field_names())

    def test_ip_address_hash_field(self):
        self.assertIn('ip_address_hash', self._field_names())

    def test_org_slug_field(self):
        self.assertIn('org_slug', self._field_names())

    def test_db_table(self):
        self.assertEqual(self.model._meta.db_table, 'video_access_logs')

    def test_ordering(self):
        self.assertEqual(self.model._meta.ordering, ['-timestamp'])

    def test_status_choices(self):
        self.assertEqual(self.model.ACCESS_GRANTED, 'granted')
        self.assertEqual(self.model.ACCESS_DENIED, 'denied')

    def test_user_allows_null(self):
        field = self.model._meta.get_field('user')
        self.assertTrue(field.null)


# ===========================================================================
# 5. Model methods: SignedPlaybackToken
# ===========================================================================

class TestSignedPlaybackTokenMethods(TestCase):
    """Tests with real DB (tables created at module level)."""

    def _create_user(self, username='testuser'):
        User = get_user_model()
        user, _ = User.objects.get_or_create(username=username, defaults={'password': 'x'})
        return user

    def test_str_representation(self):
        from openedx_video_protection.models import SignedPlaybackToken
        user = self._create_user()
        expires = timezone.now() + timedelta(hours=12)
        token = SignedPlaybackToken(
            user=user, video_id='vid123', expires_at=expires,
            course_key='course-v1:T+C+R', token='jwt-token', org_slug='TestOrg',
        )
        result = str(token)
        self.assertIn('testuser', result)
        self.assertIn('vid123', result)
        self.assertIn('expires', result)

    def test_is_expired_future(self):
        from openedx_video_protection.models import SignedPlaybackToken
        token = SignedPlaybackToken(expires_at=timezone.now() + timedelta(hours=1))
        self.assertFalse(token.is_expired)

    def test_is_expired_past(self):
        from openedx_video_protection.models import SignedPlaybackToken
        token = SignedPlaybackToken(expires_at=timezone.now() - timedelta(hours=1))
        self.assertTrue(token.is_expired)

    def test_cleanup_expired_tokens(self):
        from openedx_video_protection.models import SignedPlaybackToken
        user = self._create_user('cleaner')
        # Create token expired 10 days ago
        old = SignedPlaybackToken.objects.create(
            user=user, video_id='v1', course_key='course-v1:O+C+R',
            token='t1', expires_at=timezone.now() - timedelta(days=10),
            org_slug='O',
        )
        # Create token expired 3 days ago (within 7-day window)
        recent = SignedPlaybackToken.objects.create(
            user=user, video_id='v2', course_key='course-v1:O+C+R',
            token='t2', expires_at=timezone.now() - timedelta(days=3),
            org_slug='O',
        )
        deleted = SignedPlaybackToken.cleanup_expired_tokens(days_to_keep=7)
        self.assertEqual(deleted, 1)
        # recent token still exists
        self.assertTrue(SignedPlaybackToken.objects.filter(pk=recent.pk).exists())

    def test_count_recent_tokens_for_user(self):
        from openedx_video_protection.models import SignedPlaybackToken
        user = self._create_user('counter')
        for i in range(5):
            SignedPlaybackToken.objects.create(
                user=user, video_id=f'v{i}', course_key='course-v1:O+C+R',
                token=f't{i}', expires_at=timezone.now() + timedelta(hours=12),
                org_slug='O',
            )
        count = SignedPlaybackToken.count_recent_tokens_for_user(user, hours=1)
        self.assertEqual(count, 5)


# ===========================================================================
# 6. Model methods: VideoAccessLog
# ===========================================================================

class TestVideoAccessLogMethods(TestCase):

    def _create_user(self, username='loguser'):
        User = get_user_model()
        user, _ = User.objects.get_or_create(username=username, defaults={'password': 'x'})
        return user

    def test_str_authenticated(self):
        from openedx_video_protection.models import VideoAccessLog
        user = self._create_user()
        log = VideoAccessLog(user=user, video_id='vid1', status='granted',
                             course_key='course-v1:T+C+R')
        result = str(log)
        self.assertIn('loguser', result)
        self.assertIn('vid1', result)
        self.assertIn('granted', result)

    def test_str_anonymous(self):
        from openedx_video_protection.models import VideoAccessLog
        log = VideoAccessLog(user=None, video_id='vid2', status='denied',
                             course_key='course-v1:T+C+R')
        result = str(log)
        self.assertIn('anonymous', result)

    def test_log_access_creates_record(self):
        from openedx_video_protection.models import VideoAccessLog
        user = self._create_user('access_logger')
        entry = VideoAccessLog.log_access(
            user=user, course_key='course-v1:T+C+R', video_id='vid3',
            status=VideoAccessLog.ACCESS_DENIED, denial_reason='not_enrolled',
            ip_address_hash='abc123', org_slug='TestOrg',
        )
        self.assertIsNotNone(entry.pk)
        self.assertEqual(entry.status, 'denied')
        self.assertEqual(entry.denial_reason, 'not_enrolled')
        self.assertEqual(entry.org_slug, 'TestOrg')


# ===========================================================================
# 7. Serializer validation
# ===========================================================================

class TestSignedPlaybackURLRequestSerializer(unittest.TestCase):

    def test_valid_request(self):
        from openedx_video_protection.serializers import SignedPlaybackURLRequestSerializer
        data = {'playback_id': 'abc123', 'course_key': 'course-v1:T+C+R'}
        s = SignedPlaybackURLRequestSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)
        self.assertEqual(s.validated_data['expiry_hours'], 12)  # default

    def test_missing_playback_id(self):
        from openedx_video_protection.serializers import SignedPlaybackURLRequestSerializer
        data = {'course_key': 'course-v1:T+C+R'}
        s = SignedPlaybackURLRequestSerializer(data=data)
        self.assertFalse(s.is_valid())
        self.assertIn('playback_id', s.errors)

    def test_missing_course_key(self):
        from openedx_video_protection.serializers import SignedPlaybackURLRequestSerializer
        data = {'playback_id': 'abc123'}
        s = SignedPlaybackURLRequestSerializer(data=data)
        self.assertFalse(s.is_valid())
        self.assertIn('course_key', s.errors)

    def test_expiry_hours_min_value(self):
        from openedx_video_protection.serializers import SignedPlaybackURLRequestSerializer
        data = {'playback_id': 'abc', 'course_key': 'ck', 'expiry_hours': 0}
        s = SignedPlaybackURLRequestSerializer(data=data)
        self.assertFalse(s.is_valid())
        self.assertIn('expiry_hours', s.errors)

    def test_expiry_hours_max_value(self):
        from openedx_video_protection.serializers import SignedPlaybackURLRequestSerializer
        data = {'playback_id': 'abc', 'course_key': 'ck', 'expiry_hours': 100}
        s = SignedPlaybackURLRequestSerializer(data=data)
        self.assertFalse(s.is_valid())
        self.assertIn('expiry_hours', s.errors)

    def test_custom_expiry(self):
        from openedx_video_protection.serializers import SignedPlaybackURLRequestSerializer
        data = {'playback_id': 'abc', 'course_key': 'ck', 'expiry_hours': 24}
        s = SignedPlaybackURLRequestSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)
        self.assertEqual(s.validated_data['expiry_hours'], 24)


class TestSignedPlaybackURLResponseSerializer(unittest.TestCase):

    def test_response_fields(self):
        from openedx_video_protection.serializers import SignedPlaybackURLResponseSerializer
        data = {
            'url': 'https://stream.mux.com/abc.m3u8?token=xyz',
            'expires_at': '2026-03-30T12:00:00Z',
            'playback_id': 'abc',
        }
        s = SignedPlaybackURLResponseSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)


# ===========================================================================
# 8. Utility functions
# ===========================================================================

class TestHashIpAddress(unittest.TestCase):

    def test_deterministic(self):
        from openedx_video_protection.utils import hash_ip_address
        h1 = hash_ip_address('192.168.1.1')
        h2 = hash_ip_address('192.168.1.1')
        self.assertEqual(h1, h2)

    def test_truncated_to_16(self):
        from openedx_video_protection.utils import hash_ip_address
        result = hash_ip_address('10.0.0.1')
        self.assertEqual(len(result), 16)

    def test_empty_returns_empty(self):
        from openedx_video_protection.utils import hash_ip_address
        self.assertEqual(hash_ip_address(''), '')

    def test_none_returns_empty(self):
        from openedx_video_protection.utils import hash_ip_address
        self.assertEqual(hash_ip_address(None), '')

    def test_different_ips_different_hashes(self):
        from openedx_video_protection.utils import hash_ip_address
        self.assertNotEqual(hash_ip_address('1.1.1.1'), hash_ip_address('8.8.8.8'))


class TestGetClientIp(unittest.TestCase):

    def test_x_forwarded_for_single(self):
        from openedx_video_protection.utils import get_client_ip
        request = MagicMock()
        request.META = {'HTTP_X_FORWARDED_FOR': '1.2.3.4', 'REMOTE_ADDR': '10.0.0.1'}
        self.assertEqual(get_client_ip(request), '1.2.3.4')

    def test_x_forwarded_for_chain(self):
        from openedx_video_protection.utils import get_client_ip
        request = MagicMock()
        request.META = {'HTTP_X_FORWARDED_FOR': '1.2.3.4, 5.6.7.8'}
        self.assertEqual(get_client_ip(request), '1.2.3.4')

    def test_remote_addr_fallback(self):
        from openedx_video_protection.utils import get_client_ip
        request = MagicMock()
        request.META = {'REMOTE_ADDR': '10.0.0.1'}
        self.assertEqual(get_client_ip(request), '10.0.0.1')

    def test_no_ip_returns_empty(self):
        from openedx_video_protection.utils import get_client_ip
        request = MagicMock()
        request.META = {}
        self.assertEqual(get_client_ip(request), '')


class TestExtractOrgSlug(unittest.TestCase):

    def test_extracts_org(self):
        from openedx_video_protection.utils import extract_org_slug_from_course_key
        key = MagicMock()
        key.org = 'MerekaAcademy'
        self.assertEqual(extract_org_slug_from_course_key(key), 'MerekaAcademy')

    def test_no_org_attribute(self):
        from openedx_video_protection.utils import extract_org_slug_from_course_key
        result = extract_org_slug_from_course_key('not-a-key-object')
        self.assertEqual(result, '')


class TestGenerateSignedPlaybackUrl(unittest.TestCase):

    @patch('openedx_video_protection.utils.settings')
    def test_missing_credentials_raises(self, mock_settings):
        from openedx_video_protection.utils import generate_signed_playback_url
        mock_settings.MUX_SIGNING_KEY_ID = None
        mock_settings.MUX_SIGNING_PRIVATE_KEY = None
        with self.assertRaises(ValueError) as ctx:
            generate_signed_playback_url('playback123')
        self.assertIn('MUX_SIGNING_KEY_ID', str(ctx.exception))

    @patch('openedx_video_protection.utils.settings')
    def test_generates_url_with_token(self, mock_settings):
        """With valid RSA key, generate a proper signed URL."""
        from openedx_video_protection.utils import generate_signed_playback_url
        # Generate a real RSA key for testing
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.hazmat.primitives import serialization
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        pem = private_key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
        mock_settings.MUX_SIGNING_KEY_ID = 'test-key-id'
        mock_settings.MUX_SIGNING_PRIVATE_KEY = pem.decode()

        result = generate_signed_playback_url('play123', user_id=42, expiry_hours=6)

        self.assertIn('https://stream.mux.com/play123.m3u8?token=', result['url'])
        self.assertEqual(result['playback_id'], 'play123')
        self.assertIn('token', result)
        self.assertIn('expires_at', result)

    @patch('openedx_video_protection.utils.settings')
    def test_audience_claim(self, mock_settings):
        """When audience is set, JWT payload should include it."""
        from openedx_video_protection.utils import generate_signed_playback_url
        import jwt as pyjwt
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.hazmat.primitives import serialization
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        pem = private_key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
        mock_settings.MUX_SIGNING_KEY_ID = 'kid1'
        mock_settings.MUX_SIGNING_PRIVATE_KEY = pem.decode()

        result = generate_signed_playback_url('play1', audience='academyv2.mereka.io')
        decoded = pyjwt.decode(result['token'], options={'verify_signature': False})
        self.assertEqual(decoded['aud'], 'academyv2.mereka.io')
        self.assertEqual(decoded['sub'], 'play1')


class TestIsRateLimited(unittest.TestCase):

    @patch('openedx_video_protection.models.SignedPlaybackToken.count_recent_tokens_for_user')
    def test_under_limit(self, mock_count):
        from openedx_video_protection.utils import is_rate_limited
        mock_count.return_value = 10
        user = MagicMock(username='test')
        self.assertFalse(is_rate_limited(user, max_requests=100, window_hours=1))

    @patch('openedx_video_protection.models.SignedPlaybackToken.count_recent_tokens_for_user')
    def test_at_limit(self, mock_count):
        from openedx_video_protection.utils import is_rate_limited
        mock_count.return_value = 100
        user = MagicMock(username='test')
        self.assertTrue(is_rate_limited(user, max_requests=100, window_hours=1))

    @patch('openedx_video_protection.models.SignedPlaybackToken.count_recent_tokens_for_user')
    def test_over_limit(self, mock_count):
        from openedx_video_protection.utils import is_rate_limited
        mock_count.return_value = 150
        user = MagicMock(username='test')
        self.assertTrue(is_rate_limited(user, max_requests=100, window_hours=1))


# ===========================================================================
# 9. URL patterns
# ===========================================================================

class TestURLPatterns(unittest.TestCase):

    def test_url_names_exist(self):
        from openedx_video_protection.urls import urlpatterns
        names = [p.name for p in urlpatterns]
        self.assertIn('generate_signed_url', names)
        self.assertIn('check_video_access', names)

    def test_app_name(self):
        from openedx_video_protection import urls
        self.assertEqual(urls.app_name, 'openedx_video_protection')


# ===========================================================================
# 10. Admin registration
# ===========================================================================

class TestAdminRegistration(unittest.TestCase):

    def test_signed_playback_token_admin(self):
        from django.contrib import admin
        from openedx_video_protection.models import SignedPlaybackToken
        self.assertIn(SignedPlaybackToken, admin.site._registry)

    def test_video_access_log_admin(self):
        from django.contrib import admin
        from openedx_video_protection.models import VideoAccessLog
        self.assertIn(VideoAccessLog, admin.site._registry)

    def test_token_admin_no_add(self):
        from django.contrib import admin
        from openedx_video_protection.models import SignedPlaybackToken
        model_admin = admin.site._registry[SignedPlaybackToken]
        request = MagicMock()
        self.assertFalse(model_admin.has_add_permission(request))

    def test_access_log_admin_no_add(self):
        from django.contrib import admin
        from openedx_video_protection.models import VideoAccessLog
        model_admin = admin.site._registry[VideoAccessLog]
        request = MagicMock()
        self.assertFalse(model_admin.has_add_permission(request))

    def test_access_log_admin_no_delete(self):
        from django.contrib import admin
        from openedx_video_protection.models import VideoAccessLog
        model_admin = admin.site._registry[VideoAccessLog]
        request = MagicMock()
        self.assertFalse(model_admin.has_delete_permission(request))


# ===========================================================================
# 11. View feature flag gating
# ===========================================================================

class TestViewFeatureFlagGating(TestCase):
    """Verify views respect ENABLE_MUX_SIGNED_PLAYBACK feature flag."""

    def _create_user(self, username='viewuser'):
        User = get_user_model()
        user, _ = User.objects.get_or_create(username=username, defaults={'password': 'x'})
        return user

    def test_generate_signed_url_returns_503_when_disabled(self):
        """When feature flag is off, endpoint returns 503."""
        from rest_framework.test import APIRequestFactory, force_authenticate
        from openedx_video_protection.views import generate_signed_url_view

        user = self._create_user('view-503')
        factory = APIRequestFactory()
        request = factory.post('/api/mux/protection/signed-url/',
                               {'playback_id': 'x', 'course_key': 'course-v1:T+C+R'},
                               format='json')
        force_authenticate(request, user=user)

        with patch('openedx_video_protection.views.settings') as mock_settings:
            mock_settings.ENABLE_MUX_SIGNED_PLAYBACK = False
            mock_settings.MUX_PLAYBACK_AUDIENCE = None
            response = generate_signed_url_view(request)

        self.assertEqual(response.status_code, 503)

    def test_check_access_returns_feature_disabled(self):
        """When feature flag is off, has_access is false."""
        from rest_framework.test import APIRequestFactory, force_authenticate
        from openedx_video_protection.views import check_video_access_view

        user = self._create_user('view-access')
        factory = APIRequestFactory()
        request = factory.get('/api/mux/protection/check-access/',
                              {'course_key': 'course-v1:T+C+R'})
        force_authenticate(request, user=user)

        with patch('openedx_video_protection.views.settings') as mock_settings:
            mock_settings.ENABLE_MUX_SIGNED_PLAYBACK = False
            response = check_video_access_view(request)

        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data['has_access'])
        self.assertFalse(response.data['feature_enabled'])

    def test_check_access_missing_course_key(self):
        from rest_framework.test import APIRequestFactory, force_authenticate
        from openedx_video_protection.views import check_video_access_view

        user = self._create_user('view-nokey')
        factory = APIRequestFactory()
        request = factory.get('/api/mux/protection/check-access/')
        force_authenticate(request, user=user)

        response = check_video_access_view(request)
        self.assertEqual(response.status_code, 400)


if __name__ == '__main__':
    unittest.main()
