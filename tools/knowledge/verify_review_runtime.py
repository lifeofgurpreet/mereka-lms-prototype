#!/usr/bin/env python3
"""Verify decision-grade review/runtime semantics for the active diff range."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path


HIGH_RISK_PREFIXES = (
    ".github/workflows/release.yml",
    "scripts/infra/canonical-release.sh",
    "scripts/infra/release-openedx-gitops.sh",
    "scripts/qa/verify-release-automation.sh",
    "scripts/qa/verify-release-workflow-invocation.sh",
    "docs/reference/operations/RELEASE_PROCESS.md",
    "docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md",
    "docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md",
    "tools/docs/verify/verify_temporal_integrity.py",
    "tools/docs/verify/verify_generated_navigation.py",
)

REQUIRED_REVIEWER_SOURCES = (
    "docs/meta/standing-orders/README.md",
    "docs/policies/operations/BRANCH_PROTECTION.md",
)

REQUIRED_EVIDENCE_SOURCES = (
    "docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md",
    "docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md",
    "docs/reference/operations/RELEASE_PROCESS.md",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="diff_range", default="")
    return parser.parse_args()


def resolve_range(explicit: str) -> str:
    if explicit:
        return explicit
    if os.environ.get("REVIEW_RUNTIME_RANGE"):
        return os.environ["REVIEW_RUNTIME_RANGE"]
    if os.environ.get("DOCS_POLICY_RANGE"):
        return os.environ["DOCS_POLICY_RANGE"]
    before = os.environ.get("GITHUB_EVENT_BEFORE")
    sha = os.environ.get("GITHUB_SHA")
    if before and sha and before != "0000000000000000000000000000000000000000":
        return f"{before}...{sha}"
    return "HEAD~1...HEAD"


def changed_paths(repo_root: Path, diff_range: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", diff_range],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    diff_range = resolve_range(args.diff_range)
    changed = changed_paths(repo_root, diff_range)

    findings = load_json(repo_root / "generated/knowledge/wave9-findings-ledger.json")["findings"]
    docs_catalog = load_json(repo_root / "docs/catalog.json")
    generated_catalog = load_json(repo_root / "generated/catalogs/docs-catalog.json")

    errors: list[str] = []

    open_findings = [f for f in findings if f["current_status"] == "OPEN"]
    if open_findings:
        errors.append(
            "open findings remain: "
            + ", ".join(f"{f['finding_id']}({f['severity']}/{f['user_or_agent_risk']})" for f in open_findings)
        )

    blocking_partial = [
        f for f in findings
        if f["current_status"] == "PARTIAL"
        and (f["severity"] in {"blocker", "major"} or f["user_or_agent_risk"] == "high")
    ]
    if blocking_partial:
        errors.append(
            "partial high-risk findings remain: "
            + ", ".join(f"{f['finding_id']}({f['severity']}/{f['user_or_agent_risk']})" for f in blocking_partial)
        )

    if docs_catalog != generated_catalog:
        errors.append("docs/catalog.json no longer matches generated/catalogs/docs-catalog.json")

    workflow_text = (repo_root / ".github/workflows/docs-policy.yml").read_text(encoding="utf-8")
    if "DOCS_POLICY_RANGE" not in workflow_text:
        errors.append("docs-policy workflow does not export DOCS_POLICY_RANGE")

    high_risk_changes = [path for path in changed if path.startswith(HIGH_RISK_PREFIXES)]
    if high_risk_changes:
        for rel in REQUIRED_REVIEWER_SOURCES + REQUIRED_EVIDENCE_SOURCES:
            if not (repo_root / rel).exists():
                errors.append(f"missing required review/evidence source for high-risk changes: {rel}")

    if errors:
        print("REVIEW_RUNTIME_FAILED")
        print(f"range={diff_range}")
        print(f"high_risk_changes={len(high_risk_changes)}")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        "REVIEW_RUNTIME_OK "
        f"range={diff_range} high_risk_changes={len(high_risk_changes)} "
        f"open_findings=0 blocking_partial=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
