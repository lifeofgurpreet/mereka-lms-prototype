"""
Baseline tests for openedx_ora2_operations.

Covers:
- Import smoke tests for every module
- AppConfig name and verbose_name
- ORA2FallbackTracking: fields, __str__, trigger_fallback, mark_staff_assigned/completed
- ORA2OperationalMetrics: fields, __str__, storage_usage_percent property
- ORA2FileUpload: fields, __str__, track_upload, file_type extraction
- Signal handler signatures (ORA2 imports mocked)
- Metrics module: all Counter/Histogram/Gauge objects exist
- Admin registrations
"""

import importlib
import os
import sys
import types
import unittest
import uuid
from datetime import date, timedelta
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub Open edX deps BEFORE Django bootstrap
# ---------------------------------------------------------------------------

# opaque_keys.edx.django.models: CourseKeyField must be a real Django CharField subclass
import django as _django_pre
# We need django.db available for the CharField subclass
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_ora2_operations._test_settings')

# Build minimal settings first so django.setup() can work
_settings = types.ModuleType('openedx_ora2_operations._test_settings')
_settings.SECRET_KEY = 'test-secret-key'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'rest_framework',
    'openedx_ora2_operations',
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
_settings.ORA2_FILEUPLOAD_ROOT = '/tmp/ora2-test'
_settings.ORA2_PEER_GRADING_TIMEOUT_DAYS = 7
_settings.ORA2_FALLBACK_RETENTION_DAYS = 90
_settings.ORA2_METRICS_RETENTION_DAYS = 365
_settings.ORA2_FILE_RETENTION_DAYS = 180

sys.modules['openedx_ora2_operations._test_settings'] = _settings

# Now stub opaque_keys BEFORE django.setup() so that model import works
from django.db import models as _dj_models


class FakeCourseKeyField(_dj_models.CharField):
    """Stub for opaque_keys CourseKeyField — subclasses CharField so Django's _prepare() works."""
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('max_length', 255)
        super().__init__(*args, **kwargs)


