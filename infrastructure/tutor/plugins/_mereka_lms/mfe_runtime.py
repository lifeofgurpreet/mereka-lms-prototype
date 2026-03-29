"""MFE runtime configuration — tenant branding, React components, footer.

Registers the mfe-env-config-buildtime-imports and
mfe-env-config-runtime-definitions patches. The runtime definitions
are split into surface-specific modules under mfe_runtime/ and
concatenated in load order by this module.
"""

from _mereka_lms import PACKAGE_DIR, _register_env_patch

_register_env_patch(
    "mfe-env-config-buildtime-imports",
    """
// Import Mereka theme SCSS
import './mereka/mereka.scss';
""",
)

# Surface-specific module load order.
# tenant-resolution must be first — all other modules reference its helpers.
_MFE_RUNTIME_MODULES = [
    "tenant-resolution.js",
    "header-menu.js",
    "dashboard.js",
    "learning.js",
    "certificate-profile.js",
    "authoring.js",
    "footer.js",
]

_mfe_runtime_dir = PACKAGE_DIR / "mfe_runtime"
_mfe_runtime_parts = [(_mfe_runtime_dir / module).read_text() for module in _MFE_RUNTIME_MODULES]

_register_env_patch(
    "mfe-env-config-runtime-definitions",
    "\n{% raw %}\n" + "\n".join(_mfe_runtime_parts) + "\n{% endraw %}\n",
)
