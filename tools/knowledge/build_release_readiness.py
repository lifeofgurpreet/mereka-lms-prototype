#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_JSON_OUTPUT = Path("generated/knowledge/release-readiness.json")
DEFAULT_MD_OUTPUT = Path("generated/knowledge/release-readiness.md")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/release-readiness.schema.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 12 release readiness outputs.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--json-output", default=str(DEFAULT_JSON_OUTPUT))
    parser.add_argument("--md-output", default=str(DEFAULT_MD_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def write_or_check(path: Path, content: str, check: bool, label: str) -> None:
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != content:
            raise SystemExit(f"{label} drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_payload(
    review_decision: dict[str, Any],
    reviewer_obligations: dict[str, Any],
    evidence_obligations: dict[str, Any],
    read_first_packs: dict[str, Any],
    runtime_convergence: dict[str, Any],
) -> dict[str, Any]:
    severity = review_decision["decision"]["severity"]
    runtime_state = review_decision["decision"]["runtime_convergence_state"]

    missing_reviewer_inputs = [
        "live reviewer approvals are unresolved input"
    ] if reviewer_obligations["required_reviewer_groups"] else ["required reviewer groups could not be derived"]

    missing_evidence = sorted(
        set(evidence_obligations["required_evidence_packs"])
        | set(evidence_obligations["required_status_updates"])
    )

    if runtime_state == "fail" or review_decision["decision"]["blocking"]:
        release_status = "blocked"
    elif severity == "release-critical" and runtime_state == "warning":
        release_status = "break-glass-only"
    elif severity in {"high", "release-critical"}:
        release_status = "advisory"
    else:
        release_status = "ready"

    affected_contracts = []
    if "cross-repo-impact" in review_decision["change_classes"]:
        affected_contracts.append("contracts/release-contracts.yaml")
        affected_contracts.append("contracts/service-identity-contract.yaml")

    promotion_contract_implications = []
    if "cross-repo-impact" in review_decision["change_classes"] or "review" in review_decision["change_classes"]:
        promotion_contract_implications.extend(
            [
                "promotion workflow inputs must remain aligned with release contracts",
                "promotion decision remains blocked on unresolved live reviewer approval state",
            ]
        )

    runtime_convergence_implications = []
    for check in runtime_convergence["checks"]:
        if check["status"] == "warning":
            runtime_convergence_implications.append(check["title"])
    if not runtime_convergence_implications:
        runtime_convergence_implications.append("runtime convergence reports no warnings")

    rollback_obligations = []
    if "rollback_target_reference" in evidence_obligations["required_runbook_updates"]:
        rollback_obligations.append("rollback target reference must be refreshed")
    elif severity in {"high", "release-critical"}:
        rollback_obligations.append("rollback target reference remains required for promotion review")

    why = [
        f"review severity is {severity}",
        f"runtime convergence state is {runtime_state}",
        f"required reviewer groups: {', '.join(reviewer_obligations['required_reviewer_groups'])}",
        f"required evidence obligations: {len(evidence_obligations['obligations'])}",
        f"read-first priority packs: {', '.join(read_first_packs['priority_buckets']['high_risk'] or read_first_packs['priority_buckets']['medium_risk'])}",
    ]

    return {
        "pack_id": "release-readiness",
        "generated_by": "tools/knowledge/build_release_readiness.py",
        "source_range": review_decision["source_range"],
        "canonical_inputs": sorted(
            {
                "docs/meta/knowledge/DECISION_RUNTIME_MODEL.md",
                "generated/knowledge/review-decision.json",
                "generated/knowledge/reviewer-obligations.json",
                "generated/knowledge/evidence-obligations.json",
                "generated/knowledge/read-first-packs.json",
                "generated/skills/runtime-convergence-report.json",
            }
        ),
        "schema_version": 1,
        "diff_range": review_decision["diff_range"],
        "release_status": release_status,
        "why": why,
        "missing_evidence": missing_evidence,
        "missing_reviewer_inputs": missing_reviewer_inputs,
        "affected_contracts": affected_contracts,
        "affected_repos": review_decision["touched_repos"],
        "rollback_obligations": rollback_obligations,
        "promotion_contract_implications": promotion_contract_implications,
        "runtime_convergence_implications": runtime_convergence_implications,
    }


def render_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "<!-- Generated file. Do not hand-edit. -->",
        "# Release Readiness",
        "",
        f"- Diff range: `{payload['diff_range']}`",
        f"- Release status: `{payload['release_status']}`",
        "",
        "## Why",
    ]
    for item in payload["why"]:
        lines.append(f"- {item}")
    lines.extend(["", "## Missing Evidence"])
    for item in payload["missing_evidence"]:
        lines.append(f"- `{item}`")
    lines.extend(["", "## Missing Reviewer Inputs"])
    for item in payload["missing_reviewer_inputs"]:
        lines.append(f"- {item}")
    lines.extend(["", "## Runtime Convergence Implications"])
    for item in payload["runtime_convergence_implications"]:
        lines.append(f"- {item}")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    json_output = repo_root / args.json_output
    md_output = repo_root / args.md_output
    schema = load_json(repo_root / SCHEMA_PATH)

    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    reviewer_obligations = load_json(repo_root / "generated/knowledge/reviewer-obligations.json")
    evidence_obligations = load_json(repo_root / "generated/knowledge/evidence-obligations.json")
    read_first_packs = load_json(repo_root / "generated/knowledge/read-first-packs.json")
    runtime_convergence = load_json(repo_root / "generated/skills/runtime-convergence-report.json")

    payload = build_payload(
        review_decision,
        reviewer_obligations,
        evidence_obligations,
        read_first_packs,
        runtime_convergence,
    )
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    markdown = render_markdown(payload)
    write_or_check(json_output, serialized, args.check, "RELEASE_READINESS_JSON")
    write_or_check(md_output, markdown, args.check, "RELEASE_READINESS_MD")
    mode = "check" if args.check else "write"
    print(
        "RELEASE_READINESS_OK "
        f"mode={mode} status={payload['release_status']} "
        f"repos={','.join(payload['affected_repos'])}"
    )


if __name__ == "__main__":
    main()
