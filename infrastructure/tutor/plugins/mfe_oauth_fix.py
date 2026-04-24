"""
Legacy compatibility shim for the retired standalone mfe_oauth_fix Tutor plugin.

Ownership of the MFE OAuth fix custom app now lives in the consolidated
`mereka_lms` / `_mereka_lms` plugin stack:
  - Docker image integration: `_mereka_lms/openedx_dockerfile.py`
  - LMS settings wiring: `_mereka_lms/lms_settings.py`

This shim intentionally emits no ENV_PATCHES. Its only job is to remain safe if
an older Tutor config still has `mfe_oauth_fix` enabled while the repo converges
to the single-authority plugin model.
"""

from tutor import hooks

__version__ = "1.1.0"

hooks.Filters.CONFIG_DEFAULTS.add_items(
    [
        ("MFE_OAUTH_FIX_VERSION", __version__),
    ]
)
