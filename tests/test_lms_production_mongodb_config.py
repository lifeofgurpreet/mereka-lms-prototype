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
