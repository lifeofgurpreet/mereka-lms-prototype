from .common import *

SECRET_KEY = "zFXxijS0sn7jcEo8iYVcaKA9"
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
        "PASSWORD": "ZyKJSLQp",
        "OPTIONS": {
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}

CLIENT_ID = "notes"
CLIENT_SECRET = "w6Wpu7FsFWjg3oHTLm0Aml37"

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

