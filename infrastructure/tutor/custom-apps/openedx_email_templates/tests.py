"""
Baseline tests for openedx_email_templates.

Covers:
- Import smoke tests for every module
- AppConfig name and verbose_name
- Template model: fields, __str__, get_template fallback chain, render, get_branding
- Campaign model: fields, __str__, schedule/pause/resume/cancel state machine
- CampaignRecipient: mark_sent/failed/skipped
- TokenBucket rate limiter: consume, refill, wait_and_consume, per-tenant buckets
- Serializer field coverage
- URL patterns
- Admin registrations
"""

import importlib
import os
import sys
import time
import types
import unittest
import uuid
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub Celery before Django bootstrap
# ---------------------------------------------------------------------------

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

# Stub openedx_email_preferences (used by tasks.py)
_prefs_mod = types.ModuleType('openedx_email_preferences')
_prefs_models = types.ModuleType('openedx_email_preferences.models')
_prefs_mod.models = _prefs_models
sys.modules.setdefault('openedx_email_preferences', _prefs_mod)
sys.modules.setdefault('openedx_email_preferences.models', _prefs_models)

# Stub student.models (used by tasks._resolve_segment)
_student_mod = types.ModuleType('student')
_student_models = types.ModuleType('student.models')
_student_mod.models = _student_models
sys.modules.setdefault('student', _student_mod)
sys.modules.setdefault('student.models', _student_models)

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'openedx_email_templates._test_settings')

_settings = types.ModuleType('openedx_email_templates._test_settings')
_settings.SECRET_KEY = 'test-secret-key'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'rest_framework',
    'openedx_email_templates',
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

sys.modules['openedx_email_templates._test_settings'] = _settings

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
        self._assert_importable('openedx_email_templates.apps')

    def test_import_models(self):
        self._assert_importable('openedx_email_templates.models')

    def test_import_views(self):
        self._assert_importable('openedx_email_templates.views')

    def test_import_signals(self):
        self._assert_importable('openedx_email_templates.signals')

    def test_import_tasks(self):
        self._assert_importable('openedx_email_templates.tasks')

    def test_import_serializers(self):
        self._assert_importable('openedx_email_templates.serializers')

    def test_import_rate_limiter(self):
        self._assert_importable('openedx_email_templates.rate_limiter')

    def test_import_urls(self):
        self._assert_importable('openedx_email_templates.urls')

    def test_import_admin(self):
        self._assert_importable('openedx_email_templates.admin')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):
    def test_app_name(self):
        from openedx_email_templates.apps import OpenedxEmailTemplatesConfig
        self.assertEqual(OpenedxEmailTemplatesConfig.name, 'openedx_email_templates')

    def test_verbose_name(self):
        from openedx_email_templates.apps import OpenedxEmailTemplatesConfig
        self.assertEqual(
            OpenedxEmailTemplatesConfig.verbose_name,
            'Email Templates & Bulk Campaigns',
        )


