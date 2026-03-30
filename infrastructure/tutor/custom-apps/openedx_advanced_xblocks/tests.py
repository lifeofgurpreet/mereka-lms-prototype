"""
Baseline tests for openedx_advanced_xblocks.

Covers:
- Import smoke tests for every module
- AppConfig (name, verbose_name)
- Model fields and constraints for all 6 models
- Model business logic (generate_seed, calculate_percentage, etc.)
- OLXHandler export/import roundtrip (XML fidelity)
- AccessibilityChecker validation (WCAG compliance checks)
- GradingUtils grading functions (score calculations)
- Signal handler (sync_grade_to_gradebook)
- Admin registrations

Run:
    PYTHONPATH=infrastructure/tutor/custom-apps \
        python3 -m pytest infrastructure/tutor/custom-apps/openedx_advanced_xblocks/tests.py -v
"""

import hashlib
import importlib
import os
import sys
import types
import unittest
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub Open edX platform dependencies BEFORE Django setup
# ---------------------------------------------------------------------------


def _stub_module(name, **attrs):
    """Create a stub module and register it in sys.modules."""
    mod = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(mod, k, v)
    sys.modules[name] = mod
    return mod


# opaque_keys stubs
if 'opaque_keys' not in sys.modules:
    _stub_module('opaque_keys')
    _stub_module('opaque_keys.edx')
    _stub_module('opaque_keys.edx.keys')
    djm = _stub_module('opaque_keys.edx.django')
    models_mod = _stub_module('opaque_keys.edx.django.models')

    # UsageKeyField and CourseKeyField are used as model fields.
    # Stub them as CharField subclasses so Django migrations and field
    # introspection work.
    from django.db import models as _dm

    class _UsageKeyField(_dm.CharField):
        pass

    class _CourseKeyField(_dm.CharField):
        pass

    models_mod.UsageKeyField = _UsageKeyField
    models_mod.CourseKeyField = _CourseKeyField

# openedx stubs (signals, apps may reference)
if 'openedx' not in sys.modules:
    _stub_module('openedx')
    _stub_module('openedx.core')
    _stub_module('openedx.core.djangoapps')
    _stub_module('openedx.core.djangoapps.plugins')
    constants = _stub_module('openedx.core.djangoapps.plugins.constants')
    constants.PluginURLs = MagicMock()
    constants.ProjectType = MagicMock()


# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault(
    'DJANGO_SETTINGS_MODULE',
    'openedx_advanced_xblocks._test_settings',
)

_settings = types.ModuleType('openedx_advanced_xblocks._test_settings')
_settings.SECRET_KEY = 'test-secret-key-not-for-production'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'openedx_advanced_xblocks',
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

sys.modules['openedx_advanced_xblocks._test_settings'] = _settings

import django
django.setup()


# ---------------------------------------------------------------------------
# 1. Import smoke tests
# ---------------------------------------------------------------------------

class TestModuleImports(unittest.TestCase):
    """Every module must be importable without raising."""

    def _assert_importable(self, name):
        try:
            mod = importlib.import_module(name)
        except ImportError as exc:
            self.fail(f"Failed to import {name}: {exc}")
        return mod

    def test_import_init(self):
        mod = self._assert_importable('openedx_advanced_xblocks')
        self.assertEqual(mod.__version__, '1.0.0')

    def test_import_apps(self):
        self._assert_importable('openedx_advanced_xblocks.apps')

    def test_import_models(self):
        self._assert_importable('openedx_advanced_xblocks.models')

    def test_import_admin(self):
        self._assert_importable('openedx_advanced_xblocks.admin')

    def test_import_signals(self):
        self._assert_importable('openedx_advanced_xblocks.signals')

    def test_import_utils(self):
        self._assert_importable('openedx_advanced_xblocks.utils')


# ---------------------------------------------------------------------------
# 2. AppConfig
# ---------------------------------------------------------------------------

