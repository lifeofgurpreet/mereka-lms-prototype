from __future__ import annotations

import json
import subprocess
from pathlib import Path

import jsonschema

REPO_ROOT = Path(__file__).resolve().parent.parent
IDENTITY_SESSION_SCHEMA_PATH = REPO_ROOT / "schemas" / "identity-session-proof.schema.json"
TENANT_BRANDING_SCHEMA_PATH = REPO_ROOT / "schemas" / "tenant-branding-proof.schema.json"


def load_schema(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def run_lms_ops_accept(subconcern: str, output_dir: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            "bash",
            "bin/lms-ops",
            "accept",
            subconcern,
            "--lane",
            "dev",
            "--tenant",
            "biji-biji",
            "--dry-run",
            "--output-dir",
            str(output_dir),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def load_summary(result: subprocess.CompletedProcess[str]) -> dict:
    assert result.returncode == 0, result.stdout + result.stderr
    summary_path = Path(result.stdout.strip().splitlines()[-1])
    assert summary_path.exists(), result.stdout + result.stderr
    return json.loads(summary_path.read_text(encoding="utf-8"))


def test_lms_ops_accept_identity_session_dry_run_emits_valid_summary(tmp_path: Path) -> None:
    result = run_lms_ops_accept("identity-session", tmp_path / "identity-session")
    summary = load_summary(result)

    assert summary["schema_version"] == "identity-session-proof/v1"
    assert summary["lane"] == "identity-session"
    assert summary["environment"] == "dev"
    assert summary["tenant_filter"] == "biji-biji"
    assert summary["mode"] == "dry-run"
    assert summary["verdict"]["status"] == "pass"
    assert summary["verdict"]["failed_checks"] == 0
    assert {check["name"] for check in summary["checks"]} == {
        "cookie-domain:biji-biji",
        "auth-redirect:biji-biji",
        "studio-sso:biji-biji",
    }
    assert all(check["status"] == "planned" for check in summary["checks"])
    jsonschema.validate(summary, load_schema(IDENTITY_SESSION_SCHEMA_PATH))


def test_lms_ops_accept_tenant_branding_dry_run_emits_valid_summary(tmp_path: Path) -> None:
    result = run_lms_ops_accept("tenant-branding", tmp_path / "tenant-branding")
    summary = load_summary(result)

    assert summary["schema_version"] == "tenant-branding-proof/v1"
    assert summary["lane"] == "tenant-branding"
    assert summary["environment"] == "dev"
    assert summary["tenant_filter"] == "biji-biji"
    assert summary["mode"] == "dry-run"
    assert summary["verdict"]["status"] == "pass"
    assert summary["verdict"]["failed_checks"] == 0
    assert summary["visual_contract_totals"] == {"pass": 0, "fail": 0, "warn": 0}
    assert summary["checks"] == [
        {
            "name": "visual-contract:dev:biji-biji",
            "status": "planned",
            "exit_code": 0,
            "log": str((tmp_path / "tenant-branding" / "visual-contract.log").resolve()),
        }
    ]
    visual_log = Path(summary["checks"][0]["log"]).read_text(encoding="utf-8")
    assert "--tenant biji-biji" in visual_log
    jsonschema.validate(summary, load_schema(TENANT_BRANDING_SCHEMA_PATH))
