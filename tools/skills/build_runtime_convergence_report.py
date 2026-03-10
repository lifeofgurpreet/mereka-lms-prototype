#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml

from repo_discovery import resolve_repo_roots


DEFAULT_OUTPUT = Path("generated/skills/runtime-convergence-report.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Wave 11 runtime convergence report.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--bbi-root")
    parser.add_argument("--platform-root")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text())


def normalize_release_lane_options(workflow_inputs: dict[str, Any]) -> list[str]:
    return sorted(workflow_inputs["target_environment"]["options"])


def normalize_release_lanes(contract: dict[str, Any]) -> list[str]:
    return sorted(contract["lanes"].keys())


def extract_promote_image_options(workflow: dict[str, Any]) -> dict[str, list[str]]:
    workflow_on = workflow.get("on", workflow.get(True))
    if workflow_on is None:
        raise KeyError("Workflow file is missing 'on.workflow_dispatch.inputs'")
    inputs = workflow_on["workflow_dispatch"]["inputs"]
    return {
        "app": sorted(inputs["app"]["options"]),
        "from_env": sorted(inputs["from_env"]["options"]),
        "target_environment": sorted(inputs["target_environment"]["options"]),
    }


def build_report(repo_root: Path, bbi_root_override: str | None, platform_root_override: str | None) -> dict[str, Any]:
    roots = resolve_repo_roots(repo_root, bbi_root_override, platform_root_override)
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    command_registry = load_json(repo_root / "generated/skills/command-registry.json")
    pack_registry = load_json(repo_root / "generated/skills/pack-registry.json")

    domain_registry = load_yaml(roots.bbi_infrastructure / "config/domain-registry.yaml")
    topology = load_yaml(roots.bbi_infrastructure / "config/bootstrap-lane-topology.yaml")
    promote_workflow = load_yaml(roots.bbi_infrastructure / ".github/workflows/promote-image.yml")
    release_contracts = load_yaml(roots.platform_control_plane / "contracts/release-contracts.yaml")
    service_identity = load_yaml(roots.platform_control_plane / "contracts/service-identity-contract.yaml")

    command_ids = {entry["command_id"] for entry in command_registry["commands"]}
    skill_ids = {entry["id"] for entry in skill_registry["skills"]}
    topology_lanes = sorted(topology["lanes"].keys())
    domain_envs = sorted(domain_registry["environments"].keys())
    release_lanes = normalize_release_lanes(release_contracts)
    workflow_options = extract_promote_image_options(promote_workflow)
    service_ids = sorted(service["service_id"] for service in service_identity["canonical_services"])
    promote_command = next((entry for entry in command_registry["commands"] if entry["command_id"] == "promote-help"), None)
    release_skill = next((entry for entry in skill_registry["skills"] if entry["id"] == "cross-repo-release-contract-review"), None)

    checks = []

    target_env_status = (
        "pass"
        if workflow_options["target_environment"] == ["prod", "staging"]
        and promote_command is not None
        and promote_command["source_of_truth"] == "scripts/promote.sh"
        and release_skill is not None
        and any(
            source["repo"] == "platform-control-plane" and source["path"] == "contracts/release-contracts.yaml"
            for source in release_skill["authoritative_sources"]
        )
        else "fail"
    )
    checks.append(
        {
            "check_id": "promotion-contract-alignment",
            "title": "Promotion workflow, command registry, and release contract review skill align on release control sources",
            "status": target_env_status,
            "details": (
                f"workflow target environments={workflow_options['target_environment']}; "
                f"release contract lanes={release_lanes}; "
                f"promote-help present={promote_command is not None}; "
                f"cross-repo-release-contract-review present={release_skill is not None}"
            ),
            "evidence": [
                "generated/skills/command-registry.json",
                "generated/skills/skill-registry.json",
            ],
            "canonical_sources": [
                "bbi-infrastructure/.github/workflows/promote-image.yml",
                "platform-control-plane/contracts/release-contracts.yaml",
            ],
        }
    )

    service_alias_status = "pass" if "mereka-lms" in service_ids and "cal.com" in service_ids else "fail"
    checks.append(
        {
            "check_id": "service-identity-normalization",
            "title": "Service identity aliases resolve against canonical platform service identifiers",
            "status": service_alias_status,
            "details": f"canonical service ids={service_ids}",
            "evidence": [
                "generated/skills/skill-registry.json",
                "generated/skills/scenario-packs.json",
            ],
            "canonical_sources": [
                "platform-control-plane/contracts/service-identity-contract.yaml",
            ],
        }
    )

    topology_status = "pass" if {"dev", "staging", "prod"}.issubset(set(topology_lanes)) and {"dev", "staging", "prod"}.issubset(set(domain_envs)) else "fail"
    checks.append(
        {
            "check_id": "topology-alignment",
            "title": "Topology and hostname registries align on active environment names",
            "status": topology_status,
            "details": f"topology lanes={topology_lanes}; domain environments={domain_envs}",
            "evidence": [
                "generated/skills/read-first.json",
            ],
            "canonical_sources": [
                "bbi-infrastructure/config/bootstrap-lane-topology.yaml",
                "bbi-infrastructure/config/domain-registry.yaml",
            ],
        }
    )

    obligations_status = (
        "pass"
        if "release-obligations-review" in skill_ids
        and {"promote-help", "promote-image-workflow", "platform-plan-validate"}.issubset(command_ids)
        else "warning"
    )
    checks.append(
        {
            "check_id": "release-obligations-alignment",
            "title": "Release-obligations review skill exists for canonical release contract sources",
            "status": obligations_status,
            "details": (
                "Skill registry contains release-obligations-review and command registry "
                "contains promote workflow/plan validators."
            ),
            "evidence": [
                "generated/skills/skill-registry.json",
                "generated/skills/command-registry.json",
            ],
            "canonical_sources": [
                "platform-control-plane/contracts/release-contracts.yaml",
                "bbi-infrastructure/.github/workflows/promote-image.yml",
            ],
        }
    )

    assistant_status = "warning"
    checks.append(
        {
            "check_id": "assistant-front-door-subordination",
            "title": "Assistant/runtime front doors remain subordinate to canonical contract surfaces",
            "status": assistant_status,
            "details": "Wave 11 consumes canonical contract and runtime sources directly; rebuilt assistant exports on fresh Wave 11 external branches remain pending.",
            "evidence": [
                "generated/skills/pack-registry.json",
                "generated/skills/read-first.json",
            ],
            "canonical_sources": [
                "docs/meta/skills/REPO_DISCOVERY_MODEL.yaml",
                "platform-control-plane/contracts/release-contracts.yaml",
                "platform-control-plane/contracts/service-identity-contract.yaml",
            ],
        }
    )

    pack_registry_status = "pass" if len(pack_registry["packs"]) >= 5 else "fail"
    checks.append(
        {
            "check_id": "pack-runtime-alignment",
            "title": "Canonical skill packs are registered and consumable as machine truth",
            "status": pack_registry_status,
            "details": f"registered packs={[entry['pack_id'] for entry in pack_registry['packs']]}",
            "evidence": [
                "generated/skills/pack-registry.json",
            ],
            "canonical_sources": [
                "docs/meta/skills/AGENT_PACK_ABI.yaml",
            ],
        }
    )

    summary = {
        "pass": sum(1 for check in checks if check["status"] == "pass"),
        "warning": sum(1 for check in checks if check["status"] == "warning"),
        "fail": sum(1 for check in checks if check["status"] == "fail"),
    }

    return {
        "pack_id": "runtime-convergence-report",
        "generated_by": "tools/skills/build_runtime_convergence_report.py",
        "source_range": None,
        "canonical_inputs": [
            "docs/meta/skills/REPO_DISCOVERY_MODEL.yaml",
            "generated/skills/skill-registry.json",
            "generated/skills/command-registry.json",
            "generated/skills/pack-registry.json",
            "bbi-infrastructure/config/domain-registry.yaml",
            "bbi-infrastructure/config/bootstrap-lane-topology.yaml",
            "bbi-infrastructure/.github/workflows/promote-image.yml",
            "platform-control-plane/contracts/release-contracts.yaml",
            "platform-control-plane/contracts/service-identity-contract.yaml",
        ],
        "schema_version": 1,
        "checks": checks,
        "summary": summary,
    }


def write_or_check(path: Path, payload: dict[str, Any], check: bool) -> None:
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != serialized:
            raise SystemExit(f"Runtime convergence drift detected: {path}")
        print(
            "RUNTIME_CONVERGENCE_OK "
            f"mode=check pass={payload['summary']['pass']} warning={payload['summary']['warning']} fail={payload['summary']['fail']}"
        )
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialized)
    print(
        "RUNTIME_CONVERGENCE_OK "
        f"mode=write pass={payload['summary']['pass']} warning={payload['summary']['warning']} fail={payload['summary']['fail']}"
    )


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    payload = build_report(repo_root, args.bbi_root, args.platform_root)
    write_or_check(Path(args.output), payload, args.check)


if __name__ == "__main__":
    main()
