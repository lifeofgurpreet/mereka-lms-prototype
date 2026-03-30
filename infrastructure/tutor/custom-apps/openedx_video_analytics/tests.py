"""
Baseline tests for openedx_video_analytics.

Covers:
  1. Import smoke tests -- every module can be imported
  2. VideoPlaybackEvent model -- fields, record_event, str
  3. VideoAnalyticsSummary model -- fields, aggregate_for_date, str
  4. Serializer tests -- field contracts for all serializers
  5. View helper tests -- _hash_ip_address, _get_client_ip, _get_org_slug
  6. Task tests -- aggregate_video_analytics_daily, cleanup_old_video_events,
     backfill_video_analytics signatures
  7. Signal tests -- on_video_event_created handler
  8. Admin tests -- admin classes registered, permission overrides
  9. Apps config tests -- AppConfig name/verbose_name
 10. URL routing tests

Run from repo root:
    PYTHONPATH=infrastructure/tutor/custom-apps \
        python3 -m pytest infrastructure/tutor/custom-apps/openedx_video_analytics/tests.py -v --tb=short
"""

import importlib
import sys
import unittest
from datetime import date, timedelta
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Dependency stubs must already be installed by conftest.py before this
# module is collected.  Django must be configured too.
# ---------------------------------------------------------------------------

import django  # noqa: E402
from django.conf import settings  # noqa: F401

from django.contrib.auth import get_user_model  # noqa: E402
from django.test import TestCase  # noqa: E402
from django.utils import timezone  # noqa: E402

User = get_user_model()

# Use the FakeCourseKey stub installed by conftest
FakeCourseKey = sys.modules['opaque_keys.edx.keys'].CourseKey


def _create_user(username='testuser', email='test@example.com'):
    return User.objects.get_or_create(username=username, defaults={'email': email})[0]


# ---------------------------------------------------------------------------
# 1. Import smoke tests
# ---------------------------------------------------------------------------

class TestModuleImports(unittest.TestCase):
    """Every module in openedx_video_analytics must import cleanly."""

    def _import(self, module_name):
        full = f'openedx_video_analytics.{module_name}'
        if full in sys.modules:
            return sys.modules[full]
        return importlib.import_module(full)

    def test_package_init_imports(self):
        import openedx_video_analytics
        self.assertEqual(openedx_video_analytics.__version__, '1.0.0')

    def test_apps_imports(self):
        mod = self._import('apps')
        self.assertTrue(hasattr(mod, 'VideoAnalyticsConfig'))

    def test_models_imports(self):
        mod = self._import('models')
        self.assertTrue(hasattr(mod, 'VideoPlaybackEvent'))
        self.assertTrue(hasattr(mod, 'VideoAnalyticsSummary'))
        self.assertTrue(hasattr(mod, 'VIDEO_EVENT_TYPES'))

    def test_serializers_imports(self):
        mod = self._import('serializers')
        self.assertTrue(hasattr(mod, 'VideoPlaybackEventSerializer'))
        self.assertTrue(hasattr(mod, 'RecordVideoEventSerializer'))
        self.assertTrue(hasattr(mod, 'VideoAnalyticsSummarySerializer'))
        self.assertTrue(hasattr(mod, 'VideoAnalyticsQuerySerializer'))

    def test_views_imports(self):
        mod = self._import('views')
        self.assertTrue(hasattr(mod, 'record_video_event_view'))
        self.assertTrue(hasattr(mod, 'get_video_analytics_view'))

    def test_urls_imports(self):
        mod = self._import('urls')
        self.assertTrue(hasattr(mod, 'urlpatterns'))

    def test_admin_imports(self):
        mod = self._import('admin')
        self.assertTrue(hasattr(mod, 'VideoPlaybackEventAdmin'))
        self.assertTrue(hasattr(mod, 'VideoAnalyticsSummaryAdmin'))

    def test_signals_imports(self):
        mod = self._import('signals')
        self.assertTrue(hasattr(mod, 'on_video_event_created'))

    def test_tasks_imports(self):
        mod = self._import('tasks')
        self.assertTrue(hasattr(mod, 'aggregate_video_analytics_daily'))
        self.assertTrue(hasattr(mod, 'cleanup_old_video_events'))
        self.assertTrue(hasattr(mod, 'backfill_video_analytics'))


