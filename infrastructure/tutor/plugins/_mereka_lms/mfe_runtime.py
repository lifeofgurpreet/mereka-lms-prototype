"""MFE runtime configuration — tenant branding, React components, footer.

Registers the mfe-env-config-buildtime-imports and
mfe-env-config-runtime-definitions patches. The runtime definitions
are split into surface-specific modules under mfe_runtime/ and
concatenated in load order by this module.
"""

import sys

from _mereka_lms import PACKAGE_DIR, _register_env_patch

_register_env_patch(
    "mfe-env-config-buildtime-imports",
    """
// Import Mereka theme SCSS
import './mereka/mereka.scss';
""",
)

# Surface-specific runtime-patch load order.
# tenant-resolution-runtime must be first — all other modules reference its helpers.
_MFE_RUNTIME_PATCH_MODULES = [
    "tenant-resolution-runtime.js",
    "header-menu.js",
    "dashboard.js",
    "learning.js",
    "certificate-profile.js",
    "authoring.js",
    "footer.js",
]

# Compatibility mirror preserves the older hostname-map contract for downstream
# audits while the live runtime patch consumes backend-provided tenant config.
_MFE_RUNTIME_COMPAT_MODULES = [
    "tenant-resolution.js",
    "header-menu.js",
    "dashboard.js",
    "learning.js",
    "certificate-profile.js",
    "authoring.js",
    "footer.js",
]

_mfe_runtime_dir = PACKAGE_DIR / "mfe_runtime"
_deprecated_runtime_path = PACKAGE_DIR / "mfe_runtime_definitions.js"
_deprecated_runtime_banner = """// ╔═══════════════════════════════════════════════════════════════════════╗
// ║ GENERATED COMPATIBILITY MIRROR — DO NOT EDIT DIRECTLY              ║
// ║                                                                     ║
// ║ The actual runtime is assembled from the split modules in:          ║
// ║   infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/            ║
// ║     tenant-resolution.js  header-menu.js  dashboard.js              ║
// ║     learning.js  certificate-profile.js  authoring.js  footer.js   ║
// ║                                                                     ║
// ║ Loaded by: infrastructure/tutor/plugins/_mereka_lms/mfe_runtime.py ║
// ║                                                                     ║
// ║ Regenerate with:                                                    ║
// ║   PYTHONPATH=. python -m _mereka_lms.mfe_runtime --sync-compat      ║
// ╚═══════════════════════════════════════════════════════════════════════╝"""


def _render_runtime_body(modules):
    return "\n".join([(_mfe_runtime_dir / module).read_text() for module in modules])


def _render_runtime_patch():
    return "\n{% raw %}\n" + _render_runtime_body(_MFE_RUNTIME_PATCH_MODULES) + "\n{% endraw %}\n"


def _render_compat_runtime():
    return (
        _deprecated_runtime_banner
        + "\n{% raw %}\n"
        + _render_runtime_body(_MFE_RUNTIME_COMPAT_MODULES)
        + "\n{% endraw %}\n"
    )


_register_env_patch(
    "mfe-env-config-runtime-definitions",
    _render_runtime_patch(),
)


def _sync_compat_runtime_definitions():
    _deprecated_runtime_path.write_text(_render_compat_runtime())


if __name__ == "__main__":
    if "--sync-compat" not in sys.argv:
        raise SystemExit("Usage: PYTHONPATH=. python -m _mereka_lms.mfe_runtime --sync-compat")
    _sync_compat_runtime_definitions()
    print(f"Synced {_deprecated_runtime_path}")
