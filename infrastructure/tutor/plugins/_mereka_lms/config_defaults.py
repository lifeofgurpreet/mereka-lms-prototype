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
        ("MFE_COMMON_VERSION", "release/ulmo.2"),
        ("OPENEDX_COMMON_VERSION", "release/ulmo"),
        ("OPENEDX_LMS_VERSION", "release/ulmo"),
        ("OPENEDX_CMS_VERSION", "release/ulmo"),
        ("MEREKA_PREVIEW_LMS_BASE", "preview.academyv2.mereka.dev"),
        ("MEREKA_SESSION_COOKIE_DOMAIN", ".academyv2.mereka.io"),
        ("MEREKA_CSRF_COOKIE_DOMAIN", ".academyv2.mereka.io"),
    ],
    # Tutor loads plugins alphabetically; `mereka_lms` can register defaults
    # before `mfe`, whose own `MFE_COMMON_VERSION` default follows
    # OPENEDX_COMMON_VERSION. Run this callback late so the repo-owned Ulmo MFE
    # tag remains the rendered Dockerfile source ref unless explicitly set.
    priority=hooks.priorities.LOW,
)