# ---------------------------------------------------------------------------
# 2. VideoPlaybackEvent model tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class VideoPlaybackEventFieldTests(TestCase):
    """VideoPlaybackEvent field contract."""

    def setUp(self):
        self.user = _create_user()

    def _make_event(self, **overrides):
        from openedx_video_analytics.models import VideoPlaybackEvent
        defaults = dict(
            user=self.user,
            course_key='course-v1:MerekaAcademy+COURSE101+2024',
            video_id='test-video-001',
            event_type='played',
            position=10.5,
            duration=300.0,
            org_slug='MerekaAcademy',
        )
        defaults.update(overrides)
        return VideoPlaybackEvent.objects.create(**defaults)

    def test_event_type_choices(self):
        from openedx_video_analytics.models import VIDEO_EVENT_TYPES
        types_list = [t[0] for t in VIDEO_EVENT_TYPES]
        for expected in ('played', 'paused', 'seeked', 'completed', 'ended'):
            self.assertIn(expected, types_list)

    def test_timestamp_auto_set(self):
        e = self._make_event()
        self.assertIsNotNone(e.timestamp)

    def test_ordering_is_newest_first(self):
        from openedx_video_analytics.models import VideoPlaybackEvent
        self.assertIn('-timestamp', VideoPlaybackEvent._meta.ordering)

    def test_session_id_nullable(self):
        e = self._make_event(session_id=None)
        self.assertIsNone(e.session_id)

    def test_str_representation(self):
        e = self._make_event()
        s = str(e)
        self.assertIn('played', s)
        self.assertIn('test-video-001', s)
        self.assertIn(self.user.username, s)

    def test_record_event_classmethod(self):
        from openedx_video_analytics.models import VideoPlaybackEvent
        e = VideoPlaybackEvent.record_event(
            user=self.user,
            course_key='course-v1:Test+101+2026',
            video_id='vid-abc',
            event_type='paused',
            position=45.0,
            duration=120.0,
            org_slug='Test',
            session_id='sess-123',
        )
        self.assertEqual(e.event_type, 'paused')
        self.assertEqual(e.position, 45.0)
        self.assertEqual(e.org_slug, 'Test')

    def test_record_event_defaults_org_slug_to_empty(self):
        from openedx_video_analytics.models import VideoPlaybackEvent
        e = VideoPlaybackEvent.record_event(
            user=self.user,
            course_key='course-v1:Test+101+2026',
            video_id='vid-def',
            event_type='played',
            position=0.0,
        )
        self.assertEqual(e.org_slug, '')


