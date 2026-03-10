#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml


DEFAULT_OUTPUT = Path("generated/skills/pack-registry.json")


PACKS: dict[str, dict[str, Any]] = {
    "skill-registry": {
        "title": "Skill Registry",
        "canonical_path": "generated/skills/skill-registry.json",
        "schema_path": "docs/meta/skills/schemas/skill-registry.schema.json",
        "projection_paths": [],
        "source_generators": ["tools/skills/build_skill_registry.py"],
        "primary_repo": "mereka-lms",
        "secondary_repos": ["bbi-infrastructure", "platform-control-plane"],
        "owner": "platform-team",
        "stability": "stable",
        "depends_on": [
            "docs/meta/skills/SKILL_RUNTIME_MODEL.yaml",
            "docs/meta/skills/SKILL_TAXONOMY.yaml",
        ],
    },
    "command-registry": {
        "title": "Command Registry",
        "canonical_path": "generated/skills/command-registry.json",
        "schema_path": "docs/meta/skills/schemas/command-registry.schema.json",
        "projection_paths": [],
        "source_generators": ["tools/skills/build_command_registry.py"],
        "primary_repo": "mereka-lms",
        "secondary_repos": ["bbi-infrastructure", "platform-control-plane"],
        "owner": "platform-team",
        "stability": "stable",
        "depends_on": [
            "generated/skills/skill-registry.json",
            "docs/meta/skills/SKILL_RUNTIME_MODEL.yaml",
        ],
    },
    "scenario-packs": {
        "title": "Scenario Packs",
        "canonical_path": "generated/skills/scenario-packs.json",
        "schema_path": "docs/meta/skills/schemas/scenario-packs.schema.json",
        "projection_paths": [],
        "source_generators": ["tools/skills/build_scenario_packs.py"],
        "primary_repo": "mereka-lms",
        "secondary_repos": ["bbi-infrastructure", "platform-control-plane"],
        "owner": "platform-team",
        "stability": "stable",
        "depends_on": [
            "generated/skills/skill-registry.json",
            "generated/skills/command-registry.json",
        ],
    },
    "skill-dependency-graph": {
        "title": "Skill Dependency Graph",
        "canonical_path": "generated/skills/skill-dependency-graph.json",
        "schema_path": "docs/meta/skills/schemas/skill-dependency-graph.schema.json",
        "projection_paths": [],
        "source_generators": ["tools/skills/build_skill_dependency_graph.py"],
        "primary_repo": "mereka-lms",
        "secondary_repos": ["bbi-infrastructure", "platform-control-plane"],
        "owner": "platform-team",
        "stability": "evolving",
        "depends_on": [
            "generated/skills/skill-registry.json",
            "generated/skills/command-registry.json",
            "generated/skills/scenario-packs.json",
        ],
    },
    "read-first": {
        "title": "Read-First Pack",
        "canonical_path": "generated/skills/read-first.json",
        "schema_path": "docs/meta/skills/schemas/read-first.schema.json",
        "projection_paths": ["generated/skills/read-first.md"],
        "source_generators": ["tools/skills/build_skill_dependency_graph.py"],
        "primary_repo": "mereka-lms",
        "secondary_repos": ["bbi-infrastructure", "platform-control-plane"],
        "owner": "platform-team",
        "stability": "stable",
        "depends_on": [
            "generated/skills/skill-registry.json",
            "generated/skills/scenario-packs.json",
        ],
    },
    "runtime-convergence-report": {
        "title": "Runtime Convergence Report",
        "canonical_path": "generated/skills/runtime-convergence-report.json",
        "schema_path": "docs/meta/skills/schemas/runtime-convergence-report.schema.json",
        "projection_paths": [],
        "source_generators": ["tools/skills/build_runtime_convergence_report.py"],
        "primary_repo": "mereka-lms",
        "secondary_repos": ["bbi-infrastructure", "platform-control-plane"],
        "owner": "platform-team",
        "stability": "evolving",
        "depends_on": [
            "generated/skills/skill-registry.json",
            "generated/skills/command-registry.json",
            "generated/skills/pack-registry.json",
        ],
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Wave 11 pack registry.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text())


def build_registry(repo_root: Path) -> dict[str, Any]:
    abi = load_yaml(repo_root / "docs/meta/skills/AGENT_PACK_ABI.yaml")
    if "pack-registry" not in abi["canonical_packs"]:
        raise SystemExit("AGENT_PACK_ABI does not declare pack-registry as canonical")

    entries = []
    for pack_id in sorted(PACKS):
        definition = PACKS[pack_id]
        canonical_path = repo_root / definition["canonical_path"]
        schema_path = repo_root / definition["schema_path"]
        if not canonical_path.exists():
            raise FileNotFoundError(f"Missing canonical pack payload: {canonical_path}")
        if not schema_path.exists():
            raise FileNotFoundError(f"Missing pack schema: {schema_path}")
        payload = load_json(canonical_path)
        if payload["pack_id"] != pack_id:
            raise SystemExit(f"Pack id mismatch in {definition['canonical_path']}: {payload['pack_id']} != {pack_id}")

        for projection in definition["projection_paths"]:
            projection_path = repo_root / projection
            if not projection_path.exists():
                raise FileNotFoundError(f"Missing pack projection: {projection_path}")

        entries.append(
            {
                "pack_id": pack_id,
                "title": definition["title"],
                "canonical_path": definition["canonical_path"],
                "schema_path": definition["schema_path"],
                "schema_version": payload["schema_version"],
                "projection_paths": definition["projection_paths"],
                "source_generators": definition["source_generators"],
                "canonical_inputs": payload["canonical_inputs"],
                "primary_repo": definition["primary_repo"],
                "secondary_repos": definition["secondary_repos"],
                "owner": definition["owner"],
                "stability": definition["stability"],
                "depends_on": definition["depends_on"],
            }
        )

    return {
        "pack_id": "pack-registry",
        "generated_by": "tools/skills/build_pack_registry.py",
        "source_range": None,
        "canonical_inputs": [
            "docs/meta/skills/AGENT_PACK_ABI.yaml",
            "generated/skills/skill-registry.json",
            "generated/skills/command-registry.json",
            "generated/skills/scenario-packs.json",
            "generated/skills/skill-dependency-graph.json",
            "generated/skills/read-first.json",
            "generated/skills/runtime-convergence-report.json",
        ],
        "schema_version": 1,
        "packs": entries,
    }


def write_or_check(path: Path, payload: dict[str, Any], check: bool) -> None:
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != serialized:
            raise SystemExit(f"Pack registry drift detected: {path}")
        print(f"PACK_REGISTRY_OK mode=check packs={len(payload['packs'])}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialized)
    print(f"PACK_REGISTRY_OK mode=write packs={len(payload['packs'])}")


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    payload = build_registry(repo_root)
    write_or_check(Path(args.output), payload, args.check)


if __name__ == "__main__":
    main()
