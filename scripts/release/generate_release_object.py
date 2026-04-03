#!/usr/bin/env python3
"""Build the canonical release object from the signed release bundle."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TENANT_CONTRACT_PATH = REPO_ROOT / "deploy" / "k8s" / "tenancy" / "tenant-registry.yaml"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-bundle-json", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--tenant-contract-path", type=Path, default=DEFAULT_TENANT_CONTRACT_PATH)
    parser.add_argument("--build-provenance-json", type=Path)
    parser.add_argument("--proof-ref", action="append", default=[])
    parser.add_argument("--release-id")
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def build_payload(
    release_bundle: dict[str, Any],
    *,
    release_bundle_path: Path,
    tenant_contract_path: Path,
    build_provenance: dict[str, Any] | None,
    build_provenance_path: Path | None,
    proof_refs: list[str],
    release_id: str | None,
) -> dict[str, Any]:
    bundle_id = release_bundle["bundle_id"]
    payload_release_id = release_id or f"ro-{bundle_id}"

    if build_provenance and build_provenance.get("release_bundle_id") != bundle_id:
        raise SystemExit(
            "build provenance release_bundle_id does not match the provided release bundle"
        )

    promotion_status = "gitops-linked" if build_provenance else "build-only"
    promotion_repo = build_provenance.get("gitops", {}).get("repository") if build_provenance else None
    promotion_commit = build_provenance.get("gitops", {}).get("commit_sha") if build_provenance else None
    build_origin_environment = release_bundle["target_environment"]
    promotion_target_environment = (
        build_provenance.get("target_environment") if build_provenance else None
    )

    return {
        "schema_version": "release-object/v1",
        "release_id": payload_release_id,
        "created_at_utc": release_bundle["created_at"],
        "service_id": release_bundle["service_id"],
        "repository": release_bundle["repository"],
        "app_commit_sha": release_bundle["commit_sha"],
        "build_origin_environment": build_origin_environment,
        "promotion_target_environment": promotion_target_environment,
        # Transitional alias for existing consumers; new readers should use the explicit fields above.
        "target_environment": build_origin_environment,
        "tenant_contract": {
            "path": str(tenant_contract_path.resolve()),
            "sha256": file_sha256(tenant_contract_path),
            "control_plane_ref": release_bundle.get("contract_ref"),
        },
        "build": {
            "workflow": release_bundle["build"]["workflow"],
            "run_id": release_bundle["build"]["run_id"],
            "run_attempt": release_bundle["build"]["run_attempt"],
            "release_bundle_id": bundle_id,
        },
        "images": {
            "openedx": release_bundle["images"]["openedx"],
            "mfe": release_bundle["images"]["mfe"],
        },
        "source_artifacts": {
            "release_bundle_json": str(release_bundle_path.resolve()),
            "build_provenance_json": str(build_provenance_path.resolve()) if build_provenance_path else None,
        },
        "proof_refs": proof_refs,
        "promotion": {
            "status": promotion_status,
            "gitops_repository": promotion_repo,
            "gitops_commit_sha": promotion_commit,
        },
    }


def main() -> int:
    args = parse_args()
    release_bundle_path = args.release_bundle_json.resolve()
    tenant_contract_path = args.tenant_contract_path.resolve()
    output_path = args.output.resolve()

    release_bundle = load_json(release_bundle_path)
    build_provenance = None
    build_provenance_path = None
    if args.build_provenance_json:
        build_provenance_path = args.build_provenance_json.resolve()
        build_provenance = load_json(build_provenance_path)

    payload = build_payload(
        release_bundle,
        release_bundle_path=release_bundle_path,
        tenant_contract_path=tenant_contract_path,
        build_provenance=build_provenance,
        build_provenance_path=build_provenance_path,
        proof_refs=args.proof_ref,
        release_id=args.release_id,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