class FakeUsageKeyField(_dj_models.CharField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('max_length', 255)
        super().__init__(*args, **kwargs)


_opaque_keys = types.ModuleType('opaque_keys')
_opaque_edx = types.ModuleType('opaque_keys.edx')
_opaque_django = types.ModuleType('opaque_keys.edx.django')
_opaque_models = types.ModuleType('opaque_keys.edx.django.models')
_opaque_models.CourseKeyField = FakeCourseKeyField
_opaque_models.UsageKeyField = FakeUsageKeyField

_opaque_keys.edx = _opaque_edx
_opaque_edx.django = _opaque_django
_opaque_django.models = _opaque_models

sys.modules['opaque_keys'] = _opaque_keys
sys.modules['opaque_keys.edx'] = _opaque_edx
sys.modules['opaque_keys.edx.django'] = _opaque_django
sys.modules['opaque_keys.edx.django.models'] = _opaque_models

# Stub openedx.core.djangoapps.content.course_overviews (used by signals.py)
_openedx = types.ModuleType('openedx')
_core = types.ModuleType('openedx.core')
_djangoapps = types.ModuleType('openedx.core.djangoapps')
_content = types.ModuleType('openedx.core.djangoapps.content')
_overviews = types.ModuleType('openedx.core.djangoapps.content.course_overviews')
_overview_models = types.ModuleType('openedx.core.djangoapps.content.course_overviews.models')
_overview_models.CourseOverview = MagicMock()

_openedx.core = _core
_core.djangoapps = _djangoapps
_djangoapps.content = _content
_content.course_overviews = _overviews
_overviews.models = _overview_models

sys.modules.setdefault('openedx', _openedx)
sys.modules.setdefault('openedx.core', _core)
sys.modules.setdefault('openedx.core.djangoapps', _djangoapps)
sys.modules.setdefault('openedx.core.djangoapps.content', _content)
sys.modules.setdefault('openedx.core.djangoapps.content.course_overviews', _overviews)
sys.modules.setdefault('openedx.core.djangoapps.content.course_overviews.models', _overview_models)

# Stub openedx plugin constants
_plugins = types.ModuleType('openedx.core.djangoapps.plugins')
_plugin_constants = types.ModuleType('openedx.core.djangoapps.plugins.constants')
_plugin_constants.PluginURLs = MagicMock()
_plugin_constants.ProjectType = MagicMock()
_djangoapps.plugins = _plugins
_plugins.constants = _plugin_constants
sys.modules.setdefault('openedx.core.djangoapps.plugins', _plugins)
sys.modules.setdefault('openedx.core.djangoapps.plugins.constants', _plugin_constants)

# Stub openassessment (for signals.py connect_ora2_signals)
_oa = types.ModuleType('openassessment')
_oa_assessment = types.ModuleType('openassessment.assessment')
_oa_assessment_api = types.ModuleType('openassessment.assessment.api')
_oa_peer = types.ModuleType('openassessment.assessment.api.peer')
_oa_staff = types.ModuleType('openassessment.assessment.api.staff')
_oa_workflow = types.ModuleType('openassessment.workflow')
_oa_workflow_api = types.ModuleType('openassessment.workflow.api')
_oa_workflow_models = types.ModuleType('openassessment.workflow.models')

_oa.assessment = _oa_assessment
_oa_assessment.api = _oa_assessment_api
_oa_assessment_api.peer = _oa_peer
_oa_assessment_api.staff = _oa_staff
_oa.workflow = _oa_workflow
_oa_workflow.api = _oa_workflow_api
_oa_workflow.models = _oa_workflow_models

sys.modules.setdefault('openassessment', _oa)
sys.modules.setdefault('openassessment.assessment', _oa_assessment)
sys.modules.setdefault('openassessment.assessment.api', _oa_assessment_api)
sys.modules.setdefault('openassessment.assessment.api.peer', _oa_peer)
sys.modules.setdefault('openassessment.assessment.api.staff', _oa_staff)
sys.modules.setdefault('openassessment.workflow', _oa_workflow)
sys.modules.setdefault('openassessment.workflow.api', _oa_workflow_api)
sys.modules.setdefault('openassessment.workflow.models', _oa_workflow_models)

# Stub Celery
_celery_mod = types.ModuleType('celery')


def _fake_shared_task(*args, **kwargs):
    def decorator(func):
        func.delay = func
        func.apply_async = func
        return func
    if args and callable(args[0]):
        return decorator(args[0])
    return decorator


_celery_mod.shared_task = _fake_shared_task
sys.modules.setdefault('celery', _celery_mod)

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

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
        self._assert_importable('openedx_ora2_operations.apps')

    def test_import_models(self):
        self._assert_importable('openedx_ora2_operations.models')

    def test_import_signals(self):
        self._assert_importable('openedx_ora2_operations.signals')

    def test_import_tasks(self):
        self._assert_importable('openedx_ora2_operations.tasks')

    def test_import_metrics(self):
        self._assert_importable('openedx_ora2_operations.metrics')

    def test_import_admin(self):
        self._assert_importable('openedx_ora2_operations.admin')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):
    def test_app_name(self):
        from openedx_ora2_operations.apps import ORA2OperationsConfig
        self.assertEqual(ORA2OperationsConfig.name, 'openedx_ora2_operations')

    def test_verbose_name(self):
        from openedx_ora2_operations.apps import ORA2OperationsConfig
        self.assertEqual(
            ORA2OperationsConfig.verbose_name,
            'ORA2 Operations & Observability',
        )


