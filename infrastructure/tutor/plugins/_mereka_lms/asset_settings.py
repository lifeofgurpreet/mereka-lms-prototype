"""LMS/CMS asset build settings — Redwood apps + safe_join monkeypatch."""

from _mereka_lms import _register_env_patch

# Shared patch snippets to reduce duplication in ENV_PATCHES payloads.
_REDWOOD_OPTIONAL_APPS_SNIPPET = """
# Ensure optional Redwood apps exist when collecting assets
if "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
if "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]
if "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]
if "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.theming.apps.ThemingConfig"]
""".strip()

_SAFE_JOIN_MONKEYPATCH_SNIPPET = """
import sys as _sys
import os.path as _osp
import django.utils._os as _os_mod
_orig_safe_join = _os_mod.safe_join
def _build_safe_join(base, *paths):
    return _osp.abspath(_osp.join(base, *paths))
_os_mod.safe_join = _build_safe_join
for _m in list(_sys.modules.values()):
    try:
        if getattr(_m, 'safe_join', None) is _orig_safe_join:
            _m.safe_join = _build_safe_join
    except Exception:
        pass
""".strip()

###############################################################################
# Common LMS/CMS asset settings patches (for collectstatic)
###############################################################################

_register_env_patch(
    "openedx-common-assets-settings",
    f"""
{_REDWOOD_OPTIONAL_APPS_SNIPPET}

# Monkey-patch safe_join to be permissive during asset build.
# This fixes collectstatic SuspiciousFileOperation errors when CSS files
# reference relative paths like ../../css/images/correct-icon.png
{_SAFE_JOIN_MONKEYPATCH_SNIPPET}
""",
)
