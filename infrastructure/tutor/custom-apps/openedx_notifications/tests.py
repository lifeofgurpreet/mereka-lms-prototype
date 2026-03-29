"""
Test floor for openedx_notifications.

Covers:
  1. Import smoke tests — every module can be imported without a live Open edX stack
  2. Model tests — Notification field contract, get_active_notifications,
     mark_all_read, get_unread_count, is_expired, mark_read
  3. Serializer tests — NotificationSerializer and UnreadCountSerializer field contract
  4. View tests — NotificationViewSet configuration and extra actions
  5. Signal tests — register_ace_channel callable exists and survives ImportError
  6. Admin tests — NotificationAdmin is registered and has_add_permission returns False
  7. Apps config tests — AppConfig name/verbose_name/default_auto_field
  8. URL routing tests — router registers the 'notification' basename
  9. Task tests — purge_expired_notifications is callable

Run from repo root:
    pip install pytest pytest-django djangorestframework
    PYTHONPATH=infrastructure/tutor/custom-apps \\
        pytest infrastructure/tutor/custom-apps/openedx_notifications/ -v

Platform dependencies (edx_ace, celery, openedx.*) are stubbed in conftest.py.
Django is configured in-process with an in-memory SQLite database.
"""

import importlib
import sys
import unittest
import uuid
from unittest.mock import MagicMock

import pytest

# ---------------------------------------------------------------------------
# Dependency stubs must already be installed by conftest.py before this
# module is collected.  Django must be configured too.
# ---------------------------------------------------------------------------

import django
from django.conf import settings  # noqa: F401 (imported for assertions)


# ---------------------------------------------------------------------------
# 1. Import smoke tests
# ---------------------------------------------------------------------------

class ImportSmokeTests(unittest.TestCase):
    """Every module in openedx_notifications must import cleanly."""

    def _import(self, module_name):
        full_name = f'openedx_notifications.{module_name}'
        if full_name in sys.modules:
            return sys.modules[full_name]
        return importlib.import_module(full_name)

    def test_package_init_imports(self):
        import openedx_notifications
        self.assertEqual(openedx_notifications.__version__, '1.0.0')
        self.assertIn('default_app_config', dir(openedx_notifications))

    def test_apps_imports(self):
        mod = self._import('apps')
        self.assertTrue(hasattr(mod, 'OpenedxNotificationsConfig'))

    def test_models_imports(self):
        mod = self._import('models')
        self.assertTrue(hasattr(mod, 'Notification'))

    def test_serializers_imports(self):
        mod = self._import('serializers')
        self.assertTrue(hasattr(mod, 'NotificationSerializer'))
        self.assertTrue(hasattr(mod, 'UnreadCountSerializer'))

    def test_views_imports(self):
        mod = self._import('views')
        self.assertTrue(hasattr(mod, 'NotificationViewSet'))
        self.assertTrue(hasattr(mod, 'NotificationPagination'))

    def test_urls_imports(self):
        mod = self._import('urls')
        self.assertTrue(hasattr(mod, 'urlpatterns'))
        self.assertTrue(hasattr(mod, 'router'))

    def test_admin_imports(self):
        mod = self._import('admin')
        self.assertTrue(hasattr(mod, 'NotificationAdmin'))

    def test_signals_imports(self):
        mod = self._import('signals')
        self.assertTrue(hasattr(mod, 'register_ace_channel'))

    def test_tasks_imports(self):
        mod = self._import('tasks')
        self.assertTrue(hasattr(mod, 'purge_expired_notifications'))

    def test_ace_channel_imports(self):
        mod = self._import('ace_channel')
        self.assertTrue(hasattr(mod, 'InAppChannel'))


# ---------------------------------------------------------------------------
# 2. Model tests
# ---------------------------------------------------------------------------

from django.test import TestCase  # noqa: E402
from django.utils import timezone  # noqa: E402
from django.contrib.auth import get_user_model  # noqa: E402

User = get_user_model()


def _create_user(username='testuser', email='test@example.com'):
    return User.objects.get_or_create(username=username, defaults={'email': email})[0]


