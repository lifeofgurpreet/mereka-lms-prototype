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


PACK_DEPENDENCIES = {
    "documentation-truth": ["pack-registry", "read-first"],
    "review": ["pack-registry", "read-first", "runtime-convergence-report"],
    "release": ["pack-registry", "runtime-convergence-report", "evidence-sufficiency-map"],
    "contracts": ["pack-registry", "runtime-convergence-report", "mixed-diff-arbitration"],
    "topology": ["pack-registry", "runtime-convergence-report"],
    "operations": ["pack-registry", "read-first", "evidence-sufficiency-map"],
    "wrapper-retirement": ["pack-registry"],
    "cross-repo-impact": ["pack-registry", "runtime-convergence-report", "mixed-diff-arbitration"],
}

COMMAND_IDS = {
    "python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD": "docs-catalog-governance",
    "bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD": "docs-policy-gate",
    "bash tools/docs/verify/run-docs-world-class-gates.sh": "docs-world-class-gates",
    "./scripts/plan-all.sh --validate-only": "platform-plan-validate",
    "bash scripts/promote.sh --dry-run": "promote-dry-run",
    "bash scripts/promote.sh --help": "promote-help",
    "python3 scripts/qa/spec-tools/spec_verify.py specs/ --scan-dirs tests/ scripts/ --repo-root .": "spec-verify",
    "python3 tools/docs/verify/scan-doc-catalog-residue.py --fail-on-residue": "wrapper-residue-scan",
}


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
        applies_to_repos = [primary_repo, *definition["secondary_repos"]]
        pack_dependencies = PACK_DEPENDENCIES.get(definition["category"], ["pack-registry"])
        command_dependencies = [COMMAND_IDS[item["command"]] for item in definition["command_refs"] if item["command"] in COMMAND_IDS]
        registry_entry = {
            "id": skill_id,
            "skill_id": skill_id,
            "title": definition["title"],
            "purpose": definition["purpose"],
            "scope": definition["scope"],
            "category": definition["category"],
            "authoritative_sources": source_entries,
            "generated_dependencies": sorted(set(generated_dependencies)),
            "pack_dependencies": pack_dependencies,
            "command_dependencies": command_dependencies,
            "primary_repo": primary_repo,
            "secondary_repos": definition["secondary_repos"],
            "applies_to_repos": applies_to_repos,
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
            "reviewer_rules": {
                "required_reviewers": definition["required_reviewers"],
                "merge_strategy": "union-then-prioritize-primary-repo-owner",
            },
            "evidence_rules": {
                "required_evidence_classes": definition["required_evidence_classes"],
                "sufficiency_policy": "all-required-evidence-classes-must-be-present",
            },
            "escalation_rules": {
                "triggers": [
                    "canonical source missing or contradictory",
                    "cross-repo contract unknown",
                    "validation command fails",
                ],
                "manual_review_required": True,
            },
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
            "stable_inputs": source_entries,
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
