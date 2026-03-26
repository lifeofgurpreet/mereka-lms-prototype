"""
Learner-home redirect helpers for the MFE OAuth fix custom app.
"""

from urllib.parse import urlsplit

from django.conf import settings

DEFAULT_LEARNER_HOME_PATH = "/learner-dashboard/"


def learner_home_next_path() -> str:
    """
    Return the canonical learner-home path for OAuth provider callbacks.
    """

    configured = (
        getattr(settings, "LEARNER_HOME_MICROFRONTEND_URL", "")
        or DEFAULT_LEARNER_HOME_PATH
    )
    path = urlsplit(configured).path if "://" in configured else configured
    path = (path or DEFAULT_LEARNER_HOME_PATH).strip()
    if not path.startswith("/"):
        path = f"/{path}"
    if not path.endswith("/"):
        path = f"{path}/"
    return path