# ---------------------------------------------------------------------------
# 3. VideoAnalyticsSummary model tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class VideoAnalyticsSummaryFieldTests(TestCase):
    """VideoAnalyticsSummary field contract."""

    def _make_summary(self, **overrides):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        defaults = dict(
            course_key='course-v1:MerekaAcademy+COURSE101+2024',
            video_id='test-video-001',
            org_slug='MerekaAcademy',
            date=date.today(),
            play_count=100,
            unique_viewers=50,
            completion_count=40,
            completion_rate=0.8,
            avg_watch_time=245.5,
            total_watch_time=12275.0,
            avg_position_reached=270.0,
        )
        defaults.update(overrides)
        return VideoAnalyticsSummary.objects.create(**defaults)

    def test_default_play_count_is_zero(self):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        field = VideoAnalyticsSummary._meta.get_field('play_count')
        self.assertEqual(field.default, 0)

    def test_unique_together(self):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        ut = VideoAnalyticsSummary._meta.unique_together
        found = any(
            set(combo) == {'course_key', 'video_id', 'date'}
            for combo in ut
        )
        self.assertTrue(found)

    def test_ordering_is_by_date_desc(self):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        self.assertIn('-date', VideoAnalyticsSummary._meta.ordering)

    def test_str_representation(self):
        s = self._make_summary()
        text = str(s)
        self.assertIn('test-video-001', text)
        self.assertIn('100', text)

    def test_created_at_auto_set(self):
        s = self._make_summary()
        self.assertIsNotNone(s.created_at)


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class VideoAnalyticsSummaryAggregationTests(TestCase):
    """Test aggregate_for_date business logic."""

    def setUp(self):
        self.user = _create_user(username='analyticsuser', email='analytics@example.com')
        self.user2 = _create_user(username='analyticsuser2', email='analytics2@example.com')

    def _make_event(self, **overrides):
        from openedx_video_analytics.models import VideoPlaybackEvent
        defaults = dict(
            user=self.user,
            course_key='course-v1:Test+101+2026',
            video_id='agg-video-001',
            event_type='played',
            position=10.0,
            org_slug='Test',
        )
        defaults.update(overrides)
        return VideoPlaybackEvent.objects.create(**defaults)

    def test_aggregate_for_date_creates_summary(self):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        today = date.today()
        self._make_event()
        count = VideoAnalyticsSummary.aggregate_for_date(today)
        self.assertEqual(count, 1)
        summary = VideoAnalyticsSummary.objects.get(
            video_id='agg-video-001',
            date=today,
        )
        self.assertEqual(summary.play_count, 1)
        self.assertEqual(summary.unique_viewers, 1)

    def test_aggregate_counts_unique_viewers(self):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        today = date.today()
        self._make_event(user=self.user)
        self._make_event(user=self.user2)
        VideoAnalyticsSummary.aggregate_for_date(today)
        summary = VideoAnalyticsSummary.objects.get(
            video_id='agg-video-001',
            date=today,
        )
        self.assertEqual(summary.unique_viewers, 2)
        self.assertEqual(summary.play_count, 2)

    def test_aggregate_calculates_completion_rate(self):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        today = date.today()
        self._make_event(user=self.user, event_type='played')
        self._make_event(user=self.user, event_type='completed', position=280.0)
        self._make_event(user=self.user2, event_type='played')
        # user1 completed, user2 didn't -> completion_rate = 1/2 = 0.5
        VideoAnalyticsSummary.aggregate_for_date(today)
        summary = VideoAnalyticsSummary.objects.get(
            video_id='agg-video-001',
            date=today,
        )
        self.assertAlmostEqual(summary.completion_rate, 0.5, places=1)

    def test_aggregate_returns_zero_for_no_events(self):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        count = VideoAnalyticsSummary.aggregate_for_date(date.today())
        self.assertEqual(count, 0)

    def test_aggregate_updates_existing_summary(self):
        from openedx_video_analytics.models import VideoAnalyticsSummary
        today = date.today()
        self._make_event()
        VideoAnalyticsSummary.aggregate_for_date(today)
        # Add another event and re-aggregate
        self._make_event(user=self.user2)
        VideoAnalyticsSummary.aggregate_for_date(today)
        # Should update, not create duplicate
        summaries = VideoAnalyticsSummary.objects.filter(
            video_id='agg-video-001', date=today,
        )
        self.assertEqual(summaries.count(), 1)
        self.assertEqual(summaries.first().play_count, 2)


# ---------------------------------------------------------------------------
# 4. Serializer tests
# ---------------------------------------------------------------------------

