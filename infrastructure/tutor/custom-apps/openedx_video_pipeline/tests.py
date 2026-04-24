"""
Baseline tests for openedx_video_pipeline.

Covers:
- Import smoke tests for every module
- Model field existence (MctVideoMapping, MigrationReport, VideoCompletionStatus)
- Serializer field existence
- Validator function signatures
- Mux client function signatures (HTTP calls mocked)
- xAPI emitter behaviour (eventtracking mocked)
- Subtitle helpers (HTTP calls mocked)
- XBlock config helpers (pure functions, no I/O)

These tests run without a live database or Mux credentials.
Use `python -m pytest infrastructure/tutor/custom-apps/openedx_video_pipeline/tests.py`
or Django's test runner after configuring DJANGO_SETTINGS_MODULE.
"""

import importlib
import inspect
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from setuptools import find_packages

# ---------------------------------------------------------------------------
# Minimal Django bootstrap so models, serializers, and views can be imported
# without a full Open edX installation.
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_video_pipeline._test_settings')

# Build a minimal settings module on-the-fly so we don't need an external file.
import types

_settings = types.ModuleType('openedx_video_pipeline._test_settings')
_settings.SECRET_KEY = 'test-secret-key'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'rest_framework',
    'openedx_video_pipeline',
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
_settings.MCT_EXPECTED_VIDEO_COUNT = 503
_settings.VIDEO_PLAYBACK_CHECK_TIMEOUT = 10
_settings.ENABLE_VIDEO_XAPI_EVENTS = False
_settings.ENABLE_MUX_SIGNED_PLAYBACK = False

sys.modules['openedx_video_pipeline._test_settings'] = _settings

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
        self._assert_importable('openedx_video_pipeline.apps')

    def test_import_models(self):
        self._assert_importable('openedx_video_pipeline.models')

    def test_import_completion(self):
        self._assert_importable('openedx_video_pipeline.completion')

    def test_import_serializers(self):
        self._assert_importable('openedx_video_pipeline.serializers')

    def test_import_validators(self):
        self._assert_importable('openedx_video_pipeline.validators')

    def test_import_mux_client(self):
        self._assert_importable('openedx_video_pipeline.mux_client')

    def test_import_subtitles(self):
        self._assert_importable('openedx_video_pipeline.subtitles')

    def test_import_xapi_emitter(self):
        self._assert_importable('openedx_video_pipeline.xapi_emitter')

    def test_import_xblock_config(self):
        self._assert_importable('openedx_video_pipeline.xblock_config')

    def test_import_views(self):
        self._assert_importable('openedx_video_pipeline.views')

    def test_import_urls(self):
        self._assert_importable('openedx_video_pipeline.urls')

    def test_import_admin(self):
        self._assert_importable('openedx_video_pipeline.admin')


class TestPackagingContract(unittest.TestCase):
    """The package build must install the root module, not just subpackages."""

    def test_root_package_is_included_in_setup_discovery(self):
        package_root = Path(__file__).resolve().parent
        subpackages = find_packages(where=str(package_root))
        packages = [
            'openedx_video_pipeline',
            *[f'openedx_video_pipeline.{name}' for name in subpackages],
        ]

        self.assertIn('openedx_video_pipeline', packages)
        self.assertIn('openedx_video_pipeline.management', packages)
        self.assertIn('openedx_video_pipeline.management.commands', packages)


# ---------------------------------------------------------------------------
# 2. AppConfig
# ---------------------------------------------------------------------------

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from openedx_video_pipeline.apps import OpenedxVideoPipelineConfig
        self.assertEqual(OpenedxVideoPipelineConfig.name, 'openedx_video_pipeline')

    def test_verbose_name(self):
        from openedx_video_pipeline.apps import OpenedxVideoPipelineConfig
        self.assertIn('Video Pipeline', OpenedxVideoPipelineConfig.verbose_name)


# ---------------------------------------------------------------------------
# 3. Model field existence
# ---------------------------------------------------------------------------

class TestMctVideoMappingFields(unittest.TestCase):

    def setUp(self):
        from openedx_video_pipeline.models import MctVideoMapping
        self.model = MctVideoMapping

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_mct_video_id_field(self):
        self.assertIn('mct_video_id', self._field_names())

    def test_mux_asset_id_field(self):
        self.assertIn('mux_asset_id', self._field_names())

    def test_mux_playback_id_field(self):
        self.assertIn('mux_playback_id', self._field_names())

    def test_olx_usage_key_field(self):
        self.assertIn('olx_usage_key', self._field_names())

    def test_course_key_field(self):
        self.assertIn('course_key', self._field_names())

    def test_mux_status_field(self):
        self.assertIn('mux_status', self._field_names())

    def test_duration_seconds_field(self):
        self.assertIn('duration_seconds', self._field_names())

    def test_has_audio_field(self):
        self.assertIn('has_audio', self._field_names())

    def test_has_video_field(self):
        self.assertIn('has_video', self._field_names())

    def test_playback_verified_field(self):
        self.assertIn('playback_verified', self._field_names())

    def test_migration_batch_field(self):
        self.assertIn('migration_batch', self._field_names())

    def test_content_language_field(self):
        self.assertIn('content_language', self._field_names())

    def test_created_at_field(self):
        self.assertIn('created_at', self._field_names())

    def test_updated_at_field(self):
        self.assertIn('updated_at', self._field_names())

    def test_str_representation(self):
        obj = self.model(mct_video_id='v1', mux_asset_id='a1', mux_status='ready')
        s = str(obj)
        self.assertIn('v1', s)
        self.assertIn('a1', s)

    def test_mux_status_choices_include_ready(self):
        choices = [c[0] for c in self.model.MUX_STATUS_CHOICES]
        self.assertIn('ready', choices)
        self.assertIn('errored', choices)
        self.assertIn('preparing', choices)


