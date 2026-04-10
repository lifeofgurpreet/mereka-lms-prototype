from __future__ import annotations

import importlib.util
import json
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "release" / "release_object_bindings.py"


def load_module():
    spec = importlib.util.spec_from_file_location("release_object_bindings", SCRIPT_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    return module


def sample_release_object() -> dict:
    return {
        "schema_version": "release-object/v1",
        "release_id": "ro-rb-abcdef1234567-20260403T120000Z",
        "created_at_utc": "2026-04-03T12:00:00Z",
        "service_id": "mereka-lms",
        "repository": "Biji-Biji-Initiative/mereka-lms",
        "app_commit_sha": "a" * 40,
        "build_origin_environment": "dev",
        "promotion_target_environment": None,
        "tenant_contract": {
            "path": "/tmp/tenant-registry.yaml",
            "sha256": "1" * 64,
            "control_plane_ref": "Biji-Biji-Initiative/platform-control-plane@194e6001c924902e8bf3dafefdc37fc842c56653",
        },
        "build": {
            "workflow": ".github/workflows/build-tutor-images.yml",
            "run_id": "123",
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
        "proof_refs": ["var/proof/release-gate.json"],
        "promotion": {
            "status": "build-only",
            "gitops_repository": None,
            "gitops_commit_sha": None,
        },
    }


def test_release_identity_is_extracted_from_release_object(tmp_path: Path) -> None:
    module = load_module()
    release_object_path = tmp_path / "release-object.json"
    release_object_path.write_text(json.dumps(sample_release_object()) + "\n", encoding="utf-8")

    payload = module.release_identity_from_object(
        sample_release_object(),
        release_object_path,
    )

    assert payload["release_id"] == "ro-rb-abcdef1234567-20260403T120000Z"
    assert payload["release_bundle_id"] == "rb-abcdef1234567-20260403T120000Z"
    assert payload["app_commit_sha"] == "a" * 40
    assert payload["release_object_json"] == str(release_object_path.resolve())
    assert payload["proof_refs"] == ["var/proof/release-gate.json"]


def test_promotion_inputs_fill_missing_digests_and_sha_from_release_object(tmp_path: Path) -> None:
    module = load_module()
    release_object_path = tmp_path / "release-object.json"
    payload = sample_release_object()
    release_object_path.write_text(json.dumps(payload) + "\n", encoding="utf-8")

    resolved = module.resolve_promotion_inputs(
        payload,
        release_object_path=release_object_path,
        target_env="staging",
        openedx_digest=None,
        mfe_digest=None,
        app_sha=None,
    )

    assert resolved["release_id"] == "ro-rb-abcdef1234567-20260403T120000Z"
    assert resolved["openedx_digest"] == "sha256:" + "1" * 64
    assert resolved["mfe_digest"] == "sha256:" + "2" * 64
    assert resolved["app_commit_sha"] == "a" * 40


def test_promotion_inputs_reject_digest_mismatch(tmp_path: Path) -> None:
    module = load_module()
    release_object_path = tmp_path / "release-object.json"
    payload = sample_release_object()
    release_object_path.write_text(json.dumps(payload) + "\n", encoding="utf-8")

    try:
        module.resolve_promotion_inputs(
            payload,
            release_object_path=release_object_path,
            target_env="dev",
            openedx_digest="sha256:" + "f" * 64,
            mfe_digest=None,
            app_sha=None,
        )
    except SystemExit as exc:
        assert "openedx digest does not match release object" in str(exc)
    else:
        raise AssertionError("expected mismatched digest to raise SystemExit")


def test_verify_proof_envelope_detects_missing_release_binding(tmp_path: Path) -> None:
    module = load_module()
    release_object_path = tmp_path / "release-object.json"
    release_object_path.write_text(json.dumps(sample_release_object()) + "\n", encoding="utf-8")
    release_identity = module.release_identity_from_object(sample_release_object(), release_object_path)

    errors = module.verify_proof_envelope(
        {
            "schema_version": "1",
            "concern": "release-gate",
            "details": {},
        },
        release_identity,
    )

    assert errors == ["proof envelope missing top-level release_identity"]


def test_verify_proof_envelope_cli_passes_for_matching_release_identity(tmp_path: Path) -> None:
    release_object_path = tmp_path / "release-object.json"
    release_object_path.write_text(json.dumps(sample_release_object()) + "\n", encoding="utf-8")
    release_identity = {
        "release_id": "ro-rb-abcdef1234567-20260403T120000Z",
        "release_bundle_id": "rb-abcdef1234567-20260403T120000Z",
        "app_commit_sha": "a" * 40,
        "release_object_json": str(release_object_path.resolve()),
        "build_origin_environment": "dev",
        "promotion_target_environment": None,
        "proof_refs": ["var/proof/release-gate.json"],
    }
    envelope_path = tmp_path / "release-gate-envelope.json"
    envelope_path.write_text(
        json.dumps(
            {
                "schema_version": "1",
                "concern": "release-gate",
                "details": {"release_identity": release_identity},
                "release_identity": release_identity,
            }
        )
        + "\n",
        encoding="utf-8",
    )

    result = subprocess.run(
        [
            "python3",
            str(SCRIPT_PATH),
            "verify-proof-envelope",
            "--envelope-json",
            str(envelope_path),
            "--release-object-json",
            str(release_object_path),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS: proof envelope bound to ro-rb-abcdef1234567-20260403T120000Z" in result.stdout