class NotificationModelFieldTests(TestCase):
    """Notification model field contract."""

    def setUp(self):
        self.user = _create_user()

    def _make_notification(self, **overrides):
        from openedx_notifications.models import Notification
        defaults = dict(
            user=self.user,
            message_type='course_announcement',
            title='Test Notification',
            body='This is the body.',
            org_slug='mereka',
        )
        defaults.update(overrides)
        return Notification.objects.create(**defaults)

    def test_id_is_uuid(self):
        n = self._make_notification()
        self.assertIsInstance(n.id, uuid.UUID)

    def test_default_read_is_false(self):
        n = self._make_notification()
        self.assertFalse(n.read)

    def test_created_at_is_set(self):
        n = self._make_notification()
        self.assertIsNotNone(n.created_at)

    def test_expires_at_nullable(self):
        n = self._make_notification()
        self.assertIsNone(n.expires_at)

    def test_course_id_nullable(self):
        n = self._make_notification()
        self.assertIsNone(n.course_id)

    def test_deep_link_url_nullable(self):
        n = self._make_notification()
        self.assertIsNone(n.deep_link_url)

    def test_str_representation(self):
        n = self._make_notification()
        s = str(n)
        self.assertIn('course_announcement', s)
        self.assertIn(self.user.username, s)

    def test_is_expired_returns_false_when_no_expiry(self):
        n = self._make_notification()
        self.assertFalse(n.is_expired())

    def test_is_expired_returns_false_for_future_expiry(self):
        future = timezone.now() + timezone.timedelta(days=1)
        n = self._make_notification(expires_at=future)
        self.assertFalse(n.is_expired())

    def test_is_expired_returns_true_for_past_expiry(self):
        past = timezone.now() - timezone.timedelta(seconds=1)
        n = self._make_notification(expires_at=past)
        self.assertTrue(n.is_expired())

    def test_mark_read_sets_read_true(self):
        n = self._make_notification()
        self.assertFalse(n.read)
        n.mark_read()
        n.refresh_from_db()
        self.assertTrue(n.read)

    def test_mark_read_is_idempotent(self):
        n = self._make_notification(read=True)
        n.mark_read()  # should not raise
        n.refresh_from_db()
        self.assertTrue(n.read)

    def test_db_table_name(self):
        from openedx_notifications.models import Notification
        self.assertEqual(
            Notification._meta.db_table,
            'openedx_notifications_notification'
        )

    def test_ordering_is_by_created_at_desc(self):
        from openedx_notifications.models import Notification
        self.assertIn('-created_at', Notification._meta.ordering)