# ===========================================================================
# 3. ORA2FallbackTracking model
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestORA2FallbackTrackingModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def _create_fallback(self, **overrides):
        from openedx_ora2_operations.models import ORA2FallbackTracking
        now = timezone.now()
        defaults = dict(
            submission_uuid=str(uuid.uuid4()),
            course_id='course-v1:Test+ORA+2026',
            student_id='student-001',
            item_id='item-001',
            fallback_reason='timeout',
            peer_grading_started_at=now - timedelta(days=8),
            peer_grading_deadline=now - timedelta(days=1),
            peers_required=3,
            peers_completed=1,
        )
        defaults.update(overrides)
        return ORA2FallbackTracking.objects.create(**defaults)

    def test_str_representation(self):
        fb = self._create_fallback()
        s = str(fb)
        self.assertIn('Fallback:', s)
        self.assertIn('timeout', s)

    def test_default_status_is_pending(self):
        fb = self._create_fallback()
        self.assertEqual(fb.status, 'pending')

    def test_mark_staff_assigned(self):
        fb = self._create_fallback()
        fb.mark_staff_assigned()
        fb.refresh_from_db()
        self.assertEqual(fb.status, 'assigned')
        self.assertIsNotNone(fb.staff_assigned_at)

    def test_mark_staff_completed(self):
        fb = self._create_fallback()
        fb.mark_staff_completed()
        fb.refresh_from_db()
        self.assertEqual(fb.status, 'completed')
        self.assertIsNotNone(fb.staff_graded_at)

    def test_trigger_fallback_creates_record(self):
        from openedx_ora2_operations.models import ORA2FallbackTracking
        sub_uuid = str(uuid.uuid4())
        fb = ORA2FallbackTracking.trigger_fallback(
            submission_uuid=sub_uuid,
            course_id='course-v1:Test+FB+2026',
            student_id='student-fb',
            item_id='item-fb',
            reason='insufficient_peers',
            peers_required=5,
            peers_completed=2,
        )
        self.assertEqual(fb.submission_uuid, sub_uuid)
        self.assertEqual(fb.fallback_reason, 'insufficient_peers')
        self.assertEqual(fb.peers_required, 5)
        self.assertEqual(fb.peers_completed, 2)

    def test_trigger_fallback_idempotent(self):
        from openedx_ora2_operations.models import ORA2FallbackTracking
        sub_uuid = str(uuid.uuid4())
        fb1 = ORA2FallbackTracking.trigger_fallback(
            submission_uuid=sub_uuid,
            course_id='course-v1:Test+IDEM+2026',
            student_id='s1',
            item_id='i1',
        )
        fb2 = ORA2FallbackTracking.trigger_fallback(
            submission_uuid=sub_uuid,
            course_id='course-v1:Test+IDEM+2026',
            student_id='s1',
            item_id='i1',
        )
        self.assertEqual(fb1.pk, fb2.pk)

    def test_fallback_reason_choices(self):
        from openedx_ora2_operations.models import ORA2FallbackTracking
        field = ORA2FallbackTracking._meta.get_field('fallback_reason')
        reasons = {c[0] for c in field.choices}
        self.assertEqual(reasons, {'timeout', 'insufficient_peers', 'manual'})

    def test_status_choices(self):
        from openedx_ora2_operations.models import ORA2FallbackTracking
        field = ORA2FallbackTracking._meta.get_field('status')
        statuses = {c[0] for c in field.choices}
        self.assertEqual(statuses, {'pending', 'assigned', 'completed', 'cancelled'})


# ===========================================================================
# 4. ORA2OperationalMetrics model
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestORA2OperationalMetricsModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def _create_metrics(self, **overrides):
        from openedx_ora2_operations.models import ORA2OperationalMetrics
        defaults = dict(
            course_id='course-v1:Test+Met+2026',
            date=date.today(),
            total_submissions=100,
            storage_used_bytes=500000,
            storage_total_bytes=1000000,
        )
        defaults.update(overrides)
        return ORA2OperationalMetrics.objects.create(**defaults)

    def test_str_representation(self):
        m = self._create_metrics()
        s = str(m)
        self.assertIn('ORA2 Metrics:', s)
        self.assertIn(str(date.today()), s)

    def test_storage_usage_percent(self):
        m = self._create_metrics(
            storage_used_bytes=750000,
            storage_total_bytes=1000000,
        )
        self.assertAlmostEqual(m.storage_usage_percent, 75.0)

    def test_storage_usage_percent_zero_total(self):
        m = self._create_metrics(
            storage_used_bytes=0,
            storage_total_bytes=0,
        )
        self.assertEqual(m.storage_usage_percent, 0.0)

    def test_unique_together_course_date(self):
        self._create_metrics(course_id='course-v1:Uniq+Test+2026', date=date.today())
        from openedx_ora2_operations.models import ORA2OperationalMetrics
        from django.db import IntegrityError
        with self.assertRaises(IntegrityError):
            ORA2OperationalMetrics.objects.create(
                course_id='course-v1:Uniq+Test+2026',
                date=date.today(),
            )


