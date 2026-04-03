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
    release_object_path = tmp_path / "release-object.json"
    release_object_path.write_text(
        json.dumps(
            {
                "schema_version": "release-object/v1",
                "release_id": "ro-rb-abcdef1234567-20260403T120000Z",
                "created_at_utc": "2026-04-03T12:00:00Z",
                "service_id": "mereka-lms",
                "repository": "Biji-Biji-Initiative/mereka-lms",
                "app_commit_sha": "55c932f75d4144cba8d5a6789aa7ab0fa8dd426a",
                "build_origin_environment": "dev",
                "promotion_target_environment": None,
                "target_environment": "dev",
                "tenant_contract": {
                    "path": str(REPO_ROOT / "deploy/k8s/tenancy/tenant-registry.yaml"),
                    "sha256": "b" * 64,
                    "control_plane_ref": "Biji-Biji-Initiative/platform-control-plane@5fffde1a",
                },
                "build": {
                    "workflow": ".github/workflows/build-tutor-images.yml",
                    "run_id": "1",
                    "run_attempt": "1",
                    "release_bundle_id": "rb-abcdef1234567-20260403T120000Z",
                },
                "images": {
                    "openedx": {
                        "name": "ghcr.io/biji-biji-initiative/mereka-lms/openedx",
                        "digest": "sha256:" + "1" * 64,
                    },
                    "mfe": {
                        "name": "ghcr.io/biji-biji-initiative/mereka-lms/mfe",
                        "digest": "sha256:" + "2" * 64,
                    },
                },
                "source_artifacts": {
                    "release_bundle_json": "/tmp/release-bundle.json",
                    "build_provenance_json": None,
                },
                "proof_refs": ["var/acceptance/runtime-routing/dev/example/summary.json"],
                "promotion": {
                    "status": "build-only",
                    "gitops_repository": None,
                    "gitops_commit_sha": None,
                },
            }
        )
        + "\n",
        encoding="utf-8",
    )
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
            "--release-object-json",
            str(release_object_path),
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
    assert summary["verdict_planes"]["routing_core"]["status"] == "pass"
    assert summary["verdict_planes"]["adjacent_surface"]["status"] == "pass"
    assert summary["contract"]["schema_version"] == "runtime-routing-contract/v1"
    assert summary["release_truth"]["release_object_id"] == "ro-rb-abcdef1234567-20260403T120000Z"
    assert summary["release_truth"]["build_origin_environment"] == "dev"
    assert summary["release_truth"]["promotion_target_environment"] is None
    assert summary["artifacts"]["release_object_json"] == str(release_object_path.resolve())
    assert Path(summary["artifacts"]["truth_ledger_json"]).exists()
    assert Path(summary["artifacts"]["canonical_truth_ledger_json"]).exists()
    truth_ledger = json.loads(Path(summary["artifacts"]["truth_ledger_json"]).read_text(encoding="utf-8"))
    assert truth_ledger["release_truth"]["release_object_id"] == "ro-rb-abcdef1234567-20260403T120000Z"
    assert any(check["name"].startswith("playwright:biji-biji") for check in summary["checks"])
    jsonschema.validate(summary, load_proof_schema())