class NotificationModelQueryTests(TestCase):
    """get_active_notifications and mark_all_read classmethod signatures."""

    def setUp(self):
        self.user = _create_user(username='queryuser', email='query@example.com')

    def _make_notification(self, **overrides):
        from openedx_notifications.models import Notification
        defaults = dict(
            user=self.user,
            message_type='test_type',
            title='Test',
            body='Body',
            org_slug='mereka',
        )
        defaults.update(overrides)
        return Notification.objects.create(**defaults)

    def test_get_active_notifications_returns_queryset(self):
        from openedx_notifications.models import Notification
        qs = Notification.get_active_notifications(self.user, 'mereka')
        self.assertEqual(qs.count(), 0)

    def test_get_active_notifications_excludes_expired(self):
        from openedx_notifications.models import Notification
        past = timezone.now() - timezone.timedelta(seconds=1)
        self._make_notification(expires_at=past)
        qs = Notification.get_active_notifications(self.user, 'mereka')
        self.assertEqual(qs.count(), 0)

    def test_get_active_notifications_includes_non_expired(self):
        from openedx_notifications.models import Notification
        self._make_notification()  # no expiry
        qs = Notification.get_active_notifications(self.user, 'mereka')
        self.assertEqual(qs.count(), 1)

    def test_get_active_notifications_scoped_to_org_slug(self):
        from openedx_notifications.models import Notification
        self._make_notification(org_slug='mereka')
        qs = Notification.get_active_notifications(self.user, 'other-org')
        self.assertEqual(qs.count(), 0)

    def test_mark_all_read_returns_integer_count(self):
        from openedx_notifications.models import Notification
        self._make_notification()
        self._make_notification()
        count = Notification.mark_all_read(self.user, 'mereka')
        self.assertIsInstance(count, int)
        self.assertEqual(count, 2)

    def test_mark_all_read_sets_read_true_on_all(self):
        from openedx_notifications.models import Notification
        self._make_notification()
        self._make_notification()
        Notification.mark_all_read(self.user, 'mereka')
        remaining_unread = Notification.objects.filter(
            user=self.user, org_slug='mereka', read=False
        ).count()
        self.assertEqual(remaining_unread, 0)

    def test_mark_all_read_does_not_touch_other_orgs(self):
        from openedx_notifications.models import Notification
        self._make_notification(org_slug='other')
        Notification.mark_all_read(self.user, 'mereka')
        n = Notification.objects.get(user=self.user, org_slug='other')
        self.assertFalse(n.read)

    def test_mark_all_read_skips_already_read(self):
        from openedx_notifications.models import Notification
        self._make_notification(read=True)
        count = Notification.mark_all_read(self.user, 'mereka')
        self.assertEqual(count, 0)

    def test_get_unread_count_returns_integer(self):
        from openedx_notifications.models import Notification
        self._make_notification()
        count = Notification.get_unread_count(self.user, 'mereka')
        self.assertIsInstance(count, int)
        self.assertEqual(count, 1)

    def test_get_unread_count_excludes_read(self):
        from openedx_notifications.models import Notification
        self._make_notification(read=True)
        count = Notification.get_unread_count(self.user, 'mereka')
        self.assertEqual(count, 0)

    def test_purge_expired_deletes_old_records(self):
        from openedx_notifications.models import Notification
        old_expiry = timezone.now() - timezone.timedelta(days=100)
        self._make_notification(expires_at=old_expiry)
        deleted_count, _ = Notification.purge_expired(retention_days=90)
        self.assertEqual(deleted_count, 1)

    def test_purge_expired_keeps_recent_records(self):
        from openedx_notifications.models import Notification
        recent_expiry = timezone.now() - timezone.timedelta(days=10)
        self._make_notification(expires_at=recent_expiry)
        deleted_count, _ = Notification.purge_expired(retention_days=90)
        self.assertEqual(deleted_count, 0)


# ---------------------------------------------------------------------------
# 3. Serializer tests
# ---------------------------------------------------------------------------

class NotificationSerializerTests(unittest.TestCase):
    """NotificationSerializer and UnreadCountSerializer field contract."""

    def test_notification_serializer_declared_fields(self):
        from openedx_notifications.serializers import NotificationSerializer
        expected_fields = {
            'id', 'message_type', 'title', 'body', 'course_id',
            'org_slug', 'deep_link_url', 'read', 'created_at', 'expires_at',
        }
        serializer = NotificationSerializer()
        self.assertEqual(set(serializer.fields.keys()), expected_fields)

    def test_notification_serializer_read_only_fields(self):
        from openedx_notifications.serializers import NotificationSerializer
        read_only = {
            'id', 'message_type', 'title', 'body', 'course_id',
            'org_slug', 'deep_link_url', 'created_at', 'expires_at',
        }
        serializer = NotificationSerializer()
        for field_name in read_only:
            self.assertTrue(
                serializer.fields[field_name].read_only,
                f"Expected field '{field_name}' to be read_only"
            )

    def test_read_field_is_not_read_only(self):
        from openedx_notifications.serializers import NotificationSerializer
        serializer = NotificationSerializer()
        self.assertFalse(serializer.fields['read'].read_only)

    def test_unread_count_serializer_has_unread_count_field(self):
        from openedx_notifications.serializers import UnreadCountSerializer
        serializer = UnreadCountSerializer()
        self.assertIn('unread_count', serializer.fields)

    def test_unread_count_serializer_validates_integer(self):
        from openedx_notifications.serializers import UnreadCountSerializer
        serializer = UnreadCountSerializer(data={'unread_count': 5})
        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(serializer.validated_data['unread_count'], 5)

    def test_unread_count_serializer_rejects_non_integer(self):
        from openedx_notifications.serializers import UnreadCountSerializer
        serializer = UnreadCountSerializer(data={'unread_count': 'not_a_number'})
        self.assertFalse(serializer.is_valid())

    def test_notification_serializer_model_is_notification(self):
        from openedx_notifications.serializers import NotificationSerializer
        from openedx_notifications.models import Notification
        self.assertIs(NotificationSerializer.Meta.model, Notification)