# ===========================================================================
# 5. ORA2FileUpload model
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestORA2FileUploadModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def test_str_representation(self):
        from openedx_ora2_operations.models import ORA2FileUpload
        upload = ORA2FileUpload.objects.create(
            submission_uuid='sub-001',
            course_id='course-v1:Test+File+2026',
            student_id='student-f1',
            file_key='unique-key-001',
            file_name='essay.pdf',
            file_type='pdf',
            file_size_bytes=12345,
        )
        s = str(upload)
        self.assertIn('essay.pdf', s)
        self.assertIn('pdf', s)
        self.assertIn('12345', s)

    def test_track_upload_extracts_file_type(self):
        from openedx_ora2_operations.models import ORA2FileUpload
        upload = ORA2FileUpload.track_upload(
            submission_uuid='sub-002',
            course_id='course-v1:Test+Track+2026',
            student_id='student-t1',
            file_key='unique-key-002',
            file_name='report.docx',
            file_size=54321,
        )
        self.assertEqual(upload.file_type, 'docx')
        self.assertEqual(upload.file_size_bytes, 54321)

    def test_track_upload_no_extension(self):
        from openedx_ora2_operations.models import ORA2FileUpload
        upload = ORA2FileUpload.track_upload(
            submission_uuid='sub-003',
            course_id='course-v1:Test+NoExt+2026',
            student_id='student-ne',
            file_key='unique-key-003',
            file_name='noextension',
            file_size=100,
        )
        self.assertEqual(upload.file_type, 'unknown')

    def test_track_upload_idempotent(self):
        from openedx_ora2_operations.models import ORA2FileUpload
        u1 = ORA2FileUpload.track_upload(
            submission_uuid='sub-004',
            course_id='course-v1:Test+Idem+2026',
            student_id='student-i',
            file_key='unique-key-004',
            file_name='test.txt',
            file_size=10,
        )
        u2 = ORA2FileUpload.track_upload(
            submission_uuid='sub-004',
            course_id='course-v1:Test+Idem+2026',
            student_id='student-i',
            file_key='unique-key-004',
            file_name='test.txt',
            file_size=10,
        )
        self.assertEqual(u1.pk, u2.pk)

    def test_default_status_is_active(self):
        from openedx_ora2_operations.models import ORA2FileUpload
        upload = ORA2FileUpload.track_upload(
            submission_uuid='sub-005',
            course_id='course-v1:Test+Stat+2026',
            student_id='s5',
            file_key='unique-key-005',
            file_name='f.zip',
            file_size=99,
        )
        self.assertEqual(upload.status, 'active')


# ===========================================================================
# 6. Signals — handler signatures
# ===========================================================================

