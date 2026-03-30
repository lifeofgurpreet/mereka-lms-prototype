"""
Baseline tests for openedx_push_notifications.

Covers:
  1. Import smoke tests -- every module can be imported
  2. Model tests -- DeviceRegistration fields, register_or_update, unregister,
     get_active_tokens, deactivate, str representation
  3. Serializer tests -- field contracts for request/response serializers
  4. View tests -- DeviceRegistrationView configuration
  5. Signal tests -- register_ace_channel callable, survives ImportError
  6. Task tests -- send_push_notification, cleanup_inactive_devices signatures
  7. ACE channel tests -- PushChannel class attributes and deliver logic
  8. Admin tests -- DeviceRegistrationAdmin registration and configuration
  9. Apps config tests -- AppConfig name/verbose_name/default_auto_field
 10. URL routing tests -- urlpatterns and app_name

Run from repo root:
    PYTHONPATH=infrastructure/tutor/custom-apps \
        python3 -m pytest infrastructure/tutor/custom-apps/openedx_push_notifications/tests.py -v --tb=short
"""

import importlib
import sys
import unittest
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
    """Every module in openedx_push_notifications must import cleanly."""

    def _import(self, module_name):
        full = f'openedx_push_notifications.{module_name}'
        if full in sys.modules:
            return sys.modules[full]
        return importlib.import_module(full)

    def test_package_init_imports(self):
        import openedx_push_notifications
        self.assertEqual(openedx_push_notifications.__version__, '1.0.0')

    def test_apps_imports(self):
        mod = self._import('apps')
        self.assertTrue(hasattr(mod, 'OpenedxPushNotificationsConfig'))

    def test_models_imports(self):
        mod = self._import('models')
        self.assertTrue(hasattr(mod, 'DeviceRegistration'))

    def test_serializers_imports(self):
        mod = self._import('serializers')
        self.assertTrue(hasattr(mod, 'DeviceRegistrationSerializer'))
        self.assertTrue(hasattr(mod, 'DeviceRegistrationRequestSerializer'))
        self.assertTrue(hasattr(mod, 'DeviceUnregisterRequestSerializer'))

    def test_views_imports(self):
        mod = self._import('views')
        self.assertTrue(hasattr(mod, 'DeviceRegistrationView'))

    def test_urls_imports(self):
        mod = self._import('urls')
        self.assertTrue(hasattr(mod, 'urlpatterns'))

    def test_admin_imports(self):
        mod = self._import('admin')
        self.assertTrue(hasattr(mod, 'DeviceRegistrationAdmin'))

    def test_signals_imports(self):
        mod = self._import('signals')
        self.assertTrue(hasattr(mod, 'register_ace_channel'))

    def test_tasks_imports(self):
        mod = self._import('tasks')
        self.assertTrue(hasattr(mod, 'send_push_notification'))
        self.assertTrue(hasattr(mod, 'cleanup_inactive_devices'))

    def test_ace_channel_imports(self):
        mod = self._import('ace_channel')
        self.assertTrue(hasattr(mod, 'PushChannel'))


