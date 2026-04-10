from __future__ import annotations

import importlib.util
import json
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "release" / "generate_release_object.py"


def load_module():
    spec = importlib.util.spec_from_file_location("release_object", SCRIPT_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    return module

def release_bundle_payload() -> dict:
    return {
        "schema_version": "1.1",
        "bundle_id": "rb-abcdef1234567-20260403T120000Z",
        "created_at": "2026-04-03T12:00:00Z",
        "repository": "Biji-Biji-Initiative/mereka-lms",
        "commit_sha": "a" * 40,
        "target_environment": "dev",
        "service_id": "mereka-lms",
        "contract_family": "release_bundle_schema",
        "contract_version": "1.0",
        "contract_ref": "Biji-Biji-Initiative/platform-control-plane@194e6001c924902e8bf3dafefdc37fc842c56653",
        "build": {
            "workflow": ".github/workflows/build-tutor-images.yml",
            "run_id": "123",
            "run_attempt": "1"
        },
        "images": {
            "openedx": {
                "name": "ghcr.io/biji-biji-initiative/mereka-lms/openedx",
                "digest": "sha256:" + "1" * 64
            },
            "mfe": {
                "name": "ghcr.io/biji-biji-initiative/mereka-lms/mfe",
                "digest": "sha256:" + "2" * 64
            }
        },
        "artifacts": {
            "sbom": {"openedx": "sbom-openedx", "mfe": "sbom-mfe"},
            "provenance": {
                "artifact_name": "slsa-provenance",
                "openedx_predicate": "var/ci/provenance-openedx.json",
                "mfe_predicate": "var/ci/provenance-mfe.json"
            },
            "vulnerability_scan": {"openedx": "trivy-openedx-scan", "mfe": "trivy-mfe-scan"}
        }
    }


def test_release_object_builds_from_release_bundle_only(tmp_path: Path) -> None:
    module = load_module()
    release_bundle_path = tmp_path / "release-bundle.json"
    tenant_contract_path = tmp_path / "tenant-registry.yaml"
    release_bundle_path.write_text(json.dumps(release_bundle_payload()) + "\n", encoding="utf-8")
    tenant_contract_path.write_text("tenants: []\n", encoding="utf-8")

    payload = module.build_payload(
        release_bundle_payload(),
        release_bundle_path=release_bundle_path,
        tenant_contract_path=tenant_contract_path,
        build_provenance=None,
        build_provenance_path=None,
        proof_refs=[],
        release_id=None,
    )

    assert payload["schema_version"] == "release-object/v1"
    assert payload["release_id"] == "ro-rb-abcdef1234567-20260403T120000Z"
    assert payload["build_origin_environment"] == "dev"
    assert payload["promotion_target_environment"] is None
    assert payload["target_environment"] == "dev"
    assert payload["contract_family"] == "release_object_projection_schema"
    assert payload["contract_version"] == "1.0"
    assert payload["contract_ref"] == release_bundle_payload()["contract_ref"]
    assert payload["promotion"]["status"] == "build-only"
    assert payload["promotion"]["gitops_commit_sha"] is None
    assert payload["tenant_contract"]["sha256"]


def test_release_object_links_build_provenance_when_present(tmp_path: Path) -> None:
    module = load_module()
    release_bundle_path = tmp_path / "release-bundle.json"
    build_provenance_path = tmp_path / "build-provenance.json"
    tenant_contract_path = tmp_path / "tenant-registry.yaml"
    release_bundle_path.write_text(json.dumps(release_bundle_payload()) + "\n", encoding="utf-8")
    build_provenance_path.write_text(
        json.dumps(
            {
                "schema_version": "1.0.0",
                "repository": "Biji-Biji-Initiative/mereka-lms",
                "commit_sha": "a" * 40,
                "target_environment": "dev",
                "release_bundle_id": "rb-abcdef1234567-20260403T120000Z",
                "images": {
                    "openedx_digest": "sha256:" + "1" * 64,
                    "mfe_digest": "sha256:" + "2" * 64
                },
                "gitops": {
                    "repository": "Biji-Biji-Initiative/bbi-infrastructure",
                    "commit_sha": "b" * 40
                }
            }
        ) + "\n",
        encoding="utf-8",
    )
    tenant_contract_path.write_text("tenants: []\n", encoding="utf-8")

    payload = module.build_payload(
        release_bundle_payload(),
        release_bundle_path=release_bundle_path,
        tenant_contract_path=tenant_contract_path,
        build_provenance=json.loads(build_provenance_path.read_text(encoding="utf-8")),
        build_provenance_path=build_provenance_path,
        proof_refs=["var/acceptance/runtime-routing/dev/20260403T120000Z/summary.json"],
        release_id=None,
    )

    assert payload["promotion"]["status"] == "gitops-linked"
    assert payload["promotion"]["gitops_repository"] == "Biji-Biji-Initiative/bbi-infrastructure"
    assert payload["promotion"]["gitops_commit_sha"] == "b" * 40
    assert payload["build_origin_environment"] == "dev"
    assert payload["promotion_target_environment"] == "dev"
    assert payload["proof_refs"] == ["var/acceptance/runtime-routing/dev/20260403T120000Z/summary.json"]
    assert payload["contract_family"] == "release_object_projection_schema"
    assert payload["contract_version"] == "1.0"
    assert payload["contract_ref"] == release_bundle_payload()["contract_ref"]


def test_release_object_cli_emits_schema_valid_payload(tmp_path: Path) -> None:
    release_bundle_path = tmp_path / "release-bundle.json"
    tenant_contract_path = tmp_path / "tenant-registry.yaml"
    output_path = tmp_path / "release-object.json"
    release_bundle_path.write_text(json.dumps(release_bundle_payload()) + "\n", encoding="utf-8")
    tenant_contract_path.write_text("tenants: []\n", encoding="utf-8")

    result = subprocess.run(
        [
            "python3",
            str(SCRIPT_PATH),
            "--release-bundle-json",
            str(release_bundle_path),
            "--tenant-contract-path",
            str(tenant_contract_path),
            "--output",
            str(output_path),
            "--proof-ref",
            "var/acceptance/runtime-routing/dev/20260403T120000Z/summary.json"
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr

    payload = json.loads(output_path.read_text(encoding="utf-8"))
    assert payload["release_id"] == "ro-rb-abcdef1234567-20260403T120000Z"
    assert payload["build_origin_environment"] == "dev"
    assert payload["promotion_target_environment"] is None
    assert payload["proof_refs"] == ["var/acceptance/runtime-routing/dev/20260403T120000Z/summary.json"]
    assert payload["contract_family"] == "release_object_projection_schema"
    assert payload["contract_version"] == "1.0"
    assert payload["contract_ref"] == release_bundle_payload()["contract_ref"]
