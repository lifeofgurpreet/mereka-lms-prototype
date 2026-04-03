from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import jsonschema


REPO_ROOT = Path(__file__).resolve().parent.parent
GENERATOR_PATH = REPO_ROOT / "scripts" / "acceptance" / "generate_runtime_routing_matrix.py"
PROOF_SCHEMA_PATH = REPO_ROOT / "schemas" / "runtime-routing-proof.schema.json"


def load_generator_module():
    spec = importlib.util.spec_from_file_location("runtime_routing_matrix", GENERATOR_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    return module


def load_proof_schema() -> dict:
    return json.loads(PROOF_SCHEMA_PATH.read_text(encoding="utf-8"))


def test_runtime_routing_matrix_builds_dev_payload() -> None:
    module = load_generator_module()
    payload = module.build_payload(module.load_registry(), "dev")

    assert payload["schema_version"] == "runtime-routing-contract/v1"
    assert payload["lane"] == "runtime-routing"
    assert payload["environment"] == "dev"
    assert payload["environment_contract"]["runtime_proof_script"] == "scripts/tenants/verify-dev-runtime-proof.sh"
    assert payload["environment_contract"]["acceptance_profile"]["dashboard_redirect"]["expect_final_role"] == "mfe"
    assert "generated_at_utc" not in payload
    assert any(tenant["tenant"] == "biji-biji" for tenant in payload["tenants"])

    biji = next(tenant for tenant in payload["tenants"] if tenant["tenant"] == "biji-biji")
    assert biji["hosts"]["mfe"].startswith("apps.")
    assert biji["forbidden_hosts"]
    assert biji["playwright_selector_audit_routes"] == ["/authn/login", "/learner-dashboard/", "/profile/"]
    assert any(assertion["id"] == "dashboard-route" for assertion in biji["assertions"])


def test_runtime_routing_matrix_is_deterministic_for_noop_regen() -> None:
    module = load_generator_module()
    registry = module.load_registry()

    assert module.build_payload(registry, "dev") == module.build_payload(registry, "dev")


def test_accept_runtime_routing_dry_run_emits_summary(tmp_path: Path) -> None:
    output_dir = tmp_path / "accept-runtime-routing"
    result = subprocess.run(
        [
            "bash",
            "bin/accept",
            "runtime-routing",
            "--env",
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

    assert result.returncode == 0, result.stdout + result.stderr
    summary_path = Path(result.stdout.strip())
    assert summary_path.exists(), result.stdout + result.stderr

    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    assert summary["schema_version"] == "runtime-routing-proof/v1"
    assert summary["lane"] == "runtime-routing"
    assert summary["environment"] == "dev"
    assert summary["mode"] == "dry-run"
    assert summary["tenant_filter"] == "biji-biji"
    assert summary["verdict"]["status"] == "pass"
    assert summary["verdict"]["failed_checks"] == 0
    assert summary["contract"]["schema_version"] == "runtime-routing-contract/v1"
    assert Path(summary["artifacts"]["truth_ledger_json"]).exists()
    assert Path(summary["artifacts"]["canonical_truth_ledger_json"]).exists()
    assert any(check["name"].startswith("playwright:biji-biji") for check in summary["checks"])
    jsonschema.validate(summary, load_proof_schema())