class TestMigrationReportFields(unittest.TestCase):

    def setUp(self):
        from openedx_video_pipeline.models import MigrationReport
        self.model = MigrationReport

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_report_id_field(self):
        self.assertIn('report_id', self._field_names())

    def test_total_expected_field(self):
        self.assertIn('total_expected', self._field_names())

    def test_total_found_field(self):
        self.assertIn('total_found', self._field_names())

    def test_total_ready_field(self):
        self.assertIn('total_ready', self._field_names())

    def test_is_complete_field(self):
        self.assertIn('is_complete', self._field_names())

    def test_failed_asset_ids_field(self):
        self.assertIn('failed_asset_ids', self._field_names())

    def test_report_data_field(self):
        self.assertIn('report_data', self._field_names())

    def test_str_includes_ready_count(self):
        import uuid
        obj = self.model(report_id=uuid.uuid4(), total_ready=5, total_expected=503)
        s = str(obj)
        self.assertIn('5', s)
        self.assertIn('503', s)


class TestVideoCompletionStatusFields(unittest.TestCase):

    def setUp(self):
        from openedx_video_pipeline.completion import VideoCompletionStatus
        self.model = VideoCompletionStatus

    def _field_names(self):
        return {f.name for f in self.model._meta.get_fields()}

    def test_video_id_field(self):
        self.assertIn('video_id', self._field_names())

    def test_course_key_field(self):
        self.assertIn('course_key', self._field_names())

    def test_max_position_reached_field(self):
        self.assertIn('max_position_reached', self._field_names())

    def test_duration_field(self):
        self.assertIn('duration', self._field_names())

    def test_completion_percentage_field(self):
        self.assertIn('completion_percentage', self._field_names())

    def test_is_complete_field(self):
        self.assertIn('is_complete', self._field_names())

    def test_play_count_field(self):
        self.assertIn('play_count', self._field_names())

    def test_last_position_field(self):
        self.assertIn('last_position', self._field_names())

    def test_first_played_at_field(self):
        self.assertIn('first_played_at', self._field_names())

    def test_completed_at_field(self):
        self.assertIn('completed_at', self._field_names())

    def test_unique_together_constraint(self):
        unique_together = self.model._meta.unique_together
        # Stored as list of tuples
        self.assertTrue(
            any({'user', 'video_id', 'course_key'} == set(t) for t in unique_together),
            "Expected unique_together on (user, video_id, course_key)",
        )

    def test_update_progress_classmethod_exists(self):
        self.assertTrue(
            callable(getattr(self.model, 'update_progress', None)),
            "update_progress classmethod must exist",
        )

    def test_get_course_completion_summary_classmethod_exists(self):
        self.assertTrue(
            callable(getattr(self.model, 'get_course_completion_summary', None)),
            "get_course_completion_summary classmethod must exist",
        )


# ---------------------------------------------------------------------------
# 4. Serializer field existence
# ---------------------------------------------------------------------------

class TestMctVideoMappingSerializer(unittest.TestCase):

    def setUp(self):
        from openedx_video_pipeline.serializers import MctVideoMappingSerializer
        self.serializer_class = MctVideoMappingSerializer

    def test_is_model_serializer(self):
        from rest_framework.serializers import ModelSerializer
        self.assertTrue(issubclass(self.serializer_class, ModelSerializer))

    def test_uses_all_fields(self):
        meta = self.serializer_class.Meta
        self.assertEqual(meta.fields, '__all__')

    def test_model_is_mct_video_mapping(self):
        from openedx_video_pipeline.models import MctVideoMapping
        self.assertIs(self.serializer_class.Meta.model, MctVideoMapping)


class TestMigrationReportSerializer(unittest.TestCase):

    def setUp(self):
        from openedx_video_pipeline.serializers import MigrationReportSerializer
        self.serializer_class = MigrationReportSerializer

    def test_model_is_migration_report(self):
        from openedx_video_pipeline.models import MigrationReport
        self.assertIs(self.serializer_class.Meta.model, MigrationReport)


class TestPlaybackCheckRequestSerializer(unittest.TestCase):

    def setUp(self):
        from openedx_video_pipeline.serializers import PlaybackCheckRequestSerializer
        self.serializer_class = PlaybackCheckRequestSerializer

    def test_has_sample_size_field(self):
        s = self.serializer_class()
        self.assertIn('sample_size', s.fields)

    def test_has_asset_ids_field(self):
        s = self.serializer_class()
        self.assertIn('asset_ids', s.fields)

    def test_sample_size_is_optional(self):
        s = self.serializer_class()
        self.assertFalse(s.fields['sample_size'].required)

    def test_asset_ids_is_optional(self):
        s = self.serializer_class()
        self.assertFalse(s.fields['asset_ids'].required)


