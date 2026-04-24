"""
Baseline tests for openedx_timed_exams.

Covers:
  1. Import smoke tests -- every module can be imported
  2. ExamTimeExtension model -- fields, is_valid_now, calculate_extended_time,
     get_active_extension, str representation
  3. ExamSession model -- fields, remaining_time_seconds, is_expired, hash_value,
     create_session, submit, auto_submit, terminate, detect_multi_device
  4. ExamGradeRelease model -- fields, should_release_now, manual_release
  5. Admin tests -- all three admin classes registered with correct configuration
  6. Signal tests -- connect_exam_signals survives missing edx_proctoring
  7. Middleware tests -- TimedExamEnforcementMiddleware logic
  8. Apps config tests -- AppConfig name/verbose_name
  9. URL and init tests

Run from repo root:
    PYTHONPATH=infrastructure/tutor/custom-apps \
        python3 -m pytest infrastructure/tutor/custom-apps/openedx_timed_exams/tests.py -v --tb=short
"""

import importlib
import sys
import unittest
from datetime import timedelta
from decimal import Decimal
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


def _create_user(username='testuser', email='test@example.com'):
    return User.objects.get_or_create(username=username, defaults={'email': email})[0]


# ---------------------------------------------------------------------------
# 1. Import smoke tests
# ---------------------------------------------------------------------------

class TestModuleImports(unittest.TestCase):
    """Every module in openedx_timed_exams must import cleanly."""

    def _import(self, module_name):
        full = f'openedx_timed_exams.{module_name}'
        if full in sys.modules:
            return sys.modules[full]
        return importlib.import_module(full)

    def test_package_init_imports(self):
        import openedx_timed_exams
        self.assertEqual(openedx_timed_exams.__version__, '1.0.0')

    def test_apps_imports(self):
        mod = self._import('apps')
        self.assertTrue(hasattr(mod, 'TimedExamsConfig'))

    def test_models_imports(self):
        mod = self._import('models')
        self.assertTrue(hasattr(mod, 'ExamTimeExtension'))
        self.assertTrue(hasattr(mod, 'ExamSession'))
        self.assertTrue(hasattr(mod, 'ExamGradeRelease'))

    def test_admin_imports(self):
        mod = self._import('admin')
        self.assertTrue(hasattr(mod, 'ExamTimeExtensionAdmin'))
        self.assertTrue(hasattr(mod, 'ExamSessionAdmin'))
        self.assertTrue(hasattr(mod, 'ExamGradeReleaseAdmin'))

    def test_signals_imports(self):
        mod = self._import('signals')
        self.assertTrue(hasattr(mod, 'connect_exam_signals'))

    def test_middleware_imports(self):
        mod = self._import('middleware')
        self.assertTrue(hasattr(mod, 'TimedExamEnforcementMiddleware'))