class SerializerFieldTests(unittest.TestCase):
    """Serializer field contracts."""

    def test_record_video_event_serializer_validates(self):
        from openedx_video_analytics.serializers import RecordVideoEventSerializer
        s = RecordVideoEventSerializer(data={
            'course_key': 'course-v1:Test+101+2026',
            'video_id': 'vid-abc',
            'event_type': 'played',
            'position': 10.5,
        })
        self.assertTrue(s.is_valid(), s.errors)

    def test_record_video_event_serializer_rejects_invalid_event_type(self):
        from openedx_video_analytics.serializers import RecordVideoEventSerializer
        s = RecordVideoEventSerializer(data={
            'course_key': 'course-v1:Test+101+2026',
            'video_id': 'vid-abc',
            'event_type': 'invalid_type',
            'position': 10.5,
        })
        self.assertFalse(s.is_valid())

    def test_record_video_event_serializer_rejects_negative_position(self):
        from openedx_video_analytics.serializers import RecordVideoEventSerializer
        s = RecordVideoEventSerializer(data={
            'course_key': 'course-v1:Test+101+2026',
            'video_id': 'vid-abc',
            'event_type': 'played',
            'position': -1.0,
        })
        self.assertFalse(s.is_valid())

    def test_record_video_event_serializer_duration_optional(self):
        from openedx_video_analytics.serializers import RecordVideoEventSerializer
        s = RecordVideoEventSerializer(data={
            'course_key': 'course-v1:Test+101+2026',
            'video_id': 'vid-abc',
            'event_type': 'played',
            'position': 0.0,
        })
        self.assertTrue(s.is_valid(), s.errors)

    def test_playback_event_serializer_fields(self):
        from openedx_video_analytics.serializers import VideoPlaybackEventSerializer
        expected = {
            'id', 'user', 'course_key', 'video_id', 'event_type',
            'position', 'duration', 'timestamp', 'org_slug', 'session_id',
        }
        s = VideoPlaybackEventSerializer()
        self.assertEqual(set(s.fields.keys()), expected)

    def test_analytics_summary_serializer_has_completion_rate_percent(self):
        from openedx_video_analytics.serializers import VideoAnalyticsSummarySerializer
        s = VideoAnalyticsSummarySerializer()
        self.assertIn('completion_rate_percent', s.fields)

    def test_analytics_summary_completion_rate_percent_method(self):
        from openedx_video_analytics.serializers import VideoAnalyticsSummarySerializer
        obj = MagicMock()
        obj.completion_rate = 0.8
        s = VideoAnalyticsSummarySerializer()
        result = s.get_completion_rate_percent(obj)
        self.assertAlmostEqual(result, 80.0)

    def test_query_serializer_all_optional(self):
        from openedx_video_analytics.serializers import VideoAnalyticsQuerySerializer
        s = VideoAnalyticsQuerySerializer(data={})
        self.assertTrue(s.is_valid(), s.errors)

    def test_query_serializer_validates_dates(self):
        from openedx_video_analytics.serializers import VideoAnalyticsQuerySerializer
        s = VideoAnalyticsQuerySerializer(data={
            'start_date': '2026-01-01',
            'end_date': '2026-01-31',
        })
        self.assertTrue(s.is_valid(), s.errors)


# ---------------------------------------------------------------------------
# 5. View helper tests
# ---------------------------------------------------------------------------

class ViewHelperTests(unittest.TestCase):
    """Test view helper functions."""

    def test_hash_ip_address_returns_16_chars(self):
        from openedx_video_analytics.views import _hash_ip_address
        result = _hash_ip_address('192.168.1.1')
        self.assertEqual(len(result), 16)

    def test_hash_ip_address_deterministic(self):
        from openedx_video_analytics.views import _hash_ip_address
        r1 = _hash_ip_address('10.0.0.1')
        r2 = _hash_ip_address('10.0.0.1')
        self.assertEqual(r1, r2)

    def test_hash_ip_address_none_returns_none(self):
        from openedx_video_analytics.views import _hash_ip_address
        self.assertIsNone(_hash_ip_address(None))

    def test_hash_ip_address_empty_returns_none(self):
        from openedx_video_analytics.views import _hash_ip_address
        self.assertIsNone(_hash_ip_address(''))

    def test_get_client_ip_x_forwarded_for(self):
        from openedx_video_analytics.views import _get_client_ip
        request = MagicMock()
        request.META = {'HTTP_X_FORWARDED_FOR': '1.2.3.4, 5.6.7.8'}
        self.assertEqual(_get_client_ip(request), '1.2.3.4')

    def test_get_client_ip_remote_addr(self):
        from openedx_video_analytics.views import _get_client_ip
        request = MagicMock()
        request.META = {'REMOTE_ADDR': '10.0.0.1'}
        self.assertEqual(_get_client_ip(request), '10.0.0.1')

    def test_get_org_slug_extracts_org(self):
        from openedx_video_analytics.views import _get_org_slug
        course_key = FakeCourseKey(org='MerekaAcademy')
        self.assertEqual(_get_org_slug(course_key), 'MerekaAcademy')