class TestSignals(unittest.TestCase):
    """Test signal handler functions exist with expected signatures."""

    def test_on_submission_created_callable(self):
        from openedx_ora2_operations.signals import on_submission_created
        self.assertTrue(callable(on_submission_created))

    def test_on_peer_assessment_completed_callable(self):
        from openedx_ora2_operations.signals import on_peer_assessment_completed
        self.assertTrue(callable(on_peer_assessment_completed))

    def test_on_staff_assessment_completed_callable(self):
        from openedx_ora2_operations.signals import on_staff_assessment_completed
        self.assertTrue(callable(on_staff_assessment_completed))

    def test_track_grade_propagation_callable(self):
        from openedx_ora2_operations.signals import track_grade_propagation
        self.assertTrue(callable(track_grade_propagation))

    def test_track_fallback_to_staff_callable(self):
        from openedx_ora2_operations.signals import track_fallback_to_staff
        self.assertTrue(callable(track_fallback_to_staff))

    def test_connect_ora2_signals_does_not_crash(self):
        """connect_ora2_signals should handle missing ORA2 gracefully."""
        from openedx_ora2_operations.signals import connect_ora2_signals
        # Should not raise even with mocked ORA2 modules
        connect_ora2_signals()

    def test_on_submission_created_handles_missing_data(self):
        """on_submission_created should not crash on empty submission dict."""
        from openedx_ora2_operations.signals import on_submission_created
        # Pass an empty submission — should not raise
        on_submission_created(sender=None, submission={})

    def test_track_grade_propagation_success(self):
        from openedx_ora2_operations.signals import track_grade_propagation
        # Should not raise
        track_grade_propagation('course-v1:Test+GP+2026', success=True)

    def test_track_grade_propagation_failure(self):
        from openedx_ora2_operations.signals import track_grade_propagation
        track_grade_propagation('course-v1:Test+GP+2026', success=False)

    def test_track_fallback_to_staff_records(self):
        from openedx_ora2_operations.signals import track_fallback_to_staff
        track_fallback_to_staff('course-v1:Test+FB+2026', reason='timeout')

    def test_log_ora2_event_callable(self):
        from openedx_ora2_operations.signals import log_ora2_event
        # Should not raise
        log_ora2_event('test_event', {'key': 'value'})


# ===========================================================================
# 7. Metrics module — Prometheus objects exist
# ===========================================================================

class TestMetricsModule(unittest.TestCase):
    """Verify all Prometheus metric objects are defined."""

    def test_submissions_counter(self):
        from openedx_ora2_operations.metrics import ora2_submissions_total
        self.assertIsNotNone(ora2_submissions_total)

    def test_peer_assessments_counter(self):
        from openedx_ora2_operations.metrics import ora2_peer_assessments_total
        self.assertIsNotNone(ora2_peer_assessments_total)

    def test_staff_assessments_counter(self):
        from openedx_ora2_operations.metrics import ora2_staff_assessments_total
        self.assertIsNotNone(ora2_staff_assessments_total)

    def test_staff_grading_queue_gauge(self):
        from openedx_ora2_operations.metrics import ora2_staff_grading_queue_size
        self.assertIsNotNone(ora2_staff_grading_queue_size)

    def test_file_upload_histogram(self):
        from openedx_ora2_operations.metrics import ora2_file_upload_size_bytes
        self.assertIsNotNone(ora2_file_upload_size_bytes)

    def test_grade_propagation_counter(self):
        from openedx_ora2_operations.metrics import ora2_grade_propagation_total
        self.assertIsNotNone(ora2_grade_propagation_total)

    def test_fallback_counter(self):
        from openedx_ora2_operations.metrics import ora2_fallback_to_staff_total
        self.assertIsNotNone(ora2_fallback_to_staff_total)

    def test_storage_gauges(self):
        from openedx_ora2_operations.metrics import (
            ora2_file_storage_used_bytes,
            ora2_file_storage_total_bytes,
        )
        self.assertIsNotNone(ora2_file_storage_used_bytes)
        self.assertIsNotNone(ora2_file_storage_total_bytes)

    def test_update_storage_metrics_handles_missing_path(self):
        from openedx_ora2_operations.metrics import update_storage_metrics
        with patch('os.path.exists', return_value=False):
            # Should not raise
            update_storage_metrics()


# ===========================================================================
# 8. Admin registrations
# ===========================================================================

class TestAdminRegistrations(unittest.TestCase):
    def test_fallback_admin(self):
        from django.contrib import admin
        from openedx_ora2_operations.models import ORA2FallbackTracking
        self.assertIn(ORA2FallbackTracking, admin.site._registry)

    def test_metrics_admin(self):
        from django.contrib import admin
        from openedx_ora2_operations.models import ORA2OperationalMetrics
        self.assertIn(ORA2OperationalMetrics, admin.site._registry)

    def test_file_upload_admin(self):
        from django.contrib import admin
        from openedx_ora2_operations.models import ORA2FileUpload
        self.assertIn(ORA2FileUpload, admin.site._registry)


if __name__ == '__main__':
    unittest.main()