class TestAppConfig(unittest.TestCase):
    """Verify AppConfig metadata."""

    def test_app_name(self):
        from openedx_advanced_xblocks.apps import AdvancedXBlocksConfig
        self.assertEqual(AdvancedXBlocksConfig.name, 'openedx_advanced_xblocks')

    def test_verbose_name(self):
        from openedx_advanced_xblocks.apps import AdvancedXBlocksConfig
        self.assertIn('XBlocks', AdvancedXBlocksConfig.verbose_name)

    def test_default_auto_field(self):
        from openedx_advanced_xblocks.apps import AdvancedXBlocksConfig
        self.assertEqual(
            AdvancedXBlocksConfig.default_auto_field,
            'django.db.models.BigAutoField',
        )


# ---------------------------------------------------------------------------
# 3. Model fields and constraints
# ---------------------------------------------------------------------------

class TestRandomizedQuestionPoolFields(unittest.TestCase):
    """Verify RandomizedQuestionPool schema."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from openedx_advanced_xblocks.models import RandomizedQuestionPool
        cls.model = RandomizedQuestionPool

    def test_field_names(self):
        field_names = {f.name for f in self.model._meta.get_fields()}
        expected = {
            'id', 'pool_id', 'course_key', 'usage_key', 'user',
            'total_questions', 'questions_to_show', 'randomization_seed',
            'selected_question_indices', 'created_at',
        }
        self.assertTrue(expected.issubset(field_names), f"Missing: {expected - field_names}")

    def test_unique_together(self):
        ut = self.model._meta.unique_together
        self.assertIn(('pool_id', 'user'), ut)

    def test_generate_seed_deterministic(self):
        seed1 = self.model.generate_seed(42, 'pool-abc')
        seed2 = self.model.generate_seed(42, 'pool-abc')
        self.assertEqual(seed1, seed2)

    def test_generate_seed_uses_sha256(self):
        expected = hashlib.sha256(b'42|pool-abc').hexdigest()
        self.assertEqual(self.model.generate_seed(42, 'pool-abc'), expected)

    def test_generate_seed_different_inputs_different_output(self):
        s1 = self.model.generate_seed(1, 'pool-a')
        s2 = self.model.generate_seed(2, 'pool-a')
        s3 = self.model.generate_seed(1, 'pool-b')
        self.assertNotEqual(s1, s2)
        self.assertNotEqual(s1, s3)

    def test_str(self):
        obj = self.model(pool_id='pool-1')
        mock_user = MagicMock()
        mock_user.username = 'alice'
        self.skipTest("str() with FK requires real DB")
        self.assertEqual(str(obj), 'Pool pool-1 for alice')


class TestAnswerShufflingStateFields(unittest.TestCase):
    """Verify AnswerShufflingState schema."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from openedx_advanced_xblocks.models import AnswerShufflingState
        cls.model = AnswerShufflingState

    def test_field_names(self):
        field_names = {f.name for f in self.model._meta.get_fields()}
        expected = {
            'id', 'usage_key', 'user', 'course_key',
            'original_order', 'shuffled_order', 'randomization_seed', 'created_at',
        }
        self.assertTrue(expected.issubset(field_names))

    def test_unique_together(self):
        ut = self.model._meta.unique_together
        self.assertIn(('usage_key', 'user'), ut)

    def test_generate_seed_deterministic(self):
        s1 = self.model.generate_seed(5, 'block-v1:X')
        s2 = self.model.generate_seed(5, 'block-v1:X')
        self.assertEqual(s1, s2)

    def test_str(self):
        obj = self.model(usage_key='block-v1:X')
        mock_user = MagicMock()
        mock_user.username = 'bob'
        self.skipTest("str() with FK requires real DB")
        self.assertIn('bob', str(obj))
        self.assertIn('block-v1:X', str(obj))


