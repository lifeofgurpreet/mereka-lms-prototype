#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml


REPOS = {
    "mereka-lms": (
        Path.cwd(),
        Path("/home/gurpreet/projects/k8s/mereka-lms"),
    ),
    "bbi-infrastructure": (
        Path("/home/gurpreet/projects/k8s/bbi-infrastructure"),
    ),
    "platform-control-plane": (
        Path("/home/gurpreet/projects/platform-control-plane"),
    ),
}


def load_yaml(path: Path):
    return yaml.safe_load(path.read_text())


def read_json(path: Path):
    return json.loads(path.read_text())


def assert_exists(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(path)


def resolve_repo_path(candidates: tuple[Path, ...], required: str) -> Path:
    for candidate in candidates:
        if (candidate / required).exists():
            return candidate
    raise FileNotFoundError(f"no repo candidate contains {required}")


def detect_paths() -> dict[str, Path]:
    paths = {
        "repo_root": Path.cwd(),
        "mereka-lms": resolve_repo_path(REPOS["mereka-lms"], "docs/README.md"),
        "bbi-infrastructure": resolve_repo_path(REPOS["bbi-infrastructure"], "docs/README.md"),
        "platform-control-plane": resolve_repo_path(REPOS["platform-control-plane"], "docs/README.md"),
    }
    for path in paths.values():
        if path != Path.cwd():
            assert_exists(path)
    return paths


def repo_rel(paths: dict[str, Path], repo_key: str, path: Path) -> str:
    return f"{repo_key}:{path.relative_to(paths[repo_key]).as_posix()}"


def build_cross_repo_manifest(paths: dict[str, Path], source_map: dict) -> dict:
    canonical_roots = {
        "mereka-lms": [
            repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "docs/README.md"),
            repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "specs/INDEX.md"),
            repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "docs/architecture/PLATFORM_AUTHORITY_MAP.md"),
        ],
        "bbi-infrastructure": [
            repo_rel(paths, "bbi-infrastructure", paths["bbi-infrastructure"] / "docs/README.md"),
            repo_rel(paths, "bbi-infrastructure", paths["bbi-infrastructure"] / "docs/reference/CANONICAL_TOPOLOGY.md"),
            repo_rel(paths, "bbi-infrastructure", paths["bbi-infrastructure"] / "docs/reference/PROMOTION_CONTRACT_REFERENCE.md"),
        ],
        "platform-control-plane": [
            repo_rel(paths, "platform-control-plane", paths["platform-control-plane"] / "docs/README.md"),
            repo_rel(paths, "platform-control-plane", paths["platform-control-plane"] / "contracts/release-contracts.yaml"),
            repo_rel(paths, "platform-control-plane", paths["platform-control-plane"] / "contracts/service-identity-contract.yaml"),
        ],
    }
    return {
        "version": 1,
        "generated_by": "tools/knowledge/build_cross_repo_agent_packs.py",
        "repos_in_scope": sorted(paths_key for paths_key in ("mereka-lms", "bbi-infrastructure", "platform-control-plane")),
        "canonical_roots": canonical_roots,
        "authoritative_domains": source_map["domains"],
        "validation_entrypoints": {
            "mereka-lms": [
                "python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD",
                "bash scripts/qa/run-review-runtime-gates.sh",
            ],
            "bbi-infrastructure": [
                "python3 tools/docs/build_contract_reference_surfaces.py --check",
                "bash scripts/qa/verify-contract-front-doors.sh",
                "make verify",
            ],
            "platform-control-plane": [
                "./scripts/plan-all.sh --validate-only",
            ],
        },
    }


def build_command_registry(paths: dict[str, Path], source_map: dict) -> dict:
    commands = []
    for domain in source_map["domains"]:
        commands.append(
            {
                "domain": domain["domain"],
                "command": domain["validation_command"],
                "owner_repo": domain["authoritative_repo"],
                "when_to_use": f"Validate {domain['domain']} truth or drift risk",
            }
        )
    commands.extend(
        [
            {
                "domain": "compiled_front_doors",
                "command": "python3 tools/docs/build_contract_reference_surfaces.py --check",
                "owner_repo": "bbi-infrastructure",
                "when_to_use": "Check compiled topology/promotion/service/security references",
            },
            {
                "domain": "assistant_surfaces",
                "command": "python3 tools/docs/build_assistant_surfaces.py --check",
                "owner_repo": "bbi-infrastructure",
                "when_to_use": "Check generated assistant front doors",
            },
            {
                "domain": "agent_pack_generation",
                "command": "python3 tools/knowledge/build_cross_repo_agent_packs.py --check",
                "owner_repo": "mereka-lms",
                "when_to_use": "Check cross-repo agent packs",
            },
        ]
    )
    return {
        "version": 1,
        "generated_by": "tools/knowledge/build_cross_repo_agent_packs.py",
        "commands": sorted(commands, key=lambda item: (item["owner_repo"], item["domain"], item["command"])),
    }


def build_reviewer_map(source_map: dict) -> dict:
    entries = []
    for domain in source_map["domains"]:
        entries.append(
            {
                "truth_lane": domain["domain"],
                "owners": domain["reviewers_owners"],
                "required_reviewers": domain["reviewers_owners"],
                "escalation_rules": [
                    "Escalate when canonical source and compiled projection disagree",
                    "Escalate when cross-repo change touches more than one authoritative repo",
                ],
            }
        )
    return {
        "version": 1,
        "generated_by": "tools/knowledge/build_cross_repo_agent_packs.py",
        "reviewer_map": entries,
    }