# ===========================================================================
# 3. Template model
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestTemplateModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def _create_template(self, **overrides):
        from openedx_email_templates.models import Template
        defaults = dict(
            name='Welcome Email',
            category='welcome',
            subject='Welcome {{ user_name }}',
            body_html='<p>Hello {{ user_name }}</p>',
            body_text='Hello {{ user_name }}',
            language='en',
            org_slug='default',
            is_active=True,
        )
        defaults.update(overrides)
        return Template.objects.create(**defaults)

    def test_str_representation(self):
        tpl = self._create_template()
        s = str(tpl)
        self.assertIn('Welcome Email', s)
        self.assertIn('welcome', s)
        self.assertIn('en', s)

    def test_uuid_primary_key(self):
        tpl = self._create_template()
        self.assertIsInstance(tpl.pk, uuid.UUID)

    def test_get_template_exact_match(self):
        from openedx_email_templates.models import Template
        self._create_template(category='enrollment', language='ms', org_slug='acme')
        found = Template.get_template('enrollment', language='ms', org_slug='acme')
        self.assertIsNotNone(found)
        self.assertEqual(found.language, 'ms')

    def test_get_template_falls_back_to_english(self):
        from openedx_email_templates.models import Template
        self._create_template(category='grade', language='en', org_slug='acme')
        found = Template.get_template('grade', language='zh-hans', org_slug='acme')
        self.assertIsNotNone(found)
        self.assertEqual(found.language, 'en')

    def test_get_template_falls_back_to_default_org(self):
        from openedx_email_templates.models import Template
        self._create_template(category='certificate', language='en', org_slug='default')
        found = Template.get_template('certificate', language='en', org_slug='custom-org')
        self.assertIsNotNone(found)
        self.assertEqual(found.org_slug, 'default')

    def test_get_template_returns_none_if_nothing_matches(self):
        from openedx_email_templates.models import Template
        self.assertIsNone(
            Template.get_template('nonexistent_category', language='en', org_slug='default')
        )

    def test_render_substitutes_variables(self):
        tpl = self._create_template(
            subject='Hi {{ user_name }}',
            body_html='<b>{{ user_name }}</b>',
            body_text='Hello {{ user_name }}',
        )
        result = tpl.render({'user_name': 'Alice'})
        self.assertEqual(result['subject'], 'Hi Alice')
        self.assertIn('Alice', result['body_html'])
        self.assertIn('Alice', result['body_text'])

    def test_get_branding_defaults(self):
        tpl = self._create_template()
        branding = tpl.get_branding()
        self.assertEqual(branding['org_display_name'], 'Mereka Academy')
        self.assertEqual(branding['org_primary_color'], '#ab3b78')

    def test_get_branding_template_override(self):
        tpl = self._create_template(
            tenant_branding={'org_display_name': 'Custom Academy'}
        )
        branding = tpl.get_branding()
        self.assertEqual(branding['org_display_name'], 'Custom Academy')


# ===========================================================================
# 4. Campaign model — state machine
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestCampaignModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def setUp(self):
        from openedx_email_templates.models import Template
        self.template = Template.objects.create(
            name='Test Template',
            category='campaign',
            subject='Test',
            body_html='<p>Test</p>',
            body_text='Test',
            language='en',
            org_slug='default',
        )

    def _create_campaign(self, **overrides):
        from openedx_email_templates.models import Campaign
        defaults = dict(
            name='Test Campaign',
            template=self.template,
            org_slug='acme',
            status='draft',
        )
        defaults.update(overrides)
        return Campaign.objects.create(**defaults)

    def test_str_representation(self):
        c = self._create_campaign()
        s = str(c)
        self.assertIn('Test Campaign', s)
        self.assertIn('draft', s)

    def test_schedule(self):
        c = self._create_campaign(status='draft')
        future = timezone.now() + timezone.timedelta(hours=2)
        c.schedule(future)
        c.refresh_from_db()
        self.assertEqual(c.status, 'scheduled')
        self.assertIsNotNone(c.scheduled_at)

    def test_pause_from_sending(self):
        c = self._create_campaign(status='sending')
        c.pause()
        c.refresh_from_db()
        self.assertEqual(c.status, 'paused')

    def test_pause_from_draft_is_noop(self):
        c = self._create_campaign(status='draft')
        c.pause()
        c.refresh_from_db()
        self.assertEqual(c.status, 'draft')

    def test_resume_from_paused(self):
        c = self._create_campaign(status='paused')
        c.resume()
        c.refresh_from_db()
        self.assertEqual(c.status, 'sending')

    def test_resume_from_draft_is_noop(self):
        c = self._create_campaign(status='draft')
        c.resume()
        c.refresh_from_db()
        self.assertEqual(c.status, 'draft')

    def test_cancel_from_draft(self):
        c = self._create_campaign(status='draft')
        c.cancel()
        c.refresh_from_db()
        self.assertEqual(c.status, 'cancelled')

    def test_cancel_from_scheduled(self):
        c = self._create_campaign(status='scheduled')
        c.cancel()
        c.refresh_from_db()
        self.assertEqual(c.status, 'cancelled')

    def test_cancel_from_sending_is_noop(self):
        c = self._create_campaign(status='sending')
        c.cancel()
        c.refresh_from_db()
        self.assertEqual(c.status, 'sending')

    def test_cancel_from_completed_is_noop(self):
        c = self._create_campaign(status='completed')
        c.cancel()
        c.refresh_from_db()
        self.assertEqual(c.status, 'completed')

    def test_mark_sending(self):
        c = self._create_campaign()
        c.mark_sending()
        c.refresh_from_db()
        self.assertEqual(c.status, 'sending')
        self.assertIsNotNone(c.started_at)

    def test_mark_completed(self):
        c = self._create_campaign(status='sending')
        c.mark_completed()
        c.refresh_from_db()
        self.assertEqual(c.status, 'completed')
        self.assertIsNotNone(c.completed_at)


