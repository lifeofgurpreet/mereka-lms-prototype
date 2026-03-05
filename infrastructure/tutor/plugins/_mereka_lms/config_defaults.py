"""Tutor CONFIG_DEFAULTS for Mereka LMS.

These values are overridable via `tutor config save --set KEY=VALUE`.
"""

from tutor import hooks

from _mereka_lms import __version__

hooks.Filters.CONFIG_DEFAULTS.add_items(
    [
        ("MEREKA_LMS_VERSION", __version__),
        (
            "MEREKA_LMS_EXTRA_HOSTS",
            [
                "admin.academyv2.mereka.io",
                "academy.biji-biji.com",
                "learner.academyv2.mereka.io",
                "skillourfuture.academy.mereka.io",
            ],
        ),
        (
            "MEREKA_LMS_EXTRA_CSRF_ORIGINS",
            [
                "https://admin.academyv2.mereka.io",
                "https://academy.biji-biji.com",
                "https://learner.academyv2.mereka.io",
                "https://skillourfuture.academy.mereka.io",
                "https://apps.academy.biji-biji.com",
            ],
        ),
        ("MEREKA_PARAGON_THEME_ENABLED", True),
        ("MEREKA_PARAGON_THEME_CDN_BASE", "/theme"),
        ("MEREKA_SESSION_COOKIE_DOMAIN", ".academyv2.mereka.io"),
        ("MEREKA_CSRF_COOKIE_DOMAIN", ".academyv2.mereka.io"),
    ]
)
