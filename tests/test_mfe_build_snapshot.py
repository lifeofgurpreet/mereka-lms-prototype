from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
PLUGIN_FILE = REPO_ROOT / "infrastructure" / "tutor" / "plugins" / "_mereka_lms" / "mfe_dockerfile.py"
SNAPSHOT_DOCKERFILE = REPO_ROOT / "infrastructure" / "tutor" / "mfe-build" / "Dockerfile"
RENDERED_DOCKERFILE = REPO_ROOT / "tutor_env" / "env" / "plugins" / "mfe" / "build" / "mfe" / "Dockerfile"


def test_account_mfe_hook_guards_null_social_links() -> None:
    content = PLUGIN_FILE.read_text(encoding="utf-8")

    assert '"mfe-dockerfile-post-npm-install-account"' in content
    assert 'service_path = Path("/openedx/app/src/account-settings/data/service.js")' in content
    assert "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];" in content
    assert "frontend-app-account social_links lookup anchor missing" in content


def test_rendered_account_mfe_dockerfile_carries_null_guard_when_available() -> None:
    snapshot = SNAPSHOT_DOCKERFILE.read_text(encoding="utf-8")
    assert 'service_path = Path("/openedx/app/src/account-settings/data/service.js")' in snapshot

    if not RENDERED_DOCKERFILE.exists():
        return

    content = RENDERED_DOCKERFILE.read_text(encoding="utf-8")
    assert 'service_path = Path("/openedx/app/src/account-settings/data/service.js")' in content