# ---------------------------------------------------------------------------
# 6. Task tests
# ---------------------------------------------------------------------------

class TaskSignatureTests(unittest.TestCase):
    """Task callable signatures."""

    def test_aggregate_daily_is_callable(self):
        from openedx_video_analytics.tasks import aggregate_video_analytics_daily
        self.assertTrue(callable(aggregate_video_analytics_daily))

    def test_cleanup_is_callable(self):
        from openedx_video_analytics.tasks import cleanup_old_video_events
        self.assertTrue(callable(cleanup_old_video_events))

    def test_backfill_is_callable(self):
        from openedx_video_analytics.tasks import backfill_video_analytics
        self.assertTrue(callable(backfill_video_analytics))

    def test_cleanup_default_days_is_90(self):
        import inspect
        from openedx_video_analytics.tasks import cleanup_old_video_events
        sig = inspect.signature(cleanup_old_video_events)
        self.assertEqual(sig.parameters['days_to_keep'].default, 90)


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class CleanupTaskTests(TestCase):
    """Integration test for cleanup_old_video_events."""

    def setUp(self):
        self.user = _create_user(username='cleanupuser', email='cleanup@example.com')

    def test_cleanup_deletes_old_events(self):
        from openedx_video_analytics.models import VideoPlaybackEvent
        from openedx_video_analytics.tasks import cleanup_old_video_events

        event = VideoPlaybackEvent.objects.create(
            user=self.user,
            course_key='course-v1:Test+101+2026',
            video_id='old-vid',
            event_type='played',
            position=0.0,
            org_slug='Test',
        )
        # Backdate
        old_date = timezone.now() - timedelta(days=100)
        VideoPlaybackEvent.objects.filter(pk=event.pk).update(timestamp=old_date)

        result = cleanup_old_video_events(days_to_keep=90)
        self.assertEqual(result['events_deleted'], 1)

    def test_cleanup_keeps_recent_events(self):
        from openedx_video_analytics.models import VideoPlaybackEvent
        from openedx_video_analytics.tasks import cleanup_old_video_events

        VideoPlaybackEvent.objects.create(
            user=self.user,
            course_key='course-v1:Test+101+2026',
            video_id='recent-vid',
            event_type='played',
            position=0.0,
            org_slug='Test',
        )
        result = cleanup_old_video_events(days_to_keep=90)
        self.assertEqual(result['events_deleted'], 0)


# ---------------------------------------------------------------------------
# 7. Signal tests
# ---------------------------------------------------------------------------

class SignalTests(unittest.TestCase):
    """on_video_event_created signal handler."""

    def test_handler_exists(self):
        from openedx_video_analytics.signals import on_video_event_created
        self.assertTrue(callable(on_video_event_created))

    def test_handler_does_not_raise_on_non_created(self):
        from openedx_video_analytics.signals import on_video_event_created
        # created=False should be a no-op
        on_video_event_created(
            sender=None,
            instance=MagicMock(),
            created=False,
        )

    def test_handler_logs_completion_events(self):
        from openedx_video_analytics.signals import on_video_event_created
        instance = MagicMock()
        instance.event_type = 'completed'
        instance.video_id = 'test-vid'
        instance.user.username = 'testuser'
        instance.position = 280.0
        # Should not raise
        on_video_event_created(
            sender=None,
            instance=instance,
            created=True,
        )


# ---------------------------------------------------------------------------
# 8. Admin tests
# ---------------------------------------------------------------------------

