"""
pytest configuration for openedx_email_preferences standalone tests.

Stubs out Open edX platform dependencies (django_ratelimit, celery, openedx.*)
before Django settings are loaded so the app can be imported and tested
without a live Open edX stack.
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


# ---- django_ratelimit stubs ----
if 'django_ratelimit' not in sys.modules:
    _stub_module('django_ratelimit')
    decorators_mod = _stub_module('django_ratelimit.decorators')

    def _ratelimit(**kwargs):
        """No-op ratelimit decorator stub."""
        def decorator(func):
            return func
        return decorator

    decorators_mod.ratelimit = _ratelimit

# ---- celery stubs ----
if 'celery' not in sys.modules:
    celery = _stub_module('celery')

    def shared_task(func=None, **kwargs):
        if func is not None:
            return func
        return lambda f: f

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
                'openedx_email_preferences',
            ],
            DEFAULT_AUTO_FIELD='django.db.models.BigAutoField',
            USE_TZ=True,
            ROOT_URLCONF='openedx_email_preferences.urls',
            SECRET_KEY='test-secret-key-not-for-production',
            EMAIL_UNSUBSCRIBE_SECRET_KEY='test-unsubscribe-secret-key',
            LMS_ROOT_URL='https://academyv2.mereka.io',
        )
        django.setup()
