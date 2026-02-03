from .settings import *
import os

ALLOWED_HOSTS = [
    "xqueue.localhost",
    "xqueue",
]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "HOST": "mysql",
        "PORT": 3306,
        "NAME": "xqueue",
        "USER": "xqueue",
        "PASSWORD": os.environ.get("MYSQL_XQUEUE_PASSWORD", ""),
        "OPTIONS": {"init_command": "SET sql_mode='STRICT_TRANS_TABLES'",},
    }
}

# User-uploaded assets will be stored in this media folder
MEDIA_ROOT = "/openedx/data/media"
MEDIA_URL = "media/"

LOGGING["handlers"].pop("local")
LOGGING["loggers"][""]["handlers"] = ["console"]
LOGGING["loggers"]["submission_queue.management.commands.run_consumer"] = {
    "level": "WARN",
    "handlers": ["console"]
}

SECRET_KEY = os.environ.get("XQUEUE_SECRET_KEY", "")

USERS = {"lms": os.environ.get("XQUEUE_LMS_PASSWORD", "")}
XQUEUES = {"openedx": None}

