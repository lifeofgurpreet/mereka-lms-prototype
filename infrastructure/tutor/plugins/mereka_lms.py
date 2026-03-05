"""
Tutor plugin for Mereka LMS customizations.

This plugin consolidates Mereka-specific configuration patches that can be
delivered via Tutor's template hook system. The companion apply-patches.sh
script handles file-system operations (asset sync, theme copy) and content
modifications that require find-and-replace on generated files.

Patches included:
- Multi-site domain configuration (biji-biji.com, skillourfuture.academy.mereka.io)
- MySQL 8 authentication plugin fix
- MFE Node 24 build toolchain
- Forum MongoDB SRV connection support
- Caddy multi-domain configuration
- LMS/CMS settings (CSRF, sessions, enterprise integration)
- Prometheus metrics integration
- MFE OAuth fix integration
- Custom branding and theme support

Architecture:
    mereka_lms.py          ← This entrypoint (imports submodules)
    _mereka_lms/           ← Package with domain-specific modules:
      __init__.py           - Shared: __version__, _register_env_patch()
      config_defaults.py    - CONFIG_DEFAULTS (hosts, CSRF, cookies)
      lms_settings.py       - LMS production settings (multi-site, CSP, etc.)
      cms_settings.py       - CMS settings + Credentials Dockerfile
      asset_settings.py     - LMS/CMS asset build settings
      openedx_dockerfile.py - OpenEdX Docker image patches
      mfe_dockerfile.py     - MFE Docker image patches
      mfe_runtime.py        - MFE JSX components + branding (loads .js file)
      infrastructure.py     - MySQL, Caddy, Nginx patches
      mfe_runtime_definitions.js - 1,177 lines of JSX (tenant branding, footer)
    mereka_lms_mfe_slots.py ← MFE plugin slot registrations (63 slots)

Usage:
    tutor plugins enable mereka_lms
    tutor config save
    tutor images build openedx mfe
"""

from __future__ import annotations

from tutor import hooks

from mereka_lms_mfe_slots import register_mfe_plugin_slots

# Import all submodules — each registers its own ENV_PATCHES on import.
# Order does not matter for Tutor hook collection; listed by domain for clarity.
from _mereka_lms import __version__
from _mereka_lms import config_defaults  # noqa: F401  CONFIG_DEFAULTS
from _mereka_lms import lms_settings  # noqa: F401  LMS production settings
from _mereka_lms import cms_settings  # noqa: F401  CMS settings + credentials
from _mereka_lms import asset_settings  # noqa: F401  LMS/CMS asset build
from _mereka_lms import openedx_dockerfile  # noqa: F401  OpenEdX Dockerfile
from _mereka_lms import mfe_dockerfile  # noqa: F401  MFE Dockerfile
from _mereka_lms import mfe_runtime  # noqa: F401  MFE JSX components
from _mereka_lms import infrastructure  # noqa: F401  MySQL, Caddy, Nginx

###############################################################################
# MFE Plugin Slot Configuration
###############################################################################

register_mfe_plugin_slots()

###############################################################################
# Plugin Initialization Hook
###############################################################################


@hooks.Actions.PLUGIN_LOADED.add()
def _print_loading_message(plugin_name: str):
    """Print a message when the plugin is loaded."""
    if plugin_name == "mereka_lms":
        print(f"Mereka LMS plugin v{__version__} loaded")