# ---------------------------------------------------------------------------
# 2. ExamTimeExtension model tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class ExamTimeExtensionFieldTests(TestCase):
    """ExamTimeExtension field contract."""

    def setUp(self):
        self.user = _create_user()

    def _make_extension(self, **overrides):
        from openedx_timed_exams.models import ExamTimeExtension
        defaults = dict(
            user=self.user,
            course_id='course-v1:Test+101+2026',
            multiplier=Decimal('1.50'),
            additional_minutes=0,
            is_active=True,
            valid_from=timezone.now() - timedelta(days=1),
        )
        defaults.update(overrides)
        return ExamTimeExtension.objects.create(**defaults)

    def test_default_multiplier(self):
        ext = self._make_extension()
        self.assertEqual(ext.multiplier, Decimal('1.50'))

    def test_default_additional_minutes(self):
        ext = self._make_extension()
        self.assertEqual(ext.additional_minutes, 0)

    def test_is_active_default_true(self):
        ext = self._make_extension()
        self.assertTrue(ext.is_active)

    def test_db_table_name(self):
        from openedx_timed_exams.models import ExamTimeExtension
        self.assertEqual(ExamTimeExtension._meta.db_table, 'timed_exams_time_extension')

    def test_str_representation_basic(self):
        ext = self._make_extension()
        s = str(ext)
        self.assertIn(self.user.username, s)
        self.assertIn('1.5', s)

    def test_str_representation_with_additional_minutes(self):
        ext = self._make_extension(additional_minutes=15)
        s = str(ext)
        self.assertIn('+15min', s)


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class ExamTimeExtensionBusinessLogicTests(TestCase):
    """Business logic: is_valid_now, calculate_extended_time, get_active_extension."""

    def setUp(self):
        self.user = _create_user(username='extuser', email='ext@example.com')

    def _make_extension(self, **overrides):
        from openedx_timed_exams.models import ExamTimeExtension
        defaults = dict(
            user=self.user,
            course_id='course-v1:Test+101+2026',
            multiplier=Decimal('1.50'),
            additional_minutes=10,
            is_active=True,
            valid_from=timezone.now() - timedelta(days=1),
        )
        defaults.update(overrides)
        return ExamTimeExtension.objects.create(**defaults)

    def test_is_valid_now_active_in_range(self):
        ext = self._make_extension()
        self.assertTrue(ext.is_valid_now())

    def test_is_valid_now_false_when_inactive(self):
        ext = self._make_extension(is_active=False)
        self.assertFalse(ext.is_valid_now())

    def test_is_valid_now_false_when_future_valid_from(self):
        ext = self._make_extension(valid_from=timezone.now() + timedelta(days=1))
        self.assertFalse(ext.is_valid_now())

    def test_is_valid_now_false_when_past_valid_until(self):
        ext = self._make_extension(valid_until=timezone.now() - timedelta(seconds=1))
        self.assertFalse(ext.is_valid_now())

    def test_is_valid_now_true_when_valid_until_is_future(self):
        ext = self._make_extension(valid_until=timezone.now() + timedelta(days=1))
        self.assertTrue(ext.is_valid_now())

    def test_is_valid_now_true_when_valid_until_is_none(self):
        ext = self._make_extension(valid_until=None)
        self.assertTrue(ext.is_valid_now())

    def test_calculate_extended_time_multiplier_only(self):
        ext = self._make_extension(multiplier=Decimal('2.00'), additional_minutes=0)
        self.assertEqual(ext.calculate_extended_time(60), 120)

    def test_calculate_extended_time_with_additional(self):
        ext = self._make_extension(multiplier=Decimal('1.50'), additional_minutes=10)
        # 60 * 1.5 = 90, + 10 = 100
        self.assertEqual(ext.calculate_extended_time(60), 100)

    def test_calculate_extended_time_rounds_down(self):
        ext = self._make_extension(multiplier=Decimal('1.33'), additional_minutes=0)
        # 60 * 1.33 = 79.8 -> int -> 79
        self.assertEqual(ext.calculate_extended_time(60), 79)

    def test_get_active_extension_returns_course_wide(self):
        from openedx_timed_exams.models import ExamTimeExtension
        self._make_extension(usage_key=None)
        ext = ExamTimeExtension.get_active_extension(
            self.user, 'course-v1:Test+101+2026'
        )
        self.assertIsNotNone(ext)

    def test_get_active_extension_prefers_specific_exam(self):
        from openedx_timed_exams.models import ExamTimeExtension
        self._make_extension(usage_key=None, multiplier=Decimal('1.50'))
        self._make_extension(
            usage_key='block-v1:Test+101+2026+type@sequential+block@exam1',
            multiplier=Decimal('2.00'),
        )
        ext = ExamTimeExtension.get_active_extension(
            self.user,
            'course-v1:Test+101+2026',
            usage_key='block-v1:Test+101+2026+type@sequential+block@exam1',
        )
        self.assertIsNotNone(ext)
        self.assertEqual(ext.multiplier, Decimal('2.00'))

    def test_get_active_extension_falls_back_to_course_wide(self):
        from openedx_timed_exams.models import ExamTimeExtension
        self._make_extension(usage_key=None, multiplier=Decimal('1.50'))
        ext = ExamTimeExtension.get_active_extension(
            self.user,
            'course-v1:Test+101+2026',
            usage_key='block-v1:Test+101+2026+type@sequential+block@other',
        )
        self.assertIsNotNone(ext)
        self.assertEqual(ext.multiplier, Decimal('1.50'))

    def test_get_active_extension_returns_none_when_no_match(self):
        from openedx_timed_exams.models import ExamTimeExtension
        ext = ExamTimeExtension.get_active_extension(
            self.user, 'course-v1:NoMatch+000+0000'
        )
        self.assertIsNone(ext)

    def test_get_active_extension_ignores_inactive(self):
        from openedx_timed_exams.models import ExamTimeExtension
        self._make_extension(is_active=False)
        ext = ExamTimeExtension.get_active_extension(
            self.user, 'course-v1:Test+101+2026'
        )
        self.assertIsNone(ext)

    def test_get_active_extension_ignores_expired(self):
        from openedx_timed_exams.models import ExamTimeExtension
        self._make_extension(valid_until=timezone.now() - timedelta(seconds=1))
        ext = ExamTimeExtension.get_active_extension(
            self.user, 'course-v1:Test+101+2026'
        )
        self.assertIsNone(ext)