def build_topology_pack(paths: dict[str, Path]) -> dict:
    domain_registry = load_yaml(paths["bbi-infrastructure"] / "config/domain-registry.yaml")
    topology = load_yaml(paths["bbi-infrastructure"] / "config/bootstrap-lane-topology.yaml")
    service_identity = load_yaml(paths["platform-control-plane"] / "contracts/service-identity-contract.yaml")
    return {
        "version": 1,
        "generated_by": "tools/knowledge/build_cross_repo_agent_packs.py",
        "lanes": sorted(topology.get("lanes", {}).keys()),
        "domains": domain_registry.get("environments", {}),
        "service_aliases": service_identity.get("input_aliases", {}),
        "canonical_services": service_identity.get("canonical_services", []),
    }


def build_release_obligations_pack(paths: dict[str, Path]) -> dict:
    release_contracts = load_yaml(paths["platform-control-plane"] / "contracts/release-contracts.yaml")
    obligations = {}
    for lane, meta in sorted(release_contracts.get("lanes", {}).items()):
        obligations[lane] = {
            "required_evidence": meta.get("required_evidence", []),
            "rollback_method": meta.get("rollback_method"),
            "approved_intake_paths": meta.get("approved_intake_paths", []),
            "owners": meta.get("owners", []),
        }
    return {
        "version": 1,
        "generated_by": "tools/knowledge/build_cross_repo_agent_packs.py",
        "release_lanes": obligations,
        "source_pointers": [
            repo_rel(paths, "platform-control-plane", paths["platform-control-plane"] / "contracts/release-contracts.yaml"),
            repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md"),
            repo_rel(paths, "bbi-infrastructure", paths["bbi-infrastructure"] / "docs/reference/PROMOTION_CONTRACT_REFERENCE.md"),
        ],
    }


def build_read_first(paths: dict[str, Path]) -> str:
    ordered = [
        repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "docs/README.md"),
        repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "docs/architecture/PLATFORM_AUTHORITY_MAP.md"),
        repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "specs/INDEX.md"),
        repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md"),
        repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md"),
        repo_rel(paths, "mereka-lms", paths["mereka-lms"] / "docs/meta/knowledge/AGENT_CONSUMPTION_MODEL.md"),
        repo_rel(paths, "bbi-infrastructure", paths["bbi-infrastructure"] / "docs/README.md"),
        repo_rel(paths, "bbi-infrastructure", paths["bbi-infrastructure"] / "docs/reference/CANONICAL_TOPOLOGY.md"),
        repo_rel(paths, "bbi-infrastructure", paths["bbi-infrastructure"] / "docs/reference/PROMOTION_CONTRACT_REFERENCE.md"),
        repo_rel(paths, "bbi-infrastructure", paths["bbi-infrastructure"] / "docs/reference/SERVICE_IDENTITY_REFERENCE.md"),
        repo_rel(paths, "platform-control-plane", paths["platform-control-plane"] / "docs/README.md"),
        repo_rel(paths, "platform-control-plane", paths["platform-control-plane"] / "contracts/release-contracts.yaml"),
    ]
    lines = [
        "# Cross-Repo Read First",
        "",
        "> GENERATED FILE. DO NOT EDIT.",
        "> Source: `tools/knowledge/build_cross_repo_agent_packs.py`",
        "",
        "Use this exact order before broad repo scans.",
        "",
        "## Start order",
        "",
    ]
    lines.extend(f"{idx}. `{path}`" for idx, path in enumerate(ordered, start=1))
    lines.extend(
        [
            "",
            "## Do not trust first",
            "",
            "- archive roots unless explicitly marked historical context",
            "- hand-written summary docs when a compiled reference exists",
            "- generated mirrors when canonical machine contracts are available",
            "",
        ]
    )
    return "\n".join(lines) + "\n"


def render_json(value) -> str:
    return json.dumps(value, indent=2, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    paths = detect_paths()
    source_map = read_json(paths["repo_root"] / "generated/knowledge/wave10-source-map.json")

    outputs = {
        paths["repo_root"] / "generated/agent/cross-repo-manifest.json": render_json(
            build_cross_repo_manifest(paths, source_map)
        ),
        paths["repo_root"] / "generated/agent/command-registry.json": render_json(
            build_command_registry(paths, source_map)
        ),
        paths["repo_root"] / "generated/agent/reviewer-map.json": render_json(
            build_reviewer_map(source_map)
        ),
        paths["repo_root"] / "generated/agent/topology-pack.json": render_json(
            build_topology_pack(paths)
        ),
        paths["repo_root"] / "generated/agent/release-obligations-pack.json": render_json(
            build_release_obligations_pack(paths)
        ),
        paths["repo_root"] / "generated/agent/read-first.md": build_read_first(paths),
    }

    stale = []
    for path, content in outputs.items():
        if args.check:
            existing = path.read_text() if path.exists() else None
            if existing != content:
                stale.append(str(path.relative_to(paths["repo_root"])))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)

    if args.check:
        if stale:
            print("CROSS_REPO_AGENT_PACKS_STALE")
            for item in stale:
                print(f"- {item}")
            return 1
        print("CROSS_REPO_AGENT_PACKS_OK mode=check packs=6")
        return 0

    print("CROSS_REPO_AGENT_PACKS_OK mode=write packs=6")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
