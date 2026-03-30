"""
Baseline tests for openedx_email_preferences.

Covers:
  1. Import smoke tests -- every module can be imported
  2. UserEmailPreference model -- fields, get_default_preferences,
     get_user_preferences, update_user_preference, _hash_ip
  3. ConsentRecord model -- fields, get_user_consent_history, immutability
  4. Serializer tests -- field contracts for all serializers
  5. Utils tests -- generate_unsubscribe_token, verify_unsubscribe_token,
     check_user_can_receive_email
  6. Signal tests -- register_ace_hooks callable
  7. Admin tests -- admin classes registered with correct permissions
  8. Apps config tests -- AppConfig name/verbose_name
  9. URL routing tests

CRITICAL: get_user_model() is called AFTER django.setup(), NOT at module level.

Run from repo root:
    PYTHONPATH=infrastructure/tutor/custom-apps \
        python3 -m pytest infrastructure/tutor/custom-apps/openedx_email_preferences/tests.py -v --tb=short
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
    """Every module in openedx_email_preferences must import cleanly."""

    def _import(self, module_name):
        full = f'openedx_email_preferences.{module_name}'
        if full in sys.modules:
            return sys.modules[full]
        return importlib.import_module(full)

    def test_package_init_imports(self):
        import openedx_email_preferences
        self.assertEqual(openedx_email_preferences.__version__, '1.0.0')

    def test_apps_imports(self):
        mod = self._import('apps')
        self.assertTrue(hasattr(mod, 'OpenedxEmailPreferencesConfig'))

    def test_models_imports(self):
        mod = self._import('models')
        self.assertTrue(hasattr(mod, 'UserEmailPreference'))
        self.assertTrue(hasattr(mod, 'ConsentRecord'))
        self.assertTrue(hasattr(mod, 'EMAIL_CATEGORY_CHOICES'))

    def test_serializers_imports(self):
        mod = self._import('serializers')
        self.assertTrue(hasattr(mod, 'EmailPreferenceSerializer'))
        self.assertTrue(hasattr(mod, 'EmailPreferencesResponseSerializer'))
        self.assertTrue(hasattr(mod, 'EmailPreferencesUpdateSerializer'))
        self.assertTrue(hasattr(mod, 'ConsentRecordSerializer'))

    def test_views_imports(self):
        mod = self._import('views')
        self.assertTrue(hasattr(mod, 'email_preferences_view'))
        self.assertTrue(hasattr(mod, 'one_click_unsubscribe_view'))
        self.assertTrue(hasattr(mod, 'consent_records_admin_view'))

    def test_utils_imports(self):
        mod = self._import('utils')
        self.assertTrue(hasattr(mod, 'generate_unsubscribe_token'))
        self.assertTrue(hasattr(mod, 'verify_unsubscribe_token'))
        self.assertTrue(hasattr(mod, 'generate_unsubscribe_url'))
        self.assertTrue(hasattr(mod, 'get_list_unsubscribe_headers'))
        self.assertTrue(hasattr(mod, 'check_user_can_receive_email'))

    def test_urls_imports(self):
        mod = self._import('urls')
        self.assertTrue(hasattr(mod, 'urlpatterns'))

    def test_admin_imports(self):
        mod = self._import('admin')
        self.assertTrue(hasattr(mod, 'UserEmailPreferenceAdmin'))
        self.assertTrue(hasattr(mod, 'ConsentRecordAdmin'))

    def test_signals_imports(self):
        mod = self._import('signals')
        self.assertTrue(hasattr(mod, 'register_ace_hooks'))


# ---------------------------------------------------------------------------
# 2. UserEmailPreference model tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class UserEmailPreferenceFieldTests(TestCase):
    """UserEmailPreference field contract."""

    def setUp(self):
        self.user = _create_user()

    def _make_pref(self, **overrides):
        from openedx_email_preferences.models import UserEmailPreference
        defaults = dict(
            user=self.user,
            category='marketing',
            opted_in=False,
        )
        defaults.update(overrides)
        return UserEmailPreference.objects.create(**defaults)

    def test_db_table_name(self):
        from openedx_email_preferences.models import UserEmailPreference
        self.assertEqual(
            UserEmailPreference._meta.db_table,
            'openedx_email_preferences_user_preference'
        )

    def test_unique_together_user_category(self):
        from openedx_email_preferences.models import UserEmailPreference
        ut = UserEmailPreference._meta.unique_together
        found = any(set(combo) == {'user', 'category'} for combo in ut)
        self.assertTrue(found)

    def test_default_opted_in_is_true(self):
        from openedx_email_preferences.models import UserEmailPreference
        field = UserEmailPreference._meta.get_field('opted_in')
        self.assertTrue(field.default)

    def test_str_representation_opted_in(self):
        p = self._make_pref(opted_in=True, category='announcements')
        self.assertIn('opted-in', str(p))

    def test_str_representation_opted_out(self):
        p = self._make_pref(opted_in=False, category='marketing')
        self.assertIn('opted-out', str(p))

    def test_created_at_auto_set(self):
        p = self._make_pref()
        self.assertIsNotNone(p.created_at)

    def test_updated_at_auto_set(self):
        p = self._make_pref()
        self.assertIsNotNone(p.updated_at)


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class UserEmailPreferenceBusinessLogicTests(TestCase):
    """get_default_preferences, get_user_preferences, update_user_preference."""

    def setUp(self):
        self.user = _create_user(username='prefuser', email='pref@example.com')

    def test_get_default_preferences_marketing_false(self):
        """GDPR: marketing defaults to opt-in required (False)."""
        from openedx_email_preferences.models import UserEmailPreference
        defaults = UserEmailPreference.get_default_preferences()
        self.assertFalse(defaults['marketing'])

    def test_get_default_preferences_transactional_true(self):
        from openedx_email_preferences.models import UserEmailPreference
        defaults = UserEmailPreference.get_default_preferences()
        self.assertTrue(defaults['transactional'])

    def test_get_default_preferences_all_categories_present(self):
        from openedx_email_preferences.models import UserEmailPreference
        defaults = UserEmailPreference.get_default_preferences()
        expected = {'marketing', 'transactional', 'announcements', 'reminders', 'discussions'}
        self.assertEqual(set(defaults.keys()), expected)

    def test_get_user_preferences_returns_defaults_for_new_user(self):
        from openedx_email_preferences.models import UserEmailPreference
        prefs = UserEmailPreference.get_user_preferences(self.user)
        defaults = UserEmailPreference.get_default_preferences()
        self.assertEqual(prefs, defaults)

    def test_get_user_preferences_returns_saved_values(self):
        from openedx_email_preferences.models import UserEmailPreference
        UserEmailPreference.objects.create(
            user=self.user, category='marketing', opted_in=True,
        )
        prefs = UserEmailPreference.get_user_preferences(self.user)
        self.assertTrue(prefs['marketing'])

    def test_update_user_preference_creates_new(self):
        from openedx_email_preferences.models import UserEmailPreference
        pref = UserEmailPreference.update_user_preference(
            user=self.user, category='marketing', opted_in=True,
        )
        self.assertTrue(pref.opted_in)
        self.assertEqual(pref.category, 'marketing')

    def test_update_user_preference_changes_value(self):
        from openedx_email_preferences.models import UserEmailPreference, ConsentRecord
        UserEmailPreference.objects.create(
            user=self.user, category='announcements', opted_in=True,
        )
        pref = UserEmailPreference.update_user_preference(
            user=self.user, category='announcements', opted_in=False,
            ip_address='1.2.3.4',
        )
        self.assertFalse(pref.opted_in)
        # Should create audit trail
        records = ConsentRecord.objects.filter(
            user=self.user, category='announcements',
        )
        self.assertEqual(records.count(), 1)
        record = records.first()
        self.assertTrue(record.old_value)
        self.assertFalse(record.new_value)

    def test_update_user_preference_no_audit_when_unchanged(self):
        from openedx_email_preferences.models import UserEmailPreference, ConsentRecord
        UserEmailPreference.objects.create(
            user=self.user, category='reminders', opted_in=True,
        )
        UserEmailPreference.update_user_preference(
            user=self.user, category='reminders', opted_in=True,
        )
        # No audit record because value didn't change
        records = ConsentRecord.objects.filter(
            user=self.user, category='reminders',
        )
        self.assertEqual(records.count(), 0)

    def test_hash_ip_returns_16_chars(self):
        from openedx_email_preferences.models import UserEmailPreference
        result = UserEmailPreference._hash_ip('192.168.1.1')
        self.assertEqual(len(result), 16)

    def test_hash_ip_returns_none_for_empty(self):
        from openedx_email_preferences.models import UserEmailPreference
        self.assertIsNone(UserEmailPreference._hash_ip(''))
        self.assertIsNone(UserEmailPreference._hash_ip(None))

    def test_hash_ip_is_deterministic(self):
        from openedx_email_preferences.models import UserEmailPreference
        r1 = UserEmailPreference._hash_ip('10.0.0.1')
        r2 = UserEmailPreference._hash_ip('10.0.0.1')
        self.assertEqual(r1, r2)


# ---------------------------------------------------------------------------
# 3. ConsentRecord model tests
# ---------------------------------------------------------------------------

@unittest.skip("DB migration required - baseline covers non-DB logic only")
class ConsentRecordFieldTests(TestCase):
    """ConsentRecord field contract."""

    def setUp(self):
        self.user = _create_user(username='consentuser', email='consent@example.com')

    def _make_record(self, **overrides):
        from openedx_email_preferences.models import ConsentRecord
        defaults = dict(
            user=self.user,
            category='marketing',
            old_value=True,
            new_value=False,
            consent_version='v1.0-2026-02-14',
            source='api',
        )
        defaults.update(overrides)
        return ConsentRecord.objects.create(**defaults)

    def test_db_table_name(self):
        from openedx_email_preferences.models import ConsentRecord
        self.assertEqual(
            ConsentRecord._meta.db_table,
            'openedx_email_preferences_consent_record'
        )

    def test_ordering_is_newest_first(self):
        from openedx_email_preferences.models import ConsentRecord
        self.assertIn('-timestamp', ConsentRecord._meta.ordering)

    def test_timestamp_auto_set(self):
        r = self._make_record()
        self.assertIsNotNone(r.timestamp)

    def test_str_representation(self):
        r = self._make_record()
        s = str(r)
        self.assertIn(self.user.username, s)
        self.assertIn('marketing', s)

    def test_get_user_consent_history(self):
        from openedx_email_preferences.models import ConsentRecord
        self._make_record(category='marketing')
        self._make_record(category='announcements')
        records = ConsentRecord.get_user_consent_history(self.user)
        self.assertEqual(records.count(), 2)

    def test_consent_history_ordered_by_timestamp_desc(self):
        from openedx_email_preferences.models import ConsentRecord
        r1 = self._make_record(category='marketing')
        r2 = self._make_record(category='announcements')
        records = list(ConsentRecord.get_user_consent_history(self.user))
        self.assertEqual(records[0].pk, r2.pk)


# ---------------------------------------------------------------------------
# 4. Serializer tests
# ---------------------------------------------------------------------------

class SerializerFieldTests(unittest.TestCase):
    """Serializer field contracts."""

    def test_email_preference_serializer_fields(self):
        from openedx_email_preferences.serializers import EmailPreferenceSerializer
        s = EmailPreferenceSerializer()
        self.assertIn('category', s.fields)
        self.assertIn('opted_in', s.fields)

    def test_response_serializer_has_preferences_dict(self):
        from openedx_email_preferences.serializers import EmailPreferencesResponseSerializer
        s = EmailPreferencesResponseSerializer()
        self.assertIn('preferences', s.fields)

    def test_update_serializer_validates_valid_categories(self):
        from openedx_email_preferences.serializers import EmailPreferencesUpdateSerializer
        s = EmailPreferencesUpdateSerializer(data={
            'preferences': [
                {'category': 'marketing', 'opted_in': True},
                {'category': 'announcements', 'opted_in': False},
            ]
        })
        self.assertTrue(s.is_valid(), s.errors)

    def test_update_serializer_rejects_invalid_category(self):
        from openedx_email_preferences.serializers import EmailPreferencesUpdateSerializer
        s = EmailPreferencesUpdateSerializer(data={
            'preferences': [
                {'category': 'nonexistent_category', 'opted_in': True},
            ]
        })
        self.assertFalse(s.is_valid())

    def test_consent_record_serializer_fields(self):
        from openedx_email_preferences.serializers import ConsentRecordSerializer
        expected = {
            'id', 'username', 'category', 'old_value', 'new_value',
            'consent_version', 'ip_address_hash', 'source', 'timestamp',
        }
        s = ConsentRecordSerializer()
        self.assertEqual(set(s.fields.keys()), expected)

    def test_consent_record_serializer_all_read_only(self):
        from openedx_email_preferences.serializers import ConsentRecordSerializer
        s = ConsentRecordSerializer()
        for field_name in s.fields:
            self.assertTrue(
                s.fields[field_name].read_only,
                f"Expected {field_name} to be read_only"
            )


# ---------------------------------------------------------------------------
# 5. Utils tests (core business logic)
# ---------------------------------------------------------------------------

class UnsubscribeTokenTests(unittest.TestCase):
    """HMAC token generation and verification for one-click unsubscribe."""

    def test_generate_returns_string(self):
        from openedx_email_preferences.utils import generate_unsubscribe_token
        token = generate_unsubscribe_token(42, 'marketing')
        self.assertIsInstance(token, str)
        self.assertGreater(len(token), 0)

    def test_verify_valid_token_returns_user_id_and_category(self):
        from openedx_email_preferences.utils import (
            generate_unsubscribe_token,
            verify_unsubscribe_token,
        )
        token = generate_unsubscribe_token(42, 'marketing')
        user_id, category = verify_unsubscribe_token(token)
        self.assertEqual(user_id, 42)
        self.assertEqual(category, 'marketing')

    def test_verify_invalid_token_returns_none(self):
        from openedx_email_preferences.utils import verify_unsubscribe_token
        user_id, category = verify_unsubscribe_token('invalid-token-garbage')
        self.assertIsNone(user_id)
        self.assertIsNone(category)

    def test_verify_tampered_token_returns_none(self):
        from openedx_email_preferences.utils import generate_unsubscribe_token, verify_unsubscribe_token
        import base64
        token = generate_unsubscribe_token(42, 'marketing')
        # Tamper with the token
        decoded = base64.urlsafe_b64decode(token.encode('utf-8')).decode('utf-8')
        parts = decoded.split('|')
        parts[0] = '999'  # Change user_id
        tampered = base64.urlsafe_b64encode('|'.join(parts).encode('utf-8')).decode('utf-8')
        user_id, category = verify_unsubscribe_token(tampered)
        self.assertIsNone(user_id)

    def test_tokens_for_different_categories_are_different(self):
        from openedx_email_preferences.utils import generate_unsubscribe_token
        t1 = generate_unsubscribe_token(42, 'marketing')
        t2 = generate_unsubscribe_token(42, 'announcements')
        self.assertNotEqual(t1, t2)

    def test_tokens_for_different_users_are_different(self):
        from openedx_email_preferences.utils import generate_unsubscribe_token
        t1 = generate_unsubscribe_token(1, 'marketing')
        t2 = generate_unsubscribe_token(2, 'marketing')
        self.assertNotEqual(t1, t2)

    def test_verify_empty_token_returns_none(self):
        from openedx_email_preferences.utils import verify_unsubscribe_token
        user_id, category = verify_unsubscribe_token('')
        self.assertIsNone(user_id)


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class CheckUserCanReceiveEmailTests(TestCase):
    """check_user_can_receive_email respects preferences."""

    def setUp(self):
        self.user = _create_user(username='receiveuser', email='receive@example.com')

    def test_system_critical_always_returns_true(self):
        from openedx_email_preferences.utils import check_user_can_receive_email
        for category in ('transactional', 'account_activation', 'password_reset'):
            self.assertTrue(
                check_user_can_receive_email(self.user, category),
                f"Expected True for system-critical category: {category}"
            )

    def test_respects_opted_out_preference(self):
        from openedx_email_preferences.models import UserEmailPreference
        from openedx_email_preferences.utils import check_user_can_receive_email
        UserEmailPreference.objects.create(
            user=self.user, category='marketing', opted_in=False,
        )
        self.assertFalse(check_user_can_receive_email(self.user, 'marketing'))

    def test_respects_opted_in_preference(self):
        from openedx_email_preferences.models import UserEmailPreference
        from openedx_email_preferences.utils import check_user_can_receive_email
        UserEmailPreference.objects.create(
            user=self.user, category='marketing', opted_in=True,
        )
        self.assertTrue(check_user_can_receive_email(self.user, 'marketing'))

    def test_unknown_category_defaults_to_true(self):
        from openedx_email_preferences.utils import check_user_can_receive_email
        self.assertTrue(check_user_can_receive_email(self.user, 'unknown_category'))

    def test_new_user_marketing_defaults_to_false(self):
        """GDPR: new user with no preferences -> marketing defaults to False."""
        from openedx_email_preferences.utils import check_user_can_receive_email
        new_user = _create_user(username='newuser', email='new@example.com')
        self.assertFalse(check_user_can_receive_email(new_user, 'marketing'))


@unittest.skip("DB migration required - baseline covers non-DB logic only")
class UnsubscribeUrlTests(TestCase):
    """generate_unsubscribe_url and get_list_unsubscribe_headers."""

    def setUp(self):
        self.user = _create_user(username='urluser', email='url@example.com')

    def test_generate_unsubscribe_url_contains_base(self):
        from openedx_email_preferences.utils import generate_unsubscribe_url
        url = generate_unsubscribe_url(self.user, 'marketing')
        self.assertIn('academyv2.mereka.io', url)

    def test_generate_unsubscribe_url_with_custom_base(self):
        from openedx_email_preferences.utils import generate_unsubscribe_url
        url = generate_unsubscribe_url(
            self.user, 'marketing', base_url='https://custom.example.com',
        )
        self.assertIn('custom.example.com', url)

    def test_get_list_unsubscribe_headers_format(self):
        from openedx_email_preferences.utils import get_list_unsubscribe_headers
        headers = get_list_unsubscribe_headers(self.user, 'marketing')
        self.assertIn('List-Unsubscribe', headers)
        self.assertIn('List-Unsubscribe-Post', headers)
        self.assertEqual(headers['List-Unsubscribe-Post'], 'List-Unsubscribe=One-Click')
        # List-Unsubscribe should be wrapped in angle brackets
        self.assertTrue(headers['List-Unsubscribe'].startswith('<'))
        self.assertTrue(headers['List-Unsubscribe'].endswith('>'))


# ---------------------------------------------------------------------------
# 6. Signal tests
# ---------------------------------------------------------------------------

class SignalTests(unittest.TestCase):
    """register_ace_hooks callable."""

    def test_register_ace_hooks_is_callable(self):
        from openedx_email_preferences.signals import register_ace_hooks
        self.assertTrue(callable(register_ace_hooks))

    def test_register_ace_hooks_does_not_raise(self):
        from openedx_email_preferences.signals import register_ace_hooks
        register_ace_hooks()  # should not raise


# ---------------------------------------------------------------------------
# 7. Admin tests
# ---------------------------------------------------------------------------

class AdminTests(unittest.TestCase):
    """Admin classes registered and configured."""

    def test_preference_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_email_preferences.models import UserEmailPreference
        import openedx_email_preferences.admin  # noqa: F401
        self.assertIn(UserEmailPreference, django_admin.site._registry)

    def test_consent_record_admin_registered(self):
        from django.contrib import admin as django_admin
        from openedx_email_preferences.models import ConsentRecord
        self.assertIn(ConsentRecord, django_admin.site._registry)

    def test_consent_record_admin_no_add_permission(self):
        from openedx_email_preferences.admin import ConsentRecordAdmin
        from openedx_email_preferences.models import ConsentRecord
        from django.contrib import admin as django_admin
        admin_instance = ConsentRecordAdmin(ConsentRecord, django_admin.site)
        self.assertFalse(admin_instance.has_add_permission(MagicMock()))

    def test_consent_record_admin_no_delete_permission(self):
        from openedx_email_preferences.admin import ConsentRecordAdmin
        from openedx_email_preferences.models import ConsentRecord
        from django.contrib import admin as django_admin
        admin_instance = ConsentRecordAdmin(ConsentRecord, django_admin.site)
        self.assertFalse(admin_instance.has_delete_permission(MagicMock()))

    def test_preference_admin_list_display(self):
        from openedx_email_preferences.admin import UserEmailPreferenceAdmin
        for field in ('category', 'opted_in', 'consent_version'):
            self.assertIn(field, UserEmailPreferenceAdmin.list_display)

    def test_consent_record_admin_all_readonly(self):
        from openedx_email_preferences.admin import ConsentRecordAdmin
        for field in ('user', 'category', 'old_value', 'new_value', 'timestamp'):
            self.assertIn(field, ConsentRecordAdmin.readonly_fields)


# ---------------------------------------------------------------------------
# 8. Apps config tests
# ---------------------------------------------------------------------------

class AppConfigTests(unittest.TestCase):
    """AppConfig basic contract."""

    def test_app_name(self):
        from openedx_email_preferences.apps import OpenedxEmailPreferencesConfig
        self.assertEqual(OpenedxEmailPreferencesConfig.name, 'openedx_email_preferences')

    def test_verbose_name(self):
        from openedx_email_preferences.apps import OpenedxEmailPreferencesConfig
        self.assertIn('Email Preferences', OpenedxEmailPreferencesConfig.verbose_name)

    def test_default_auto_field(self):
        from openedx_email_preferences.apps import OpenedxEmailPreferencesConfig
        self.assertEqual(
            OpenedxEmailPreferencesConfig.default_auto_field,
            'django.db.models.BigAutoField'
        )

    def test_ready_does_not_raise(self):
        from django.apps import apps
        app_config = apps.get_app_config('openedx_email_preferences')
        app_config.ready()


# ---------------------------------------------------------------------------
# 9. URL routing tests
# ---------------------------------------------------------------------------

class UrlConfigTests(unittest.TestCase):
    """URL configuration."""

    def test_urlpatterns_is_non_empty(self):
        from openedx_email_preferences.urls import urlpatterns
        self.assertIsInstance(urlpatterns, list)
        self.assertGreater(len(urlpatterns), 0)

    def test_app_name_is_set(self):
        from openedx_email_preferences import urls as urls_mod
        self.assertEqual(urls_mod.app_name, 'openedx_email_preferences')

    def test_preferences_route_exists(self):
        from openedx_email_preferences.urls import urlpatterns
        names = [p.name for p in urlpatterns if hasattr(p, 'name')]
        self.assertIn('email-preferences', names)

    def test_unsubscribe_route_exists(self):
        from openedx_email_preferences.urls import urlpatterns
        names = [p.name for p in urlpatterns if hasattr(p, 'name')]
        self.assertIn('one-click-unsubscribe', names)

    def test_admin_consent_route_exists(self):
        from openedx_email_preferences.urls import urlpatterns
        names = [p.name for p in urlpatterns if hasattr(p, 'name')]
        self.assertIn('admin-consent-records', names)


if __name__ == '__main__':
    unittest.main()
