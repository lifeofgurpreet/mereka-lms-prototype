#!/usr/bin/env python3
"""Render a truthful PCP-facing projection from an app-local release bundle.

This does not claim the app release bundle is already the canonical
platform-control-plane release-bundle object. Instead it derives the fields that
are already knowable at build time and records the required PCP fields that
remain unresolved until later promotion/realization stages.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PLATFORM_ROOTS = [
    REPO_ROOT / ".." / "platform-control-plane",
    Path.home() / "projects" / "k8s" / "platform-control-plane",
    Path.home() / "projects" / "platform-control-plane",
    REPO_ROOT / ".." / ".." / "platform-control-plane",
]
REQUIRED_UNRESOLVED_REASONS = {
    "config_digest": (
        "Rendered GitOps/app config digest is not known at app image-build time; "
        "it becomes authoritative during promotion/realization."
    ),
    "evidence_pack_ref": (
        "Evidence pack identity is assembled from promotion/runtime proof after "
        "the build bundle is emitted."
    ),
    "rollback_target": (
        "Rollback target requires current promotion context and previous known-good "
        "bundle selection, which is not owned by the app build."
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-bundle-json", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--platform-control-plane-root", type=Path)
    return parser.parse_args()


def discover_platform_root(explicit: Path | None) -> Path:
    if explicit:
        root = explicit.resolve()
        if not (root / "contracts" / "release-contracts.yaml").is_file():
            raise SystemExit(
                f"platform-control-plane root missing contracts/release-contracts.yaml: {root}"
            )
        return root

    for candidate in DEFAULT_PLATFORM_ROOTS:
        resolved = candidate.resolve()
        if (resolved / "contracts" / "release-contracts.yaml").is_file():
            return resolved

    searched = ", ".join(str(path) for path in DEFAULT_PLATFORM_ROOTS)
    raise SystemExit(
        "platform-control-plane root not found; pass --platform-control-plane-root. "
        f"Searched: {searched}"
    )


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_yaml(path: Path) -> dict[str, Any]:
    payload = yaml.safe_load(path.read_text(encoding="utf-8"))
    return payload if isinstance(payload, dict) else {}


def bundle_image_to_artifact(name: str, image: dict[str, Any]) -> dict[str, str]:
    image_name = str(image.get("name", "")).strip()
    digest = str(image.get("digest", "")).strip()
    if not image_name or not digest:
        raise SystemExit(f"release bundle image '{name}' missing name/digest")
    return {"name": name, "image": image_name, "digest": digest}


def build_projection(
    release_bundle: dict[str, Any],
    *,
    platform_root: Path,
) -> dict[str, Any]:
    contracts = load_yaml(platform_root / "contracts" / "release-contracts.yaml")
    bundle_schema = load_yaml(platform_root / "contracts" / "release-bundle-schema.yaml")

    service_id = str(release_bundle.get("service_id", "")).strip()
    if not service_id:
        raise SystemExit("release bundle missing service_id")

    lanes = contracts.get("lanes")
    if not isinstance(lanes, dict):
        raise SystemExit("release-contracts.yaml missing lanes mapping")
    lane_contract = lanes.get(service_id)
    if not isinstance(lane_contract, dict):
        raise SystemExit(f"release-contracts.yaml missing lane for service_id '{service_id}'")

    images = release_bundle.get("images")
    if not isinstance(images, dict):
        raise SystemExit("release bundle missing images object")

    canonical_projection = {
        "bundle_id": release_bundle["bundle_id"],
        "lane": service_id,
        "service_id": service_id,
        "contract_family": release_bundle.get("contract_family"),
        "contract_version": release_bundle.get("contract_version"),
        "contract_ref": release_bundle.get("contract_ref"),
        "runtime_profile": lane_contract.get("runtime_profile"),
        "source_provenance_class": lane_contract.get("source_provenance_class"),
        "created_at": release_bundle["created_at"],
        "source_revision": f"git:{release_bundle['commit_sha']}",
        "artifacts": [
            bundle_image_to_artifact("openedx", images.get("openedx") or {}),
            bundle_image_to_artifact("mfe", images.get("mfe") or {}),
        ],
    }

    required_fields = bundle_schema.get("required_fields") or []
    resolved_fields = [field for field in required_fields if field in canonical_projection]
    unresolved_fields = [
        {
            "field": field,
            "reason": REQUIRED_UNRESOLVED_REASONS.get(
                field,
                "Field is required by the PCP release-bundle contract but is not derivable "
                "from the app-local build bundle alone.",
            ),
        }
        for field in required_fields
        if field not in canonical_projection
    ]

    return {
        "schema_version": "control-plane-release-bundle-projection/v1",
        "projection_status": "partial",
        "source_release_bundle": {
            "bundle_id": release_bundle.get("bundle_id"),
            "commit_sha": release_bundle.get("commit_sha"),
            "target_environment": release_bundle.get("target_environment"),
            "service_id": service_id,
            "contract_ref": release_bundle.get("contract_ref"),
        },
        "control_plane_contract": {
            "root": str(platform_root),
            "release_contracts": str(platform_root / "contracts" / "release-contracts.yaml"),
            "release_bundle_schema": str(platform_root / "contracts" / "release-bundle-schema.yaml"),
            "lane": service_id,
        },
        "canonical_projection": canonical_projection,
        "required_field_resolution": {
            "resolved": resolved_fields,
            "unresolved": unresolved_fields,
        },
        "notes": [
            "This projection is preparatory and non-authoritative.",
            "delivery_lane is intentionally omitted because app build target_environment is not "
            "the same thing as promotion delivery lane.",
            "The unresolved fields must be bound during later promotion/realization stages rather "
            "than guessed at build time.",
        ],
    }


def main() -> int:
    args = parse_args()
    platform_root = discover_platform_root(args.platform_control_plane_root)
    release_bundle = load_json(args.release_bundle_json.resolve())
    projection = build_projection(release_bundle, platform_root=platform_root)

    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(projection, indent=2) + "\n", encoding="utf-8")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