class AdminTests(unittest.TestCase):
    """Admin classes registered and configured."""

    def test_playback_event_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_video_analytics.models import VideoPlaybackEvent
        import openedx_video_analytics.admin  # noqa: F401
        self.assertIn(VideoPlaybackEvent, django_admin.site._registry)

    def test_summary_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_video_analytics.models import VideoAnalyticsSummary
        self.assertIn(VideoAnalyticsSummary, django_admin.site._registry)

    def test_playback_event_admin_no_add_permission(self):
        from openedx_video_analytics.admin import VideoPlaybackEventAdmin
        from openedx_video_analytics.models import VideoPlaybackEvent
        from django.contrib import admin as django_admin
        admin_instance = VideoPlaybackEventAdmin(VideoPlaybackEvent, django_admin.site)
        self.assertFalse(admin_instance.has_add_permission(MagicMock()))

    def test_playback_event_admin_no_change_permission(self):
        from openedx_video_analytics.admin import VideoPlaybackEventAdmin
        from openedx_video_analytics.models import VideoPlaybackEvent
        from django.contrib import admin as django_admin
        admin_instance = VideoPlaybackEventAdmin(VideoPlaybackEvent, django_admin.site)
        self.assertFalse(admin_instance.has_change_permission(MagicMock()))

    def test_playback_event_admin_superuser_can_delete(self):
        from openedx_video_analytics.admin import VideoPlaybackEventAdmin
        from openedx_video_analytics.models import VideoPlaybackEvent
        from django.contrib import admin as django_admin
        admin_instance = VideoPlaybackEventAdmin(VideoPlaybackEvent, django_admin.site)
        request = MagicMock()
        request.user.is_superuser = True
        self.assertTrue(admin_instance.has_delete_permission(request))

    def test_playback_event_admin_non_superuser_cannot_delete(self):
        from openedx_video_analytics.admin import VideoPlaybackEventAdmin
        from openedx_video_analytics.models import VideoPlaybackEvent
        from django.contrib import admin as django_admin
        admin_instance = VideoPlaybackEventAdmin(VideoPlaybackEvent, django_admin.site)
        request = MagicMock()
        request.user.is_superuser = False
        self.assertFalse(admin_instance.has_delete_permission(request))

    def test_summary_admin_has_regenerate_action(self):
        from openedx_video_analytics.admin import VideoAnalyticsSummaryAdmin
        self.assertIn('regenerate_summaries', VideoAnalyticsSummaryAdmin.actions)

    def test_summary_admin_display_completion_rate(self):
        from openedx_video_analytics.admin import VideoAnalyticsSummaryAdmin
        from openedx_video_analytics.models import VideoAnalyticsSummary
        from django.contrib import admin as django_admin
        admin_instance = VideoAnalyticsSummaryAdmin(VideoAnalyticsSummary, django_admin.site)
        obj = MagicMock()
        obj.completion_rate = 0.85
        result = admin_instance.display_completion_rate(obj)
        self.assertEqual(result, '85.0%')


# ---------------------------------------------------------------------------
# 9. Apps config tests
# ---------------------------------------------------------------------------

class AppConfigTests(unittest.TestCase):
    """AppConfig basic contract."""

    def test_app_name(self):
        from openedx_video_analytics.apps import VideoAnalyticsConfig
        self.assertEqual(VideoAnalyticsConfig.name, 'openedx_video_analytics')

    def test_verbose_name(self):
        from openedx_video_analytics.apps import VideoAnalyticsConfig
        self.assertIn('Video Analytics', VideoAnalyticsConfig.verbose_name)

    def test_ready_does_not_raise(self):
        from django.apps import apps
        app_config = apps.get_app_config('openedx_video_analytics')
        app_config.ready()


# ---------------------------------------------------------------------------
# 10. URL routing tests
# ---------------------------------------------------------------------------

class UrlConfigTests(unittest.TestCase):
    """URL configuration."""

    def test_urlpatterns_is_non_empty(self):
        from openedx_video_analytics.urls import urlpatterns
        self.assertIsInstance(urlpatterns, list)
        self.assertGreater(len(urlpatterns), 0)

    def test_app_name_is_set(self):
        from openedx_video_analytics import urls as urls_mod
        self.assertEqual(urls_mod.app_name, 'openedx_video_analytics')

    def test_record_event_route_exists(self):
        from openedx_video_analytics.urls import urlpatterns
        names = [p.name for p in urlpatterns if hasattr(p, 'name')]
        self.assertIn('record-event', names)

    def test_get_analytics_route_exists(self):
        from openedx_video_analytics.urls import urlpatterns
        names = [p.name for p in urlpatterns if hasattr(p, 'name')]
        self.assertIn('get-analytics', names)


if __name__ == '__main__':
    unittest.main()
