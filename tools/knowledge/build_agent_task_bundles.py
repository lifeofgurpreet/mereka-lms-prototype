#!/usr/bin/env python3
"""Build Wave 8 agent task bundles for deterministic consumption."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml


FILE_NAME_MAP = {
    "normative_spec_change": "normative-spec-change.md",
    "proposal_change": "proposal-change.md",
    "docs_architecture_change": "docs-architecture-change.md",
    "incident_debug": "incident-debug.md",
    "release_change": "release-change.md",
    "migration_change": "migration-change.md",
    "cross_repo_contract_change": "cross-repo-contract-change.md",
    "wrapper_retirement": "wrapper-retirement.md",
    "reviewer_pass": "reviewer-pass.md",
    "evidence_status_update": "evidence-status-update.md",
}

TASK_DOMAIN_MAP = {
    "normative_spec_change": ["specs-control-plane", "architecture"],
    "proposal_change": ["frontend", "docs-control-plane"],
    "docs_architecture_change": ["architecture", "docs-control-plane"],
    "incident_debug": ["observability", "runtime/release"],
    "release_change": ["runtime/release", "cross-repo contracts"],
    "migration_change": ["mobile", "cross-repo contracts"],
    "cross_repo_contract_change": ["cross-repo contracts", "runtime/release"],
    "wrapper_retirement": ["docs-control-plane", "specs-control-plane"],
    "reviewer_pass": ["architecture", "cross-repo contracts"],
    "evidence_status_update": ["docs-control-plane", "runtime/release"],
}

WHY_THIS_EXISTS = {
    "normative_spec_change": "Prevents agents from treating proposals, plans, or generated summaries as normative law.",
    "proposal_change": "Keeps proposal work from being mistaken for binding contract truth.",
    "docs_architecture_change": "Directs agents to governing architecture surfaces instead of broad docs spelunking.",
    "incident_debug": "Starts incident work from runtime and runbook truth instead of stale status notes.",
    "release_change": "Makes release obligations and downstream repo impact explicit before merge.",
    "migration_change": "Pairs normative migration law with execution companions and contract fallout.",
    "cross_repo_contract_change": "Makes infra-coupled fallout visible before an agent edits app-repo contract surfaces.",
    "wrapper_retirement": "Prevents agents from deleting compatibility surfaces without canonical replacement proof.",
    "reviewer_pass": "Gives reviewers and review agents one deterministic path through the change runtime.",
    "evidence_status_update": "Keeps evidence and status updates grounded in actual obligations instead of narrative-only summaries.",
}

WHAT_EXCLUDES = {
    "normative_spec_change": "Does not authorize archive, wrappers, or proposal-only material as default sources.",
    "proposal_change": "Does not authorize normative spec rewrites unless the task escalates.",
    "docs_architecture_change": "Does not reopen Wave 4 root topology or spec taxonomy.",
    "incident_debug": "Does not claim live-cluster truth beyond the repo and generated runtime evidence.",
    "release_change": "Does not replace release signoff or imply deploy permission on its own.",
    "migration_change": "Does not collapse intentionally normative migration specs into plans.",
    "cross_repo_contract_change": "Does not guess missing infra file mappings where Wave 6 still marks them unknown.",
    "wrapper_retirement": "Does not treat generated inventories as sufficient proof without canonical replacement and zero live refs.",
    "reviewer_pass": "Does not replace human judgment on mixed high-risk diffs.",
    "evidence_status_update": "Does not treat status docs as a source of normative behavior.",
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def load_yaml(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text())


def classify_surface(path: str) -> str:
    if path.startswith("specs/proposals/"):
        return "proposal"
    if "/plans/" in path or path.endswith("_plan.md") or path.endswith("_testplan.md"):
        return "plan"
    if path.startswith("specs/") and path.endswith("_spec.md"):
        return "normative"
    if path.startswith("generated/"):
        return "generated"
    if "/archive/" in path or path.startswith("docs/archive/") or path.startswith("specs/archive/"):
        return "archive"
    return "canonical"


def build_bundle(repo_root: Path, task_type: str) -> dict[str, Any]:
    taxonomy = load_yaml(repo_root / "docs" / "meta" / "knowledge" / "AGENT_TASK_TAXONOMY.yaml")["task_types"][task_type]
    entrypoints = load_json(repo_root / "generated" / "knowledge" / "agent-entrypoints.json")["domains"]
    change_manifest = load_json(repo_root / "generated" / "knowledge" / "change-manifest.json")
    truth_impact = load_json(repo_root / "generated" / "knowledge" / "truth-impact-report.json")
    cross_repo_manifest = load_json(repo_root / "generated" / "contracts" / "cross-repo-manifest.json")
    deployment_impact = load_json(repo_root / "generated" / "contracts" / "deployment-impact-report.json")

    chosen_domains = [entry for entry in entrypoints if entry["domain"] in TASK_DOMAIN_MAP[task_type]]
    read_first = []
    seen = set()
    for entry in chosen_domains:
        for path in entry["read_first"]:
            if path not in seen:
                seen.add(path)
                read_first.append(
                    {
                        "path": path,
                        "lane": classify_surface(path),
                        "why": f"Canonical entrypoint for domain `{entry['domain']}`.",
                    }
                )

    generated_surfaces = sorted(
        {
            "generated/knowledge/agent-entrypoints.json",
            "generated/knowledge/change-manifest.json",
            "generated/knowledge/truth-impact-report.json",
            "generated/knowledge/review-bundle.md",
            *[path for entry in chosen_domains for path in entry["cross_repo_surfaces"]],
        }
    )
    historical_context = [
        {
            "label": "historical_context_only",
            "paths": sorted(set(taxonomy["forbidden_low_signal_surfaces"])),
        }
    ]

    return {
        "task_type": task_type,
        "title": task_type.replace("_", " "),
        "purpose": taxonomy["purpose"],
        "why_this_bundle_exists": WHY_THIS_EXISTS[task_type],
        "what_this_bundle_intentionally_excludes": WHAT_EXCLUDES[task_type],
        "domains": [entry["domain"] for entry in chosen_domains],
        "read_first": read_first,
        "normative_surfaces": [item["path"] for item in read_first if item["lane"] == "normative"],
        "proposal_surfaces": [item["path"] for item in read_first if item["lane"] == "proposal"],
        "plan_surfaces": [item["path"] for item in read_first if item["lane"] == "plan"],
        "generated_surfaces": generated_surfaces,
        "historical_context": historical_context,
        "required_reviewers": sorted(
            {
                reviewer
                for reviewer in taxonomy["required_reviewers"]
                for _ in [0]
            }
            | {
                reviewer
                for entry in chosen_domains
                for reviewer in entry["required_reviewers"]
            }
        ),
        "required_evidence": sorted(
            {
                evidence
                for evidence in taxonomy["required_evidence"]
                for _ in [0]
            }
            | {
                evidence
                for entry in chosen_domains
                for evidence in entry["required_evidence"]
            }
        ),
        "required_validation_commands": taxonomy["required_validation_commands"],
        "cross_repo_fallout": {
            "overall_verdict": cross_repo_manifest["overall_verdict"],
            "required_repositories": deployment_impact["required_repositories"],
            "required_reviewers": deployment_impact["required_reviewers"],
        },
        "upstream_runtime_artifacts": [
            "generated/knowledge/change-manifest.json",
            "generated/knowledge/review-bundle.md",
            "generated/knowledge/truth-impact-report.json",
            "generated/knowledge/wrapper-retirement-report.json",
            "generated/contracts/cross-repo-manifest.json",
            "generated/contracts/deployment-impact-report.json",
            "generated/contracts/release-obligations.md",
        ],
        "change_count": change_manifest["change_count"],
        "truth_impact_change_count": truth_impact["change_count"],
    }


def render_bundle_markdown(bundle: dict[str, Any]) -> str:
    lines = [
        "<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->",
        f"# Task Bundle: {bundle['title']}",
        "",
        f"- Purpose: {bundle['purpose']}",
        f"- Why this bundle exists: {bundle['why_this_bundle_exists']}",
        f"- What this bundle intentionally excludes: {bundle['what_this_bundle_intentionally_excludes']}",
        "",
        "## Read First",
    ]
    for item in bundle["read_first"]:
        lines.append(f"- `{item['path']}` [{item['lane']}] {item['why']}")
    lines.extend(["", "## Surface Meaning"])
    lines.append(f"- Normative: {', '.join(bundle['normative_surfaces']) or 'none'}")
    lines.append(f"- Proposal: {', '.join(bundle['proposal_surfaces']) or 'none'}")
    lines.append(f"- Plan: {', '.join(bundle['plan_surfaces']) or 'none'}")
    lines.append(f"- Generated: {', '.join(bundle['generated_surfaces']) or 'none'}")
    lines.append(f"- Historical context only: {', '.join(bundle['historical_context'][0]['paths']) or 'none'}")
    lines.extend(["", "## Reviewers And Evidence"])
    lines.append(f"- Reviewers: {', '.join(bundle['required_reviewers']) or 'none'}")
    lines.append(f"- Evidence: {', '.join(bundle['required_evidence']) or 'none'}")
    lines.extend(["", "## Validation Commands"])
    for command in bundle["required_validation_commands"]:
        lines.append(f"- `{command}`")
    lines.extend(["", "## Cross-Repo Fallout"])
    lines.append(f"- Overall verdict: `{bundle['cross_repo_fallout']['overall_verdict']}`")
    lines.append(
        f"- Repositories: {', '.join(bundle['cross_repo_fallout']['required_repositories']) or 'none'}"
    )
    lines.append(
        f"- Reviewers: {', '.join(bundle['cross_repo_fallout']['required_reviewers']) or 'none'}"
    )
    return "\n".join(lines).rstrip() + "\n"


def expected_bundle_files() -> set[str]:
    return set(FILE_NAME_MAP.values())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", default="origin/main...HEAD")
    parser.add_argument("--output-dir", default="generated/knowledge/task-bundles")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_dir = repo_root / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    taxonomy = load_yaml(repo_root / "docs" / "meta" / "knowledge" / "AGENT_TASK_TAXONOMY.yaml")["task_types"]

    expected_files = expected_bundle_files()
    existing_files = {path.name for path in output_dir.glob("*.md")}

    if args.check and existing_files != expected_files:
        raise SystemExit("AGENT_TASK_BUNDLE_SET_MISMATCH")
    if not args.check:
        for stale in sorted(existing_files - expected_files):
            (output_dir / stale).unlink()

    for task_type in taxonomy:
        bundle = build_bundle(repo_root, task_type)
        rendered = render_bundle_markdown(bundle)
        target = output_dir / FILE_NAME_MAP[task_type]
        if args.check:
            if not target.exists() or target.read_text() != rendered:
                raise SystemExit(f"AGENT_TASK_BUNDLE_DRIFT:{task_type}")
        else:
            target.write_text(rendered)

    print(f"AGENT_TASK_BUNDLES_OK mode={'check' if args.check else 'write'} bundles={len(taxonomy)}")


if __name__ == "__main__":
    main()
