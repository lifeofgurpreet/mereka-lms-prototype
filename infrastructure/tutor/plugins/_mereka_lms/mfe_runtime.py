"""MFE runtime configuration — tenant branding, React components, footer.

Registers the mfe-env-config-buildtime-imports and
mfe-env-config-runtime-definitions patches. The runtime definitions
(~1,177 lines of JSX) are loaded from a standalone .js file for
readability and proper syntax highlighting.
"""

from _mereka_lms import PACKAGE_DIR, _register_env_patch

_register_env_patch(
    "mfe-env-config-buildtime-imports",
    """
// Import Mereka theme SCSS
import './mereka/mereka.scss';
""",
)

_register_env_patch(
    "mfe-env-config-runtime-definitions",
    "\n" + (PACKAGE_DIR / "mfe_runtime_definitions.js").read_text() + "\n",
)