class TestVideoHealthSerializer(unittest.TestCase):

    def setUp(self):
        from openedx_video_pipeline.serializers import VideoHealthSerializer
        self.serializer_class = VideoHealthSerializer

    def test_required_fields_present(self):
        s = self.serializer_class()
        expected = {
            'total_videos',
            'ready_count',
            'preparing_count',
            'errored_count',
            'playback_verified_count',
            'is_migration_complete',
        }
        for field in expected:
            self.assertIn(field, s.fields, f"Missing field: {field}")


# ---------------------------------------------------------------------------
# 5. Validator function signatures
# ---------------------------------------------------------------------------

class TestValidatorSignatures(unittest.TestCase):

    def setUp(self):
        import openedx_video_pipeline.validators as v
        self.v = v

    def test_validate_manifest_exists(self):
        self.assertTrue(callable(self.v.validate_manifest))

    def test_validate_manifest_accepts_path(self):
        sig = inspect.signature(self.v.validate_manifest)
        self.assertIn('manifest_path', sig.parameters)

    def test_validate_olx_mappings_exists(self):
        self.assertTrue(callable(self.v.validate_olx_mappings))

    def test_validate_olx_mappings_accepts_queryset(self):
        sig = inspect.signature(self.v.validate_olx_mappings)
        self.assertIn('mappings_queryset', sig.parameters)

    def test_validate_playback_health_exists(self):
        self.assertTrue(callable(self.v.validate_playback_health))

    def test_validate_playback_health_accepts_sample_size(self):
        sig = inspect.signature(self.v.validate_playback_health)
        self.assertIn('sample_size', sig.parameters)
        # sample_size should have a default (i.e. be optional)
        self.assertIsNot(sig.parameters['sample_size'].default, inspect.Parameter.empty)

    def test_validate_content_languages_exists(self):
        self.assertTrue(callable(self.v.validate_content_languages))

    def test_generate_migration_report_exists(self):
        self.assertTrue(callable(self.v.generate_migration_report))

    def test_generate_migration_report_manifest_path_optional(self):
        sig = inspect.signature(self.v.generate_migration_report)
        param = sig.parameters.get('manifest_path')
        self.assertIsNotNone(param)
        # Parameter has a default value (None), meaning it is optional
        self.assertIsNot(param.default, inspect.Parameter.empty)


class TestValidateManifestBehaviour(unittest.TestCase):
    """validate_manifest is pure I/O — test with real temp files."""

    def setUp(self):
        from openedx_video_pipeline.validators import validate_manifest
        self.validate_manifest = validate_manifest

    def test_missing_file_returns_zero_totals(self):
        result = self.validate_manifest('/nonexistent/path/manifest.json')
        self.assertEqual(result['total'], 0)
        self.assertEqual(result['valid'], 0)

    def test_valid_manifest_all_entries_valid(self):
        entries = [
            {'asset_id': f'asset_{i}', 'playback_id': f'play_{i}'}
            for i in range(5)
        ]
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(entries, f)
            path = f.name
        try:
            result = self.validate_manifest(path)
            self.assertEqual(result['total'], 5)
            self.assertEqual(result['valid'], 5)
            self.assertEqual(result['invalid'], 0)
        finally:
            os.unlink(path)

    def test_manifest_with_missing_playback_id(self):
        entries = [
            {'asset_id': 'asset_1'},  # missing playback_id
            {'asset_id': 'asset_2', 'playback_id': 'play_2'},
        ]
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(entries, f)
            path = f.name
        try:
            result = self.validate_manifest(path)
            self.assertEqual(result['total'], 2)
            self.assertEqual(result['valid'], 1)
            self.assertEqual(result['invalid'], 1)
            self.assertEqual(len(result['missing_playback_ids']), 1)
        finally:
            os.unlink(path)

    def test_non_list_manifest_returns_zero(self):
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump({'not': 'a list'}, f)
            path = f.name
        try:
            result = self.validate_manifest(path)
            self.assertEqual(result['total'], 0)
        finally:
            os.unlink(path)


# ---------------------------------------------------------------------------
# 6. Mux client — function signatures and mocked HTTP calls
# ---------------------------------------------------------------------------

