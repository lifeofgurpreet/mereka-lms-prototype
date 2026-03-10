#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
from pathlib import Path
from typing import Any

import yaml

DEFAULT_OUTPUT = Path("generated/skills/command-registry.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Wave 11 command registry.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--bbi-root")
    parser.add_argument("--platform-root")
    return parser.parse_args()


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text())


def discover_repo_root(
    repo_root: Path,
    override: str | None,
    env_var: str,
    candidates: list[str],
    label: str,
) -> Path:
    candidate_values = []
    if override:
        candidate_values.append(Path(override))
    env_value = os.environ.get(env_var)
    if env_value:
        candidate_values.append(Path(env_value))
    for candidate in candidates:
        candidate_values.append((repo_root / candidate).resolve())

    checked: list[str] = []
    for candidate in candidate_values:
        resolved = candidate.resolve()
        checked.append(str(resolved))
        if resolved.exists():
            return resolved

    raise FileNotFoundError(
        f"Unable to resolve {label} repo root. Checked: {', '.join(checked)}. "
        f"Set {env_var} or pass an explicit override."
    )


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
        candidate = repo_root / target
        if not candidate.exists():
            raise FileNotFoundError(f"Missing command target: {candidate}")
        return
    if executable.startswith("./"):
        candidate = repo_root / executable
        if not candidate.exists():
            raise FileNotFoundError(f"Missing executable target: {candidate}")
        return
    if executable.startswith("/"):
        if not Path(executable).exists():
            raise FileNotFoundError(f"Missing absolute executable target: {executable}")
        return
    if not shutil.which(executable):
        raise FileNotFoundError(f"Missing executable in PATH: {executable}")


def workflow_exists(workflow_path: str, repo_root: Path) -> None:
    candidate = repo_root / workflow_path
    if not candidate.exists():
        raise FileNotFoundError(f"Missing workflow target: {candidate}")


