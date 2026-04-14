from __future__ import annotations

import os
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "qa" / "verify-vendored-settings-drift.sh"
TRACKED_FILE = "apps/openedx/settings/lms/production.py"
RUNTIME_TRACKED_FILE = "apps/lms/deployment.yaml"


def write_tracked_file(root: Path, relative_path: str, content: str) -> None:
    path = root / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def init_git_repo(repo_root: Path) -> None:
    subprocess.run(["git", "init"], cwd=repo_root, check=True, capture_output=True, text=True)
    subprocess.run(["git", "config", "user.name", "Codex"], cwd=repo_root, check=True, capture_output=True, text=True)
    subprocess.run(["git", "config", "user.email", "codex@example.com"], cwd=repo_root, check=True, capture_output=True, text=True)
    subprocess.run(["git", "add", "."], cwd=repo_root, check=True, capture_output=True, text=True)
    subprocess.run(["git", "commit", "-m", "seed"], cwd=repo_root, check=True, capture_output=True, text=True)
    subprocess.run(
        ["git", "update-ref", "refs/remotes/origin/main", "HEAD"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )


def run_verify(repo_root: Path, *, infra_repo: Path | None, home_dir: Path) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["REPO_ROOT_OVERRIDE"] = str(repo_root)
    env["HOME"] = str(home_dir)
    if infra_repo is None:
        env.pop("INFRA_REPO", None)
    else:
        env["INFRA_REPO"] = str(infra_repo)
    return subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )


def test_explicit_infra_repo_is_not_overridden_by_autodetect(tmp_path: Path) -> None:
    app_repo = tmp_path / "app"
    explicit_infra = tmp_path / "explicit-infra"
    autodetect_infra = tmp_path / "home" / "projects" / "k8s" / "bbi-infrastructure"
    tracked_rel = f"deploy/k8s/base/{TRACKED_FILE}"
    vendored_rel = f"apps/mereka-lms/base/deploy/k8s/base/{TRACKED_FILE}"

    write_tracked_file(app_repo, tracked_rel, "APP=canonical\n")
    write_tracked_file(explicit_infra, vendored_rel, "APP=canonical\n")
    write_tracked_file(autodetect_infra, vendored_rel, "APP=stale\n")
    init_git_repo(explicit_infra)
    init_git_repo(autodetect_infra)

    result = run_verify(app_repo, infra_repo=explicit_infra, home_dir=tmp_path / "home")

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"Infra repo: {explicit_infra}" in result.stdout
    assert "OK   production.py: in sync" in result.stdout


def test_autodetect_falls_back_to_default_infra_repo(tmp_path: Path) -> None:
    app_repo = tmp_path / "app"
    autodetect_infra = tmp_path / "home" / "projects" / "k8s" / "bbi-infrastructure"
    tracked_rel = f"deploy/k8s/base/{TRACKED_FILE}"
    vendored_rel = f"apps/mereka-lms/base/deploy/k8s/base/{TRACKED_FILE}"

    write_tracked_file(app_repo, tracked_rel, "APP=canonical\n")
    write_tracked_file(autodetect_infra, vendored_rel, "APP=stale\n")
    init_git_repo(autodetect_infra)

    result = run_verify(app_repo, infra_repo=None, home_dir=tmp_path / "home")

    assert result.returncode == 1, result.stdout + result.stderr
    assert f"Infra repo: {autodetect_infra}" in result.stdout
    assert "FAIL production.py: diverged" in result.stdout


def test_explicit_invalid_infra_repo_fails_loudly(tmp_path: Path) -> None:
    app_repo = tmp_path / "app"
    invalid_infra = tmp_path / "missing-infra"
    tracked_rel = f"deploy/k8s/base/{TRACKED_FILE}"

    write_tracked_file(app_repo, tracked_rel, "APP=canonical\n")

    result = run_verify(app_repo, infra_repo=invalid_infra, home_dir=tmp_path / "home")

    assert result.returncode == 2
    assert f"ERROR: explicit INFRA_REPO is invalid: {invalid_infra}" in result.stderr


def test_runtime_manifest_drift_fails_loudly(tmp_path: Path) -> None:
    app_repo = tmp_path / "app"
    infra_repo = tmp_path / "infra"
    tracked_rel = f"deploy/k8s/base/{RUNTIME_TRACKED_FILE}"
    vendored_rel = f"apps/mereka-lms/base/deploy/k8s/base/{RUNTIME_TRACKED_FILE}"

    write_tracked_file(
        app_repo,
        tracked_rel,
        "startupProbe:\n  timeoutSeconds: 30\nlivenessProbe:\n  timeoutSeconds: 30\n",
    )
    write_tracked_file(
        infra_repo,
        vendored_rel,
        "startupProbe:\n  timeoutSeconds: 5\nlivenessProbe:\n  timeoutSeconds: 5\n",
    )
    init_git_repo(infra_repo)

    result = run_verify(app_repo, infra_repo=infra_repo, home_dir=tmp_path / "home")

    assert result.returncode == 1, result.stdout + result.stderr
    assert "FAIL deployment.yaml: diverged" in result.stdout


def test_explicit_git_worktree_path_is_accepted(tmp_path: Path) -> None:
    app_repo = tmp_path / "app"
    infra_main = tmp_path / "infra-main"
    infra_worktree = tmp_path / "infra-worktree"
    tracked_rel = f"deploy/k8s/base/{TRACKED_FILE}"
    vendored_rel = f"apps/mereka-lms/base/deploy/k8s/base/{TRACKED_FILE}"

    write_tracked_file(app_repo, tracked_rel, "APP=canonical\n")
    write_tracked_file(infra_main, vendored_rel, "APP=canonical\n")
    init_git_repo(infra_main)
    subprocess.run(
        ["git", "worktree", "add", str(infra_worktree), "HEAD"],
        cwd=infra_main,
        check=True,
        capture_output=True,
        text=True,
    )

    result = run_verify(app_repo, infra_repo=infra_worktree, home_dir=tmp_path / "home")

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"Infra repo: {infra_worktree}" in result.stdout
    assert "OK   production.py: in sync" in result.stdout