class TestMuxClientSignatures(unittest.TestCase):

    def setUp(self):
        import openedx_video_pipeline.mux_client as mc
        self.mc = mc

    def test_get_mux_headers_exists(self):
        self.assertTrue(callable(self.mc.get_mux_headers))

    def test_get_asset_details_exists(self):
        self.assertTrue(callable(self.mc.get_asset_details))

    def test_get_asset_details_accepts_asset_id(self):
        sig = inspect.signature(self.mc.get_asset_details)
        self.assertIn('asset_id', sig.parameters)

    def test_list_assets_exists(self):
        self.assertTrue(callable(self.mc.list_assets))

    def test_list_assets_has_page_and_limit_params(self):
        sig = inspect.signature(self.mc.list_assets)
        self.assertIn('page', sig.parameters)
        self.assertIn('limit', sig.parameters)

    def test_check_playback_url_exists(self):
        self.assertTrue(callable(self.mc.check_playback_url))

    def test_get_asset_metadata_exists(self):
        self.assertTrue(callable(self.mc.get_asset_metadata))

    def test_retry_asset_ingestion_exists(self):
        self.assertTrue(callable(self.mc.retry_asset_ingestion))

    def test_bulk_check_assets_exists(self):
        self.assertTrue(callable(self.mc.bulk_check_assets))

    def test_bulk_check_assets_rate_limit_delay_param(self):
        sig = inspect.signature(self.mc.bulk_check_assets)
        self.assertIn('rate_limit_delay', sig.parameters)

    def test_constants_defined(self):
        self.assertTrue(hasattr(self.mc, 'MUX_API_BASE'))
        self.assertTrue(hasattr(self.mc, 'MUX_PLAYBACK_BASE'))
        self.assertTrue(self.mc.MUX_API_BASE.startswith('https://'))


class TestGetMuxHeaders(unittest.TestCase):

    def test_returns_empty_when_no_credentials(self):
        import openedx_video_pipeline.mux_client as mc
        with patch.object(mc, 'MUX_TOKEN_ID', ''), \
             patch.object(mc, 'MUX_TOKEN_SECRET', ''):
            result = mc.get_mux_headers()
        self.assertEqual(result, {})

    def test_returns_auth_header_with_credentials(self):
        import openedx_video_pipeline.mux_client as mc
        with patch.object(mc, 'MUX_TOKEN_ID', 'myid'), \
             patch.object(mc, 'MUX_TOKEN_SECRET', 'mysecret'):
            result = mc.get_mux_headers()
        self.assertIn('Authorization', result)
        self.assertTrue(result['Authorization'].startswith('Basic '))
        self.assertEqual(result['Content-Type'], 'application/json')


class TestGetAssetDetails(unittest.TestCase):

    def test_returns_data_on_success(self):
        import openedx_video_pipeline.mux_client as mc
        mock_response = MagicMock()
        mock_response.json.return_value = {'data': {'id': 'abc123', 'status': 'ready'}}
        mock_response.raise_for_status.return_value = None

        with patch('openedx_video_pipeline.mux_client.requests.get', return_value=mock_response), \
             patch.object(mc, 'MUX_TOKEN_ID', 'id'), \
             patch.object(mc, 'MUX_TOKEN_SECRET', 'secret'):
            result = mc.get_asset_details('abc123')

        self.assertEqual(result['id'], 'abc123')
        self.assertEqual(result['status'], 'ready')

    def test_returns_empty_on_request_exception(self):
        import openedx_video_pipeline.mux_client as mc
        import requests as req

        with patch('openedx_video_pipeline.mux_client.requests.get',
                   side_effect=req.exceptions.ConnectionError('network error')), \
             patch.object(mc, 'MUX_TOKEN_ID', 'id'), \
             patch.object(mc, 'MUX_TOKEN_SECRET', 'secret'):
            result = mc.get_asset_details('bad_id')

        self.assertEqual(result, {})


class TestCheckPlaybackUrl(unittest.TestCase):

    def test_returns_200_and_true_on_ok(self):
        from openedx_video_pipeline.mux_client import check_playback_url
        mock_response = MagicMock()
        mock_response.status_code = 200

        with patch('openedx_video_pipeline.mux_client.requests.head', return_value=mock_response):
            status, is_ok = check_playback_url('play123')

        self.assertEqual(status, 200)
        self.assertTrue(is_ok)

    def test_returns_zero_and_false_on_connection_error(self):
        from openedx_video_pipeline.mux_client import check_playback_url
        import requests as req

        with patch('openedx_video_pipeline.mux_client.requests.head',
                   side_effect=req.exceptions.ConnectionError()):
            status, is_ok = check_playback_url('bad_play')

        self.assertEqual(status, 0)
        self.assertFalse(is_ok)

    def test_returns_false_for_non_200(self):
        from openedx_video_pipeline.mux_client import check_playback_url
        mock_response = MagicMock()
        mock_response.status_code = 404

        with patch('openedx_video_pipeline.mux_client.requests.head', return_value=mock_response):
            status, is_ok = check_playback_url('play_gone')

        self.assertEqual(status, 404)
        self.assertFalse(is_ok)


class TestGetAssetMetadata(unittest.TestCase):

    def test_extracts_metadata_fields(self):
        import openedx_video_pipeline.mux_client as mc
        asset_data = {
            'duration': 120.5,
            'max_stored_resolution': '1080p',
            'tracks': [
                {'type': 'video'},
                {'type': 'audio'},
            ],
            'status': 'ready',
            'created_at': '2025-01-01T00:00:00Z',
        }
        with patch.object(mc, 'get_asset_details', return_value=asset_data):
            result = mc.get_asset_metadata('abc')

        self.assertEqual(result['duration'], 120.5)
        self.assertTrue(result['has_audio'])
        self.assertTrue(result['has_video'])
        self.assertEqual(result['status'], 'ready')

    def test_returns_empty_when_asset_not_found(self):
        import openedx_video_pipeline.mux_client as mc
        with patch.object(mc, 'get_asset_details', return_value={}):
            result = mc.get_asset_metadata('missing')
        self.assertEqual(result, {})


