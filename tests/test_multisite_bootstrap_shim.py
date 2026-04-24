from __future__ import annotations

import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "shared" / "multisite_bootstrap.py"


def run_script(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def test_help_proxies_to_django_helper() -> None:
    result = run_script("--help")

    assert result.returncode == 0
    assert "compatibility shim" in result.stderr
    assert "--scope {full,sites}" in result.stdout
    assert "Bootstrap django.contrib.sites + SiteConfiguration entries" in result.stdout


def test_legacy_direct_db_flags_fail_with_guidance() -> None:
    result = run_script("--env", "/tmp/lms.env.yml")
    combined = result.stdout + result.stderr

    assert result.returncode == 2
    assert "direct SQL or Cloud SQL connector mode" in combined
    assert "apply-multisite-config.sh" in combined
    assert "--env" in combined
