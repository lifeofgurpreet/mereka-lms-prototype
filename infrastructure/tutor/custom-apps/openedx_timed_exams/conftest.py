"""
pytest configuration for openedx_timed_exams standalone tests.

Stubs out Open edX platform dependencies (opaque_keys, edx_proctoring, celery, openedx.*)
before Django settings are loaded so the app can be imported and tested
without a live Open edX stack.

CRITICAL: CourseKeyField and UsageKeyField MUST subclass django.db.models.CharField
or Django _prepare() crashes during migration/table creation.
"""

import sys
import types
from unittest.mock import MagicMock

import django.db.models


def _stub_module(name, **attrs):
    mod = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(mod, k, v)
    sys.modules[name] = mod
    return mod


# ---- opaque_keys stubs (MUST subclass CharField) ----

class FakeCourseKeyField(django.db.models.CharField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('max_length', 255)
        super().__init__(*args, **kwargs)


class FakeUsageKeyField(django.db.models.CharField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('max_length', 255)
        super().__init__(*args, **kwargs)


if 'opaque_keys' not in sys.modules:
    _stub_module('opaque_keys')
    _stub_module('opaque_keys.edx')
    _stub_module('opaque_keys.edx.django')
    opaque_django_models = _stub_module('opaque_keys.edx.django.models')
    opaque_django_models.CourseKeyField = FakeCourseKeyField
    opaque_django_models.UsageKeyField = FakeUsageKeyField
    _stub_module('opaque_keys.edx.keys')

# ---- edx_proctoring stubs ----
if 'edx_proctoring' not in sys.modules:
    _stub_module('edx_proctoring')
    signals_mod = _stub_module('edx_proctoring.signals')
    signals_mod.exam_attempt_created = MagicMock()
    signals_mod.exam_attempt_submitted = MagicMock()

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

    # Minimal URL conf so Django admin doesn't complain
    _urls = types.ModuleType('openedx_timed_exams._test_urls')
    _urls.urlpatterns = []
    sys.modules['openedx_timed_exams._test_urls'] = _urls

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
                'openedx_timed_exams',
            ],
            DEFAULT_AUTO_FIELD='django.db.models.BigAutoField',
            USE_TZ=True,
            ROOT_URLCONF='openedx_timed_exams._test_urls',
            SECRET_KEY='test-secret-key-not-for-production',
        )
        django.setup()

        # Create tables for in-memory SQLite
        from django.core.management import call_command
        call_command('migrate', '--run-syncdb', verbosity=0)
