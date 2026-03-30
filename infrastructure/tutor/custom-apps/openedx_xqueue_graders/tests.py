"""
Baseline tests for openedx_xqueue_graders.

Covers:
- Import smoke tests for every module
- Model field existence (GraderSubmission, GraderQueueMetrics)
- Model method behaviour (calculate_hash, mark_* helpers, processing_time_ms)
- Sandbox security (validate_imports, SecureSandbox init)
- Grader logic (PythonGrader._parse_grader_payload, _evaluate_results)
- Metrics module (counters/gauges present as module-level names)
- Admin registration (GraderSubmissionAdmin, GraderQueueMetricsAdmin)
- AppConfig (name, verbose_name)

Run from repo root:
    PYTHONPATH=infrastructure/tutor/custom-apps \\
        python -m pytest infrastructure/tutor/custom-apps/openedx_xqueue_graders/tests.py -v

All Open edX / external dependencies are mocked in-process.
"""

import importlib
import sys
import types
import unittest
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub external dependencies before Django setup
# ---------------------------------------------------------------------------

def _stub(name, **attrs):
    mod = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(mod, k, v)
    sys.modules[name] = mod
    return mod


# prometheus_client
if 'prometheus_client' not in sys.modules:
    pc = _stub('prometheus_client')
    pc.Counter = MagicMock(return_value=MagicMock())
    pc.Histogram = MagicMock(return_value=MagicMock())
    pc.Gauge = MagicMock(return_value=MagicMock())

# numpy (used in GraderQueueMetrics.capture_snapshot)
if 'numpy' not in sys.modules:
    np = _stub('numpy')
    np.mean = MagicMock(return_value=500)
    np.percentile = MagicMock(return_value=800)

# ---------------------------------------------------------------------------
# Minimal Django bootstrap
# ---------------------------------------------------------------------------
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_xqueue_graders._test_settings')

import django
from django.conf import settings

if not settings.configured:
    settings.configure(
        SECRET_KEY='test-secret-key',
        INSTALLED_APPS=[
            'django.contrib.contenttypes',
            'django.contrib.auth',
            'django.contrib.admin',
            'openedx_xqueue_graders',
        ],
        DATABASES={
            'default': {
                'ENGINE': 'django.db.backends.sqlite3',
                'NAME': ':memory:',
            }
        },
        DEFAULT_AUTO_FIELD='django.db.models.BigAutoField',
        USE_TZ=True,
        TIME_ZONE='UTC',
    )
    django.setup()


# ---------------------------------------------------------------------------
# 1. Import smoke tests
# ---------------------------------------------------------------------------

class TestModuleImports(unittest.TestCase):
    """Every module must import cleanly."""

    def _import(self, module_name):
        try:
            return importlib.import_module(module_name)
        except ImportError as exc:
            self.fail(f"Failed to import {module_name}: {exc}")

    def test_import_apps(self):
        self._import('openedx_xqueue_graders.apps')

    def test_import_models(self):
        self._import('openedx_xqueue_graders.models')

    def test_import_sandbox(self):
        self._import('openedx_xqueue_graders.sandbox')

    def test_import_grader(self):
        self._import('openedx_xqueue_graders.grader')

    def test_import_metrics(self):
        self._import('openedx_xqueue_graders.metrics')

    def test_import_admin(self):
        self._import('openedx_xqueue_graders.admin')


# ---------------------------------------------------------------------------
# 2. AppConfig
# ---------------------------------------------------------------------------

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from openedx_xqueue_graders.apps import XQueueGradersConfig
        self.assertEqual(XQueueGradersConfig.name, 'openedx_xqueue_graders')

    def test_verbose_name(self):
        from openedx_xqueue_graders.apps import XQueueGradersConfig
        self.assertIn('XQueue', XQueueGradersConfig.verbose_name)

    def test_default_auto_field(self):
        from openedx_xqueue_graders.apps import XQueueGradersConfig
        self.assertEqual(XQueueGradersConfig.default_auto_field, 'django.db.models.BigAutoField')


# ---------------------------------------------------------------------------
# 3. Model field existence – GraderSubmission
# ---------------------------------------------------------------------------