def write_or_check(path: Path, payload: dict[str, Any], check: bool) -> None:
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != serialized:
            raise SystemExit(f"Command registry drift detected: {path}")
        print(f"COMMAND_REGISTRY_OK mode=check commands={len(payload['commands'])}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialized)
    print(f"COMMAND_REGISTRY_OK mode=write commands={len(payload['commands'])}")


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    runtime_model = load_yaml(repo_root / "docs/meta/skills/SKILL_RUNTIME_MODEL.yaml")
    bbi_root = discover_repo_root(
        repo_root,
        args.bbi_root,
        runtime_model["repo_discovery"]["environment_overrides"]["bbi_infrastructure"],
        runtime_model["repo_discovery"]["preferred_relative_candidates"]["bbi_infrastructure"],
        "bbi-infrastructure",
    )
    platform_root = discover_repo_root(
        repo_root,
        args.platform_root,
        runtime_model["repo_discovery"]["environment_overrides"]["platform_control_plane"],
        runtime_model["repo_discovery"]["preferred_relative_candidates"]["platform_control_plane"],
        "platform-control-plane",
    )

    skill_registry = json.loads((repo_root / "generated/skills/skill-registry.json").read_text())

    command_specs: dict[str, dict[str, Any]] = {
        "docs-policy-gate": {
            "canonical_command": "bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD",
            "repo": "mereka-lms",
            "owner": "docs",
            "purpose": "Validate canonical docs policy on the current diff range.",
            "safe_contexts": ["docs truth review", "reviewer pass"],
            "forbidden_contexts": ["none"],
            "required_flags": ["--range origin/main...HEAD"],
            "source_of_truth": "tools/docs/verify/verify-docs-policy.sh",
            "validator": "bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD",
            "replacement_if_deprecated": None,
            "execution_kind": "command",
        },
        "docs-catalog-governance": {
            "canonical_command": "python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD",
            "repo": "mereka-lms",
            "owner": "docs",
            "purpose": "Check docs catalog governance on changed docs.",
            "safe_contexts": ["docs truth review", "catalog validation"],
            "forbidden_contexts": ["none"],
            "required_flags": ["--range origin/main...HEAD"],
            "source_of_truth": "tools/docs/verify/verify-doc-catalog-governance.py",
            "validator": "python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD",
            "replacement_if_deprecated": None,
            "execution_kind": "command",
        },
        "docs-world-class-gates": {
            "canonical_command": "bash tools/docs/verify/run-docs-world-class-gates.sh",
            "repo": "mereka-lms",
            "owner": "docs",
            "purpose": "Run the full local docs verification entrypoint.",
            "safe_contexts": ["control-plane validation"],
            "forbidden_contexts": ["partial file-only edits without docs impact"],
            "required_flags": [],
            "source_of_truth": "tools/docs/verify/run-docs-world-class-gates.sh",
            "validator": "bash tools/docs/verify/run-docs-world-class-gates.sh",
            "replacement_if_deprecated": None,
            "execution_kind": "command",
        },
        "spec-verify": {
            "canonical_command": "python3 scripts/qa/spec-tools/spec_verify.py specs/ --scan-dirs tests/ scripts/ --repo-root .",
            "repo": "mereka-lms",
            "owner": "specs",
            "purpose": "Verify the spec plane against local tests and scripts.",
            "safe_contexts": ["spec parity", "spec review"],
            "forbidden_contexts": ["none"],
            "required_flags": ["specs/", "--scan-dirs tests/ scripts/", "--repo-root ."],
            "source_of_truth": "scripts/qa/spec-tools/spec_verify.py",
            "validator": "python3 scripts/qa/spec-tools/spec_verify.py specs/ --scan-dirs tests/ scripts/ --repo-root .",
            "replacement_if_deprecated": None,
            "execution_kind": "command",
        },
        "promote-help": {
            "canonical_command": "bash scripts/promote.sh --help",
            "repo": "bbi-infrastructure",
            "owner": "platform",
            "purpose": "Resolve canonical promotion flags and help text.",
            "safe_contexts": ["promotion workflow review", "topology lookup"],
            "forbidden_contexts": ["imperative production mutation"],
            "required_flags": ["--help"],
            "source_of_truth": "scripts/promote.sh",
            "validator": "bash scripts/promote.sh --help",
            "replacement_if_deprecated": None,
            "execution_kind": "command",
        },
        "promote-dry-run": {
            "canonical_command": "bash scripts/promote.sh --dry-run",
            "repo": "bbi-infrastructure",
            "owner": "platform",
            "purpose": "Preview promotion behavior without mutating overlays.",
            "safe_contexts": ["promotion workflow review"],
            "forbidden_contexts": ["without app/from-env context in real use"],
            "required_flags": ["--dry-run"],
            "source_of_truth": "scripts/promote.sh",
            "validator": "bash scripts/promote.sh --help",
            "replacement_if_deprecated": None,
            "execution_kind": "command",
        },
        "promote-image-workflow": {
            "canonical_command": "workflow_dispatch:.github/workflows/promote-image.yml",
            "repo": "bbi-infrastructure",
            "owner": "platform",
            "purpose": "Canonical GitHub Actions promotion workflow entrypoint.",
            "safe_contexts": ["release review", "workflow input lookup"],
            "forbidden_contexts": ["manual summary drift"],
            "required_flags": ["app", "from_env", "target_environment", "release_bundle_id"],
            "source_of_truth": ".github/workflows/promote-image.yml",
            "validator": "python3 -c \"import yaml, pathlib; yaml.safe_load(pathlib.Path('.github/workflows/promote-image.yml').read_text())\"",
            "replacement_if_deprecated": None,
            "execution_kind": "workflow_dispatch",
        },
        "platform-plan-validate": {
            "canonical_command": "./scripts/plan-all.sh --validate-only",
            "repo": "platform-control-plane",
            "owner": "platform",
            "purpose": "Validate platform control-plane release and contract conformance.",
            "safe_contexts": ["control-plane validation", "contract review"],
            "forbidden_contexts": ["none"],
            "required_flags": ["--validate-only"],
            "source_of_truth": "scripts/plan-all.sh",
            "validator": "./scripts/plan-all.sh --validate-only",
            "replacement_if_deprecated": None,
            "execution_kind": "command",
        },
        "wrapper-residue-scan": {
            "canonical_command": "python3 tools/docs/verify/scan-doc-catalog-residue.py --fail-on-residue",
            "repo": "mereka-lms",
            "owner": "docs",
            "purpose": "Detect transitional residue and wrapper retirement opportunities.",
            "safe_contexts": ["wrapper retirement assessment"],
            "forbidden_contexts": ["none"],
            "required_flags": ["--fail-on-residue"],
            "source_of_truth": "tools/docs/verify/scan-doc-catalog-residue.py",
            "validator": "python3 tools/docs/verify/scan-doc-catalog-residue.py --fail-on-residue",
            "replacement_if_deprecated": None,
            "execution_kind": "command",
        },
    }

    repo_roots = {
        "mereka-lms": repo_root,
        "bbi-infrastructure": bbi_root,
        "platform-control-plane": platform_root,
    }

    for spec in command_specs.values():
        target_root = repo_roots[spec["repo"]]
        if spec["execution_kind"] == "workflow_dispatch":
            workflow_exists(spec["source_of_truth"], target_root)
        else:
            ensure_command_exists(spec["canonical_command"], target_root)
            ensure_command_exists(spec["validator"], target_root)

    referenced = set()
    for skill in skill_registry["skills"]:
        for command in skill["allowed_commands"]:
            referenced.add((command["repo"], command["command"]))

    commands = []
    for command_id in sorted(command_specs):
        spec = dict(command_specs[command_id])
        spec["command_id"] = command_id
        spec["referenced_by_skills"] = sorted(
            skill["id"]
            for skill in skill_registry["skills"]
            if any(
                c["repo"] == spec["repo"] and c["command"] == spec["canonical_command"]
                for c in skill["allowed_commands"]
            )
        )
        if (spec["repo"], spec["canonical_command"]) in referenced:
            spec["registry_status"] = "active"
        else:
            spec["registry_status"] = "supporting"
        commands.append(spec)

    payload = {
        "schema_version": 1,
        "repo_discovery_model": "docs/meta/skills/SKILL_RUNTIME_MODEL.yaml",
        "source_skill_registry": "generated/skills/skill-registry.json",
        "commands": commands,
    }
    write_or_check(Path(args.output), payload, args.check)


if __name__ == "__main__":
    main()
