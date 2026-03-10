#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


FORBIDDEN_PREFIXES = (
    "docs/archive/",
    "docs/operations/",
    "docs/architecture/",
    "reports/",
    "evidence/",
    "specs/archive/",
)
HIGH_RISK_CATEGORIES = {"release", "contracts", "cross-repo-impact", "review"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify the Wave 11 skill runtime.")
    parser.add_argument("--repo-root", default=".")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    command_registry = load_json(repo_root / "generated/skills/command-registry.json")
    scenario_packs = load_json(repo_root / "generated/skills/scenario-packs.json")
    dep_graph = load_json(repo_root / "generated/skills/skill-dependency-graph.json")
    pack_registry = load_json(repo_root / "generated/skills/pack-registry.json")
    read_first_json = load_json(repo_root / "generated/skills/read-first.json")
    read_first = (repo_root / "generated/skills/read-first.md").read_text().splitlines()

    skills = skill_registry["skills"]
    commands = command_registry["commands"]
    scenarios = scenario_packs["scenarios"]

    skill_ids = {entry["id"] for entry in skills}
    command_ids = {entry["command_id"] for entry in commands}

    ensure(len(skill_ids) >= 8, "Expected at least 8 skills in registry")
    ensure(len(scenarios) >= 8, "Expected at least 8 scenarios")
    ensure(len(command_ids) >= 8, "Expected at least 8 commands in registry")
    ensure(pack_registry["pack_id"] == "pack-registry", "Unexpected pack registry payload")
    ensure("docs/meta/skills/REPO_DISCOVERY_MODEL.yaml" in skill_registry["canonical_inputs"], "Skill registry missing repo discovery model")
    ensure("docs/meta/skills/REPO_DISCOVERY_MODEL.yaml" in command_registry["canonical_inputs"], "Command registry missing repo discovery model")
    ensure(read_first_json["pack_id"] == "read-first", "Unexpected read-first payload")

    for skill in skills:
        ensure(skill["authoritative_sources"], f"Skill missing authoritative_sources: {skill['id']}")
        ensure(skill["allowed_commands"], f"Skill missing allowed_commands: {skill['id']}")
        ensure(skill["required_reviewers"], f"Skill missing required_reviewers: {skill['id']}")
        ensure(skill["required_evidence_classes"], f"Skill missing required_evidence_classes: {skill['id']}")
        for source in skill["read_first_paths"]:
            ensure(
                not source["path"].startswith(FORBIDDEN_PREFIXES),
                f"Forbidden canonical path in skill {skill['id']}: {source['path']}",
            )
        for key in ("authoritative_sources", "read_first_paths"):
            for source in skill[key]:
                ensure("/home/gurpreet" not in source["path"], f"Absolute path leaked in skill {skill['id']}: {source['path']}")
        if skill["category"] in HIGH_RISK_CATEGORIES:
            ensure(
                len(skill["required_reviewers"]) > 0,
                f"High-risk skill missing reviewers: {skill['id']}",
            )
            ensure(
                len(skill["required_evidence_classes"]) > 0,
                f"High-risk skill missing evidence classes: {skill['id']}",
            )

    for scenario in scenarios:
        ensure(scenario["required_skills"], f"Scenario missing required_skills: {scenario['scenario_id']}")
        for skill_id in scenario["required_skills"]:
            ensure(skill_id in skill_ids, f"Scenario references missing skill: {scenario['scenario_id']} -> {skill_id}")
        for command in scenario["commands_to_run"]:
            ensure(
                command["command_id"] in command_ids,
                f"Scenario references missing command id: {scenario['scenario_id']} -> {command['command_id']}",
            )
        for source in scenario["read_first"]:
            ensure(
                not source["path"].startswith(FORBIDDEN_PREFIXES),
                f"Forbidden read-first path in scenario {scenario['scenario_id']}: {source['path']}",
            )
            ensure("/home/gurpreet" not in source["path"], f"Absolute path leaked in scenario {scenario['scenario_id']}: {source['path']}")

    read_first_entries = [
        line for line in read_first if line[:2].strip().isdigit() and ". " in line
    ]
    ensure(0 < len(read_first_entries) <= 12, "Read-first pack must contain between 1 and 12 entries")
    for line in read_first_entries:
        ensure(
            not any(prefix in line for prefix in FORBIDDEN_PREFIXES),
            f"Forbidden read-first entry: {line}",
        )
        ensure("/home/gurpreet" not in line, f"Absolute path leaked in read-first markdown: {line}")

    for entry in read_first_json["entries"]:
        ensure("/home/gurpreet" not in entry["path"], f"Absolute path leaked in read-first JSON: {entry['path']}")

    for pack in pack_registry["packs"]:
        ensure("/home/gurpreet" not in pack["canonical_path"], f"Absolute path leaked in pack registry canonical_path: {pack['pack_id']}")
        ensure("/home/gurpreet" not in pack["schema_path"], f"Absolute path leaked in pack registry schema_path: {pack['pack_id']}")
        for projection in pack["projection_paths"]:
            ensure("/home/gurpreet" not in projection, f"Absolute path leaked in pack registry projection: {pack['pack_id']}")
        for dependency in pack["canonical_inputs"]:
            ensure("/home/gurpreet" not in dependency, f"Absolute path leaked in pack registry canonical input: {pack['pack_id']}")

    node_ids = {node["id"] for node in dep_graph["nodes"]}
    for skill_id in skill_ids:
        ensure(f"skill:{skill_id}" in node_ids, f"Missing skill node in dependency graph: {skill_id}")
    for command_id in command_ids:
        ensure(f"command:{command_id}" in node_ids, f"Missing command node in dependency graph: {command_id}")
    for scenario in scenarios:
        ensure(
            f"scenario:{scenario['scenario_id']}" in node_ids,
            f"Missing scenario node in dependency graph: {scenario['scenario_id']}",
        )

    print(
        "SKILL_RUNTIME_OK "
        f"skills={len(skill_ids)} commands={len(command_ids)} scenarios={len(scenarios)} "
        f"high_risk_skills={sum(1 for skill in skills if skill['category'] in HIGH_RISK_CATEGORIES)}"
    )


if __name__ == "__main__":
    main()
