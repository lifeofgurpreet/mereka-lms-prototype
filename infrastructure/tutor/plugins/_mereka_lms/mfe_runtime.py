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
import './theme-source/mereka.scss';

// Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
// The SDK is installed via mfe-dockerfile-post-npm-install. Init is gated
// on getConfig().SENTRY_DSN being non-empty at runtime — empty DSN means
// the SDK stays dormant and never makes a network call.
//
// APP_READY fires after @edx/frontend-platform finishes loading the MFE
// config API response, so getConfig() is populated by the time we init.
// That misses the earliest bootstrap window (0-500ms before config
// arrives), which is an acceptable tradeoff to keep the DSN per-env and
// avoid hardcoding it into the bundle at build time.
import * as Sentry from '@sentry/browser';
import { subscribe, APP_READY } from '@edx/frontend-platform';

subscribe(APP_READY, () => {
  try {
    const cfg = getConfig() || {};
    const dsn = (cfg.SENTRY_DSN || '').trim();
    if (!dsn) return;
    Sentry.init({
      dsn,
      environment: cfg.SENTRY_ENVIRONMENT || 'unknown',
      // Release tag derived from MFE build-time SHA if webpack DefinePlugin
      // set process.env.MEREKA_RELEASE_SHA; falls back to undefined which
      // lets Sentry auto-detect.
      release: (typeof process !== 'undefined' && process.env && process.env.MEREKA_RELEASE_SHA) || undefined,
      // Conservative sample rates for Phase 1 — tune once we have baseline
      // traffic volume. No profiling until explicitly enabled per env.
      tracesSampleRate: 0.05,
      // Attach the MFE's BASE_URL so event filtering by MFE surface works.
      initialScope: {
        tags: {
          mfe_base_url: cfg.BASE_URL || 'unknown',
          lms_base_url: cfg.LMS_BASE_URL || 'unknown',
        },
      },
    });
  } catch (err) {
    // Never let Sentry initialization failure break the app. Log to
    // console so issues surface during local dev / E2E runs.
    if (typeof console !== 'undefined' && console.warn) {
      console.warn('[mereka-obs-001] Sentry.init failed', err);
    }
  }
});
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
