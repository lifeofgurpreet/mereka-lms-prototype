from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_SETTINGS = REPO_ROOT / "deploy" / "k8s" / "base" / "apps" / "openedx" / "settings" / "lms" / "production.py"


def test_modulestore_mongo_defaults_are_derived_before_forum_fallback() -> None:
    lines = PRODUCTION_SETTINGS.read_text(encoding="utf-8").splitlines()

    mongodb_username_idx = next(
        idx for idx, line in enumerate(lines, start=1) if "_mongodb_username = None" in line
    )
    forum_fallback_idx = next(
        idx
        for idx, line in enumerate(lines, start=1)
        if '_forum_username = os.environ.get("FORUM_MONGODB_USERNAME") or _mongodb_username' in line
    )

    assert mongodb_username_idx < forum_fallback_idx


def test_atlas_detection_uses_host_classifier_instead_of_raw_substring_match() -> None:
    text = PRODUCTION_SETTINGS.read_text(encoding="utf-8")

    assert "def _is_mongodb_atlas_host(raw_value):" in text
    assert '_mongodb_is_atlas = _is_mongodb_atlas_host(MONGODB_HOST)' in text
    assert '_forum_mongo_is_atlas = _is_mongodb_atlas_host(_forum_mongo_host)' in text
    assert '".mongodb.net" in _mongodb_host_lower' not in text
    assert '".mongodb.net" in _forum_mongo_host_lower' not in text
