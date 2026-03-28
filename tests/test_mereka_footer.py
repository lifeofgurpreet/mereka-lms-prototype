"""Regression tests for the shared public footer payload."""

from __future__ import annotations

import importlib.util
from pathlib import Path


REPO_ROOT = Path(__file__).parent.parent
FOOTER_HELPER_PATH = REPO_ROOT / "deploy" / "k8s" / "base" / "apps" / "openedx" / "settings" / "lms" / "mereka_footer.py"


spec = importlib.util.spec_from_file_location("mereka_footer", FOOTER_HELPER_PATH)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)  # type: ignore[union-attr]

build_mereka_public_footer = module.build_mereka_public_footer


def test_shared_footer_payload_covers_public_footer_sections():
    footer = build_mereka_public_footer()

    assert footer["brand"]["logoText"] == "mereka"
    assert [link["name"] for link in footer["socialLinks"]] == [
        "TikTok",
        "Instagram",
        "Facebook",
        "LinkedIn",
        "YouTube",
    ]
    assert [link["label"] for link in footer["navLinks"]] == [
        "About",
        "Andragogy",
        "Portfolio",
        "Team",
        "Careers",
        "Ecosystem",
        "Blog",
    ]
    assert footer["support"]["helpLabel"] == "Help Centre"
    assert footer["support"]["contactSupportLabel"] == "Contact Support"
    assert footer["support"]["contactCtaLabel"] == "Contact Us"
    assert footer["support"]["whatsapp"] == "601135271981"

    assert footer["sections"]["corporate"]["title"] == "Corporate"
    assert footer["sections"]["marketplace"]["title"] == "Marketplace"
    assert footer["sections"]["academy"]["title"] == "Academy"
    assert footer["sections"]["space"]["title"] == "Space"
    assert footer["sections"]["marketplace"]["cta"]["label"] == "Become a Hub"
    assert [badge["label"] for badge in footer["sections"]["marketplace"]["appBadges"]] == [
        "App Store",
        "Google Play",
    ]
    assert footer["legal"]["termsLabel"] == "TERMS OF USE"
    assert footer["legal"]["privacyLabel"] == "PRIVACY POLICY"
    assert footer["legal"]["cookiesLabel"] == "COOKIES POLICY"


def test_shared_footer_payload_is_returned_as_a_copy():
    first = build_mereka_public_footer()
    second = build_mereka_public_footer()

    first["navLinks"][0]["label"] = "Changed"
    assert second["navLinks"][0]["label"] == "About"