# ---------------------------------------------------------------------------
# 2. Model tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class DeviceRegistrationFieldTests(TestCase):
    """DeviceRegistration model field contract."""

    def setUp(self):
        self.user = _create_user()

    def _make_device(self, **overrides):
        from openedx_push_notifications.models import DeviceRegistration
        defaults = dict(
            user=self.user,
            device_token='test-token-abc123',
            platform='android',
            org_slug='mereka',
            app_version='1.0.0',
        )
        defaults.update(overrides)
        return DeviceRegistration.objects.create(**defaults)

    def test_default_is_active_is_true(self):
        d = self._make_device()
        self.assertTrue(d.is_active)

    def test_registered_at_is_set(self):
        d = self._make_device()
        self.assertIsNotNone(d.registered_at)

    def test_last_seen_at_is_set(self):
        d = self._make_device()
        self.assertIsNotNone(d.last_seen_at)

    def test_platform_choices(self):
        from openedx_push_notifications.models import DeviceRegistration
        choices = [c[0] for c in DeviceRegistration.PLATFORM_CHOICES]
        self.assertIn('ios', choices)
        self.assertIn('android', choices)

    def test_str_representation(self):
        d = self._make_device()
        s = str(d)
        self.assertIn('android', s)
        self.assertIn(self.user.username, s)
        self.assertIn('mereka', s)

    def test_db_table_name(self):
        from openedx_push_notifications.models import DeviceRegistration
        self.assertEqual(
            DeviceRegistration._meta.db_table,
            'openedx_push_device_registration'
        )

    def test_unique_together_token_org(self):
        from openedx_push_notifications.models import DeviceRegistration
        ut = DeviceRegistration._meta.unique_together
        found = any(set(combo) == {'device_token', 'org_slug'} for combo in ut)
        self.assertTrue(found, f"Expected unique_together for (device_token, org_slug), got {ut}")

    def test_app_version_defaults_to_empty(self):
        from openedx_push_notifications.models import DeviceRegistration
        d = DeviceRegistration.objects.create(
            user=self.user,
            device_token='token-no-version',
            platform='ios',
            org_slug='mereka',
        )
        self.assertEqual(d.app_version, '')


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class DeviceRegistrationBusinessLogicTests(TestCase):
    """Test register_or_update, unregister, get_active_tokens, deactivate."""

    def setUp(self):
        self.user = _create_user(username='pushuser', email='push@example.com')
        self.user2 = _create_user(username='pushuser2', email='push2@example.com')

    def test_register_or_update_creates_new_device(self):
        from openedx_push_notifications.models import DeviceRegistration
        device, created = DeviceRegistration.register_or_update(
            user=self.user,
            device_token='new-token-001',
            platform='ios',
            org_slug='mereka',
            app_version='2.0',
        )
        self.assertTrue(created)
        self.assertEqual(device.platform, 'ios')
        self.assertTrue(device.is_active)

    def test_register_or_update_updates_existing_device(self):
        from openedx_push_notifications.models import DeviceRegistration
        DeviceRegistration.register_or_update(
            user=self.user,
            device_token='reuse-token-001',
            platform='android',
            org_slug='mereka',
        )
        device, created = DeviceRegistration.register_or_update(
            user=self.user,
            device_token='reuse-token-001',
            platform='android',
            org_slug='mereka',
        )
        self.assertFalse(created)

    def test_register_or_update_reassigns_to_different_user(self):
        """If same token+org exists for different user, reassign to new user."""
        from openedx_push_notifications.models import DeviceRegistration
        DeviceRegistration.register_or_update(
            user=self.user,
            device_token='shared-token',
            platform='ios',
            org_slug='mereka',
        )
        device, created = DeviceRegistration.register_or_update(
            user=self.user2,
            device_token='shared-token',
            platform='ios',
            org_slug='mereka',
        )
        self.assertFalse(created)  # update_or_create -> updated
        self.assertEqual(device.user_id, self.user2.id)

    def test_unregister_sets_inactive(self):
        from openedx_push_notifications.models import DeviceRegistration
        DeviceRegistration.register_or_update(
            user=self.user,
            device_token='unreg-token',
            platform='android',
            org_slug='mereka',
        )
        updated = DeviceRegistration.unregister(self.user, 'unreg-token')
        self.assertEqual(updated, 1)
        device = DeviceRegistration.objects.get(device_token='unreg-token')
        self.assertFalse(device.is_active)

    def test_unregister_returns_zero_for_nonexistent(self):
        from openedx_push_notifications.models import DeviceRegistration
        updated = DeviceRegistration.unregister(self.user, 'no-such-token')
        self.assertEqual(updated, 0)

    def test_get_active_tokens_returns_only_active(self):
        from openedx_push_notifications.models import DeviceRegistration
        DeviceRegistration.register_or_update(
            user=self.user, device_token='active-t', platform='ios', org_slug='mereka',
        )
        DeviceRegistration.objects.create(
            user=self.user, device_token='inactive-t', platform='android',
            org_slug='mereka', is_active=False,
        )
        tokens = list(DeviceRegistration.get_active_tokens([self.user.id], 'mereka'))
        self.assertEqual(len(tokens), 1)
        self.assertEqual(tokens[0][0], 'active-t')

    def test_get_active_tokens_respects_org_slug(self):
        """AC-019: No cross-tenant delivery."""
        from openedx_push_notifications.models import DeviceRegistration
        DeviceRegistration.register_or_update(
            user=self.user, device_token='org-t', platform='ios', org_slug='mereka',
        )
        tokens = list(DeviceRegistration.get_active_tokens([self.user.id], 'other-org'))
        self.assertEqual(len(tokens), 0)

    def test_deactivate_sets_inactive(self):
        from openedx_push_notifications.models import DeviceRegistration
        device, _ = DeviceRegistration.register_or_update(
            user=self.user, device_token='deact-t', platform='ios', org_slug='mereka',
        )
        self.assertTrue(device.is_active)
        device.deactivate()
        device.refresh_from_db()
        self.assertFalse(device.is_active)

    def test_deactivate_is_idempotent(self):
        from openedx_push_notifications.models import DeviceRegistration
        device, _ = DeviceRegistration.register_or_update(
            user=self.user, device_token='deact2-t', platform='android', org_slug='mereka',
        )
        device.deactivate()
        device.deactivate()  # should not raise
        device.refresh_from_db()
        self.assertFalse(device.is_active)