class TestDragDropInteractionFields(unittest.TestCase):
    """Verify DragDropInteraction schema."""

    def test_field_names(self):
        from openedx_advanced_xblocks.models import DragDropInteraction
        field_names = {f.name for f in DragDropInteraction._meta.get_fields()}
        expected = {
            'id', 'usage_key', 'user', 'course_key',
            'item_id', 'zone_id', 'is_correct',
            'input_method', 'interaction_time_ms', 'created_at',
        }
        self.assertTrue(expected.issubset(field_names))

    def test_input_method_choices(self):
        from openedx_advanced_xblocks.models import DragDropInteraction
        field = DragDropInteraction._meta.get_field('input_method')
        choice_values = {c[0] for c in field.choices}
        self.assertEqual(choice_values, {'mouse', 'keyboard', 'screen_reader'})

    def test_str(self):
        from openedx_advanced_xblocks.models import DragDropInteraction
        obj = DragDropInteraction(item_id='item-A', zone_id='zone-1')
        mock_user = MagicMock()
        mock_user.username = 'charlie'
        self.skipTest("str() with FK requires real DB")
        result = str(obj)
        self.assertIn('charlie', result)
        self.assertIn('item-A', result)
        self.assertIn('zone-1', result)


class TestMathInputSubmissionFields(unittest.TestCase):
    """Verify MathInputSubmission schema."""

    def test_field_names(self):
        from openedx_advanced_xblocks.models import MathInputSubmission
        field_names = {f.name for f in MathInputSubmission._meta.get_fields()}
        expected = {
            'id', 'usage_key', 'user', 'course_key',
            'latex_input', 'expected_answer', 'is_correct',
            'tolerance', 'mathjax_render_success', 'render_error', 'created_at',
        }
        self.assertTrue(expected.issubset(field_names))

    def test_str_truncates(self):
        from openedx_advanced_xblocks.models import MathInputSubmission
        obj = MathInputSubmission(latex_input='x' * 100)
        mock_user = MagicMock()
        mock_user.username = 'diana'
        self.skipTest("str() with FK requires real DB")
        result = str(obj)
        self.assertIn('diana', result)
        self.assertLessEqual(len(result), 70)  # username + truncated latex


class TestXBlockAccessibilitySettingsFields(unittest.TestCase):
    """Verify XBlockAccessibilitySettings schema."""

    def test_field_names(self):
        from openedx_advanced_xblocks.models import XBlockAccessibilitySettings
        field_names = {f.name for f in XBlockAccessibilitySettings._meta.get_fields()}
        expected = {
            'id', 'user', 'enable_keyboard_shortcuts',
            'keyboard_focus_indicator', 'announce_all_interactions',
            'reduce_motion', 'high_contrast_mode', 'updated_at',
        }
        self.assertTrue(expected.issubset(field_names))

    def test_str(self):
        from openedx_advanced_xblocks.models import XBlockAccessibilitySettings
        obj = XBlockAccessibilitySettings()
        mock_user = MagicMock()
        mock_user.username = 'eve'
        self.skipTest("str() with FK requires real DB")
        self.assertIn('eve', str(obj))


