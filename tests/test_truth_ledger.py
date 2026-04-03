from __future__ import annotations

import importlib.util
import json
import subprocess
from pathlib import Path

import jsonschema

REPO_ROOT = Path(__file__).resolve().parent.parent
LEDGER_PATH = REPO_ROOT / "scripts" / "release" / "generate_truth_ledger.py"
LEDGER_SCHEMA_PATH = REPO_ROOT / "schemas" / "truth-ledger.schema.json"


def load_ledger_module():
    spec = importlib.util.spec_from_file_location("truth_ledger", LEDGER_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    return module


def load_ledger_schema() -> dict:
    return json.loads(LEDGER_SCHEMA_PATH.read_text(encoding="utf-8"))


def test_truth_ledger_builds_partial_payload_from_acceptance_summary(tmp_path: Path) -> None:
    module = load_ledger_module()
    summary = {
        "schema_version": "runtime-routing-proof/v1",
        "lane": "runtime-routing",
        "environment": "dev",
        "tenant_filter": "biji-biji",
        "mode": "execute",
        "verdict": {"status": "pass", "failed_checks": 0},
        "verdict_planes": {
            "routing_core": {"status": "pass", "failed_checks": 0, "check_count": 1},
            "adjacent_surface": {"status": "not-applicable", "failed_checks": 0, "check_count": 0},
        },
        "contract": {
            "source": "deploy/k8s/tenancy/tenant-registry.yaml",
            "source_version": "2026-04-03",
            "schema_version": "runtime-routing-contract/v1",
        },
        "artifacts": {"output_dir": str(tmp_path / "bundle")},
        "matrix": {"tenant": "biji-biji", "hosts": {"mfe": "apps.biji-biji.academyv2.mereka.dev"}},
        "checks": [{"name": "contract:biji-biji", "status": "pass", "exit_code": 0, "log": "contract.log"}],
    }
    summary_path = tmp_path / "summary.json"
    output_path = tmp_path / "truth-ledger.json"
    summary_path.write_text(json.dumps(summary) + "\n", encoding="utf-8")

    payload = module.build_payload(
        summary,
        app_sha="55c932f75d4144cba8d5a6789aa7ab0fa8dd426a",
        infra_commit_sha=None,
        argo_truth={"status": "unknown", "app_name": None},
        runtime_truth={"status": "unknown", "namespace": None, "deployments": [], "tracked_images": []},
        release_truth={
            "release_object_id": None,
            "release_object_json": None,
            "build_origin_environment": None,
            "promotion_target_environment": None,
            "openedx_image": None,
            "mfe_image": None,
            "proof_refs": [],
        },
        summary_path=summary_path,
        output_path=output_path,
    )

    assert payload["schema_version"] == "runtime-truth-ledger/v1"
    assert payload["record_id"] == "runtime-routing:dev:biji-biji"
    assert payload["repo_truth"]["app_commit_sha"] == "55c932f75d4144cba8d5a6789aa7ab0fa8dd426a"
    assert payload["acceptance_truth"]["verdict"]["status"] == "pass"
    assert payload["acceptance_truth"]["verdict_planes"]["routing_core"]["status"] == "pass"
    assert payload["contract_truth"]["matrix_sha256"]
    assert payload["final_verdict"]["status"] == "partial"
    jsonschema.validate(payload, load_ledger_schema())


def test_truth_ledger_marks_release_runtime_digest_mismatch_as_fail(tmp_path: Path) -> None:
    module = load_ledger_module()
    summary = {
        "lane": "runtime-routing",
        "environment": "dev",
        "tenant_filter": "biji-biji",
        "mode": "execute",
        "verdict": {"status": "pass", "failed_checks": 0},
        "verdict_planes": {
            "routing_core": {"status": "pass", "failed_checks": 0, "check_count": 0},
            "adjacent_surface": {"status": "not-applicable", "failed_checks": 0, "check_count": 0},
        },
        "contract": {"source": "deploy/k8s/tenancy/tenant-registry.yaml", "source_version": "2026-04-03", "schema_version": "runtime-routing-contract/v1"},
        "artifacts": {"output_dir": str(tmp_path / "bundle")},
        "matrix": {"tenant": "biji-biji"},
        "checks": [],
    }
    summary_path = tmp_path / "summary.json"
    output_path = tmp_path / "truth-ledger.json"
    summary_path.write_text(json.dumps(summary) + "\n", encoding="utf-8")

    release_truth = {
        "release_object_id": "ro-rb-abcdef1234567-20260403T120000Z",
        "release_object_json": str(tmp_path / "release-object.json"),
        "build_origin_environment": "dev",
        "promotion_target_environment": "staging",
        "openedx_image": module.parse_image_reference("ghcr.io/biji-biji-initiative/mereka-lms/openedx:abc@sha256:111"),
        "mfe_image": module.parse_image_reference("ghcr.io/biji-biji-initiative/mereka-lms/mfe:abc@sha256:222"),
        "proof_refs": [],
    }
    runtime_truth = {
        "status": "known",
        "namespace": "mereka-lms-dev",
        "deployments": [],
        "tracked_images": [
            module.parse_image_reference("ghcr.io/biji-biji-initiative/mereka-lms/openedx:abc@sha256:999"),
            module.parse_image_reference("ghcr.io/biji-biji-initiative/mereka-lms/mfe:abc@sha256:222"),
        ],
    }

    payload = module.build_payload(
        summary,
        app_sha="55c932f75d4144cba8d5a6789aa7ab0fa8dd426a",
        infra_commit_sha="cefd938f4058a9f63cb1f1b78d31acb34ce3c9d0",
        argo_truth={"status": "known", "app_name": "mereka-lms-dev", "sync_status": "Synced", "health_status": "Healthy", "revision": "cefd938f4058a9f63cb1f1b78d31acb34ce3c9d0", "reconciled_at": "2026-04-03T00:00:00Z"},
        runtime_truth=runtime_truth,
        release_truth=release_truth,
        summary_path=summary_path,
        output_path=output_path,
    )

    assert payload["final_verdict"]["status"] == "fail"
    assert any(item["status"] == "fail" for item in payload["plane_comparisons"])
    jsonschema.validate(payload, load_ledger_schema())


def test_truth_ledger_cli_emits_file_from_dry_run_bundle(tmp_path: Path) -> None:
    output_dir = tmp_path / "accept-runtime-routing"
    accept = subprocess.run(
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
    assert accept.returncode == 0, accept.stdout + accept.stderr
    summary_path = Path(accept.stdout.strip())

    ledger = subprocess.run(
        [
            "python3",
            str(LEDGER_PATH),
            "--summary-json",
            str(summary_path),
            "--output",
            str(output_dir / "truth-ledger.json"),
            "--app-sha",
            "55c932f75d4144cba8d5a6789aa7ab0fa8dd426a",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert ledger.returncode == 0, ledger.stdout + ledger.stderr

    payload = json.loads((output_dir / "truth-ledger.json").read_text(encoding="utf-8"))
    assert payload["schema_version"] == "runtime-truth-ledger/v1"
    assert payload["artifacts"]["acceptance_summary_json"] == str(summary_path)
    jsonschema.validate(payload, load_ledger_schema())


def test_truth_ledger_uses_release_object_when_provided(tmp_path: Path) -> None:
    output_dir = tmp_path / "accept-runtime-routing"
    accept = subprocess.run(
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
    assert accept.returncode == 0, accept.stdout + accept.stderr
    summary_path = Path(accept.stdout.strip())
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

    ledger = subprocess.run(
        [
            "python3",
            str(LEDGER_PATH),
            "--summary-json",
            str(summary_path),
            "--output",
            str(output_dir / "truth-ledger.json"),
            "--release-object-json",
            str(release_object_path),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert ledger.returncode == 0, ledger.stdout + ledger.stderr

    payload = json.loads((output_dir / "truth-ledger.json").read_text(encoding="utf-8"))
    assert payload["release_truth"]["release_object_id"] == "ro-rb-abcdef1234567-20260403T120000Z"
    assert payload["release_truth"]["build_origin_environment"] == "dev"
    assert payload["release_truth"]["promotion_target_environment"] is None
    assert payload["artifacts"]["release_object_json"] == str(release_object_path.resolve())
    jsonschema.validate(payload, load_ledger_schema())
