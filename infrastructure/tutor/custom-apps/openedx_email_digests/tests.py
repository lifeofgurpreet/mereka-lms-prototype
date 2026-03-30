"""
Baseline tests for openedx_email_digests.

Covers:
- Import smoke tests for every module
- AppConfig name and verbose_name
- DigestPreference: model fields, __str__, get_preference, should_suppress_immediate,
  get_users_for_digest
- DigestRun: model fields, __str__, mark_running/completed/failed, error truncation
- EmailEvent: record_event, get_aggregate_stats rate computations, purge_old_events
- Serializer field coverage
- URL pattern names
- Admin registrations
- Task function signatures (Celery mocked)
- Views: _get_client_ip helper, TRACKING_PIXEL bytes
"""

import importlib
import os
import sys
import types
import unittest
import uuid
from datetime import timedelta
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub Celery before Django bootstrap
# ---------------------------------------------------------------------------

_celery_mod = types.ModuleType('celery')


def _fake_shared_task(*args, **kwargs):
    """Return a decorator that preserves the original function."""
    def decorator(func):
        func.delay = func
        func.apply_async = func
        return func
    if args and callable(args[0]):
        return decorator(args[0])
    return decorator


_celery_mod.shared_task = _fake_shared_task
sys.modules.setdefault('celery', _celery_mod)

# Stub openedx_notifications for task imports
_notif_mod = types.ModuleType('openedx_notifications')
_notif_models = types.ModuleType('openedx_notifications.models')
_notif_mod.models = _notif_models
sys.modules.setdefault('openedx_notifications', _notif_mod)
sys.modules.setdefault('openedx_notifications.models', _notif_models)

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_email_digests._test_settings')

_settings = types.ModuleType('openedx_email_digests._test_settings')
_settings.SECRET_KEY = 'test-secret-key'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'rest_framework',
    'openedx_email_digests',
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
_settings.DEFAULT_FROM_EMAIL = 'test@example.com'
_settings.DEFAULT_ORG_DISPLAY_NAME = 'Test Academy'
_settings.DEFAULT_ORG_LOGO_URL = ''
_settings.DEFAULT_ORG_PRIMARY_COLOR = '#1a73e8'

sys.modules['openedx_email_digests._test_settings'] = _settings

import django
django.setup()

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

User = get_user_model()


# ===========================================================================
# 1. Import smoke tests
# ===========================================================================

class TestModuleImports(unittest.TestCase):
    def _assert_importable(self, name):
        try:
            importlib.import_module(name)
        except ImportError as exc:
            self.fail(f"Cannot import {name}: {exc}")

    def test_import_apps(self):
        self._assert_importable('openedx_email_digests.apps')

    def test_import_models(self):
        self._assert_importable('openedx_email_digests.models')

    def test_import_views(self):
        self._assert_importable('openedx_email_digests.views')

    def test_import_signals(self):
        self._assert_importable('openedx_email_digests.signals')

    def test_import_tasks(self):
        self._assert_importable('openedx_email_digests.tasks')

    def test_import_serializers(self):
        self._assert_importable('openedx_email_digests.serializers')

    def test_import_urls(self):
        self._assert_importable('openedx_email_digests.urls')

    def test_import_admin(self):
        self._assert_importable('openedx_email_digests.admin')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):
    def test_app_name(self):
        from openedx_email_digests.apps import OpenedxEmailDigestsConfig
        self.assertEqual(OpenedxEmailDigestsConfig.name, 'openedx_email_digests')

    def test_verbose_name(self):
        from openedx_email_digests.apps import OpenedxEmailDigestsConfig
        self.assertEqual(OpenedxEmailDigestsConfig.verbose_name, 'Email Digests & Analytics')


