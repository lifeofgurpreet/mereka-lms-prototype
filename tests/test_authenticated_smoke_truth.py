from __future__ import annotations

from pathlib import Path
import subprocess


REPO_ROOT = Path(__file__).resolve().parents[1]


def run_script(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", script],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def test_verify_authenticated_ui_smoke_enforces_staging_default_contract() -> None:
    result = run_script("scripts/qa/verify-authenticated-ui-smoke.sh")

    assert result.returncode == 0, result.stdout + result.stderr
    assert "CI workflow defaults env_scope to staging" in result.stdout
    assert "CI workflow resolves staging as the default authenticated smoke target" in result.stdout
    assert "CI workflow wires dedicated smoke secrets and staging canary fallback" in result.stdout
    assert "CI workflow propagates the resolved env scope into visual regression" in result.stdout


def test_authenticated_sso_canary_wiring_audit_checks_staging_first_defaults() -> None:
    audit_script = (REPO_ROOT / "scripts/qa/audit-authenticated-sso-canary-wiring.sh").read_text(encoding="utf-8")
    canary_script = (REPO_ROOT / "scripts/qa/verify-authenticated-sso-canary.sh").read_text(encoding="utf-8")
    workflow = (REPO_ROOT / ".github/workflows/smoke-authenticated.yml").read_text(encoding="utf-8")

    assert "canary workflow default env scope is staging" in audit_script
    assert "canary workflow fallback env scope is staging" in audit_script
    assert "authenticated smoke resolver defaults to staging" in audit_script
    assert 'ENV_SCOPE="staging"' in canary_script
    assert "default: 'staging'" in workflow
    assert "github.event.inputs.env_scope || 'staging'" in workflow
    assert 'scope="${INPUT_ENV_SCOPE:-staging}"' in workflow
    assert "steps.resolve-smoke.outputs.resolved_scope" in workflow
