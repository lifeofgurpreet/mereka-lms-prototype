from __future__ import annotations

from pathlib import Path
import re

REPO_ROOT = Path(__file__).resolve().parent.parent
PLUGIN_FILE = REPO_ROOT / "infrastructure" / "tutor" / "plugins" / "_mereka_lms" / "mfe_dockerfile.py"
# mfe-node.sh removed in tracker #32; assertions now target the plugin module only.
SNAPSHOT_DOCKERFILE = REPO_ROOT / "infrastructure" / "tutor" / "mfe-build" / "Dockerfile"
RENDERED_DOCKERFILE = REPO_ROOT / "tutor_env" / "env" / "plugins" / "mfe" / "build" / "mfe" / "Dockerfile"
PULL_TRANSLATIONS_RETRY_SENTINEL = "pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry"
PULL_TRANSLATIONS_RETRY_FRAGMENT = 'pull_translations attempt ${attempt} failed; retrying in 15s'
RAW_PULL_TRANSLATIONS_REGEX = re.compile(
    r'^RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="[^"]*" pull_translations$',
    re.MULTILINE,
)


def test_account_mfe_hook_guards_null_social_links() -> None:
    plugin = PLUGIN_FILE.read_text(encoding="utf-8")

    # Pre-build patch hook must exist (applies fix to source before webpack builds)
    assert '"mfe-dockerfile-pre-npm-build-account"' in plugin
    assert "account social_links null-safety patch applied" in plugin

    # Post-build guard must exist (v2: checks source, not minified dist)
    assert '"mfe-dockerfile-post-npm-build"' in plugin
    assert "unguarded social_links lookup survived account build" in plugin
    # v2 guard checks source, not compiled dist (variable renamed by webpack)
    assert "guarded social_links fix missing from" in plugin

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

    # Snapshot must have source copy followed by patch step followed by guard
    assert copy_line in snapshot
    assert patch_anchor in snapshot
    assert snapshot.index(copy_line) < snapshot.index(patch_anchor)
    # Pre-build source patch assertions (applies fix before webpack build)
    assert "account social_links null-safety patch applied" in snapshot
    assert "account social_links patch anchor missing" in snapshot
    # Post-build guard assertions (v2: checks source for fix)
    assert "unguarded social_links lookup survived account build" in snapshot
    assert "guarded social_links fix missing from" in snapshot

    if not RENDERED_DOCKERFILE.exists():
        return

    content = RENDERED_DOCKERFILE.read_text(encoding="utf-8")
    assert copy_line in content
    assert patch_anchor in content
    assert content.index(copy_line) < content.index(patch_anchor)


def test_rendered_mfe_snapshot_matches_generated_authority_when_available() -> None:
    snapshot = SNAPSHOT_DOCKERFILE.read_text(encoding="utf-8")

    if not RENDERED_DOCKERFILE.exists():
        return

    rendered = RENDERED_DOCKERFILE.read_text(encoding="utf-8")
    assert rendered == snapshot, (
        "Generated MFE Dockerfile diverged from infrastructure/tutor/mfe-build/Dockerfile. "
        "Refresh the tracked snapshot from tutor_env/env/plugins/mfe/build/mfe/Dockerfile "
        "after tutor config save + prepare-tutor-build-context.sh."
    )


def test_snapshot_only_uses_wrapped_pull_translations_contract() -> None:
    snapshot = SNAPSHOT_DOCKERFILE.read_text(encoding="utf-8")

    sentinel_count = snapshot.count(PULL_TRANSLATIONS_RETRY_SENTINEL)
    retry_count = snapshot.count(PULL_TRANSLATIONS_RETRY_FRAGMENT)

    assert sentinel_count >= 1, (
        "Tracked MFE Dockerfile snapshot must carry the explicit pull_translations "
        "retry sentinel while it remains the sole allowed rendered Dockerfile rewrite."
    )
    assert not RAW_PULL_TRANSLATIONS_REGEX.search(snapshot), (
        "Tracked MFE Dockerfile snapshot still contains an unwrapped "
        "pull_translations RUN line."
    )
    assert sentinel_count == retry_count, (
        "Tracked MFE Dockerfile snapshot has inconsistent retry wrapper markers "
        f"(sentinels={sentinel_count}, retry_messages={retry_count})."
    )