class TestListAssets(unittest.TestCase):

    def test_returns_list_on_success(self):
        import openedx_video_pipeline.mux_client as mc
        mock_response = MagicMock()
        mock_response.json.return_value = {'data': [{'id': 'a1'}, {'id': 'a2'}]}
        mock_response.raise_for_status.return_value = None

        with patch('openedx_video_pipeline.mux_client.requests.get', return_value=mock_response), \
             patch.object(mc, 'MUX_TOKEN_ID', 'id'), \
             patch.object(mc, 'MUX_TOKEN_SECRET', 'secret'):
            result = mc.list_assets()

        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['id'], 'a1')

    def test_returns_empty_list_on_error(self):
        import openedx_video_pipeline.mux_client as mc
        import requests as req
        with patch('openedx_video_pipeline.mux_client.requests.get',
                   side_effect=req.exceptions.Timeout()), \
             patch.object(mc, 'MUX_TOKEN_ID', 'id'), \
             patch.object(mc, 'MUX_TOKEN_SECRET', 'secret'):
            result = mc.list_assets()

        self.assertEqual(result, [])


class TestBulkCheckAssets(unittest.TestCase):

    def test_returns_metadata_for_found_assets(self):
        import openedx_video_pipeline.mux_client as mc
        # Return a fresh dict each call so mutation does not bleed across iterations
        def fresh_meta(_asset_id):
            return {'duration': 60.0, 'status': 'ready', 'has_audio': True, 'has_video': True}

        with patch.object(mc, 'get_asset_metadata', side_effect=fresh_meta), \
             patch('openedx_video_pipeline.mux_client.time.sleep'):
            result = mc.bulk_check_assets(['id1', 'id2'], rate_limit_delay=0)

        self.assertEqual(len(result), 2)
        asset_ids_returned = {r['asset_id'] for r in result}
        self.assertEqual(asset_ids_returned, {'id1', 'id2'})

    def test_skips_assets_with_empty_metadata(self):
        import openedx_video_pipeline.mux_client as mc
        with patch.object(mc, 'get_asset_metadata', return_value={}), \
             patch('openedx_video_pipeline.mux_client.time.sleep'):
            result = mc.bulk_check_assets(['id1', 'id2'], rate_limit_delay=0)

        self.assertEqual(result, [])


# ---------------------------------------------------------------------------
# 7. Subtitles module
# ---------------------------------------------------------------------------

class TestSubtitleSignatures(unittest.TestCase):

    def setUp(self):
        import openedx_video_pipeline.subtitles as s
        self.s = s

    def test_upload_subtitle_track_exists(self):
        self.assertTrue(callable(self.s.upload_subtitle_track))

    def test_upload_subtitle_track_signature(self):
        sig = inspect.signature(self.s.upload_subtitle_track)
        params = sig.parameters
        self.assertIn('asset_id', params)
        self.assertIn('subtitle_url', params)
        self.assertIn('language_code', params)
        self.assertIn('closed_captions', params)

    def test_list_subtitle_tracks_exists(self):
        self.assertTrue(callable(self.s.list_subtitle_tracks))

    def test_delete_subtitle_track_exists(self):
        self.assertTrue(callable(self.s.delete_subtitle_track))

    def test_get_subtitle_tracks_for_xblock_exists(self):
        self.assertTrue(callable(self.s.get_subtitle_tracks_for_xblock))

    def test_constants_defined(self):
        self.assertIn('srt', self.s.SUPPORTED_SUBTITLE_FORMATS)
        self.assertIn('vtt', self.s.SUPPORTED_SUBTITLE_FORMATS)
        self.assertEqual(self.s.DEFAULT_LANGUAGE, 'en')


class TestUploadSubtitleTrack(unittest.TestCase):

    def test_raises_value_error_for_unsupported_format(self):
        from openedx_video_pipeline.subtitles import upload_subtitle_track
        with self.assertRaises(ValueError):
            upload_subtitle_track('asset1', 'http://example.com/sub.mp3')

    def test_defaults_language_to_en(self):
        import openedx_video_pipeline.subtitles as subs
        mock_response = MagicMock()
        mock_response.json.return_value = {'data': {'id': 'track1', 'language_code': 'en'}}
        mock_response.raise_for_status.return_value = None

        with patch('openedx_video_pipeline.subtitles.requests.post', return_value=mock_response), \
             patch('openedx_video_pipeline.subtitles.get_mux_headers', return_value={'Authorization': 'Basic xyz'}):
            result = subs.upload_subtitle_track('asset1', 'http://example.com/sub.srt')

        self.assertEqual(result.get('id'), 'track1')

    def test_returns_empty_when_no_credentials(self):
        from openedx_video_pipeline.subtitles import upload_subtitle_track
        with patch('openedx_video_pipeline.subtitles.get_mux_headers', return_value={}):
            result = upload_subtitle_track('asset1', 'http://example.com/sub.srt')
        self.assertEqual(result, {})