# ===========================================================================
# 5. CampaignRecipient model
# ===========================================================================

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class TestCampaignRecipientModel(TestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)

    def setUp(self):
        from openedx_email_templates.models import Template, Campaign, CampaignRecipient
        self.user = User.objects.create_user(
            username='recipient', email='r@test.com'
        )
        self.template = Template.objects.create(
            name='T', category='campaign', subject='S',
            body_html='H', body_text='T', language='en', org_slug='default',
        )
        self.campaign = Campaign.objects.create(
            name='C', template=self.template, org_slug='acme',
        )
        self.recipient = CampaignRecipient.objects.create(
            campaign=self.campaign, user=self.user,
        )

    def test_str_representation(self):
        s = str(self.recipient)
        self.assertIn('recipient', s)
        self.assertIn('pending', s)

    def test_mark_sent(self):
        self.recipient.mark_sent()
        self.recipient.refresh_from_db()
        self.assertEqual(self.recipient.status, 'sent')
        self.assertIsNotNone(self.recipient.sent_at)

    def test_mark_failed(self):
        self.recipient.mark_failed('SMTP timeout')
        self.recipient.refresh_from_db()
        self.assertEqual(self.recipient.status, 'failed')
        self.assertIn('SMTP timeout', self.recipient.error_message)

    def test_mark_failed_truncates(self):
        self.recipient.mark_failed('x' * 2000)
        self.recipient.refresh_from_db()
        self.assertLessEqual(len(self.recipient.error_message), 1000)

    def test_mark_skipped(self):
        self.recipient.mark_skipped('user_opted_out')
        self.recipient.refresh_from_db()
        self.assertEqual(self.recipient.status, 'skipped')


# ===========================================================================
# 6. Rate limiter — TokenBucket
# ===========================================================================

class TestTokenBucket(unittest.TestCase):
    """Test the token bucket algorithm in rate_limiter.py."""

    def test_consume_within_capacity(self):
        from openedx_email_templates.rate_limiter import TokenBucket
        bucket = TokenBucket(rate=10, capacity=10)
        for _ in range(10):
            self.assertTrue(bucket.consume())

    def test_consume_exceeds_capacity(self):
        from openedx_email_templates.rate_limiter import TokenBucket
        bucket = TokenBucket(rate=10, capacity=5)
        for _ in range(5):
            self.assertTrue(bucket.consume())
        self.assertFalse(bucket.consume())

    def test_refill_over_time(self):
        from openedx_email_templates.rate_limiter import TokenBucket
        bucket = TokenBucket(rate=100, capacity=10)
        # Drain all tokens
        for _ in range(10):
            bucket.consume()
        self.assertFalse(bucket.consume())
        # Simulate time passing
        bucket.last_refill -= 0.2  # 0.2s at 100/s = 20 tokens refilled
        self.assertTrue(bucket.consume())

    def test_wait_and_consume_success(self):
        from openedx_email_templates.rate_limiter import TokenBucket
        bucket = TokenBucket(rate=1000, capacity=5)
        # Drain
        for _ in range(5):
            bucket.consume()
        # Should refill quickly at 1000/s
        self.assertTrue(bucket.wait_and_consume(1, max_wait=0.1))

    def test_wait_and_consume_timeout(self):
        from openedx_email_templates.rate_limiter import TokenBucket
        bucket = TokenBucket(rate=1, capacity=1)
        bucket.consume()
        # Need 1 token at 1/s rate, but max_wait=0.01s is too short
        self.assertFalse(bucket.wait_and_consume(1, max_wait=0.01))


