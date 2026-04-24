#!/usr/bin/env python3
"""Build Wave 8 agent domain entrypoints from existing repo truth."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml


DOMAIN_RULES: dict[str, dict[str, Any]] = {
    "architecture": {
        "description": "Architecture decisions, governing docs, and system-level intent.",
        "canonical_surfaces": [
            "docs/meta/docs-program/WAVE4_CLOSEOUT.md",
            "docs/adr",
            "generated/knowledge/review-bundle.md",
            "generated/knowledge/truth-impact-report.json",
        ],
        "task_types": ["docs_architecture_change", "reviewer_pass"],
        "cross_repo_artifacts": [],
        "forbidden_starting_points": ["docs/archive/**", "compatibility wrappers"],
    },
    "docs-control-plane": {
        "description": "Canonical docs governance, catalogs, and docs/spec boundary policy.",
        "canonical_surfaces": [
            "docs/meta/docs-program/WAVE4_CLOSEOUT.md",
            "tools/docs/verify/build-doc-catalog.py",
            "tools/docs/verify/verify-doc-catalog-governance.py",
            "generated/catalogs/docs-catalog.json",
        ],
        "task_types": ["docs_architecture_change", "reviewer_pass", "evidence_status_update"],
        "cross_repo_artifacts": [],
        "forbidden_starting_points": ["docs/archive/**", "generated docs catalog as sole authority"],
    },
    "specs-control-plane": {
        "description": "Normative spec law, metadata model, and spec validation surfaces.",
        "canonical_surfaces": [
            "specs/standards/SPEC_SYSTEM_CHARTER.md",
            "specs/standards/SPEC_METADATA_MODEL.md",
            "specs/standards/SPEC_AUTHORING_STANDARD.md",
            "tools/specs/verify_spec_frontmatter.py",
            "tools/specs/verify_spec_taxonomy.py",
        ],
        "task_types": ["normative_spec_change", "reviewer_pass"],
        "cross_repo_artifacts": [],
        "forbidden_starting_points": ["specs/archive/**", "compatibility wrappers"],
    },
    "auth": {
        "description": "Authentication and identity surfaces, especially SSO and auth boundaries.",
        "canonical_surfaces": [
            "specs/auth-sso-enterprise_spec.md",
            "generated/knowledge/truth-impact-report.json",
            "generated/knowledge/review-bundle.md",
        ],
        "task_types": ["normative_spec_change", "incident_debug", "cross_repo_contract_change"],
        "cross_repo_artifacts": ["generated/contracts/deployment-impact-report.json"],
        "forbidden_starting_points": ["docs/archive/**", "status-only notes"],
    },
    "tenancy": {
        "description": "Tenant isolation, tenancy contracts, and tenancy-auth review surfaces.",
        "canonical_surfaces": [
            "specs/multi-tenancy-architecture_spec.md",
            "generated/knowledge/truth-impact-report.json",
            "generated/contracts/deployment-impact-report.json",
        ],
        "task_types": ["normative_spec_change", "cross_repo_contract_change", "incident_debug"],
        "cross_repo_artifacts": ["generated/contracts/deployment-impact-report.json"],
        "forbidden_starting_points": ["docs/archive/**", "generated reports without canonical spec context"],
    },
    "frontend": {
        "description": "Frontend architecture, theming, and performance control-plane surfaces.",
        "canonical_surfaces": [
            "specs/frontend-performance-budgets_spec.md",
            "docs/meta/docs-program/WAVE4_CLOSEOUT.md",
            "generated/knowledge/review-bundle.md",
        ],
        "task_types": ["normative_spec_change", "proposal_change", "docs_architecture_change"],
        "cross_repo_artifacts": [],
        "forbidden_starting_points": ["docs/archive/**", "historical prompts as primary source"],
    },
    "mobile": {
        "description": "Mobile plans, runtime parity, and related release/debug surfaces.",
        "canonical_surfaces": [
            "specs/plans/mobile-apps-enterprise_plan.md",
            "docs/reference/architecture/MOBILE_TOKEN_PARITY.md",
            "generated/contracts/release-obligations.md",
        ],
        "task_types": ["migration_change", "release_change", "incident_debug"],
        "cross_repo_artifacts": [
            "generated/contracts/cross-repo-manifest.json",
            "generated/contracts/release-obligations.md",
        ],
        "forbidden_starting_points": ["docs/archive/**", "retired wrapper paths"],
    },
    "observability": {
        "description": "SLO/SLA, runtime observability, and operational response surfaces.",
        "canonical_surfaces": [
            "specs/slo-sla-service-level-management_spec.md",
            "generated/contracts/deployment-impact-report.json",
            "generated/knowledge/truth-impact-report.json",
        ],
        "task_types": ["incident_debug", "release_change", "cross_repo_contract_change"],
        "cross_repo_artifacts": [
            "generated/contracts/deployment-impact-report.json",
            "generated/contracts/cross-repo-manifest.json",
        ],
        "forbidden_starting_points": ["docs/archive/**", "status-only evidence without runbook context"],
    },
    "commerce": {
        "description": "Purchase gateway, payment-related contracts, and release fallout surfaces.",
        "canonical_surfaces": [
            "specs/ecommerce-purchase-gateway_spec.md",
            "generated/contracts/cross-repo-manifest.json",
            "generated/contracts/release-obligations.md",
        ],
        "task_types": ["normative_spec_change", "release_change", "cross_repo_contract_change"],
        "cross_repo_artifacts": [
            "generated/contracts/cross-repo-manifest.json",
            "generated/contracts/deployment-impact-report.json",
            "generated/contracts/release-obligations.md",
        ],
        "forbidden_starting_points": ["docs/archive/**", "guessed infra paths"],
    },
    "runtime/release": {
        "description": "Release obligations, deployment impact, and runtime-affecting review surfaces.",
        "canonical_surfaces": [
            "docs/meta/contracts/RELEASE_OBLIGATIONS.yaml",
            "generated/contracts/release-obligations.md",
            "generated/contracts/deployment-impact-report.json",
        ],
        "task_types": ["release_change", "incident_debug", "reviewer_pass"],
        "cross_repo_artifacts": [
            "generated/contracts/cross-repo-manifest.json",
            "generated/contracts/deployment-impact-report.json",
            "generated/contracts/release-obligations.md",
        ],
        "forbidden_starting_points": ["docs/archive/**", "historical release notes as authority"],
    },
    "cross-repo contracts": {
        "description": "Repo-to-infra contract, ownership, and deployment crosswalk surfaces.",
        "canonical_surfaces": [
            "docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md",
            "docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml",
            "docs/meta/contracts/INFRA_CROSSWALK.md",
            "generated/contracts/cross-repo-manifest.json",
        ],
        "task_types": ["cross_repo_contract_change", "release_change", "reviewer_pass"],
        "cross_repo_artifacts": [
            "generated/contracts/cross-repo-manifest.json",
            "generated/contracts/deployment-impact-report.json",
            "generated/contracts/release-obligations.md",
        ],
        "forbidden_starting_points": ["docs/archive/**", "guessed infra file mappings"],
    },
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def load_yaml(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text())


def gather_task_metadata(repo_root: Path) -> dict[str, dict[str, Any]]:
    taxonomy = load_yaml(repo_root / "docs" / "meta" / "knowledge" / "AGENT_TASK_TAXONOMY.yaml")["task_types"]
    return taxonomy


def build_entrypoints(repo_root: Path) -> dict[str, Any]:
    taxonomy = gather_task_metadata(repo_root)
    deployment_impact = load_json(repo_root / "generated" / "contracts" / "deployment-impact-report.json")
    cross_repo_manifest = load_json(repo_root / "generated" / "contracts" / "cross-repo-manifest.json")
    review_bundle_path = repo_root / "generated" / "knowledge" / "review-bundle.md"

    entries: list[dict[str, Any]] = []
    unresolved_domains: list[str] = []

    for domain in sorted(DOMAIN_RULES):
        rule = DOMAIN_RULES[domain]
        canonical_surfaces = [p for p in rule["canonical_surfaces"] if (repo_root / p).exists()]
        if not canonical_surfaces:
            unresolved_domains.append(domain)
            continue

        task_types = rule["task_types"]
        required_reviewers = sorted(
            {
                reviewer
                for task_type in task_types
                for reviewer in taxonomy[task_type]["required_reviewers"]
            }
        )
        required_evidence = sorted(
            {
                evidence
                for task_type in task_types
                for evidence in taxonomy[task_type]["required_evidence"]
            }
        )
        validation_commands = []
        seen_commands: set[str] = set()
        for task_type in task_types:
            for command in taxonomy[task_type]["required_validation_commands"]:
                if command not in seen_commands:
                    seen_commands.add(command)
                    validation_commands.append(command)

        cross_repo_surfaces = [p for p in rule["cross_repo_artifacts"] if (repo_root / p).exists()]
        entries.append(
            {
                "domain": domain,
                "description": rule["description"],
                "authoritative_roots": sorted({surface.split("/")[0] for surface in canonical_surfaces}),
                "read_first": canonical_surfaces,
                "prohibited_starting_points": rule["forbidden_starting_points"],
                "task_types": task_types,
                "required_reviewers": required_reviewers,
                "required_evidence": required_evidence,
                "validation_commands": validation_commands,
                "cross_repo_surfaces": cross_repo_surfaces,
                "cross_repo_repositories": deployment_impact.get("required_repositories", []) if cross_repo_surfaces else [],
                "cross_repo_overall_verdict": cross_repo_manifest.get("overall_verdict") if cross_repo_surfaces else "not_applicable",
                "review_bundle_available": review_bundle_path.exists(),
                "resolved": True,
            }
        )

    return {
        "generated_by": "tools/knowledge/build_agent_entrypoints.py",
        "entrypoint_version": 1,
        "domains": entries,
        "domain_count": len(entries),
        "unresolved_domains": sorted(unresolved_domains),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default="generated/knowledge/agent-entrypoints.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    payload = build_entrypoints(repo_root)
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    output_path = repo_root / args.output

    if args.check:
        if not output_path.exists() or output_path.read_text() != rendered:
            raise SystemExit("AGENT_ENTRYPOINTS_DRIFT")
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered)

    print(
        f"AGENT_ENTRYPOINTS_OK mode={'check' if args.check else 'write'} "
        f"domains={payload['domain_count']} unresolved={len(payload['unresolved_domains'])}"
    )


if __name__ == "__main__":
    main()
