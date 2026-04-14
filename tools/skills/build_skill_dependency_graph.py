#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_GRAPH = Path("generated/skills/skill-dependency-graph.json")
DEFAULT_READ_FIRST = Path("generated/skills/read-first.md")
DEFAULT_READ_FIRST_JSON = Path("generated/skills/read-first.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 11 read-first pack and skill dependency graph.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--graph-output", default=str(DEFAULT_GRAPH))
    parser.add_argument("--read-first-output", default=str(DEFAULT_READ_FIRST))
    parser.add_argument("--read-first-json-output", default=str(DEFAULT_READ_FIRST_JSON))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def rank_source(path: str) -> tuple[int, str]:
    if path.startswith("docs/architecture/"):
        return (0, path)
    if path.startswith("docs/concepts/architecture/"):
        return (1, path)
    if path.startswith("docs/meta/standing-orders/"):
        return (2, path)
    if path.startswith("specs/"):
        return (3, path)
    if path.startswith("config/"):
        return (4, path)
    if path.startswith("contracts/"):
        return (5, path)
    if path.startswith("docs/ops/"):
        return (6, path)
    if path.startswith("tools/"):
        return (7, path)
    if path.startswith("scripts/"):
        return (8, path)
    if path.startswith(".github/"):
        return (9, path)
    return (10, path)


def build_read_first(skills: list[dict[str, Any]], max_docs: int = 12) -> tuple[list[dict[str, str]], str, dict[str, Any]]:
    seen: set[tuple[str, str]] = set()
    candidates: list[dict[str, str]] = []
    for skill in skills:
        for source in skill["read_first_paths"]:
            key = (source["repo"], source["path"])
            if key in seen:
                continue
            seen.add(key)
            candidates.append(source)

    filtered = []
    for source in candidates:
        path = source["path"]
        if path.startswith(("docs/archive/", "docs/operations/", "reports/", "evidence/", "specs/archive/")):
            continue
        filtered.append(source)

    filtered.sort(key=lambda item: (rank_source(item["path"]), item["repo"]))
    selected = filtered[:max_docs]

    lines = [
        "# Wave 11 Read-First Pack",
        "",
        "> GENERATED FILE. DO NOT EDIT.",
        "> Source: generated/skills/skill-registry.json, generated/skills/scenario-packs.json",
        "",
        "Start here before repo spelunking. These are the default canonical surfaces for humans and agents.",
        "",
    ]
    for index, source in enumerate(selected, start=1):
        lines.append(f"{index}. `{source['repo']}` -> `{source['path']}`")
    lines.extend(
        [
            "",
            "## Do not trust first",
            "",
            "- archive or transitional paths unless explicitly marked historical",
            "- duplicated freehand summaries when a contract, registry, or standing order exists",
            "- generated surfaces not referenced from the current skill registry",
            "",
        ]
    )
    read_first_json = {
        "pack_id": "read-first",
        "generated_by": "tools/skills/build_skill_dependency_graph.py",
        "source_range": None,
        "canonical_inputs": [
            "generated/skills/skill-registry.json",
            "generated/skills/scenario-packs.json",
        ],
        "schema_version": 1,
        "entries": selected,
        "do_not_trust_first": [
            "archive or transitional paths unless explicitly marked historical",
            "duplicated freehand summaries when a contract, registry, or standing order exists",
            "generated surfaces not referenced from the current skill registry",
        ],
    }
    return selected, "\n".join(lines) + "\n", read_first_json


def build_graph(skills: list[dict[str, Any]], commands: list[dict[str, Any]], scenarios: list[dict[str, Any]]) -> dict[str, Any]:
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, str]] = []
    seen_nodes: set[str] = set()

    def add_node(node_id: str, node_type: str, label: str) -> None:
        if node_id in seen_nodes:
            return
        seen_nodes.add(node_id)
        nodes.append({"id": node_id, "type": node_type, "label": label})

    command_ids = {entry["command_id"] for entry in commands}

    for command in commands:
        add_node(f"command:{command['command_id']}", "command", command["command_id"])

    for skill in skills:
        skill_node = f"skill:{skill['id']}"
        add_node(skill_node, "skill", skill["title"])
        for source in skill["authoritative_sources"]:
            source_id = f"source:{source['repo']}:{source['path']}"
            add_node(source_id, "source", f"{source['repo']}:{source['path']}")
            edges.append({"from": skill_node, "to": source_id, "kind": "reads"})
        for command in skill["allowed_commands"]:
            for entry in commands:
                if entry["repo"] == command["repo"] and entry["canonical_command"] == command["command"]:
                    edges.append({"from": skill_node, "to": f"command:{entry['command_id']}", "kind": "runs"})
                    break

    for scenario in scenarios:
        scenario_node = f"scenario:{scenario['scenario_id']}"
        add_node(scenario_node, "scenario", scenario["title"])
        for skill_id in scenario["required_skills"]:
            edges.append({"from": scenario_node, "to": f"skill:{skill_id}", "kind": "requires"})
        for command in scenario["commands_to_run"]:
            if command["command_id"] in command_ids:
                edges.append({"from": scenario_node, "to": f"command:{command['command_id']}", "kind": "runs"})

    return {
        "pack_id": "skill-dependency-graph",
        "generated_by": "tools/skills/build_skill_dependency_graph.py",
        "source_range": None,
        "canonical_inputs": [
            "generated/skills/skill-registry.json",
            "generated/skills/command-registry.json",
            "generated/skills/scenario-packs.json",
        ],
        "schema_version": 1,
        "nodes": sorted(nodes, key=lambda item: item["id"]),
        "edges": sorted(edges, key=lambda item: (item["from"], item["to"], item["kind"])),
    }


def write_or_check(path: Path, content: str, check: bool, ok_label: str) -> None:
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != content:
            raise SystemExit(f"Drift detected: {path}")
        print(f"{ok_label} mode=check")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    print(f"{ok_label} mode=write")


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    command_registry = load_json(repo_root / "generated/skills/command-registry.json")
    scenario_packs = load_json(repo_root / "generated/skills/scenario-packs.json")

    selected, read_first_markdown, read_first_json = build_read_first(skill_registry["skills"])
    graph = build_graph(skill_registry["skills"], command_registry["commands"], scenario_packs["scenarios"])
    graph_serialized = json.dumps(graph, indent=2, sort_keys=True) + "\n"
    read_first_json_serialized = json.dumps(read_first_json, indent=2, sort_keys=True) + "\n"

    if len(selected) > 12:
        raise SystemExit("Read-first pack exceeds 12 docs")

    write_or_check(Path(args.graph_output), graph_serialized, args.check, f"SKILL_DEP_GRAPH_OK nodes={len(graph['nodes'])} edges={len(graph['edges'])}")
    write_or_check(Path(args.read_first_output), read_first_markdown, args.check, f"SKILL_READ_FIRST_OK entries={len(selected)}")
    write_or_check(Path(args.read_first_json_output), read_first_json_serialized, args.check, f"SKILL_READ_FIRST_JSON_OK entries={len(selected)}")


if __name__ == "__main__":
    main()