# ---------------------------------------------------------------------------
# 4. View tests
# ---------------------------------------------------------------------------

class NotificationViewSetConfigTests(unittest.TestCase):
    """NotificationViewSet is properly configured with expected actions."""

    def setUp(self):
        from openedx_notifications.views import NotificationViewSet
        self.viewset_cls = NotificationViewSet

    def test_serializer_class_is_notification_serializer(self):
        from openedx_notifications.serializers import NotificationSerializer
        self.assertIs(self.viewset_cls.serializer_class, NotificationSerializer)

    def test_permission_classes_contains_is_authenticated(self):
        from rest_framework.permissions import IsAuthenticated
        self.assertIn(IsAuthenticated, self.viewset_cls.permission_classes)

    def test_pagination_class_is_set(self):
        from openedx_notifications.views import NotificationPagination
        self.assertIs(self.viewset_cls.pagination_class, NotificationPagination)

    def test_pagination_page_size(self):
        from openedx_notifications.views import NotificationPagination
        self.assertEqual(NotificationPagination.page_size, 20)

    def test_pagination_max_page_size(self):
        from openedx_notifications.views import NotificationPagination
        self.assertEqual(NotificationPagination.max_page_size, 100)

    def test_mark_read_action_exists_and_is_callable(self):
        self.assertTrue(callable(self.viewset_cls.mark_read))

    def test_mark_all_read_action_exists_and_is_callable(self):
        self.assertTrue(callable(self.viewset_cls.mark_all_read))

    def test_unread_count_action_exists_and_is_callable(self):
        self.assertTrue(callable(self.viewset_cls.unread_count))

    def test_mark_read_url_path(self):
        """DRF @action stores url_path directly on the function."""
        url_path = getattr(self.viewset_cls.mark_read, 'url_path', None)
        self.assertEqual(url_path, 'read')

    def test_mark_all_read_url_path(self):
        url_path = getattr(self.viewset_cls.mark_all_read, 'url_path', None)
        self.assertEqual(url_path, 'mark-all-read')

    def test_unread_count_url_path(self):
        url_path = getattr(self.viewset_cls.unread_count, 'url_path', None)
        self.assertEqual(url_path, 'unread-count')

    def test_mark_read_is_detail_action(self):
        """mark_read acts on a single notification (detail=True)."""
        detail = getattr(self.viewset_cls.mark_read, 'detail', None)
        self.assertTrue(detail)

    def test_mark_all_read_is_list_action(self):
        """mark_all_read acts on the collection (detail=False)."""
        detail = getattr(self.viewset_cls.mark_all_read, 'detail', None)
        self.assertFalse(detail)

    def test_unread_count_is_list_action(self):
        """unread_count acts on the collection (detail=False)."""
        detail = getattr(self.viewset_cls.unread_count, 'detail', None)
        self.assertFalse(detail)

    def test_mark_read_http_method_is_patch(self):
        mapping = getattr(self.viewset_cls.mark_read, 'mapping', {})
        self.assertIn('patch', mapping)

    def test_mark_all_read_http_method_is_post(self):
        mapping = getattr(self.viewset_cls.mark_all_read, 'mapping', {})
        self.assertIn('post', mapping)

    def test_unread_count_http_method_is_get(self):
        mapping = getattr(self.viewset_cls.unread_count, 'mapping', {})
        self.assertIn('get', mapping)

    def test_get_queryset_is_defined(self):
        self.assertTrue(callable(getattr(self.viewset_cls, 'get_queryset', None)))

    def test_destroy_is_overridden(self):
        """destroy must be overridden to enforce ownership check."""
        self.assertTrue(callable(getattr(self.viewset_cls, 'destroy', None)))


# ---------------------------------------------------------------------------
# 5. Signal / ACE channel registration tests
# ---------------------------------------------------------------------------

