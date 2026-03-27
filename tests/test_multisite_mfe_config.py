"""
Regression tests for complete multisite MFE_CONFIG generation.

These tests cover the pure-Python helper that builds SiteConfiguration.MFE_CONFIG
payloads for tenant LMS/MFE hosts. No Django, database, or network required.
"""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

import yaml as _yaml

REPO_ROOT = Path(__file__).parent.parent
BOOTSTRAP_PATH = REPO_ROOT / "scripts" / "shared" / "multisite_bootstrap_django.py"


def _make_minimal_yaml(tmp_path: Path) -> Path:
    content = {"organizations": [], "sites": []}
    path = tmp_path / "minimal.yml"
    path.write_text(_yaml.dump(content))
    return path


_TMP = Path(tempfile.mkdtemp())
_MINIMAL_YAML = _make_minimal_yaml(_TMP)
os.environ.setdefault("MULTISITE_DEFINITIONS_PATH", str(_MINIMAL_YAML))

spec = importlib.util.spec_from_file_location("multisite_bootstrap_django", BOOTSTRAP_PATH)
assert spec is not None and spec.loader is not None
_mod = importlib.util.module_from_spec(spec)
sys.modules["multisite_bootstrap_django"] = _mod
spec.loader.exec_module(_mod)  # type: ignore[union-attr]

build_site_mfe_config_overrides = _mod.build_site_mfe_config_overrides


def test_build_site_mfe_config_overrides_preserves_defaults_and_sets_complete_mfe_urls():
    default_cfg = {
        "DISCOVERY_API_BASE_URL": "https://discovery.academyv2.mereka.io",
        "CREDENTIALS_BASE_URL": "https://credentials.academyv2.mereka.io",
        "BRAND_PRIMARY": "#2d898b",
        "DISABLE_ENTERPRISE_LOGIN": True,
    }
    rendered_values = {
        "LMS_ROOT_URL": "https://academyv2.mereka.dev",
        "CMS_ROOT_URL": "https://studio.academyv2.mereka.dev",
        "MFE_BASE_URL": "https://apps.academyv2.mereka.dev",
        "THEME_NAME": "mereka",
    }

    payload = build_site_mfe_config_overrides(
        rendered_values=rendered_values,
        default_cfg=default_cfg,
    )

    assert payload["DISCOVERY_API_BASE_URL"] == "https://discovery.academyv2.mereka.io"
    assert payload["CREDENTIALS_BASE_URL"] == "https://credentials.academyv2.mereka.io"
    assert payload["BRAND_PRIMARY"] == "#2d898b"
    assert payload["LMS_BASE_URL"] == "https://academyv2.mereka.dev"
    assert payload["STUDIO_BASE_URL"] == "https://studio.academyv2.mereka.dev"
    assert payload["BASE_URL"] == "apps.academyv2.mereka.dev"
    assert payload["AUTHN_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/authn"
    assert payload["AUTHN_MICROFRONTEND_DOMAIN"] == "apps.academyv2.mereka.dev"
    assert payload["ACCOUNT_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/account/"
    assert payload["ACCOUNT_SETTINGS_URL"] == "https://apps.academyv2.mereka.dev/account/"
    assert payload["DISCUSSIONS_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/discussions"
    assert payload["DISCUSSIONS_MFE_BASE_URL"] == "https://apps.academyv2.mereka.dev/discussions"
    assert payload["WRITABLE_GRADEBOOK_URL"] == "https://apps.academyv2.mereka.dev/gradebook"
    assert payload["LEARNER_HOME_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/learner-dashboard/"
    assert payload["LEARNER_RECORD_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/learner-record"
    assert payload["LEARNING_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/learning"
    assert payload["LEARNING_BASE_URL"] == "https://apps.academyv2.mereka.dev/learning"
    assert payload["ORA_GRADING_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/ora-grading"
    assert payload["PROFILE_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/u/"
    assert payload["ACCOUNT_PROFILE_URL"] == "https://apps.academyv2.mereka.dev/u/"
    assert payload["COMMUNICATIONS_MICROFRONTEND_URL"] == "https://apps.academyv2.mereka.dev/communications"
    assert payload["LOGIN_REDIRECT_URL"] == "https://apps.academyv2.mereka.dev/learner-dashboard/"


def test_build_site_mfe_config_overrides_falls_back_to_lms_assets_without_mfe_base():
    payload = build_site_mfe_config_overrides(
        rendered_values={
            "LMS_ROOT_URL": "https://academy.biji-biji.com",
            "THEME_NAME": "mereka",
        },
        default_cfg={
            "AUTHN_MICROFRONTEND_URL": "https://apps.default.example/authn",
            "AUTHN_MICROFRONTEND_DOMAIN": "apps.default.example",
            "DISABLE_ENTERPRISE_LOGIN": True,
        },
    )

    assert payload["LMS_BASE_URL"] == "https://academy.biji-biji.com"
    assert payload["AUTHN_MICROFRONTEND_URL"] == "https://apps.default.example/authn"
    assert payload["AUTHN_MICROFRONTEND_DOMAIN"] == "apps.default.example"
    assert payload["LOGO_URL"] == (
        "https://academy.biji-biji.com/theming/asset/mereka/images/logo-horizontal.png"
    )