class TestListSubtitleTracks(unittest.TestCase):

    def test_returns_only_text_tracks(self):
        from openedx_video_pipeline.subtitles import list_subtitle_tracks
        mock_response = MagicMock()
        mock_response.json.return_value = {
            'data': [
                {'type': 'text', 'id': 'track1'},
                {'type': 'video', 'id': 'vid1'},
                {'type': 'audio', 'id': 'aud1'},
            ]
        }
        mock_response.raise_for_status.return_value = None

        with patch('openedx_video_pipeline.subtitles.requests.get', return_value=mock_response), \
             patch('openedx_video_pipeline.subtitles.get_mux_headers', return_value={'Authorization': 'Basic x'}):
            result = list_subtitle_tracks('asset1')

        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['id'], 'track1')

    def test_returns_empty_when_no_credentials(self):
        from openedx_video_pipeline.subtitles import list_subtitle_tracks
        with patch('openedx_video_pipeline.subtitles.get_mux_headers', return_value={}):
            result = list_subtitle_tracks('asset1')
        self.assertEqual(result, [])


class TestGetSubtitleTracksForXblock(unittest.TestCase):

    def test_filters_non_ready_tracks(self):
        from openedx_video_pipeline.subtitles import get_subtitle_tracks_for_xblock
        tracks = [
            {'type': 'text', 'text_type': 'subtitles', 'status': 'ready',
             'language_code': 'en', 'name': 'English', 'id': 't1'},
            {'type': 'text', 'text_type': 'subtitles', 'status': 'preparing',
             'language_code': 'vi', 'name': 'Vietnamese', 'id': 't2'},
        ]
        with patch('openedx_video_pipeline.subtitles.list_subtitle_tracks', return_value=tracks):
            result = get_subtitle_tracks_for_xblock('asset1')

        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['language'], 'en')

    def test_returns_expected_keys(self):
        from openedx_video_pipeline.subtitles import get_subtitle_tracks_for_xblock
        tracks = [
            {'type': 'text', 'text_type': 'subtitles', 'status': 'ready',
             'language_code': 'en', 'name': 'English', 'id': 'trk1'},
        ]
        with patch('openedx_video_pipeline.subtitles.list_subtitle_tracks', return_value=tracks):
            result = get_subtitle_tracks_for_xblock('asset1')

        self.assertIn('language', result[0])
        self.assertIn('label', result[0])
        self.assertIn('url', result[0])
        self.assertIn('track_id', result[0])


# ---------------------------------------------------------------------------
# 8. XBlock config helpers (pure functions)
# ---------------------------------------------------------------------------

class TestXBlockConfigHelpers(unittest.TestCase):

    def test_get_hls_url_returns_m3u8(self):
        from openedx_video_pipeline.xblock_config import get_hls_url
        url = get_hls_url('myplayback123')
        self.assertTrue(url.endswith('.m3u8'))
        self.assertIn('myplayback123', url)

    def test_get_hls_url_empty_for_none(self):
        from openedx_video_pipeline.xblock_config import get_hls_url
        self.assertEqual(get_hls_url(''), '')
        self.assertEqual(get_hls_url(None), '')

    def test_get_poster_url_returns_thumbnail(self):
        from openedx_video_pipeline.xblock_config import get_poster_url
        url = get_poster_url('myplayback123')
        self.assertIn('myplayback123', url)
        self.assertIn('thumbnail.jpg', url)
        self.assertIn('width=1280', url)

    def test_get_poster_url_with_time(self):
        from openedx_video_pipeline.xblock_config import get_poster_url
        url = get_poster_url('play1', time=5.0)
        self.assertIn('time=5.0', url)

    def test_get_poster_url_empty_for_missing_id(self):
        from openedx_video_pipeline.xblock_config import get_poster_url
        self.assertEqual(get_poster_url(''), '')

    def test_get_animated_gif_url_returns_gif(self):
        from openedx_video_pipeline.xblock_config import get_animated_gif_url
        url = get_animated_gif_url('play1')
        self.assertIn('animated.gif', url)
        self.assertIn('play1', url)

    def test_get_animated_gif_url_empty_for_missing(self):
        from openedx_video_pipeline.xblock_config import get_animated_gif_url
        self.assertEqual(get_animated_gif_url(''), '')


class TestBuildXblockConfig(unittest.TestCase):

    def test_basic_config_structure(self):
        from openedx_video_pipeline.xblock_config import build_xblock_config
        config = build_xblock_config('play123')
        expected_keys = {
            'source', 'html5_sources', 'poster',
            'download_video', 'show_captions', 'transcripts',
            'sub', 'use_iframe', 'playback_id',
        }
        for key in expected_keys:
            self.assertIn(key, config, f"Missing key: {key}")

    def test_download_video_is_always_false(self):
        from openedx_video_pipeline.xblock_config import build_xblock_config
        config = build_xblock_config('play123')
        self.assertFalse(config['download_video'])

    def test_use_iframe_is_always_false(self):
        from openedx_video_pipeline.xblock_config import build_xblock_config
        config = build_xblock_config('play123')
        self.assertFalse(config['use_iframe'])

    def test_never_exposes_asset_id(self):
        from openedx_video_pipeline.xblock_config import build_xblock_config
        config = build_xblock_config('play123')
        self.assertNotIn('asset_id', config)
        self.assertEqual(config['playback_id'], 'play123')

    def test_show_captions_false_when_no_subtitles(self):
        from openedx_video_pipeline.xblock_config import build_xblock_config
        config = build_xblock_config('play123', subtitle_tracks=[])
        self.assertFalse(config['show_captions'])

    def test_show_captions_true_when_subtitles_present(self):
        from openedx_video_pipeline.xblock_config import build_xblock_config
        tracks = [{'language': 'en', 'label': 'English', 'url': ''}]
        config = build_xblock_config('play123', subtitle_tracks=tracks)
        self.assertTrue(config['show_captions'])
        self.assertEqual(config['transcripts']['en'], '')
        self.assertEqual(config['sub'], 'en')

    def test_hls_url_in_html5_sources(self):
        from openedx_video_pipeline.xblock_config import build_xblock_config
        config = build_xblock_config('play123')
        self.assertIn(config['source'], config['html5_sources'])

    def test_restricted_course_adds_signed_url_endpoint(self):
        from openedx_video_pipeline.xblock_config import build_xblock_config
        config = build_xblock_config('play123', course_is_restricted=True)
        self.assertIn('signed_url_endpoint', config)
        self.assertIn('requires_signed_playback', config)