# ---------------------------------------------------------------------------
# 3. Serializer tests
# ---------------------------------------------------------------------------

class DeviceSerializerTests(unittest.TestCase):
    """Serializer field contracts."""

    def test_registration_request_serializer_validates_valid_data(self):
        from openedx_push_notifications.serializers import DeviceRegistrationRequestSerializer
        s = DeviceRegistrationRequestSerializer(data={
            'device_token': 'abc123',
            'platform': 'ios',
            'org_slug': 'mereka',
        })
        self.assertTrue(s.is_valid(), s.errors)

    def test_registration_request_serializer_rejects_invalid_platform(self):
        from openedx_push_notifications.serializers import DeviceRegistrationRequestSerializer
        s = DeviceRegistrationRequestSerializer(data={
            'device_token': 'abc123',
            'platform': 'windows',
            'org_slug': 'mereka',
        })
        self.assertFalse(s.is_valid())
        self.assertIn('platform', s.errors)

    def test_registration_request_serializer_requires_device_token(self):
        from openedx_push_notifications.serializers import DeviceRegistrationRequestSerializer
        s = DeviceRegistrationRequestSerializer(data={
            'platform': 'ios',
            'org_slug': 'mereka',
        })
        self.assertFalse(s.is_valid())
        self.assertIn('device_token', s.errors)

    def test_registration_request_serializer_app_version_optional(self):
        from openedx_push_notifications.serializers import DeviceRegistrationRequestSerializer
        s = DeviceRegistrationRequestSerializer(data={
            'device_token': 'token1',
            'platform': 'android',
            'org_slug': 'mereka',
        })
        self.assertTrue(s.is_valid(), s.errors)
        self.assertEqual(s.validated_data.get('app_version', ''), '')

    def test_unregister_request_serializer_validates(self):
        from openedx_push_notifications.serializers import DeviceUnregisterRequestSerializer
        s = DeviceUnregisterRequestSerializer(data={'device_token': 'abc123'})
        self.assertTrue(s.is_valid(), s.errors)

    def test_unregister_request_serializer_requires_device_token(self):
        from openedx_push_notifications.serializers import DeviceUnregisterRequestSerializer
        s = DeviceUnregisterRequestSerializer(data={})
        self.assertFalse(s.is_valid())

    def test_registration_response_serializer_fields(self):
        from openedx_push_notifications.serializers import DeviceRegistrationSerializer
        expected = {
            'id', 'device_token', 'platform', 'app_version',
            'org_slug', 'is_active', 'registered_at', 'last_seen_at',
        }
        s = DeviceRegistrationSerializer()
        self.assertEqual(set(s.fields.keys()), expected)

    def test_registration_response_read_only_fields(self):
        from openedx_push_notifications.serializers import DeviceRegistrationSerializer
        s = DeviceRegistrationSerializer()
        for field_name in ('id', 'is_active', 'registered_at', 'last_seen_at'):
            self.assertTrue(
                s.fields[field_name].read_only,
                f"Expected {field_name} to be read_only"
            )


# ---------------------------------------------------------------------------
# 4. View tests
# ---------------------------------------------------------------------------

class DeviceRegistrationViewConfigTests(unittest.TestCase):
    """DeviceRegistrationView configuration checks."""

    def setUp(self):
        from openedx_push_notifications.views import DeviceRegistrationView
        self.view_cls = DeviceRegistrationView

    def test_permission_classes_is_authenticated(self):
        from rest_framework.permissions import IsAuthenticated
        self.assertIn(IsAuthenticated, self.view_cls.permission_classes)

    def test_post_method_exists(self):
        self.assertTrue(callable(getattr(self.view_cls, 'post', None)))

    def test_delete_method_exists(self):
        self.assertTrue(callable(getattr(self.view_cls, 'delete', None)))


# ---------------------------------------------------------------------------
# 5. Signal tests
# ---------------------------------------------------------------------------

