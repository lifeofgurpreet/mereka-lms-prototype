"""
pytest configuration for openedx_notifications standalone tests.

Stubs out Open edX platform dependencies (edx_ace, celery, openedx.*)
before Django settings are loaded so the app can be imported and
tested without a live Open edX stack.

Run from repo root:
    PYTHONPATH=infrastructure/tutor/custom-apps \\
        pytest infrastructure/tutor/custom-apps/openedx_notifications/ -v
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


# Stubs must be injected before pytest-django imports Django or the app.

# ---- edx_ace stubs ----
if 'edx_ace' not in sys.modules:
    edx_ace = _stub_module('edx_ace')
    channel_mod = _stub_module('edx_ace.channel')
    channel_mod.Channel = type('Channel', (), {})
    channel_mod.ChannelType = MagicMock()
    channel_mod.ChannelType.IN_APP = 'in_app'
    channel_mod.get_channel_for_message = MagicMock()
    edx_ace.channel = channel_mod
    errors_mod = _stub_module('edx_ace.errors')
    errors_mod.RecoverableChannelDeliveryError = type(
        'RecoverableChannelDeliveryError', (Exception,), {}
    )
    edx_ace.errors = errors_mod

# ---- celery stubs ----
if 'celery' not in sys.modules:
    celery = _stub_module('celery')

    def shared_task(func=None, **kwargs):
        if func is not None:
            return func
        return lambda f: f

    celery.shared_task = shared_task

# ---- openedx stubs (apps.py guards with try/except, but stub for safety) ----
if 'openedx' not in sys.modules:
    openedx = _stub_module('openedx')
    core = _stub_module('openedx.core')
    djangoapps = _stub_module('openedx.core.djangoapps')
    plugins = _stub_module('openedx.core.djangoapps.plugins')
    constants = _stub_module('openedx.core.djangoapps.plugins.constants')
    constants.PluginURLs = MagicMock()
    constants.ProjectType = MagicMock()
    openedx.core = core
    core.djangoapps = djangoapps
    djangoapps.plugins = plugins
    plugins.constants = constants


def pytest_configure(config):
    """Tell pytest-django which settings module to use."""
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
                'openedx_notifications',
            ],
            DEFAULT_AUTO_FIELD='django.db.models.BigAutoField',
            USE_TZ=True,
            ROOT_URLCONF='openedx_notifications.urls',
            SECRET_KEY='test-secret-key-not-for-production',
        )
