"""
pytest configuration for openedx_push_notifications standalone tests.

Stubs out Open edX platform dependencies (edx_ace, celery, openedx.*, google.*)
before Django settings are loaded so the app can be imported and
tested without a live Open edX stack.
"""

import sys
import types
from unittest.mock import MagicMock


def _stub_module(name, **attrs):
    mod = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(mod, k, v)
    sys.modules[name] = mod
    return mod


# ---- edx_ace stubs ----
if 'edx_ace' not in sys.modules:
    edx_ace = _stub_module('edx_ace')
    channel_mod = _stub_module('edx_ace.channel')
    channel_mod.Channel = type('Channel', (), {'deliver': lambda self, m, r: None})
    channel_mod.ChannelType = MagicMock()
    channel_mod.ChannelType.PUSH = 'push'
    edx_ace.channel = channel_mod

# ---- celery stubs ----
if 'celery' not in sys.modules:
    celery = _stub_module('celery')

    def shared_task(func=None, **kwargs):
        if func is not None:
            func.delay = lambda *a, **kw: func(*a, **kw)
            return func

        def wrapper(f):
            f.delay = lambda *a, **kw: f(*a, **kw)
            return f
        return wrapper

    celery.shared_task = shared_task

# ---- openedx plugin stubs ----
if 'openedx' not in sys.modules:
    _stub_module('openedx')
    _stub_module('openedx.core')
    _stub_module('openedx.core.djangoapps')
    _stub_module('openedx.core.djangoapps.plugins')
    constants = _stub_module('openedx.core.djangoapps.plugins.constants')
    constants.PluginURLs = MagicMock()
    constants.ProjectType = MagicMock()

# ---- google-auth stubs (for FCM) ----
if 'google' not in sys.modules:
    _stub_module('google')
    _stub_module('google.oauth2')
    _stub_module('google.oauth2.service_account')
    _stub_module('google.auth')
    _stub_module('google.auth.transport')
    _stub_module('google.auth.transport.requests')


def pytest_configure(config):
    """Configure Django and set up the test database."""
    import django
    from django.conf import settings

    if not settings.configured:
        settings.configure(
            DATABASES={
                'default': {
                    'ENGINE': 'django.db.backends.sqlite3',
                    'NAME': ':memory:',
                }
            },
            INSTALLED_APPS=[
                'django.contrib.contenttypes',
                'django.contrib.auth',
                'django.contrib.admin',
                'rest_framework',
                'openedx_push_notifications',
            ],
            DEFAULT_AUTO_FIELD='django.db.models.BigAutoField',
            USE_TZ=True,
            ROOT_URLCONF='openedx_push_notifications.urls',
            SECRET_KEY='test-secret-key-not-for-production',
            FCM_SERVICE_ACCOUNT_KEY='',
            FCM_PROJECT_ID='',
            NOTIFICATION_PUSH_ENABLED=False,
        )
        django.setup()

        # Create tables for in-memory SQLite
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)