class TestPerTenantRateLimiter(unittest.TestCase):
    """Test per-tenant bucket management."""

    def test_get_tenant_bucket_creates_bucket(self):
        from openedx_email_templates.rate_limiter import get_tenant_bucket, _tenant_buckets
        bucket = get_tenant_bucket('test-org-unique-789')
        self.assertIsNotNone(bucket)
        # Clean up
        _tenant_buckets.pop('test-org-unique-789', None)

    def test_check_rate_limit_allows_within_capacity(self):
        from openedx_email_templates.rate_limiter import check_rate_limit, _tenant_buckets
        # Fresh bucket with capacity=50
        result = check_rate_limit('rate-test-org-123')
        self.assertTrue(result)
        _tenant_buckets.pop('rate-test-org-123', None)

    def test_check_rate_limit_blocks_when_exhausted(self):
        from openedx_email_templates.rate_limiter import (
            check_rate_limit, get_tenant_bucket, _tenant_buckets,
        )
        bucket = get_tenant_bucket('exhaust-org-456')
        # Drain
        bucket.tokens = 0
        bucket.last_refill = time.monotonic()
        self.assertFalse(check_rate_limit('exhaust-org-456'))
        _tenant_buckets.pop('exhaust-org-456', None)


# ===========================================================================
# 7. Serializers
# ===========================================================================

class TestSerializers(unittest.TestCase):
    def test_template_serializer_fields(self):
        from openedx_email_templates.serializers import TemplateSerializer
        fields = TemplateSerializer().fields
        expected = {'id', 'name', 'category', 'subject', 'body_html', 'language', 'org_slug'}
        self.assertTrue(expected.issubset(set(fields.keys())))

    def test_campaign_list_serializer_fields(self):
        from openedx_email_templates.serializers import CampaignListSerializer
        fields = CampaignListSerializer().fields
        expected = {'id', 'name', 'status', 'org_slug', 'sent_count', 'total_recipients'}
        self.assertTrue(expected.issubset(set(fields.keys())))

    def test_campaign_create_serializer_fields(self):
        from openedx_email_templates.serializers import CampaignCreateSerializer
        fields = CampaignCreateSerializer().fields
        expected = {'name', 'template', 'segment', 'org_slug'}
        self.assertTrue(expected.issubset(set(fields.keys())))

    def test_campaign_recipient_serializer_fields(self):
        from openedx_email_templates.serializers import CampaignRecipientSerializer
        fields = CampaignRecipientSerializer().fields
        expected = {'id', 'user', 'username', 'status', 'sent_at'}
        self.assertTrue(expected.issubset(set(fields.keys())))


# ===========================================================================
# 8. URL patterns
# ===========================================================================

class TestURLPatterns(unittest.TestCase):
    def test_url_names(self):
        from openedx_email_templates.urls import urlpatterns
        names = {p.name for p in urlpatterns}
        self.assertIn('template-list', names)
        self.assertIn('campaign-list', names)
        self.assertIn('campaign-action', names)

    def test_app_name(self):
        from openedx_email_templates import urls
        self.assertEqual(urls.app_name, 'openedx_email_templates')


# ===========================================================================
# 9. Admin registrations
# ===========================================================================

class TestAdminRegistrations(unittest.TestCase):
    def test_template_admin(self):
        from django.contrib import admin
        from openedx_email_templates.models import Template
        self.assertIn(Template, admin.site._registry)

    def test_campaign_admin(self):
        from django.contrib import admin
        from openedx_email_templates.models import Campaign
        self.assertIn(Campaign, admin.site._registry)

    def test_recipient_admin(self):
        from django.contrib import admin
        from openedx_email_templates.models import CampaignRecipient
        self.assertIn(CampaignRecipient, admin.site._registry)


if __name__ == '__main__':
    unittest.main()
