from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LMS_SETTINGS = REPO_ROOT / "deploy" / "k8s" / "base" / "apps" / "openedx" / "settings" / "lms" / "production.py"
CMS_SETTINGS = REPO_ROOT / "deploy" / "k8s" / "base" / "apps" / "openedx" / "settings" / "cms" / "production.py"


def test_discussion_service_flag_is_not_contradictory() -> None:
    lms_text = LMS_SETTINGS.read_text(encoding="utf-8")
    cms_text = CMS_SETTINGS.read_text(encoding="utf-8")

    assert 'FEATURES["ENABLE_DISCUSSION_SERVICE"] = False' not in lms_text
    assert 'FEATURES["ENABLE_DISCUSSION_SERVICE"] = False' not in cms_text
    assert 'FEATURES["ENABLE_DISCUSSION_SERVICE"] = True' in lms_text
    assert 'FEATURES["ENABLE_DISCUSSION_SERVICE"] = True' in cms_text


def test_base_settings_document_overlay_hardening_contract() -> None:
    lms_text = LMS_SETTINGS.read_text(encoding="utf-8")
    cms_text = CMS_SETTINGS.read_text(encoding="utf-8")

    overlay_comment = "Environment-owned overlays must harden this for live lanes."

    assert overlay_comment in lms_text
    assert overlay_comment in cms_text
    assert "OAUTH_ENFORCE_SECURE = False" in lms_text