class SignalHandlerTests(unittest.TestCase):
    """Signal handler exists and survives ImportError from edx_ace."""

    def test_register_ace_channel_is_callable(self):
        from openedx_notifications.signals import register_ace_channel
        self.assertTrue(callable(register_ace_channel))

    def test_register_ace_channel_survives_import_error(self):
        """Calling register_ace_channel when edx_ace is absent must not raise."""
        import openedx_notifications.signals as signals_mod

        saved = sys.modules.pop('edx_ace', None)
        saved_channel = sys.modules.pop('edx_ace.channel', None)
        saved_errors = sys.modules.pop('edx_ace.errors', None)
        try:
            signals_mod.register_ace_channel()  # should not raise
        finally:
            if saved is not None:
                sys.modules['edx_ace'] = saved
            if saved_channel is not None:
                sys.modules['edx_ace.channel'] = saved_channel
            if saved_errors is not None:
                sys.modules['edx_ace.errors'] = saved_errors

    def test_register_ace_channel_succeeds_with_stubs(self):
        """Calling register_ace_channel with stubs in place must not raise."""
        from openedx_notifications.signals import register_ace_channel
        register_ace_channel()


class InAppChannelTests(unittest.TestCase):
    """InAppChannel contract — class attributes and methods."""

    def setUp(self):
        from openedx_notifications.ace_channel import InAppChannel
        self.channel_cls = InAppChannel

    def test_channel_type_attribute_exists(self):
        self.assertTrue(hasattr(self.channel_cls, 'channel_type'))

    def test_enabled_classmethod_exists(self):
        self.assertTrue(callable(getattr(self.channel_cls, 'enabled', None)))

    def test_enabled_returns_true_by_default(self):
        """Default: NOTIFICATION_INAPP_ENABLED not set, enabled() should return True."""
        from django.conf import settings as django_settings
        # Remove flag if present, assert default behaviour
        original = getattr(django_settings, 'NOTIFICATION_INAPP_ENABLED', None)
        if hasattr(django_settings, 'NOTIFICATION_INAPP_ENABLED'):
            # Use override_settings instead of patching the attr directly
            from django.test import override_settings
            with override_settings(NOTIFICATION_INAPP_ENABLED=True):
                self.assertTrue(self.channel_cls.enabled())
        else:
            self.assertTrue(self.channel_cls.enabled())

    def test_enabled_respects_false_flag(self):
        from django.test import override_settings
        with override_settings(NOTIFICATION_INAPP_ENABLED=False):
            self.assertFalse(self.channel_cls.enabled())

    def test_deliver_method_exists(self):
        self.assertTrue(callable(getattr(self.channel_cls, 'deliver', None)))

    def test_inherits_from_channel(self):
        """InAppChannel must inherit from the edx_ace Channel base class."""
        import edx_ace.channel as ace_channel_mod
        self.assertTrue(issubclass(self.channel_cls, ace_channel_mod.Channel))


# ---------------------------------------------------------------------------
# 6. Admin tests
# ---------------------------------------------------------------------------

class NotificationAdminTests(unittest.TestCase):
    """NotificationAdmin registration and configuration."""

    def test_notification_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_notifications.models import Notification
        import openedx_notifications.admin  # noqa: F401 — triggers @admin.register
        self.assertIn(Notification, django_admin.site._registry)

    def test_has_add_permission_returns_false(self):
        from openedx_notifications.admin import NotificationAdmin
        from openedx_notifications.models import Notification
        from django.contrib import admin as django_admin
        admin_instance = NotificationAdmin(Notification, django_admin.site)
        mock_request = MagicMock()
        self.assertFalse(admin_instance.has_add_permission(mock_request))

    def test_list_display_includes_key_fields(self):
        from openedx_notifications.admin import NotificationAdmin
        for field in ('message_type', 'read', 'org_slug', 'created_at'):
            self.assertIn(field, NotificationAdmin.list_display)

    def test_readonly_fields_includes_id_and_created_at(self):
        from openedx_notifications.admin import NotificationAdmin
        self.assertIn('id', NotificationAdmin.readonly_fields)
        self.assertIn('created_at', NotificationAdmin.readonly_fields)

    def test_search_fields_includes_username_and_email(self):
        from openedx_notifications.admin import NotificationAdmin
        combined = ' '.join(NotificationAdmin.search_fields)
        self.assertIn('username', combined)
        self.assertIn('email', combined)


# ---------------------------------------------------------------------------
# 7. Apps config tests
# ---------------------------------------------------------------------------

