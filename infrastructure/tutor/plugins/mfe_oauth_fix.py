"""
Tutor plugin to fix MFE OAuth provider visibility.

This plugin adds a custom Django app that overrides the /api/mfe_context
endpoint to properly return OAuth providers for all sites.
"""

from tutor import hooks

# Plugin metadata
__version__ = "1.0.0"

# Plugin configuration
hooks.Filters.CONFIG_DEFAULTS.add_items(
    [
        ("MFE_OAUTH_FIX_VERSION", __version__),
    ]
)

# Add the custom app to INSTALLED_APPS
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-lms-production-settings",
        """
# MFE OAuth Fix - Add custom app to INSTALLED_APPS
INSTALLED_APPS.append('mfe_oauth_fix')

# MFE OAuth Fix - Add custom URL patterns (prepend to override default)
ROOT_URLCONF_OVERRIDES = getattr(settings, 'ROOT_URLCONF_OVERRIDES', [])
ROOT_URLCONF_OVERRIDES.insert(0, 'mfe_oauth_fix.urls')
""",
    )
)

# Mount the custom app code into the LMS container
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-lms-dockerfile-post-python-requirements",
        """
# Copy MFE OAuth fix custom app
COPY --chown=app:app ./custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix
RUN pip install -e /openedx/mfe_oauth_fix
""",
    )
)

# Add build context for the custom app
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-pre-assets",
        """
# Add custom apps to Python path
ENV PYTHONPATH="${PYTHONPATH}:/openedx"
""",
    )
)
