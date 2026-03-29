"""
Minimal Django settings for openedx_notifications standalone tests.

Used via DJANGO_SETTINGS_MODULE=openedx_notifications.test_settings
"""

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}

INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.admin',
    'rest_framework',
    'openedx_notifications',
]

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

USE_TZ = True

# Required by django.contrib.admin
ROOT_URLCONF = 'openedx_notifications.urls'

# Silence Django system check warnings for tests
SECRET_KEY = 'test-secret-key-not-for-production'
