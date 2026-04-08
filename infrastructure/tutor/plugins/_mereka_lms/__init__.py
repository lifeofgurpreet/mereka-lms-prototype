"""Internal package for mereka_lms Tutor plugin submodules.

Each submodule registers its own ENV_PATCHES via _register_env_patch().
The top-level mereka_lms.py imports all submodules to trigger registration.
"""

from pathlib import Path

from tutor import hooks

__version__ = "1.0.0"

PACKAGE_DIR = Path(__file__).parent


def _register_env_patch(patch_name: str, patch_body: str) -> None:
    """Register a Tutor ENV_PATCHES item."""
    hooks.Filters.ENV_PATCHES.add_item((patch_name, patch_body))


# Register learner-record as an additional MFE (not in tutor-mfe 21.0.0 core).
# Uses webpack 4 → requires Node 18 (patched by patches/learner-record-node18.sh).
from tutormfe.hooks import MFE_APPS  # noqa: E402

MFE_APPS.add_item(
    (
        "learner-record",
        {
            "repository": "https://github.com/openedx/frontend-app-learner-record.git",
            "port": 1990,
        },
    )
)
