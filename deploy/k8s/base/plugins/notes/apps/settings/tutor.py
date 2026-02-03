from .common import *
import os

SECRET_KEY = os.environ.get("NOTES_SECRET_KEY", "")
ALLOWED_HOSTS = [
    "notes",
    "notes.localhost",
]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "HOST": "mysql",
        "PORT": 3306,
        "NAME": "notes",
        "USER": "notes",
        "PASSWORD": os.environ.get("MYSQL_NOTES_PASSWORD", ""),
        "OPTIONS": {
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}

CLIENT_ID = "notes"
CLIENT_SECRET = os.environ.get("NOTES_CLIENT_SECRET", "")

ELASTICSEARCH_DSL = {
    'default': {
        'hosts': 'http://elasticsearch:9200'
    }
}

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {
            "level": "INFO",
            "class": "logging.StreamHandler",
        },
    },
    "loggers": {
        "": {
            "handlers": ["console"],
            "level": "INFO",
        },
    },
}