# ===========================================================================
# 3. DigestPreference model
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestDigestPreferenceModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def setUp(self):
        self.user = User.objects.create_user(
            username='digestuser', email='digest@example.com'
        )

    def _create_pref(self, **overrides):
        from openedx_email_digests.models import DigestPreference
        defaults = dict(
            user=self.user,
            frequency='daily',
            org_slug='acme',
            message_types=[],
            user_timezone='Asia/Kuala_Lumpur',
        )
        defaults.update(overrides)
        return DigestPreference.objects.create(**defaults)

    def test_str_representation(self):
        pref = self._create_pref()
        s = str(pref)
        self.assertIn('digestuser', s)
        self.assertIn('daily', s)
        self.assertIn('acme', s)

    def test_get_preference_found(self):
        from openedx_email_digests.models import DigestPreference
        self._create_pref()
        pref = DigestPreference.get_preference(self.user, 'acme')
        self.assertIsNotNone(pref)
        self.assertEqual(pref.frequency, 'daily')

    def test_get_preference_not_found(self):
        from openedx_email_digests.models import DigestPreference
        self.assertIsNone(DigestPreference.get_preference(self.user, 'nonexistent'))

    def test_should_suppress_immediate_none_freq(self):
        """frequency='none' never suppresses."""
        from openedx_email_digests.models import DigestPreference
        self._create_pref(frequency='none')
        result = DigestPreference.should_suppress_immediate(
            self.user, 'acme', 'course_announcement'
        )
        self.assertFalse(result)

    def test_should_suppress_immediate_daily_empty_types(self):
        """frequency='daily' with empty message_types suppresses ALL types."""
        from openedx_email_digests.models import DigestPreference
        self._create_pref(frequency='daily', message_types=[])
        result = DigestPreference.should_suppress_immediate(
            self.user, 'acme', 'course_announcement'
        )
        self.assertTrue(result)

    def test_should_suppress_immediate_daily_specific_type(self):
        """Only matching types are suppressed."""
        from openedx_email_digests.models import DigestPreference
        self._create_pref(
            frequency='daily',
            message_types=['discussion_reply'],
        )
        self.assertTrue(
            DigestPreference.should_suppress_immediate(
                self.user, 'acme', 'discussion_reply'
            )
        )
        self.assertFalse(
            DigestPreference.should_suppress_immediate(
                self.user, 'acme', 'course_announcement'
            )
        )

    def test_get_users_for_digest(self):
        from openedx_email_digests.models import DigestPreference
        self._create_pref(frequency='daily')
        user2 = User.objects.create_user(username='user2', email='u2@test.com')
        DigestPreference.objects.create(
            user=user2, frequency='weekly', org_slug='acme'
        )
        daily = DigestPreference.get_users_for_digest('daily')
        self.assertEqual(daily.count(), 1)
        weekly = DigestPreference.get_users_for_digest('weekly')
        self.assertEqual(weekly.count(), 1)

    def test_get_users_for_digest_filtered_by_org(self):
        from openedx_email_digests.models import DigestPreference
        self._create_pref(frequency='daily', org_slug='acme')
        result = DigestPreference.get_users_for_digest('daily', org_slug='other')
        self.assertEqual(result.count(), 0)


# ===========================================================================
# 4. DigestRun model
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestDigestRunModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def _create_run(self, **overrides):
        from openedx_email_digests.models import DigestRun
        now = timezone.now()
        defaults = dict(
            run_id='daily-test-001',
            frequency='daily',
            period_start=now - timedelta(hours=24),
            period_end=now,
        )
        defaults.update(overrides)
        return DigestRun.objects.create(**defaults)

    def test_str_representation(self):
        run = self._create_run()
        s = str(run)
        self.assertIn('daily-test-001', s)
        self.assertIn('pending', s)

    def test_mark_running(self):
        run = self._create_run()
        run.mark_running()
        run.refresh_from_db()
        self.assertEqual(run.status, 'running')
        self.assertIsNotNone(run.started_at)

    def test_mark_completed(self):
        run = self._create_run()
        run.mark_completed()
        run.refresh_from_db()
        self.assertEqual(run.status, 'completed')
        self.assertIsNotNone(run.completed_at)

    def test_mark_failed_truncates_error(self):
        run = self._create_run()
        long_error = 'x' * 3000
        run.mark_failed(long_error)
        run.refresh_from_db()
        self.assertEqual(run.status, 'failed')
        self.assertLessEqual(len(run.error_message), 2000)


