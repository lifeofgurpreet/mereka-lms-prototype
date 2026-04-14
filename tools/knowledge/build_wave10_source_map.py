#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def repo_ref(repo: str, path: str) -> str:
    return f"{repo}:{path}"


def build_map() -> dict:
    domains = [
        {
            "domain": "release_lanes",
            "authoritative_repo": "platform-control-plane",
            "authoritative_files": [
                repo_ref("platform-control-plane", "contracts/release-contracts.yaml"),
                repo_ref("platform-control-plane", "contracts/service-identity-contract.yaml"),
            ],
            "derived_human_surfaces": [
                repo_ref("bbi-infrastructure", "docs/guides/PROMOTION-WORKFLOW.md"),
                repo_ref("mereka-lms", "docs/reference/operations/RELEASE_PROCESS.md"),
            ],
            "reviewers_owners": ["@platform", "@applications"],
            "drift_risk": "high",
            "validation_command": "bash scripts/qa/verify-release-automation.sh",
        },
        {
            "domain": "service_identity_aliases",
            "authoritative_repo": "platform-control-plane",
            "authoritative_files": [
                repo_ref("platform-control-plane", "contracts/service-identity-contract.yaml"),
            ],
            "derived_human_surfaces": [
                repo_ref("bbi-infrastructure", "CLAUDE.md"),
                repo_ref("bbi-infrastructure", "docs/reference/SERVICE_IDENTITY_REFERENCE.md"),
            ],
            "reviewers_owners": ["@platform"],
            "drift_risk": "high",
            "validation_command": "platform-control-plane:scripts/plan-all.sh --validate-only",
        },
        {
            "domain": "domain_registry_hostnames",
            "authoritative_repo": "bbi-infrastructure",
            "authoritative_files": [
                repo_ref("bbi-infrastructure", "config/domain-registry.yaml"),
            ],
            "derived_human_surfaces": [
                repo_ref("bbi-infrastructure", "docs/reference/CANONICAL_TOPOLOGY.md"),
                repo_ref("bbi-infrastructure", "ENVIRONMENTS.md"),
            ],
            "reviewers_owners": ["@platform"],
            "drift_risk": "medium",
            "validation_command": "make verify",
        },
        {
            "domain": "bootstrap_lane_topology",
            "authoritative_repo": "bbi-infrastructure",
            "authoritative_files": [
                repo_ref("bbi-infrastructure", "config/bootstrap-lane-topology.yaml"),
            ],
            "derived_human_surfaces": [
                repo_ref("bbi-infrastructure", "docs/reference/CANONICAL_TOPOLOGY.md"),
                repo_ref("mereka-lms", "docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md"),
            ],
            "reviewers_owners": ["@platform"],
            "drift_risk": "high",
            "validation_command": "make verify",
        },
        {
            "domain": "promotion_workflow_semantics",
            "authoritative_repo": "bbi-infrastructure",
            "authoritative_files": [
                repo_ref("bbi-infrastructure", "scripts/promote.sh"),
                repo_ref("bbi-infrastructure", ".github/workflows/promote-image.yml"),
                repo_ref("platform-control-plane", "contracts/release-contracts.yaml"),
            ],
            "derived_human_surfaces": [
                repo_ref("bbi-infrastructure", "docs/guides/PROMOTION-WORKFLOW.md"),
                repo_ref("bbi-infrastructure", "CLAUDE.md"),
            ],
            "reviewers_owners": ["@platform", "@applications"],
            "drift_risk": "high",
            "validation_command": "bash scripts/qa/verify-release-workflow-invocation.sh",
        },
        {
            "domain": "runtime_review_evidence_rules",
            "authoritative_repo": "mereka-lms",
            "authoritative_files": [
                repo_ref("mereka-lms", "docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md"),
                repo_ref("mereka-lms", "docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md"),
                repo_ref("mereka-lms", "tools/knowledge/verify_review_runtime.py"),
            ],
            "derived_human_surfaces": [
                repo_ref("mereka-lms", "docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md"),
            ],
            "reviewers_owners": ["@platform", "@docs"],
            "drift_risk": "high",
            "validation_command": "bash scripts/qa/run-review-runtime-gates.sh",
        },
        {
            "domain": "opentofu_backend_workspace_rules",
            "authoritative_repo": "platform-control-plane",
            "authoritative_files": [
                repo_ref("platform-control-plane", "specs/SPEC-CP-002-state-and-workspace-model.md"),
                repo_ref("platform-control-plane", "scripts/plan-all.sh"),
            ],
            "derived_human_surfaces": [
                repo_ref("platform-control-plane", "docs/RELEASE-CONTROL-IMPLEMENTER-PLAYBOOK.md"),
            ],
            "reviewers_owners": ["@platform"],
            "drift_risk": "medium",
            "validation_command": "platform-control-plane:scripts/plan-all.sh --validate-only",
        },
        {
            "domain": "app_deployment_contracts",
            "authoritative_repo": "mereka-lms",
            "authoritative_files": [
                repo_ref("mereka-lms", "deploy/k8s/contract.json"),
                repo_ref("mereka-lms", "config/lane-identity.yaml"),
            ],
            "derived_human_surfaces": [
                repo_ref("mereka-lms", "docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md"),
            ],
            "reviewers_owners": ["@platform", "@applications"],
            "drift_risk": "high",
            "validation_command": "python3 tools/knowledge/verify_review_runtime.py --repo-root . --range origin/main...HEAD",
        },
        {
            "domain": "canonical_entrypoints",
            "authoritative_repo": "mereka-lms",
            "authoritative_files": [
                repo_ref("mereka-lms", "scripts/governance/canonical-entrypoints.yaml"),
            ],
            "derived_human_surfaces": [
                repo_ref("mereka-lms", "docs/README.md"),
                repo_ref("bbi-infrastructure", "docs/README.md"),
            ],
            "reviewers_owners": ["@platform", "@docs"],
            "drift_risk": "medium",
            "validation_command": "bash scripts/qa/verify-authority-routing.sh",
        },
    ]
    return {
        "version": 1,
        "generated_by": "tools/knowledge/build_wave10_source_map.py",
        "domains": domains,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="generated/knowledge/wave10-source-map.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path.cwd()
    output_path = repo_root / args.output
    payload = json.dumps(build_map(), indent=2, sort_keys=True) + "\n"

    if args.check:
        existing = output_path.read_text() if output_path.exists() else None
        if existing != payload:
            print("WAVE10_SOURCE_MAP_STALE")
            return 1
        print("WAVE10_SOURCE_MAP_OK mode=check domains=9")
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(payload)
    print("WAVE10_SOURCE_MAP_OK mode=write domains=9")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
