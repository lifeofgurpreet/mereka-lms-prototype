"""
pytest configuration for openedx_video_analytics standalone tests.

Stubs out Open edX platform dependencies (opaque_keys, celery, openedx.*, lms.*)
before Django settings are loaded so the app can be imported and tested
without a live Open edX stack.

CRITICAL: CourseKeyField MUST subclass django.db.models.CharField
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


class FakeCourseKey:
    """Stub for opaque_keys.edx.keys.CourseKey."""
    def __init__(self, org='TestOrg', course='101', run='2026'):
        self.org = org
        self.course = course
        self.run = run

    @classmethod
    def from_string(cls, key_str):
        if not key_str or not key_str.startswith('course-v1:'):
            raise FakeInvalidKeyError(f"Invalid course key: {key_str}")
        parts = key_str.replace('course-v1:', '').split('+')
        if len(parts) < 3:
            raise FakeInvalidKeyError(f"Invalid course key: {key_str}")
        return cls(org=parts[0], course=parts[1], run=parts[2])

    def __str__(self):
        return f"course-v1:{self.org}+{self.course}+{self.run}"


class FakeInvalidKeyError(Exception):
    pass


if 'opaque_keys' not in sys.modules:
    _stub_module('opaque_keys', InvalidKeyError=FakeInvalidKeyError)
    _stub_module('opaque_keys.edx')
    _stub_module('opaque_keys.edx.django')
    opaque_django_models = _stub_module('opaque_keys.edx.django.models')
    opaque_django_models.CourseKeyField = FakeCourseKeyField
    opaque_django_models.UsageKeyField = FakeUsageKeyField
    opaque_keys_mod = _stub_module('opaque_keys.edx.keys')
    opaque_keys_mod.CourseKey = FakeCourseKey

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

# ---- lms stubs (for views.py import of has_access) ----
if 'lms' not in sys.modules:
    _stub_module('lms')
    _stub_module('lms.djangoapps')
    _stub_module('lms.djangoapps.courseware')
    access_mod = _stub_module('lms.djangoapps.courseware.access')
    access_mod.has_access = MagicMock(return_value=True)


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
                'openedx_video_analytics',
            ],
            DEFAULT_AUTO_FIELD='django.db.models.BigAutoField',
            USE_TZ=True,
            ROOT_URLCONF='openedx_video_analytics.urls',
            SECRET_KEY='test-secret-key-not-for-production',
            ENABLE_VIDEO_ANALYTICS=True,
            AUTH_USER_MODEL='auth.User',
        )
        django.setup()