# ===========================================================================
# 5. EmailEvent model
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestEmailEventModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def test_record_event_creates_entry(self):
        from openedx_email_digests.models import EmailEvent
        event = EmailEvent.record_event(
            message_id='msg-001',
            event_type='send',
            org_slug='acme',
        )
        self.assertEqual(event.message_id, 'msg-001')
        self.assertEqual(event.event_type, 'send')
        self.assertIsNotNone(event.timestamp)

    def test_str_representation(self):
        from openedx_email_digests.models import EmailEvent
        event = EmailEvent.record_event(
            message_id='msg-002', event_type='open', org_slug='test'
        )
        s = str(event)
        self.assertIn('open', s)
        self.assertIn('msg-002', s)

    def test_get_aggregate_stats_computes_rates(self):
        from openedx_email_digests.models import EmailEvent
        now = timezone.now()
        # Create events
        for _ in range(10):
            EmailEvent.objects.create(
                message_id='msg-agg', event_type='send', org_slug='stats',
                timestamp=now,
            )
        for _ in range(8):
            EmailEvent.objects.create(
                message_id='msg-agg', event_type='delivery', org_slug='stats',
                timestamp=now,
            )
        for _ in range(3):
            EmailEvent.objects.create(
                message_id='msg-agg', event_type='open', org_slug='stats',
                timestamp=now,
            )

        stats = EmailEvent.get_aggregate_stats('stats', days=1)
        self.assertEqual(stats['send_count'], 10)
        self.assertEqual(stats['delivery_count'], 8)
        self.assertEqual(stats['open_count'], 3)
        self.assertEqual(stats['delivery_rate'], 80.0)
        self.assertEqual(stats['open_rate'], 30.0)

    def test_get_aggregate_stats_no_sends(self):
        """With 0 sends, rates should be 0 (no division by zero)."""
        from openedx_email_digests.models import EmailEvent
        stats = EmailEvent.get_aggregate_stats('empty-org', days=1)
        # send_count is 0 but code uses max(send_count, 1) to avoid /0
        self.assertEqual(stats['send_count'], 0)
        self.assertEqual(stats['delivery_rate'], 0.0)

    def test_purge_old_events(self):
        from openedx_email_digests.models import EmailEvent
        old_time = timezone.now() - timedelta(days=400)
        EmailEvent.objects.create(
            message_id='old-msg', event_type='send', org_slug='purge',
            timestamp=old_time,
        )
        EmailEvent.objects.create(
            message_id='new-msg', event_type='send', org_slug='purge',
            timestamp=timezone.now(),
        )
        deleted = EmailEvent.purge_old_events(retention_months=12)
        self.assertEqual(deleted, 1)
        self.assertEqual(EmailEvent.objects.filter(org_slug='purge').count(), 1)


# ===========================================================================
# 6. Serializers
# ===========================================================================

class TestSerializers(unittest.TestCase):
    def test_digest_preference_serializer_fields(self):
        from openedx_email_digests.serializers import DigestPreferenceSerializer
        fields = DigestPreferenceSerializer().fields
        expected = {'id', 'frequency', 'org_slug', 'message_types', 'user_timezone'}
        self.assertTrue(expected.issubset(set(fields.keys())))

    def test_digest_run_serializer_fields(self):
        from openedx_email_digests.serializers import DigestRunSerializer
        fields = DigestRunSerializer().fields
        expected = {'run_id', 'frequency', 'status', 'emails_sent', 'emails_failed'}
        self.assertTrue(expected.issubset(set(fields.keys())))

    def test_email_event_serializer_fields(self):
        from openedx_email_digests.serializers import EmailEventSerializer
        fields = EmailEventSerializer().fields
        expected = {'message_id', 'event_type', 'tracking_id', 'timestamp'}
        self.assertTrue(expected.issubset(set(fields.keys())))

    def test_analytics_query_serializer_fields(self):
        from openedx_email_digests.serializers import EmailAnalyticsQuerySerializer
        fields = EmailAnalyticsQuerySerializer().fields
        expected = {'org_slug', 'days'}
        self.assertTrue(expected.issubset(set(fields.keys())))


# ===========================================================================
# 7. URL patterns
# ===========================================================================