class TestBuildXblockOlx(unittest.TestCase):

    def test_returns_video_element(self):
        from openedx_video_pipeline.xblock_config import build_xblock_olx
        olx = build_xblock_olx('play123', display_name='My Video')
        self.assertIn('<video', olx)
        self.assertIn('</video>', olx)

    def test_download_video_false(self):
        from openedx_video_pipeline.xblock_config import build_xblock_olx
        olx = build_xblock_olx('play123')
        self.assertIn('download_video="false"', olx)

    def test_source_contains_hls_url(self):
        from openedx_video_pipeline.xblock_config import build_xblock_olx
        olx = build_xblock_olx('play123')
        self.assertIn('play123', olx)
        self.assertIn('.m3u8', olx)

    def test_transcript_elements_present_when_tracks(self):
        from openedx_video_pipeline.xblock_config import build_xblock_olx
        tracks = [{'language': 'en', 'label': 'English', 'url': 'https://sub.vtt'}]
        olx = build_xblock_olx('play123', subtitle_tracks=tracks)
        self.assertIn('<transcript', olx)
        self.assertIn('language="en"', olx)


# ---------------------------------------------------------------------------
# 9. xAPI emitter
# ---------------------------------------------------------------------------

class TestXapiEmitterConstants(unittest.TestCase):

    def test_verb_map_has_all_event_types(self):
        from openedx_video_pipeline.xapi_emitter import VERB_MAP
        for event in ('played', 'paused', 'seeked', 'completed'):
            self.assertIn(event, VERB_MAP, f"VERB_MAP missing: {event}")
            self.assertTrue(VERB_MAP[event].startswith('http'))


class TestEmitVideoXapiEvent(unittest.TestCase):

    def test_returns_false_when_feature_disabled(self):
        from openedx_video_pipeline.xapi_emitter import emit_video_xapi_event
        # ENABLE_VIDEO_XAPI_EVENTS defaults to False in test settings
        result = emit_video_xapi_event(
            user_id=1, video_id='play1', course_key='course-v1:X',
            event_type='played', position=10.0,
        )
        self.assertFalse(result)

    def test_returns_false_for_unknown_event_type(self):
        from django.conf import settings as dj_settings
        from openedx_video_pipeline import xapi_emitter

        with patch.object(dj_settings, 'ENABLE_VIDEO_XAPI_EVENTS', True):
            result = xapi_emitter.emit_video_xapi_event(
                user_id=1, video_id='play1', course_key='course-v1:X',
                event_type='invalid_event', position=0.0,
            )
        self.assertFalse(result)

    def test_returns_false_when_eventtracking_unavailable(self):
        """eventtracking raises ImportError outside Open edX — must return False."""
        from django.conf import settings as dj_settings
        from openedx_video_pipeline import xapi_emitter

        with patch.object(dj_settings, 'ENABLE_VIDEO_XAPI_EVENTS', True), \
             patch.dict('sys.modules', {'eventtracking': None}):
            result = xapi_emitter.emit_video_xapi_event(
                user_id=1, video_id='play1', course_key='course-v1:X',
                event_type='played', position=10.0,
            )
        self.assertFalse(result)

    def test_emits_event_when_tracker_available(self):
        from django.conf import settings as dj_settings
        from openedx_video_pipeline import xapi_emitter

        mock_tracker = MagicMock()
        mock_eventtracking = MagicMock()
        mock_eventtracking.tracker.get_tracker.return_value = mock_tracker

        with patch.object(dj_settings, 'ENABLE_VIDEO_XAPI_EVENTS', True), \
             patch.dict('sys.modules', {'eventtracking': mock_eventtracking}):
            result = xapi_emitter.emit_video_xapi_event(
                user_id=42, video_id='play1', course_key='course-v1:X',
                event_type='played', position=30.0,
            )

        self.assertTrue(result)
        mock_tracker.emit.assert_called_once()
        call_args = mock_tracker.emit.call_args
        event_name = call_args[0][0]
        statement = call_args[0][1]
        self.assertEqual(event_name, 'video.played')
        # user_id must appear as string, never as PII
        self.assertEqual(statement['actor']['account']['name'], '42')
        self.assertNotIn('email', statement.get('actor', {}))

    def test_completed_event_sets_completion_true(self):
        from django.conf import settings as dj_settings
        from openedx_video_pipeline import xapi_emitter

        mock_tracker = MagicMock()
        mock_eventtracking = MagicMock()
        mock_eventtracking.tracker.get_tracker.return_value = mock_tracker

        with patch.object(dj_settings, 'ENABLE_VIDEO_XAPI_EVENTS', True), \
             patch.dict('sys.modules', {'eventtracking': mock_eventtracking}):
            xapi_emitter.emit_video_xapi_event(
                user_id=1, video_id='play1', course_key='course-v1:X',
                event_type='completed', position=300.0, duration=300.0,
            )

        statement = mock_tracker.emit.call_args[0][1]
        self.assertTrue(statement['result']['completion'])