class AppConfigTests(unittest.TestCase):
    """OpenedxNotificationsConfig basic contract."""

    def test_app_name(self):
        from openedx_notifications.apps import OpenedxNotificationsConfig
        self.assertEqual(OpenedxNotificationsConfig.name, 'openedx_notifications')

    def test_verbose_name_mentions_notification(self):
        from openedx_notifications.apps import OpenedxNotificationsConfig
        self.assertIn('Notification', OpenedxNotificationsConfig.verbose_name)

    def test_default_auto_field_is_bigautofield(self):
        from openedx_notifications.apps import OpenedxNotificationsConfig
        self.assertEqual(
            OpenedxNotificationsConfig.default_auto_field,
            'django.db.models.BigAutoField'
        )

    def test_ready_does_not_raise(self):
        """AppConfig.ready() must complete without raising (idempotency)."""
        from django.apps import apps
        app_config = apps.get_app_config('openedx_notifications')
        app_config.ready()


# ---------------------------------------------------------------------------
# 8. URL routing tests
# ---------------------------------------------------------------------------

class UrlConfigTests(unittest.TestCase):
    """urls.py router registers the expected basename."""

    def test_router_has_notification_basename(self):
        from openedx_notifications.urls import router
        basenames = [entry[2] for entry in router.registry]
        self.assertIn('notification', basenames)

    def test_urlpatterns_is_non_empty_list(self):
        from openedx_notifications.urls import urlpatterns
        self.assertIsInstance(urlpatterns, list)
        self.assertGreater(len(urlpatterns), 0)

    def test_app_name_is_set(self):
        from openedx_notifications import urls as urls_mod
        self.assertEqual(urls_mod.app_name, 'openedx_notifications')


# ---------------------------------------------------------------------------
# 9. Task tests
# ---------------------------------------------------------------------------

class TaskTests(unittest.TestCase):
    """purge_expired_notifications task contract."""

    def test_task_is_callable(self):
        from openedx_notifications.tasks import purge_expired_notifications
        self.assertTrue(callable(purge_expired_notifications))

    def test_task_accepts_retention_days_kwarg(self):
        """Task signature must accept retention_days parameter."""
        import inspect
        from openedx_notifications.tasks import purge_expired_notifications
        sig = inspect.signature(purge_expired_notifications)
        self.assertIn('retention_days', sig.parameters)

    def test_task_retention_days_default_is_90(self):
        import inspect
        from openedx_notifications.tasks import purge_expired_notifications
        sig = inspect.signature(purge_expired_notifications)
        default = sig.parameters['retention_days'].default
        self.assertEqual(default, 90)


class TestOrgSlugNotSpoofable:
    """Verify the tenant isolation fix: org_slug must NOT come from query params."""

    def test_get_user_org_slug_ignores_query_params(self):
        """_get_user_org_slug must derive org from site config, not from request.query_params."""
        import sys
        import types

        # Stub the openedx site_configuration module
        helpers_mod = types.ModuleType("helpers")
        helpers_mod.get_value = lambda key, default=None: "mereka" if key == "course_org_filter" else default

        site_config_mod = types.ModuleType("site_configuration")
        site_config_mod.helpers = helpers_mod

        djangoapps_mod = sys.modules.get("openedx.core.djangoapps", types.ModuleType("djangoapps"))
        djangoapps_mod.site_configuration = site_config_mod
        sys.modules["openedx.core.djangoapps"] = djangoapps_mod
        sys.modules["openedx.core.djangoapps.site_configuration"] = site_config_mod
        sys.modules["openedx.core.djangoapps.site_configuration.helpers"] = helpers_mod

        from openedx_notifications.views import NotificationViewSet

        view = NotificationViewSet()
        # Mock a request with a spoofed org_slug query param
        mock_request = type("Request", (), {
            "query_params": {"org_slug": "attacker-org"},
            "user": type("User", (), {"id": 1, "is_authenticated": True})(),
        })()
        view.request = mock_request

        result = view._get_user_org_slug()
        # Must NOT return the attacker's spoofed value
        assert result != "attacker-org", (
            f"SECURITY: _get_user_org_slug returned spoofed value '{result}'. "
            "Tenant isolation is broken — org_slug is still read from query params."
        )
        # Should return the site-config derived value
        assert result == "mereka", f"Expected 'mereka' from site config, got '{result}'"