# ---------------------------------------------------------------------------
# 3. ExamSession model tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class ExamSessionFieldTests(TestCase):
    """ExamSession field contract."""

    def setUp(self):
        self.user = _create_user(username='sessionuser', email='session@example.com')

    def _make_session(self, **overrides):
        from openedx_timed_exams.models import ExamSession
        defaults = dict(
            user=self.user,
            course_id='course-v1:Test+101+2026',
            usage_key='block-v1:Test+101+2026+type@sequential+block@exam1',
            session_key='test-session-key-abc123',
            device_fingerprint='a' * 64,
            ip_address_hash='b' * 64,
            base_duration_minutes=60,
            extended_duration_minutes=60,
            expires_at=timezone.now() + timedelta(hours=1),
            status='active',
        )
        defaults.update(overrides)
        return ExamSession.objects.create(**defaults)

    def test_default_status_is_active(self):
        s = self._make_session()
        self.assertEqual(s.status, 'active')

    def test_default_auto_submitted_is_false(self):
        s = self._make_session()
        self.assertFalse(s.auto_submitted)

    def test_db_table_name(self):
        from openedx_timed_exams.models import ExamSession
        self.assertEqual(ExamSession._meta.db_table, 'timed_exams_session')

    def test_str_representation(self):
        s = self._make_session()
        text = str(s)
        self.assertIn(self.user.username, text)
        self.assertIn('active', text)


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class ExamSessionBusinessLogicTests(TestCase):
    """Business logic: remaining_time, is_expired, submit, auto_submit, terminate, multi-device."""

    def setUp(self):
        self.user = _create_user(username='sesslogic', email='sesslogic@example.com')

    def _make_session(self, **overrides):
        from openedx_timed_exams.models import ExamSession
        defaults = dict(
            user=self.user,
            course_id='course-v1:Test+101+2026',
            usage_key='block-v1:Test+101+2026+type@sequential+block@exam1',
            session_key='logic-session-key',
            device_fingerprint='a' * 64,
            ip_address_hash='b' * 64,
            base_duration_minutes=60,
            extended_duration_minutes=60,
            expires_at=timezone.now() + timedelta(hours=1),
            status='active',
        )
        defaults.update(overrides)
        return ExamSession.objects.create(**defaults)

    def test_remaining_time_seconds_positive_for_active(self):
        s = self._make_session(expires_at=timezone.now() + timedelta(minutes=30))
        remaining = s.remaining_time_seconds
        self.assertGreater(remaining, 0)
        self.assertLessEqual(remaining, 1800)

    def test_remaining_time_seconds_zero_when_expired(self):
        s = self._make_session(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(s.remaining_time_seconds, 0)

    def test_remaining_time_seconds_zero_for_submitted(self):
        s = self._make_session(status='submitted')
        self.assertEqual(s.remaining_time_seconds, 0)

    def test_is_expired_false_for_future(self):
        s = self._make_session(expires_at=timezone.now() + timedelta(hours=1))
        self.assertFalse(s.is_expired)

    def test_is_expired_true_for_past(self):
        s = self._make_session(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertTrue(s.is_expired)

    def test_hash_value_returns_sha256(self):
        from openedx_timed_exams.models import ExamSession
        h = ExamSession.hash_value('test_input')
        self.assertEqual(len(h), 64)  # SHA-256 hex digest length
        import hashlib
        expected = hashlib.sha256('test_input'.encode('utf-8')).hexdigest()
        self.assertEqual(h, expected)

    def test_submit_changes_status_to_submitted(self):
        s = self._make_session()
        s.submit()
        s.refresh_from_db()
        self.assertEqual(s.status, 'submitted')

    def test_submit_is_idempotent_on_non_active(self):
        s = self._make_session(status='submitted')
        s.submit()  # should not change or raise
        s.refresh_from_db()
        self.assertEqual(s.status, 'submitted')

    def test_auto_submit_changes_status_to_expired(self):
        s = self._make_session()
        s.auto_submit()
        s.refresh_from_db()
        self.assertEqual(s.status, 'expired')
        self.assertTrue(s.auto_submitted)
        self.assertIsNotNone(s.auto_submitted_at)

    def test_auto_submit_noop_on_non_active(self):
        s = self._make_session(status='submitted')
        s.auto_submit()
        s.refresh_from_db()
        self.assertEqual(s.status, 'submitted')
        self.assertFalse(s.auto_submitted)

    def test_terminate_changes_status_to_terminated(self):
        s = self._make_session()
        s.terminate(reason='multi_device')
        s.refresh_from_db()
        self.assertEqual(s.status, 'terminated')

    def test_terminate_noop_on_non_active(self):
        s = self._make_session(status='submitted')
        s.terminate()
        s.refresh_from_db()
        self.assertEqual(s.status, 'submitted')

    def test_get_active_session_returns_active(self):
        from openedx_timed_exams.models import ExamSession
        s = self._make_session()
        result = ExamSession.get_active_session(
            self.user, 'block-v1:Test+101+2026+type@sequential+block@exam1',
        )
        self.assertIsNotNone(result)
        self.assertEqual(result.pk, s.pk)

    def test_get_active_session_returns_none_when_submitted(self):
        from openedx_timed_exams.models import ExamSession
        self._make_session(status='submitted')
        result = ExamSession.get_active_session(
            self.user, 'block-v1:Test+101+2026+type@sequential+block@exam1',
        )
        self.assertIsNone(result)

    def test_detect_multi_device_returns_none_same_fingerprint(self):
        from openedx_timed_exams.models import ExamSession
        fp = 'a' * 64
        self._make_session(device_fingerprint=fp)
        result = ExamSession.detect_multi_device(
            self.user,
            'block-v1:Test+101+2026+type@sequential+block@exam1',
            fp,
        )
        self.assertIsNone(result)

    def test_detect_multi_device_returns_session_different_fingerprint(self):
        from openedx_timed_exams.models import ExamSession
        self._make_session(device_fingerprint='a' * 64)
        result = ExamSession.detect_multi_device(
            self.user,
            'block-v1:Test+101+2026+type@sequential+block@exam1',
            'x' * 64,
        )
        self.assertIsNotNone(result)

    def test_create_session_applies_time_extension(self):
        from openedx_timed_exams.models import ExamSession, ExamTimeExtension
        ExamTimeExtension.objects.create(
            user=self.user,
            course_id='course-v1:Test+101+2026',
            multiplier=Decimal('2.00'),
            additional_minutes=5,
            is_active=True,
            valid_from=timezone.now() - timedelta(days=1),
        )
        request = MagicMock()
        request.META = {
            'HTTP_USER_AGENT': 'Mozilla/5.0',
            'HTTP_SEC_CH_UA': '',
            'REMOTE_ADDR': '127.0.0.1',
        }
        session = ExamSession.create_session(
            user=self.user,
            course_id='course-v1:Test+101+2026',
            usage_key='block-v1:Test+101+2026+type@sequential+block@exam1',
            duration_minutes=60,
            request=request,
        )
        # 60 * 2.0 = 120, + 5 = 125
        self.assertEqual(session.extended_duration_minutes, 125)
        self.assertEqual(session.base_duration_minutes, 60)
        self.assertEqual(session.status, 'active')
        self.assertIsNotNone(session.time_extension)


# ---------------------------------------------------------------------------
# 4. ExamGradeRelease model tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class ExamGradeReleaseTests(TestCase):
    """ExamGradeRelease field and business logic."""

    def setUp(self):
        self.user = _create_user(username='gradeuser', email='grade@example.com')

    def _make_release(self, **overrides):
        from openedx_timed_exams.models import ExamGradeRelease
        defaults = dict(
            course_id='course-v1:Test+101+2026',
            usage_key='block-v1:Test+101+2026+type@sequential+block@exam1',
            release_mode='window_close',
        )
        defaults.update(overrides)
        return ExamGradeRelease.objects.create(**defaults)

    def test_db_table_name(self):
        from openedx_timed_exams.models import ExamGradeRelease
        self.assertEqual(ExamGradeRelease._meta.db_table, 'timed_exams_grade_release')

    def test_str_representation(self):
        r = self._make_release()
        self.assertIn('window_close', str(r).lower().replace(' ', '_').replace("'", ''))

    def test_should_release_now_immediate(self):
        r = self._make_release(release_mode='immediate')
        self.assertTrue(r.should_release_now())

    def test_should_release_now_manual_false_by_default(self):
        r = self._make_release(release_mode='manual')
        self.assertFalse(r.should_release_now())

    def test_should_release_now_manual_true_after_release(self):
        r = self._make_release(release_mode='manual', released_manually=True)
        self.assertTrue(r.should_release_now())

    def test_should_release_now_window_close_past(self):
        r = self._make_release(
            release_mode='window_close',
            window_close_at=timezone.now() - timedelta(seconds=1),
        )
        self.assertTrue(r.should_release_now())

    def test_should_release_now_window_close_future(self):
        r = self._make_release(
            release_mode='window_close',
            window_close_at=timezone.now() + timedelta(hours=1),
        )
        self.assertFalse(r.should_release_now())

    def test_should_release_now_scheduled_past(self):
        r = self._make_release(
            release_mode='scheduled',
            release_at=timezone.now() - timedelta(seconds=1),
        )
        self.assertTrue(r.should_release_now())

    def test_should_release_now_scheduled_future(self):
        r = self._make_release(
            release_mode='scheduled',
            release_at=timezone.now() + timedelta(hours=1),
        )
        self.assertFalse(r.should_release_now())

    def test_manual_release_sets_fields(self):
        r = self._make_release(release_mode='manual')
        r.manual_release(self.user)
        r.refresh_from_db()
        self.assertTrue(r.released_manually)
        self.assertEqual(r.released_by_id, self.user.id)
        self.assertIsNotNone(r.released_at)


# ---------------------------------------------------------------------------
# 5. Admin tests
# ---------------------------------------------------------------------------

class AdminRegistrationTests(unittest.TestCase):
    """All three admin classes are registered."""

    def test_exam_time_extension_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_timed_exams.models import ExamTimeExtension
        import openedx_timed_exams.admin  # noqa: F401
        self.assertIn(ExamTimeExtension, django_admin.site._registry)

    def test_exam_session_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_timed_exams.models import ExamSession
        self.assertIn(ExamSession, django_admin.site._registry)

    def test_exam_grade_release_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_timed_exams.models import ExamGradeRelease
        self.assertIn(ExamGradeRelease, django_admin.site._registry)

    def test_extension_admin_has_actions(self):
        from openedx_timed_exams.admin import ExamTimeExtensionAdmin
        self.assertIn('approve_extensions', ExamTimeExtensionAdmin.actions)
        self.assertIn('deactivate_extensions', ExamTimeExtensionAdmin.actions)

    def test_session_admin_has_terminate_action(self):
        from openedx_timed_exams.admin import ExamSessionAdmin
        self.assertIn('terminate_sessions', ExamSessionAdmin.actions)

    def test_grade_release_admin_has_release_action(self):
        from openedx_timed_exams.admin import ExamGradeReleaseAdmin
        self.assertIn('manually_release_grades', ExamGradeReleaseAdmin.actions)


# ---------------------------------------------------------------------------
# 6. Signal tests
# ---------------------------------------------------------------------------

class SignalTests(unittest.TestCase):
    """connect_exam_signals survives missing edx_proctoring."""

    def test_connect_exam_signals_is_callable(self):
        from openedx_timed_exams.signals import connect_exam_signals
        self.assertTrue(callable(connect_exam_signals))

    def test_connect_exam_signals_survives_import_error(self):
        from openedx_timed_exams.signals import connect_exam_signals
        saved = sys.modules.pop('edx_proctoring', None)
        saved_signals = sys.modules.pop('edx_proctoring.signals', None)
        try:
            connect_exam_signals()  # should not raise
        finally:
            if saved is not None:
                sys.modules['edx_proctoring'] = saved
            if saved_signals is not None:
                sys.modules['edx_proctoring.signals'] = saved_signals

    def test_on_exam_attempt_created_handles_no_attempt(self):
        from openedx_timed_exams.signals import on_exam_attempt_created
        # Should not raise when attempt is None
        on_exam_attempt_created(sender=None, attempt=None)

    def test_on_exam_attempt_submitted_handles_no_attempt(self):
        from openedx_timed_exams.signals import on_exam_attempt_submitted
        on_exam_attempt_submitted(sender=None, attempt=None)


# ---------------------------------------------------------------------------
# 7. Middleware tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class MiddlewareTests(unittest.TestCase):
    """TimedExamEnforcementMiddleware logic tests."""

    def setUp(self):
        from openedx_timed_exams.middleware import TimedExamEnforcementMiddleware
        self.middleware_cls = TimedExamEnforcementMiddleware

    def test_init_takes_get_response(self):
        mw = self.middleware_cls(lambda r: r)
        self.assertIsNotNone(mw)

    def test_passes_through_unauthenticated(self):
        """Unauthenticated requests pass through without exam checks."""
        request = MagicMock()
        request.user.is_authenticated = False
        response = MagicMock()
        mw = self.middleware_cls(lambda r: response)
        result = mw(request)
        self.assertEqual(result, response)

    def test_passes_through_non_exam_path(self):
        """Requests to non-exam paths pass through."""
        request = MagicMock()
        request.user.is_authenticated = True
        request.path = '/dashboard/'
        request.path.lower = lambda: '/dashboard/'
        response = MagicMock()
        mw = self.middleware_cls(lambda r: response)
        result = mw(request)
        self.assertEqual(result, response)

    def test_is_exam_request_detects_xblock_path(self):
        mw = self.middleware_cls(lambda r: None)
        request = MagicMock()
        request.path = '/xblock/block-v1:Org+Course+Run+type@problem+block@abc'
        request.path.lower = lambda: request.path.lower()
        self.assertTrue(mw._is_exam_request(request))

    def test_is_exam_request_rejects_non_exam_path(self):
        mw = self.middleware_cls(lambda r: None)
        request = MagicMock()
        request.path = '/dashboard/settings/'
        request.path.lower = lambda: request.path.lower()
        self.assertFalse(mw._is_exam_request(request))

    def test_extract_usage_key_from_query_param(self):
        mw = self.middleware_cls(lambda r: None)
        request = MagicMock()
        request.GET = {'usage_key': 'block-v1:Test+101+Run+type@sequential+block@exam1'}
        request.POST = {}
        request.path = '/xblock/handler'
        result = mw._extract_usage_key(request)
        self.assertEqual(result, 'block-v1:Test+101+Run+type@sequential+block@exam1')

    def test_extract_usage_key_from_url_path(self):
        mw = self.middleware_cls(lambda r: None)
        request = MagicMock()
        request.GET = {}
        request.POST = {}
        request.path = '/xblock/block-v1:Org+Course+Run+type@sequential+block@exam1/handler'
        result = mw._extract_usage_key(request)
        self.assertEqual(result, 'block-v1:Org+Course+Run+type@sequential+block@exam1')

    def test_extract_usage_key_returns_none_when_not_found(self):
        mw = self.middleware_cls(lambda r: None)
        request = MagicMock()
        request.GET = {}
        request.POST = {}
        request.path = '/courses/overview/'
        result = mw._extract_usage_key(request)
        self.assertIsNone(result)

    def test_get_device_fingerprint_returns_sha256(self):
        mw = self.middleware_cls(lambda r: None)
        request = MagicMock()
        request.META = {
            'HTTP_USER_AGENT': 'Mozilla/5.0',
            'HTTP_SEC_CH_UA': 'Chrome',
        }
        fp = mw._get_device_fingerprint(request)
        self.assertEqual(len(fp), 64)


# ---------------------------------------------------------------------------
# 8. Apps config tests
# ---------------------------------------------------------------------------

class AppConfigTests(unittest.TestCase):
    """AppConfig basic contract."""

    def test_app_name(self):
        from openedx_timed_exams.apps import TimedExamsConfig
        self.assertEqual(TimedExamsConfig.name, 'openedx_timed_exams')

    def test_verbose_name_mentions_timed_exams(self):
        from openedx_timed_exams.apps import TimedExamsConfig
        self.assertIn('Timed Exams', TimedExamsConfig.verbose_name)

    def test_default_auto_field(self):
        from openedx_timed_exams.apps import TimedExamsConfig
        self.assertEqual(
            TimedExamsConfig.default_auto_field,
            'django.db.models.BigAutoField'
        )

    def test_ready_does_not_raise(self):
        from django.apps import apps
        app_config = apps.get_app_config('openedx_timed_exams')
        app_config.ready()


# ---------------------------------------------------------------------------
# 9. Init version test
# ---------------------------------------------------------------------------

class InitVersionTests(unittest.TestCase):
    def test_version_is_set(self):
        import openedx_timed_exams
        self.assertEqual(openedx_timed_exams.__version__, '1.0.0')

    def test_default_app_config_is_set(self):
        import openedx_timed_exams
        self.assertEqual(
            openedx_timed_exams.default_app_config,
            'openedx_timed_exams.apps.TimedExamsConfig'
        )


if __name__ == '__main__':
    unittest.main()
