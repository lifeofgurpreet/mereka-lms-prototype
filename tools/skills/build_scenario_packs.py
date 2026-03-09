#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_OUTPUT = Path("generated/skills/scenario-packs.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 11 scenario packs.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def skill_map(registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {entry["id"]: entry for entry in registry["skills"]}


def command_map(registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {entry["command_id"]: entry for entry in registry["commands"]}


def entry_sources(skills: dict[str, dict[str, Any]], skill_ids: list[str]) -> list[dict[str, str]]:
    seen: set[tuple[str, str]] = set()
    results: list[dict[str, str]] = []
    for skill_id in skill_ids:
        for source in skills[skill_id]["read_first_paths"]:
            key = (source["repo"], source["path"])
            if key in seen:
                continue
            seen.add(key)
            results.append(source)
    return results


def scenario_definitions() -> list[dict[str, Any]]:
    return [
        {
            "scenario_id": "promote-app-safely",
            "title": "Can I promote this app safely?",
            "goal": "Resolve promotion semantics, obligations, and validation entrypoints before promotion.",
            "applicable_repos": ["mereka-lms", "bbi-infrastructure", "platform-control-plane"],
            "required_skills": [
                "promotion-workflow-review",
                "cross-repo-release-contract-review",
                "release-obligations-review",
            ],
            "reviewer_signoff_rules": ["release", "platform"],
        },
        {
            "scenario_id": "required-reviewers-for-diff",
            "title": "What reviewers are required for this diff?",
            "goal": "Resolve the review path and truth owners for the current change set.",
            "applicable_repos": ["mereka-lms", "bbi-infrastructure", "platform-control-plane"],
            "required_skills": ["docs-truth-review", "change-impact-triage", "control-plane-validation"],
            "reviewer_signoff_rules": ["docs", "platform"],
        },
        {
            "scenario_id": "repo-ownership-of-truth",
            "title": "Which repo owns this truth?",
            "goal": "Determine the authoritative repo and canonical source for a truth surface.",
            "applicable_repos": ["mereka-lms", "bbi-infrastructure", "platform-control-plane"],
            "required_skills": ["change-impact-triage", "service-identity-lookup", "topology-lookup"],
            "reviewer_signoff_rules": ["platform"],
        },
        {
            "scenario_id": "service-alias-change-impact",
            "title": "What changes if a service alias changes?",
            "goal": "Trace service identity fallout across release contracts, topology, and promotion workflow surfaces.",
            "applicable_repos": ["bbi-infrastructure", "platform-control-plane", "mereka-lms"],
            "required_skills": ["service-identity-lookup", "cross-repo-release-contract-review", "change-impact-triage"],
            "reviewer_signoff_rules": ["platform", "docs"],
        },
        {
            "scenario_id": "wrapper-retirement",
            "title": "Can this wrapper be retired?",
            "goal": "Assess whether transitional documentation residue can be safely removed or must stay stubbed.",
            "applicable_repos": ["mereka-lms"],
            "required_skills": ["wrapper-retirement-assessment", "docs-truth-review"],
            "reviewer_signoff_rules": ["docs"],
        },
        {
            "scenario_id": "cross-repo-diff-impact",
            "title": "What does this diff impact across repos?",
            "goal": "Map a change to affected repos, truth surfaces, and validation steps.",
            "applicable_repos": ["mereka-lms", "bbi-infrastructure", "platform-control-plane"],
            "required_skills": ["change-impact-triage", "control-plane-validation"],
            "reviewer_signoff_rules": ["docs", "platform"],
        },
        {
            "scenario_id": "canonical-topology-lookup",
            "title": "What is the correct topology, hostname, or lane?",
            "goal": "Resolve topology from registries and release-control contracts instead of prose memory.",
            "applicable_repos": ["bbi-infrastructure", "platform-control-plane"],
            "required_skills": ["topology-lookup", "service-identity-lookup"],
            "reviewer_signoff_rules": ["platform"],
        },
        {
            "scenario_id": "canonical-recovery-runbook",
            "title": "What is the canonical recovery or runbook path?",
            "goal": "Find the live runbook and evidence path without relying on archive or transitional roots.",
            "applicable_repos": ["mereka-lms", "bbi-infrastructure"],
            "required_skills": ["runbook-evidence-triage", "docs-truth-review"],
            "reviewer_signoff_rules": ["ops", "docs"],
        },
    ]


def build_payload(repo_root: Path) -> dict[str, Any]:
    skills_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    commands_registry = load_json(repo_root / "generated/skills/command-registry.json")
    skills = skill_map(skills_registry)
    commands = command_map(commands_registry)

    command_by_repo_command = {
        (entry["repo"], entry["canonical_command"]): entry["command_id"] for entry in commands_registry["commands"]
    }

    scenarios = []
    for definition in scenario_definitions():
        required_skills = definition["required_skills"]
        missing = [skill for skill in required_skills if skill not in skills]
        if missing:
            raise KeyError(f"Scenario references missing skills: {definition['scenario_id']}: {missing}")

        commands_to_run = []
        seen_commands: set[str] = set()
        evidence = []
        reviewers = []
        for skill_id in required_skills:
            skill = skills[skill_id]
            for command in skill["allowed_commands"]:
                key = (command["repo"], command["command"])
                command_id = command_by_repo_command.get(key)
                if not command_id or command_id in seen_commands:
                    continue
                seen_commands.add(command_id)
                commands_to_run.append(
                    {
                        "command_id": command_id,
                        "repo": command["repo"],
                        "command": command["command"],
                    }
                )
            for evidence_class in skill["required_evidence_classes"]:
                if evidence_class not in evidence:
                    evidence.append(evidence_class)
            for reviewer in skill["required_reviewers"]:
                if reviewer not in reviewers:
                    reviewers.append(reviewer)

        scenarios.append(
            {
                "scenario_id": definition["scenario_id"],
                "title": definition["title"],
                "goal": definition["goal"],
                "applicable_repos": definition["applicable_repos"],
                "read_first": entry_sources(skills, required_skills),
                "required_skills": required_skills,
                "commands_to_run": commands_to_run,
                "evidence_to_collect": evidence,
                "escalation_points": [
                    "canonical source missing or contradictory",
                    "cross-repo disagreement not resolved by contracts",
                    "required validator fails",
                ],
                "stop_conditions": [
                    "required command missing",
                    "required reviewer class unresolved",
                    "archive or transitional path appears as canonical source",
                ],
                "expected_outputs": [
                    "deterministic answer from canonical sources",
                    "explicit reviewer and evidence path",
                ],
                "reviewer_signoff_rules": definition["reviewer_signoff_rules"],
            }
        )

    return {"schema_version": 1, "scenarios": scenarios}


def write_or_check(path: Path, payload: dict[str, Any], check: bool) -> None:
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != serialized:
            raise SystemExit(f"Scenario pack drift detected: {path}")
        print(f"SCENARIO_PACKS_OK mode=check scenarios={len(payload['scenarios'])}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialized)
    print(f"SCENARIO_PACKS_OK mode=write scenarios={len(payload['scenarios'])}")


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    payload = build_payload(repo_root)
    write_or_check(Path(args.output), payload, args.check)


if __name__ == "__main__":
    main()