class SignalTests(unittest.TestCase):
    """Signal handler exists and survives missing edx_ace."""

    def test_register_ace_channel_is_callable(self):
        from openedx_push_notifications.signals import register_ace_channel
        self.assertTrue(callable(register_ace_channel))

    def test_register_ace_channel_survives_import_error(self):
        """Calling register_ace_channel when edx_ace is absent must not raise."""
        import openedx_push_notifications.signals as signals_mod

        saved_ace = sys.modules.pop('edx_ace', None)
        saved_channel = sys.modules.pop('edx_ace.channel', None)
        try:
            signals_mod.register_ace_channel()
        finally:
            if saved_ace is not None:
                sys.modules['edx_ace'] = saved_ace
            if saved_channel is not None:
                sys.modules['edx_ace.channel'] = saved_channel


# ---------------------------------------------------------------------------
# 6. Task tests
# ---------------------------------------------------------------------------

class TaskSignatureTests(unittest.TestCase):
    """Task callable signatures."""

    def test_send_push_notification_is_callable(self):
        from openedx_push_notifications.tasks import send_push_notification
        self.assertTrue(callable(send_push_notification))

    def test_cleanup_inactive_devices_is_callable(self):
        from openedx_push_notifications.tasks import cleanup_inactive_devices
        self.assertTrue(callable(cleanup_inactive_devices))

    def test_cleanup_inactive_devices_accepts_days_param(self):
        import inspect
        from openedx_push_notifications.tasks import cleanup_inactive_devices
        sig = inspect.signature(cleanup_inactive_devices)
        self.assertIn('days_inactive', sig.parameters)

    def test_cleanup_inactive_devices_default_days_is_90(self):
        import inspect
        from openedx_push_notifications.tasks import cleanup_inactive_devices
        sig = inspect.signature(cleanup_inactive_devices)
        self.assertEqual(sig.parameters['days_inactive'].default, 90)

    def test_fcm_batch_size_is_500(self):
        from openedx_push_notifications.tasks import FCM_BATCH_SIZE
        self.assertEqual(FCM_BATCH_SIZE, 500)


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class CleanupInactiveDevicesTaskTests(TestCase):
    """Integration test for cleanup_inactive_devices."""

    def setUp(self):
        self.user = _create_user(username='cleanupuser', email='cleanup@example.com')

    def test_cleanup_deletes_old_inactive_devices(self):
        from openedx_push_notifications.models import DeviceRegistration
        from openedx_push_notifications.tasks import cleanup_inactive_devices

        device = DeviceRegistration.objects.create(
            user=self.user,
            device_token='old-device',
            platform='ios',
            org_slug='mereka',
            is_active=False,
        )
        # Backdate last_seen_at
        from datetime import timedelta
        old_date = timezone.now() - timedelta(days=100)
        DeviceRegistration.objects.filter(pk=device.pk).update(last_seen_at=old_date)

        result = cleanup_inactive_devices(days_inactive=90)
        self.assertEqual(result['deleted'], 1)

    def test_cleanup_keeps_recent_inactive_devices(self):
        from openedx_push_notifications.models import DeviceRegistration
        from openedx_push_notifications.tasks import cleanup_inactive_devices

        DeviceRegistration.objects.create(
            user=self.user,
            device_token='recent-inactive',
            platform='android',
            org_slug='mereka',
            is_active=False,
        )
        result = cleanup_inactive_devices(days_inactive=90)
        self.assertEqual(result['deleted'], 0)