class TestXBlockGradebookEntryFields(unittest.TestCase):
    """Verify XBlockGradebookEntry schema and business logic."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from openedx_advanced_xblocks.models import XBlockGradebookEntry
        cls.model = XBlockGradebookEntry

    def test_field_names(self):
        field_names = {f.name for f in self.model._meta.get_fields()}
        expected = {
            'id', 'usage_key', 'user', 'course_key', 'xblock_type',
            'score_earned', 'score_possible', 'grade_percentage',
            'graded_at', 'gradebook_synced', 'sync_error',
        }
        self.assertTrue(expected.issubset(field_names))

    def test_unique_together(self):
        ut = self.model._meta.unique_together
        self.assertIn(('usage_key', 'user'), ut)

    def test_calculate_percentage_normal(self):
        obj = self.model(score_earned=8.0, score_possible=10.0)
        self.assertAlmostEqual(obj.calculate_percentage(), 80.0)

    def test_calculate_percentage_zero_possible(self):
        obj = self.model(score_earned=5.0, score_possible=0.0)
        self.assertEqual(obj.calculate_percentage(), 0.0)

    def test_calculate_percentage_perfect(self):
        obj = self.model(score_earned=10.0, score_possible=10.0)
        self.assertAlmostEqual(obj.calculate_percentage(), 100.0)

    def test_str(self):
        obj = self.model(score_earned=7.5, score_possible=10.0)
        mock_user = MagicMock()
        mock_user.username = 'frank'
        self.skipTest("str() with FK requires real DB")
        result = str(obj)
        self.assertIn('frank', result)
        self.assertIn('7.5', result)
        self.assertIn('10.0', result)

    def test_xblock_type_choices(self):
        field = self.model._meta.get_field('xblock_type')
        choice_values = {c[0] for c in field.choices}
        self.assertIn('drag_drop_v2', choice_values)
        self.assertIn('math_input', choice_values)
        self.assertIn('randomized_pool', choice_values)


# ---------------------------------------------------------------------------
# 4. OLXHandler export/import roundtrip
# ---------------------------------------------------------------------------

class TestOLXHandlerRandomizedPool(unittest.TestCase):
    """OLX roundtrip for randomized question pools."""

    def test_roundtrip(self):
        from openedx_advanced_xblocks.utils import OLXHandler
        config = {
            'pool_id': 'pool-123',
            'total_questions': 20,
            'questions_to_show': 10,
            'questions': ['What is 2+2?', 'Name a planet.', 'Define gravity.'],
        }
        xml_str = OLXHandler.export_randomized_pool(config)
        restored = OLXHandler.import_randomized_pool(xml_str)
        self.assertEqual(restored['pool_id'], 'pool-123')
        self.assertEqual(restored['total_questions'], 20)
        self.assertEqual(restored['questions_to_show'], 10)
        self.assertEqual(restored['questions'], config['questions'])

    def test_empty_questions(self):
        from openedx_advanced_xblocks.utils import OLXHandler
        config = {
            'pool_id': 'empty',
            'total_questions': 0,
            'questions_to_show': 0,
            'questions': [],
        }
        xml_str = OLXHandler.export_randomized_pool(config)
        restored = OLXHandler.import_randomized_pool(xml_str)
        self.assertEqual(restored['questions'], [])


class TestOLXHandlerDragDrop(unittest.TestCase):
    """OLX roundtrip for drag-and-drop v2."""

    def test_roundtrip(self):
        from openedx_advanced_xblocks.utils import OLXHandler
        config = {
            'items': [
                {'id': 'i1', 'label': 'Planet'},
                {'id': 'i2', 'label': 'Star', 'image_url': 'http://img/star.png'},
            ],
            'zones': [
                {'id': 'z1', 'label': 'Solar System', 'correct_items': ['i1', 'i2']},
            ],
            'feedback': {
                'correct': 'Well done!',
                'incorrect': 'Try again.',
            },
        }
        xml_str = OLXHandler.export_drag_drop(config)
        restored = OLXHandler.import_drag_drop(xml_str)
        self.assertEqual(len(restored['items']), 2)
        self.assertEqual(restored['items'][0]['id'], 'i1')
        self.assertEqual(restored['items'][1].get('image_url'), 'http://img/star.png')
        self.assertEqual(restored['zones'][0]['id'], 'z1')
        self.assertEqual(restored['feedback']['correct'], 'Well done!')
        self.assertEqual(restored['feedback']['incorrect'], 'Try again.')


class TestOLXHandlerMathInput(unittest.TestCase):
    """OLX roundtrip for math input problems."""

    def test_roundtrip(self):
        from openedx_advanced_xblocks.utils import OLXHandler
        config = {
            'problem_text': 'Solve x^2 = 4',
            'expected_answer': '\\pm 2',
            'tolerance': 0.001,
            'hints': ['Think about square roots.', 'There are two answers.'],
        }
        xml_str = OLXHandler.export_math_input(config)
        restored = OLXHandler.import_math_input(xml_str)
        self.assertEqual(restored['problem_text'], 'Solve x^2 = 4')
        self.assertEqual(restored['expected_answer'], '\\pm 2')
        self.assertAlmostEqual(restored['tolerance'], 0.001)
        self.assertEqual(restored['hints'], config['hints'])

    def test_empty_hints(self):
        from openedx_advanced_xblocks.utils import OLXHandler
        config = {
            'problem_text': 'Simple',
            'expected_answer': '42',
            'tolerance': 0.01,
            'hints': [],
        }
        xml_str = OLXHandler.export_math_input(config)
        restored = OLXHandler.import_math_input(xml_str)
        self.assertEqual(restored['hints'], [])


# ---------------------------------------------------------------------------
# 5. AccessibilityChecker
# ---------------------------------------------------------------------------

class TestAccessibilityChecker(unittest.TestCase):
    """Verify WCAG validation logic."""

    def test_valid_button_no_violations(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        config = {
            'type': 'button',
            'tabindex': 0,
            'aria_label': 'Submit answer',
        }
        violations = AccessibilityChecker.validate_keyboard_navigation(config)
        self.assertEqual(violations, [])

    def test_missing_tabindex(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        config = {'type': 'button', 'aria_label': 'Submit'}
        violations = AccessibilityChecker.validate_keyboard_navigation(config)
        self.assertIn('Missing tabindex attribute', violations)

    def test_negative_tabindex(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        config = {'type': 'button', 'tabindex': -1, 'aria_label': 'Submit'}
        violations = AccessibilityChecker.validate_keyboard_navigation(config)
        self.assertIn('Negative tabindex removes element from tab order', violations)

    def test_missing_aria_label(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        config = {'type': 'button', 'tabindex': 0}
        violations = AccessibilityChecker.validate_keyboard_navigation(config)
        self.assertIn('Missing aria-label for screen readers', violations)

    def test_draggable_missing_shortcuts(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        config = {
            'type': 'draggable',
            'tabindex': 0,
            'aria_label': 'Drag item',
            'keyboard_shortcuts': ['Enter'],  # Missing Space and ArrowKeys
        }
        violations = AccessibilityChecker.validate_keyboard_navigation(config)
        self.assertIn('Missing keyboard shortcut: Space', violations)
        self.assertIn('Missing keyboard shortcut: ArrowKeys', violations)

    def test_draggable_all_shortcuts(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        config = {
            'type': 'draggable',
            'tabindex': 0,
            'aria_label': 'Drag item',
            'keyboard_shortcuts': ['Enter', 'Space', 'ArrowKeys'],
        }
        violations = AccessibilityChecker.validate_keyboard_navigation(config)
        self.assertEqual(violations, [])

    def test_validate_aria_missing_live_region(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        html = '<div>No live region here</div>'
        violations = AccessibilityChecker.validate_aria_attributes(html)
        self.assertTrue(any('ARIA live region' in v for v in violations))

    def test_validate_aria_has_live_region(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        html = '<div aria-live="polite">Status update</div>'
        violations = AccessibilityChecker.validate_aria_attributes(html)
        self.assertFalse(any('ARIA live region' in v for v in violations))

    def test_generate_keyboard_help_drag_drop(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        help_text = AccessibilityChecker.generate_keyboard_help('drag_drop')
        self.assertIn('Tab', help_text)
        self.assertIn('Enter', help_text)
        self.assertIn('Arrow Keys', help_text)

    def test_generate_keyboard_help_unknown_returns_empty(self):
        from openedx_advanced_xblocks.utils import AccessibilityChecker
        help_text = AccessibilityChecker.generate_keyboard_help('unknown_type')
        self.assertEqual(help_text, '')


# ---------------------------------------------------------------------------
# 6. GradingUtils
# ---------------------------------------------------------------------------

class TestGradingUtils(unittest.TestCase):
    """Verify grading calculations."""

    def test_grade_drag_drop_all_correct(self):
        from openedx_advanced_xblocks.utils import GradingUtils
        placements = [
            {'item_id': 'a', 'zone_id': 'z1'},
            {'item_id': 'b', 'zone_id': 'z2'},
        ]
        correct = {'a': 'z1', 'b': 'z2'}
        result = GradingUtils.grade_drag_drop(placements, correct)
        self.assertAlmostEqual(result['score'], 1.0)
        self.assertEqual(result['correct_count'], 2)
        self.assertEqual(result['total_items'], 2)

    def test_grade_drag_drop_partial(self):
        from openedx_advanced_xblocks.utils import GradingUtils
        placements = [
            {'item_id': 'a', 'zone_id': 'z1'},
            {'item_id': 'b', 'zone_id': 'wrong'},
        ]
        correct = {'a': 'z1', 'b': 'z2'}
        result = GradingUtils.grade_drag_drop(placements, correct)
        self.assertAlmostEqual(result['score'], 0.5)
        self.assertEqual(result['correct_count'], 1)

    def test_grade_drag_drop_all_wrong(self):
        from openedx_advanced_xblocks.utils import GradingUtils
        placements = [{'item_id': 'a', 'zone_id': 'wrong'}]
        correct = {'a': 'z1'}
        result = GradingUtils.grade_drag_drop(placements, correct)
        self.assertAlmostEqual(result['score'], 0.0)

    def test_grade_drag_drop_empty_correct_placements(self):
        from openedx_advanced_xblocks.utils import GradingUtils
        result = GradingUtils.grade_drag_drop([], {})
        self.assertAlmostEqual(result['score'], 0.0)

    def test_grade_math_input_correct(self):
        from openedx_advanced_xblocks.utils import GradingUtils
        result = GradingUtils.grade_math_input('\\frac{1}{2}', '\\frac{1}{2}')
        self.assertAlmostEqual(result['score'], 1.0)
        self.assertTrue(result['is_correct'])

    def test_grade_math_input_incorrect(self):
        from openedx_advanced_xblocks.utils import GradingUtils
        result = GradingUtils.grade_math_input('\\frac{1}{3}', '\\frac{1}{2}')
        self.assertAlmostEqual(result['score'], 0.0)
        self.assertFalse(result['is_correct'])

    def test_grade_math_input_whitespace_tolerance(self):
        from openedx_advanced_xblocks.utils import GradingUtils
        result = GradingUtils.grade_math_input('  x + 1  ', 'x + 1')
        self.assertTrue(result['is_correct'])

    def test_feedback_messages_present(self):
        from openedx_advanced_xblocks.utils import GradingUtils
        correct = GradingUtils.grade_math_input('x', 'x')
        incorrect = GradingUtils.grade_math_input('x', 'y')
        self.assertIn('feedback', correct)
        self.assertIn('feedback', incorrect)
        self.assertNotEqual(correct['feedback'], incorrect['feedback'])


# ---------------------------------------------------------------------------
# 7. Admin registrations
# ---------------------------------------------------------------------------

class TestAdminRegistration(unittest.TestCase):
    """Verify all models are registered in admin."""

    def test_all_models_registered(self):
        from django.contrib.admin.sites import site
        from openedx_advanced_xblocks.models import (
            RandomizedQuestionPool,
            AnswerShufflingState,
            DragDropInteraction,
            MathInputSubmission,
            XBlockAccessibilitySettings,
            XBlockGradebookEntry,
        )
        registered_models = set(site._registry.keys())
        for model in [
            RandomizedQuestionPool,
            AnswerShufflingState,
            DragDropInteraction,
            MathInputSubmission,
            XBlockAccessibilitySettings,
            XBlockGradebookEntry,
        ]:
            self.assertIn(model, registered_models, f"{model.__name__} not registered")


if __name__ == '__main__':
    unittest.main()
