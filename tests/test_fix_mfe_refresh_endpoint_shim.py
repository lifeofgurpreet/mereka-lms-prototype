from __future__ import annotations

import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "infra" / "fix-mfe-refresh-endpoint-site-config.sh"


def run_script(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(SCRIPT), *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def test_help_reports_canonical_multisite_apply_flow() -> None:
    result = run_script("--help")

    assert result.returncode == 0
    assert "Retired compatibility shim." in result.stdout
    assert "apply-multisite-config.sh" in result.stdout
    assert "REFRESH_ACCESS_TOKEN_ENDPOINT=/login_refresh" in result.stdout


def test_legacy_invocation_fails_with_guidance() -> None:
    result = run_script("--apply")
    combined = result.stdout + result.stderr

    assert result.returncode == 2
    assert "retired compatibility shim" in combined
    assert "no longer patches SiteConfiguration directly" in combined
    assert "apply-multisite-config.sh" in combined
    assert "--apply" in combined