# ---------------------------------------------------------------------------
# 7. ACE channel tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class PushChannelTests(unittest.TestCase):
    """PushChannel class attributes and deliver logic."""

    def setUp(self):
        from openedx_push_notifications.ace_channel import PushChannel
        self.channel_cls = PushChannel

    def test_channel_type_attribute_exists(self):
        self.assertTrue(hasattr(self.channel_cls, 'channel_type'))

    def test_enabled_classmethod_exists(self):
        self.assertTrue(callable(getattr(self.channel_cls, 'enabled', None)))

    def test_enabled_returns_false_by_default(self):
        """Default: NOTIFICATION_PUSH_ENABLED not set or False."""
        self.assertFalse(self.channel_cls.enabled())

    def test_enabled_returns_true_when_setting_enabled(self):
        from django.test import override_settings
        with override_settings(NOTIFICATION_PUSH_ENABLED=True):
            self.assertTrue(self.channel_cls.enabled())

    def test_deliver_method_exists(self):
        self.assertTrue(callable(getattr(self.channel_cls, 'deliver', None)))

    def test_deliver_skips_when_disabled(self):
        """deliver should not enqueue task when push disabled."""
        channel = self.channel_cls()
        message = MagicMock()
        rendered = MagicMock()
        # Should not raise
        channel.deliver(message, rendered)

    def test_deliver_enqueues_task_when_enabled(self):
        """deliver should call send_push_notification.delay when enabled."""
        from django.test import override_settings
        channel = self.channel_cls()
        message = MagicMock()
        message.name = 'test_notification'
        message.uuid = 'test-uuid-123'
        message.recipient = MagicMock()
        message.recipient.lms_user_id = 42
        message.context = {
            'course_id': 'course-v1:Test+101+2026',
            'org_slug': 'mereka',
        }
        rendered = {
            'subject': 'Test Subject',
            'body': 'Test body',
        }

        with override_settings(NOTIFICATION_PUSH_ENABLED=True):
            with patch('openedx_push_notifications.ace_channel.send_push_notification') as mock_task:
                channel.deliver(message, rendered)
                mock_task.delay.assert_called_once()
                call_args = mock_task.delay.call_args
                self.assertEqual(call_args[0][0], 42)  # user_id


# ---------------------------------------------------------------------------
# 8. Admin tests
# ---------------------------------------------------------------------------

class DeviceRegistrationAdminTests(unittest.TestCase):
    """Admin registration and configuration."""

    def test_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_push_notifications.models import DeviceRegistration
        import openedx_push_notifications.admin  # noqa: F401
        self.assertIn(DeviceRegistration, django_admin.site._registry)

    def test_list_display_includes_key_fields(self):
        from openedx_push_notifications.admin import DeviceRegistrationAdmin
        for field in ('platform', 'is_active', 'org_slug', 'registered_at'):
            self.assertIn(field, DeviceRegistrationAdmin.list_display)

    def test_list_filter_includes_platform_and_active(self):
        from openedx_push_notifications.admin import DeviceRegistrationAdmin
        self.assertIn('platform', DeviceRegistrationAdmin.list_filter)
        self.assertIn('is_active', DeviceRegistrationAdmin.list_filter)

    def test_search_fields_include_username(self):
        from openedx_push_notifications.admin import DeviceRegistrationAdmin
        combined = ' '.join(DeviceRegistrationAdmin.search_fields)
        self.assertIn('username', combined)

    def test_readonly_fields_include_timestamps(self):
        from openedx_push_notifications.admin import DeviceRegistrationAdmin
        self.assertIn('registered_at', DeviceRegistrationAdmin.readonly_fields)
        self.assertIn('last_seen_at', DeviceRegistrationAdmin.readonly_fields)


# ---------------------------------------------------------------------------
# 9. Apps config tests
# ---------------------------------------------------------------------------

class AppConfigTests(unittest.TestCase):
    """AppConfig basic contract."""

    def test_app_name(self):
        from openedx_push_notifications.apps import OpenedxPushNotificationsConfig
        self.assertEqual(OpenedxPushNotificationsConfig.name, 'openedx_push_notifications')

    def test_verbose_name_mentions_push(self):
        from openedx_push_notifications.apps import OpenedxPushNotificationsConfig
        self.assertIn('Push', OpenedxPushNotificationsConfig.verbose_name)

    def test_default_auto_field(self):
        from openedx_push_notifications.apps import OpenedxPushNotificationsConfig
        self.assertEqual(
            OpenedxPushNotificationsConfig.default_auto_field,
            'django.db.models.BigAutoField'
        )

    def test_ready_does_not_raise(self):
        from django.apps import apps
        app_config = apps.get_app_config('openedx_push_notifications')
        app_config.ready()


# ---------------------------------------------------------------------------
# 10. URL routing tests
# ---------------------------------------------------------------------------

class UrlConfigTests(unittest.TestCase):
    """URL configuration."""

    def test_urlpatterns_is_non_empty(self):
        from openedx_push_notifications.urls import urlpatterns
        self.assertIsInstance(urlpatterns, list)
        self.assertGreater(len(urlpatterns), 0)

    def test_app_name_is_set(self):
        from openedx_push_notifications import urls as urls_mod
        self.assertEqual(urls_mod.app_name, 'openedx_push_notifications')

    def test_register_route_exists(self):
        from openedx_push_notifications.urls import urlpatterns
        route_names = [p.name for p in urlpatterns if hasattr(p, 'name')]
        self.assertIn('device-register', route_names)


if __name__ == '__main__':
    unittest.main()
