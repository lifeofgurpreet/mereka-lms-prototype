from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PLUGIN_FILE = REPO_ROOT / "infrastructure" / "tutor" / "plugins" / "_mereka_lms" / "mfe_dockerfile.py"
# mfe-node.sh removed in tracker #32; assertions now target the plugin module only.
SNAPSHOT_DOCKERFILE = REPO_ROOT / "infrastructure" / "tutor" / "mfe-build" / "Dockerfile"
RENDERED_DOCKERFILE = REPO_ROOT / "tutor_env" / "env" / "plugins" / "mfe" / "build" / "mfe" / "Dockerfile"


def test_account_mfe_hook_guards_null_social_links() -> None:
    plugin = PLUGIN_FILE.read_text(encoding="utf-8")

    # Post-build compiled guard must be in the plugin (not pre-build source patch)
    assert '"mfe-dockerfile-post-npm-install-account"' not in plugin
    assert '"mfe-dockerfile-post-npm-build"' in plugin
    assert "unguarded social_links lookup survived account build" in plugin
    assert "guarded social_links source missing from compiled account assets" in plugin

    # mfe-node.sh was removed in tracker #32; verify the file is absent
    removed_patch = REPO_ROOT / "infrastructure" / "tutor" / "patches" / "mfe-node.sh"
    assert not removed_patch.exists(), (
        "mfe-node.sh must not exist after tracker #32 cleanup — "
        "all MFE Dockerfile hooks live in _mereka_lms/mfe_dockerfile.py"
    )


def test_rendered_account_mfe_dockerfile_carries_null_guard_when_available() -> None:
    snapshot = SNAPSHOT_DOCKERFILE.read_text(encoding="utf-8")
    copy_line = "COPY --from=account-src / /openedx/app"
    patch_anchor = 'service_path = Path("/openedx/app/src/account-settings/data/service.js")'

    assert copy_line in snapshot
    assert patch_anchor in snapshot
    assert snapshot.index(copy_line) < snapshot.index(patch_anchor)
    assert 'service_path = Path("/openedx/app/src/account-settings/data/service.js")' in snapshot
    assert "frontend-app-account social_links patch was a no-op" in snapshot
    assert "frontend-app-account social_links guard missing after patch write" in snapshot
    assert "unguarded social_links lookup survived account build" in snapshot
    assert "guarded social_links source missing from compiled account assets" in snapshot

    if not RENDERED_DOCKERFILE.exists():
        return

    content = RENDERED_DOCKERFILE.read_text(encoding="utf-8")
    assert copy_line in content
    assert patch_anchor in content
    assert content.index(copy_line) < content.index(patch_anchor)
    assert 'service_path = Path("/openedx/app/src/account-settings/data/service.js")' in content
    assert "frontend-app-account social_links patch was a no-op" in content
    assert "frontend-app-account social_links guard missing after patch write" in content
