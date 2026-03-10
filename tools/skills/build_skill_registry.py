#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shlex
import shutil
from pathlib import Path
from typing import Any

import yaml

from repo_discovery import RepoRoots, load_yaml, resolve_repo_roots


DEFAULT_OUTPUT = Path("generated/skills/skill-registry.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Wave 11 skill registry.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--bbi-root")
    parser.add_argument("--platform-root")
    return parser.parse_args()

def relative_to_root(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()

def ensure_command_exists(command: str, repo_root: Path) -> None:
    parts = shlex.split(command)
    if not parts:
        raise ValueError(f"Empty command reference: {command!r}")
    executable = parts[0]
    if executable in {"python", "python3", "bash", "sh"}:
        if len(parts) < 2:
            raise ValueError(f"Missing script target in command: {command}")
        target = parts[1]
        if target.startswith("-"):
            return
        if not (repo_root / target).exists():
            raise FileNotFoundError(f"Missing command target: {repo_root / target}")
        return
    if executable.startswith("./"):
        if not (repo_root / executable).exists():
            raise FileNotFoundError(f"Missing executable target: {repo_root / executable}")
        return
    if executable.startswith("/"):
        if not Path(executable).exists():
            raise FileNotFoundError(f"Missing absolute executable target: {executable}")
        return
    resolved = shutil.which(executable)
    if not resolved:
        raise FileNotFoundError(f"Missing executable in PATH: {executable}")


def build_registry(args: argparse.Namespace) -> dict[str, Any]:
    repo_root = Path(args.repo_root).resolve()
    runtime_model = load_yaml(repo_root / "docs/meta/skills/SKILL_RUNTIME_MODEL.yaml")
    roots = resolve_repo_roots(repo_root, args.bbi_root, args.platform_root)
    taxonomy = load_yaml(repo_root / "docs/meta/skills/SKILL_TAXONOMY.yaml")

    seen_ids: set[str] = set()
    skills: list[dict[str, Any]] = []

    forbidden_prefixes = tuple(runtime_model["forbidden_canonical_prefixes"])
    for skill_id in sorted(taxonomy["skills"]):
        definition = taxonomy["skills"][skill_id]
        if skill_id in seen_ids:
            raise ValueError(f"Duplicate skill id: {skill_id}")
        seen_ids.add(skill_id)

        source_entries = []
        read_first_paths = []
        generated_dependencies = []
        for item in definition["source_paths"]:
            repo_key = item["repo"].replace("-", "_")
            repo_path = roots.get(repo_key)
            source_path = repo_path / item["path"]
            if not source_path.exists():
                raise FileNotFoundError(f"Missing source path for {skill_id}: {source_path}")
            if item["repo"] == "mereka-lms" and item["path"].startswith(forbidden_prefixes):
                raise ValueError(f"Forbidden canonical source for {skill_id}: {item['path']}")
            entry = {"repo": item["repo"], "path": item["path"]}
            source_entries.append(entry)
            if item["repo"] == "mereka-lms" and item["path"].startswith("generated/"):
                generated_dependencies.append(item["path"])
            read_first_paths.append(entry)

        commands = []
        for item in definition["command_refs"]:
            repo_key = item["repo"].replace("-", "_")
            repo_path = roots.get(repo_key)
            ensure_command_exists(item["command"], repo_path)
            commands.append({"repo": item["repo"], "command": item["command"]})

        primary_repo = definition["primary_repo"]
        registry_entry = {
            "id": skill_id,
            "title": definition["title"],
            "purpose": definition["purpose"],
            "scope": definition["scope"],
            "category": definition["category"],
            "authoritative_sources": source_entries,
            "generated_dependencies": sorted(set(generated_dependencies)),
            "primary_repo": primary_repo,
            "secondary_repos": definition["secondary_repos"],
            "allowed_commands": commands,
            "forbidden_or_destructive_commands": [
                "git reset --hard",
                "git checkout -- <path>",
                "kubectl apply -f <managed-resource>",
                "kubectl delete <managed-resource>",
            ],
            "canonical_entrypoints": commands[:2],
            "required_reviewers": definition["required_reviewers"],
            "required_evidence_classes": definition["required_evidence_classes"],
            "escalation_triggers": [
                "canonical source missing or contradictory",
                "cross-repo contract unknown",
                "validation command fails",
            ],
            "preconditions": [
                f"{len(source_entries)} canonical source paths resolve",
                "all allowed commands exist",
            ],
            "expected_outputs": [
                "deterministic answer from canonical sources",
                "reviewer/evidence path identified",
            ],
            "failure_modes": [
                "missing command or source path",
                "archive/transitional path presented as canonical",
                "cross-repo disagreement requiring human escalation",
            ],
            "read_first_paths": read_first_paths,
            "historical_or_archive_dependencies": [],
            "stability_level": definition["stability_level"],
        }
        skills.append(registry_entry)

    output = {
        "pack_id": "skill-registry",
        "generated_by": "tools/skills/build_skill_registry.py",
        "source_range": None,
        "canonical_inputs": [
            "docs/meta/skills/SKILL_RUNTIME_MODEL.yaml",
            "docs/meta/skills/REPO_DISCOVERY_MODEL.yaml",
            "docs/meta/skills/SKILL_TAXONOMY.yaml",
        ],
        "schema_version": 1,
        "runtime_model": relative_to_root(
            repo_root / "docs/meta/skills/SKILL_RUNTIME_MODEL.yaml", repo_root
        ),
        "repo_discovery_model": relative_to_root(
            repo_root / "docs/meta/skills/REPO_DISCOVERY_MODEL.yaml", repo_root
        ),
        "taxonomy": relative_to_root(
            repo_root / "docs/meta/skills/SKILL_TAXONOMY.yaml", repo_root
        ),
        "skills": skills,
    }
    return output


def write_or_check(output_path: Path, payload: dict[str, Any], check: bool) -> None:
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if check:
        if not output_path.exists():
            raise FileNotFoundError(f"Missing output: {output_path}")
        current = output_path.read_text()
        if current != serialized:
            raise SystemExit(f"Skill registry drift detected: {output_path}")
        print(f"SKILL_REGISTRY_OK mode=check skills={len(payload['skills'])}")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(serialized)
    print(f"SKILL_REGISTRY_OK mode=write skills={len(payload['skills'])}")


def main() -> None:
    args = parse_args()
    output = build_registry(args)
    write_or_check(Path(args.output), output, args.check)


if __name__ == "__main__":
    main()