class TestGraderSubmissionFields(unittest.TestCase):

    def setUp(self):
        from openedx_xqueue_graders.models import GraderSubmission
        self.model = GraderSubmission

    def _fields(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_xqueue_header_field(self):
        self.assertIn('xqueue_header', self._fields())

    def test_xqueue_body_field(self):
        self.assertIn('xqueue_body', self._fields())

    def test_submission_id_field(self):
        self.assertIn('submission_id', self._fields())

    def test_submission_hash_field(self):
        self.assertIn('submission_hash', self._fields())

    def test_student_response_field(self):
        self.assertIn('student_response', self._fields())

    def test_status_field(self):
        self.assertIn('status', self._fields())

    def test_correct_field(self):
        self.assertIn('correct', self._fields())

    def test_score_field(self):
        self.assertIn('score', self._fields())

    def test_feedback_field(self):
        self.assertIn('feedback', self._fields())

    def test_stdout_field(self):
        self.assertIn('stdout', self._fields())

    def test_stderr_field(self):
        self.assertIn('stderr', self._fields())

    def test_execution_time_ms_field(self):
        self.assertIn('execution_time_ms', self._fields())

    def test_exit_code_field(self):
        self.assertIn('exit_code', self._fields())

    def test_sandbox_violations_field(self):
        self.assertIn('sandbox_violations', self._fields())

    def test_submitted_at_field(self):
        self.assertIn('submitted_at', self._fields())

    def test_worker_hostname_field(self):
        self.assertIn('worker_hostname', self._fields())

    def test_worker_version_field(self):
        self.assertIn('worker_version', self._fields())

    def test_db_table(self):
        self.assertEqual(self.model._meta.db_table, 'xqueue_grader_submission')

    def test_str_contains_submission_id(self):
        obj = self.model(submission_id='sub-001', status='pending')
        s = str(obj)
        self.assertIn('sub-001', s)
        self.assertIn('pending', s)

    def test_status_choices_include_expected(self):
        choices = [c[0] for c in self.model._meta.get_field('status').choices]
        for expected in ('pending', 'processing', 'success', 'failure', 'timeout', 'sandbox_error'):
            self.assertIn(expected, choices)


# ---------------------------------------------------------------------------
# 4. GraderSubmission.calculate_hash (pure static method)
# ---------------------------------------------------------------------------

class TestGraderSubmissionHash(unittest.TestCase):

    def setUp(self):
        from openedx_xqueue_graders.models import GraderSubmission
        self.model = GraderSubmission

    def test_hash_returns_64_char_hex(self):
        h = self.model.calculate_hash('print("hello")', '{"expected": "hello"}')
        self.assertEqual(len(h), 64)
        self.assertTrue(all(c in '0123456789abcdef' for c in h))

    def test_hash_is_deterministic(self):
        h1 = self.model.calculate_hash('code', 'payload')
        h2 = self.model.calculate_hash('code', 'payload')
        self.assertEqual(h1, h2)

    def test_different_inputs_give_different_hashes(self):
        h1 = self.model.calculate_hash('code_a', 'payload')
        h2 = self.model.calculate_hash('code_b', 'payload')
        self.assertNotEqual(h1, h2)

    def test_empty_payload_still_returns_hash(self):
        h = self.model.calculate_hash('print("x")')
        self.assertEqual(len(h), 64)


# ---------------------------------------------------------------------------
# 5. GraderSubmission processing_time_ms property
# ---------------------------------------------------------------------------

class TestGraderSubmissionProcessingTime(unittest.TestCase):

    def test_processing_time_returns_none_without_timestamps(self):
        from openedx_xqueue_graders.models import GraderSubmission
        obj = GraderSubmission(started_processing_at=None, completed_at=None)
        self.assertIsNone(obj.processing_time_ms)

    def test_processing_time_calculated_correctly(self):
        from django.utils import timezone
        from datetime import timedelta
        from openedx_xqueue_graders.models import GraderSubmission

        now = timezone.now()
        obj = GraderSubmission(
            started_processing_at=now,
            completed_at=now + timedelta(seconds=2),
        )
        result = obj.processing_time_ms
        self.assertEqual(result, 2000)


# ---------------------------------------------------------------------------
# 6. GraderQueueMetrics fields
# ---------------------------------------------------------------------------

class TestGraderQueueMetricsFields(unittest.TestCase):

    def setUp(self):
        from openedx_xqueue_graders.models import GraderQueueMetrics
        self.model = GraderQueueMetrics

    def _fields(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_pending_count_field(self):
        self.assertIn('pending_count', self._fields())

    def test_processing_count_field(self):
        self.assertIn('processing_count', self._fields())

    def test_success_count_1h_field(self):
        self.assertIn('success_count_1h', self._fields())

    def test_avg_processing_time_ms_field(self):
        self.assertIn('avg_processing_time_ms', self._fields())

    def test_active_workers_field(self):
        self.assertIn('active_workers', self._fields())

    def test_str_contains_pending(self):
        from openedx_xqueue_graders.models import GraderQueueMetrics
        from django.utils import timezone
        obj = GraderQueueMetrics(pending_count=5)
        obj.timestamp = timezone.now()
        s = str(obj)
        self.assertIn('5', s)


# ---------------------------------------------------------------------------
# 7. Sandbox – SecureSandbox init and validate_imports
# ---------------------------------------------------------------------------

class TestSecureSandbox(unittest.TestCase):

    def _make_sandbox(self):
        from openedx_xqueue_graders.sandbox import SecureSandbox
        return SecureSandbox(timeout_seconds=5, memory_limit_mb=128)

    def test_init_sets_timeout(self):
        sb = self._make_sandbox()
        self.assertEqual(sb.timeout_seconds, 5)

    def test_init_sets_memory_limit(self):
        sb = self._make_sandbox()
        self.assertEqual(sb.memory_limit_mb, 128)

    def test_default_allowed_imports_non_empty(self):
        sb = self._make_sandbox()
        self.assertIn('math', sb.allowed_imports)
        self.assertIn('json', sb.allowed_imports)

    def test_validate_imports_allows_math(self):
        sb = self._make_sandbox()
        valid, violations = sb.validate_imports('import math\nprint(math.pi)')
        self.assertTrue(valid)
        self.assertEqual(violations, [])

    def test_validate_imports_blocks_socket(self):
        sb = self._make_sandbox()
        valid, violations = sb.validate_imports('import socket\ns = socket.socket()')
        self.assertFalse(valid)
        self.assertTrue(any('socket' in v for v in violations))

    def test_validate_imports_reports_syntax_error(self):
        sb = self._make_sandbox()
        valid, violations = sb.validate_imports('def broken(:')
        self.assertFalse(valid)
        self.assertTrue(any('Syntax error' in v or 'syntax' in v.lower() for v in violations))

    def test_get_sandbox_env_contains_safe_path(self):
        sb = self._make_sandbox()
        env = sb._get_sandbox_env()
        self.assertIn('/usr/bin', env['PATH'])
        self.assertNotIn('SECRET', env)


# ---------------------------------------------------------------------------
# 8. SecureSandbox custom exceptions
# ---------------------------------------------------------------------------

class TestSandboxExceptions(unittest.TestCase):

    def test_sandbox_violation_is_exception(self):
        from openedx_xqueue_graders.sandbox import SandboxViolation
        self.assertTrue(issubclass(SandboxViolation, Exception))

    def test_code_execution_timeout_is_exception(self):
        from openedx_xqueue_graders.sandbox import CodeExecutionTimeout
        self.assertTrue(issubclass(CodeExecutionTimeout, Exception))


# ---------------------------------------------------------------------------
# 9. PythonGrader – pure methods (no DB, no subprocess)
# ---------------------------------------------------------------------------

class TestPythonGraderParsing(unittest.TestCase):

    def _make_grader(self):
        from openedx_xqueue_graders.grader import PythonGrader
        return PythonGrader(timeout_seconds=5, memory_limit_mb=64)

    def test_parse_grader_payload_empty(self):
        grader = self._make_grader()
        result = grader._parse_grader_payload('')
        self.assertEqual(result, {'test_cases': '', 'expected_output': ''})

    def test_parse_grader_payload_json_string(self):
        import json
        grader = self._make_grader()
        payload = json.dumps({'test_cases': 'assert x == 1', 'expected_output': '42'})
        result = grader._parse_grader_payload(payload)
        self.assertEqual(result['expected_output'], '42')

    def test_parse_grader_payload_dict_passthrough(self):
        grader = self._make_grader()
        payload = {'test_cases': 'test()', 'points': 10}
        result = grader._parse_grader_payload(payload)
        self.assertEqual(result['points'], 10)

    def test_parse_grader_payload_non_json_string(self):
        grader = self._make_grader()
        result = grader._parse_grader_payload('assert True')
        self.assertEqual(result['test_cases'], 'assert True')

    def test_evaluate_results_exit_code_nonzero(self):
        grader = self._make_grader()
        result = grader._evaluate_results(
            {'stdout': '', 'stderr': 'NameError', 'exit_code': 1},
            {}
        )
        self.assertFalse(result['correct'])
        self.assertEqual(result['score'], 0.0)

    def test_evaluate_results_traceback_in_stderr(self):
        grader = self._make_grader()
        result = grader._evaluate_results(
            {'stdout': '', 'stderr': 'Traceback\nTypeError', 'exit_code': 0},
            {}
        )
        self.assertFalse(result['correct'])
        self.assertEqual(result['score'], 0.0)

    def test_evaluate_results_matching_output(self):
        grader = self._make_grader()
        result = grader._evaluate_results(
            {'stdout': 'hello world', 'stderr': '', 'exit_code': 0},
            {'expected_output': 'hello world'}
        )
        self.assertTrue(result['correct'])
        self.assertEqual(result['score'], 100.0)

    def test_evaluate_results_mismatched_output(self):
        grader = self._make_grader()
        result = grader._evaluate_results(
            {'stdout': 'wrong', 'stderr': '', 'exit_code': 0},
            {'expected_output': 'expected'}
        )
        self.assertFalse(result['correct'])

    def test_evaluate_results_ok_in_stdout(self):
        grader = self._make_grader()
        result = grader._evaluate_results(
            {'stdout': 'Test OK', 'stderr': '', 'exit_code': 0},
            {}
        )
        self.assertTrue(result['correct'])
        self.assertEqual(result['score'], 100.0)

    def test_evaluate_results_failed_in_stdout(self):
        grader = self._make_grader()
        result = grader._evaluate_results(
            {'stdout': 'FAILED: test_case_1', 'stderr': '', 'exit_code': 0},
            {}
        )
        self.assertFalse(result['correct'])

    def test_evaluate_results_default_partial_credit(self):
        grader = self._make_grader()
        result = grader._evaluate_results(
            {'stdout': 'some output', 'stderr': '', 'exit_code': 0},
            {}
        )
        self.assertTrue(result['correct'])
        self.assertEqual(result['score'], 50.0)


# ---------------------------------------------------------------------------
# 10. process_xqueue_submission (module-level function)
# ---------------------------------------------------------------------------

class TestProcessXqueueSubmission(unittest.TestCase):

    def test_returns_json_string_on_parse_error(self):
        import json
        from openedx_xqueue_graders.grader import process_xqueue_submission
        result = process_xqueue_submission('not valid json')
        data = json.loads(result)
        self.assertFalse(data['correct'])
        self.assertEqual(data['score'], 0.0)
        self.assertIn('error', data['msg'].lower())


# ---------------------------------------------------------------------------
# 11. Metrics – module-level names exist
# ---------------------------------------------------------------------------

class TestMetricsModuleNames(unittest.TestCase):

    def test_xqueue_grading_total_exists(self):
        import openedx_xqueue_graders.metrics as m
        self.assertTrue(hasattr(m, 'xqueue_grading_total'))

    def test_xqueue_grading_duration_exists(self):
        import openedx_xqueue_graders.metrics as m
        self.assertTrue(hasattr(m, 'xqueue_grading_duration_seconds'))

    def test_xqueue_queue_depth_exists(self):
        import openedx_xqueue_graders.metrics as m
        self.assertTrue(hasattr(m, 'xqueue_queue_depth'))

    def test_xqueue_active_workers_exists(self):
        import openedx_xqueue_graders.metrics as m
        self.assertTrue(hasattr(m, 'xqueue_active_workers'))

    def test_xqueue_sandbox_violations_total_exists(self):
        import openedx_xqueue_graders.metrics as m
        self.assertTrue(hasattr(m, 'xqueue_sandbox_violations_total'))

    def test_xqueue_cached_results_total_exists(self):
        import openedx_xqueue_graders.metrics as m
        self.assertTrue(hasattr(m, 'xqueue_cached_results_total'))

    def test_update_queue_metrics_callable(self):
        import openedx_xqueue_graders.metrics as m
        self.assertTrue(callable(m.update_queue_metrics))

    def test_update_worker_count_callable(self):
        import openedx_xqueue_graders.metrics as m
        self.assertTrue(callable(m.update_worker_count))


# ---------------------------------------------------------------------------
# 12. Admin registration
# ---------------------------------------------------------------------------

class TestAdminRegistration(unittest.TestCase):

    def test_grader_submission_admin_exists(self):
        from openedx_xqueue_graders.admin import GraderSubmissionAdmin
        self.assertTrue(hasattr(GraderSubmissionAdmin, 'list_display'))

    def test_grader_queue_metrics_admin_exists(self):
        from openedx_xqueue_graders.admin import GraderQueueMetricsAdmin
        self.assertTrue(hasattr(GraderQueueMetricsAdmin, 'list_display'))

    def test_grader_submission_admin_list_display_contains_status(self):
        from openedx_xqueue_graders.admin import GraderSubmissionAdmin
        self.assertIn('status_badge', GraderSubmissionAdmin.list_display)

    def test_grader_submission_admin_search_fields(self):
        from openedx_xqueue_graders.admin import GraderSubmissionAdmin
        self.assertIn('submission_id', GraderSubmissionAdmin.search_fields)


if __name__ == '__main__':
    unittest.main()