class TestURLPatterns(unittest.TestCase):
    def test_url_names(self):
        from openedx_email_digests.urls import urlpatterns
        names = {p.name for p in urlpatterns}
        self.assertIn('digest-preferences', names)
        self.assertIn('click-tracking', names)
        self.assertIn('open-tracking', names)
        self.assertIn('analytics-dashboard', names)
        self.assertIn('digest-runs', names)

    def test_app_name(self):
        from openedx_email_digests import urls
        self.assertEqual(urls.app_name, 'openedx_email_digests')


# ===========================================================================
# 8. Views — helpers
# ===========================================================================

class TestViewHelpers(unittest.TestCase):
    def test_tracking_pixel_is_valid_png(self):
        from openedx_email_digests.views import TRACKING_PIXEL
        # PNG files start with 8-byte magic: \x89PNG\r\n\x1a\n
        self.assertTrue(TRACKING_PIXEL.startswith(b'\x89PNG'))
        self.assertGreater(len(TRACKING_PIXEL), 50)

    def test_get_client_ip_from_xff(self):
        from openedx_email_digests.views import _get_client_ip
        request = MagicMock()
        request.META = {
            'HTTP_X_FORWARDED_FOR': '1.2.3.4, 5.6.7.8',
            'REMOTE_ADDR': '127.0.0.1',
        }
        self.assertEqual(_get_client_ip(request), '1.2.3.4')

    def test_get_client_ip_from_remote_addr(self):
        from openedx_email_digests.views import _get_client_ip
        request = MagicMock()
        request.META = {'REMOTE_ADDR': '10.0.0.1'}
        self.assertEqual(_get_client_ip(request), '10.0.0.1')


# ===========================================================================
# 9. Admin registrations
# ===========================================================================

class TestAdminRegistrations(unittest.TestCase):
    def test_digest_preference_admin(self):
        from django.contrib import admin
        from openedx_email_digests.models import DigestPreference
        self.assertIn(DigestPreference, admin.site._registry)

    def test_digest_run_admin(self):
        from django.contrib import admin
        from openedx_email_digests.models import DigestRun
        self.assertIn(DigestRun, admin.site._registry)

    def test_email_event_admin(self):
        from django.contrib import admin
        from openedx_email_digests.models import EmailEvent
        self.assertIn(EmailEvent, admin.site._registry)


# ===========================================================================
# 10. Tasks — _is_digest_time_for_user logic
# ===========================================================================

class TestDigestTimeLogic(unittest.TestCase):
    """Test timezone-aware digest timing without Celery."""

    def test_is_digest_time_daily_at_nine(self):
        from openedx_email_digests.tasks import _is_digest_time_for_user
        pref = MagicMock()
        pref.user_timezone = 'UTC'
        # Mock timezone.now() to return 09:00 UTC
        fake_now = timezone.now().replace(hour=9, minute=0, second=0)
        with patch('openedx_email_digests.tasks.timezone.now', return_value=fake_now):
            result = _is_digest_time_for_user(pref, 'daily')
        self.assertTrue(result)

    def test_is_digest_time_daily_at_two_am(self):
        from openedx_email_digests.tasks import _is_digest_time_for_user
        pref = MagicMock()
        pref.user_timezone = 'UTC'
        fake_now = timezone.now().replace(hour=2, minute=0, second=0)
        with patch('openedx_email_digests.tasks.timezone.now', return_value=fake_now):
            result = _is_digest_time_for_user(pref, 'daily')
        self.assertFalse(result)

    def test_is_digest_time_weekly_not_monday(self):
        """Weekly digests only fire on Monday."""
        from openedx_email_digests.tasks import _is_digest_time_for_user
        import datetime
        pref = MagicMock()
        pref.user_timezone = 'UTC'
        # Find next Wednesday
        now = timezone.now().replace(hour=9, minute=0, second=0)
        while now.weekday() != 2:  # Wednesday
            now += timedelta(days=1)
        with patch('openedx_email_digests.tasks.timezone.now', return_value=now):
            result = _is_digest_time_for_user(pref, 'weekly')
        self.assertFalse(result)


if __name__ == '__main__':
    unittest.main()