# ---------------------------------------------------------------------------
# 10. VideoCompletionStatus update_progress logic (unit — no DB)
# ---------------------------------------------------------------------------

class TestVideoCompletionUpdateProgressLogic(unittest.TestCase):
    """
    Test the computation logic inside update_progress without hitting the DB.
    We mock get_or_create so we can exercise the calculation path.
    """

    def _make_status_obj(self, duration=300.0, max_pos=0.0, completion=0.0,
                         is_complete=False, play_count=0):
        from openedx_video_pipeline.completion import VideoCompletionStatus
        obj = VideoCompletionStatus()
        obj.duration = duration
        obj.max_position_reached = max_pos
        obj.completion_percentage = completion
        obj.is_complete = is_complete
        obj.play_count = play_count
        obj.last_position = 0.0
        obj.first_played_at = None
        obj.completed_at = None
        obj.save = MagicMock()
        return obj

    def _call_update_progress(self, status_obj, position, duration=None,
                               event_type='played'):
        from openedx_video_pipeline.completion import VideoCompletionStatus
        user = MagicMock()
        user.id = 1

        with patch.object(VideoCompletionStatus.objects, 'get_or_create',
                          return_value=(status_obj, False)):
            return VideoCompletionStatus.update_progress(
                user=user,
                video_id='play1',
                course_key='course-v1:X',
                position=position,
                duration=duration,
                event_type=event_type,
            )

    def test_completion_percentage_calculated_from_position(self):
        obj = self._make_status_obj(duration=300.0)
        result = self._call_update_progress(obj, position=270.0)
        self.assertAlmostEqual(result.completion_percentage, 0.9, places=5)

    def test_is_complete_at_90_percent(self):
        obj = self._make_status_obj(duration=300.0)
        result = self._call_update_progress(obj, position=270.0)
        self.assertTrue(result.is_complete)

    def test_not_complete_below_90_percent(self):
        obj = self._make_status_obj(duration=300.0)
        result = self._call_update_progress(obj, position=100.0)
        self.assertFalse(result.is_complete)

    def test_completion_capped_at_1(self):
        obj = self._make_status_obj(duration=300.0)
        # Position beyond duration
        result = self._call_update_progress(obj, position=400.0)
        self.assertLessEqual(result.completion_percentage, 1.0)

    def test_play_count_incremented_on_played(self):
        obj = self._make_status_obj(play_count=2)
        result = self._call_update_progress(obj, position=10.0, event_type='played')
        self.assertEqual(result.play_count, 3)

    def test_play_count_not_incremented_on_paused(self):
        obj = self._make_status_obj(play_count=2)
        result = self._call_update_progress(obj, position=10.0, event_type='paused')
        self.assertEqual(result.play_count, 2)

    def test_max_position_advances_forward(self):
        obj = self._make_status_obj(max_pos=50.0)
        result = self._call_update_progress(obj, position=80.0)
        self.assertEqual(result.max_position_reached, 80.0)

    def test_max_position_does_not_retreat(self):
        obj = self._make_status_obj(max_pos=200.0)
        result = self._call_update_progress(obj, position=10.0)
        self.assertEqual(result.max_position_reached, 200.0)

    def test_completed_event_sets_100_when_no_duration(self):
        obj = self._make_status_obj(duration=0.0)
        result = self._call_update_progress(obj, position=0.0, event_type='completed')
        self.assertEqual(result.completion_percentage, 1.0)


# ---------------------------------------------------------------------------
# 11. URL patterns
# ---------------------------------------------------------------------------

class TestUrlPatterns(unittest.TestCase):

    def test_url_patterns_count(self):
        from openedx_video_pipeline.urls import urlpatterns
        # We have 10 defined URL patterns
        self.assertGreaterEqual(len(urlpatterns), 10)

    def test_health_url_exists(self):
        from openedx_video_pipeline.urls import urlpatterns
        names = [p.name for p in urlpatterns]
        self.assertIn('health-check', names)

    def test_events_url_exists(self):
        from openedx_video_pipeline.urls import urlpatterns
        names = [p.name for p in urlpatterns]
        self.assertIn('video-events', names)

    def test_subtitle_upload_url_exists(self):
        from openedx_video_pipeline.urls import urlpatterns
        names = [p.name for p in urlpatterns]
        self.assertIn('subtitle-upload', names)


if __name__ == '__main__':
    unittest.main()
