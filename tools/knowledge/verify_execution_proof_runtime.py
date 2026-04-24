#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


OUTPUT_SCHEMA_MAP = {
    "generated/knowledge/execution-receipt.json": "docs/meta/knowledge/schemas/execution-receipt.schema.json",
    "generated/knowledge/approval-receipt.json": "docs/meta/knowledge/schemas/approval-receipt.schema.json",
    "generated/knowledge/evidence-receipt.json": "docs/meta/knowledge/schemas/evidence-receipt.schema.json",
    "generated/knowledge/release-decision-receipt.json": "docs/meta/knowledge/schemas/release-decision-receipt.schema.json",
    "generated/knowledge/runtime-proof-receipt.json": "docs/meta/knowledge/schemas/runtime-proof-receipt.schema.json",
    "generated/knowledge/proof-bundle-manifest.json": "docs/meta/knowledge/schemas/proof-bundle-manifest.schema.json",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify Wave 13 execution proof runtime.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="diff_range", default="origin/main...HEAD")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def validate_schemas(repo_root: Path) -> None:
    for output_rel, schema_rel in OUTPUT_SCHEMA_MAP.items():
        output_path = repo_root / output_rel
        schema_path = repo_root / schema_rel
        ensure(output_path.exists(), f"Missing execution-proof output: {output_rel}")
        ensure(schema_path.exists(), f"Missing execution-proof schema: {schema_rel}")
        jsonschema.validate(instance=load_json(output_path), schema=load_json(schema_path))


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()

    validate_schemas(repo_root)

    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    reviewer_obligations = load_json(repo_root / "generated/knowledge/reviewer-obligations.json")
    evidence_obligations = load_json(repo_root / "generated/knowledge/evidence-obligations.json")
    release_readiness = load_json(repo_root / "generated/knowledge/release-readiness.json")
    runtime_convergence = load_json(repo_root / "generated/skills/runtime-convergence-report.json")

    execution_receipt = load_json(repo_root / "generated/knowledge/execution-receipt.json")
    approval_receipt = load_json(repo_root / "generated/knowledge/approval-receipt.json")
    evidence_receipt = load_json(repo_root / "generated/knowledge/evidence-receipt.json")
    release_decision_receipt = load_json(repo_root / "generated/knowledge/release-decision-receipt.json")
    runtime_proof_receipt = load_json(repo_root / "generated/knowledge/runtime-proof-receipt.json")
    manifest = load_json(repo_root / "generated/knowledge/proof-bundle-manifest.json")

    for payload in [
        execution_receipt,
        approval_receipt,
        evidence_receipt,
        release_decision_receipt,
        runtime_proof_receipt,
        manifest,
    ]:
        ensure(payload["source_range"] == args.diff_range, f"Source range drift detected in {payload.get('receipt_id', payload.get('pack_id'))}")

    ensure(
        execution_receipt["decision_reference"]["selected_skills"] == review_decision["decision"]["selected_skills"],
        "Execution receipt drift from review decision selected skills",
    )
    ensure(
        approval_receipt["required_reviewers"] == reviewer_obligations["required_reviewer_groups"],
        "Approval receipt drift from reviewer obligations",
    )
    expected_missing = sorted(evidence_obligations["required_evidence_packs"])
    ensure(
        evidence_receipt["missing_evidence_classes"] == expected_missing,
        "Evidence receipt drift from evidence obligations",
    )
    ensure(
        release_decision_receipt["release_status"] == release_readiness["release_status"],
        "Release decision receipt drift from release readiness",
    )
    ensure(
        runtime_proof_receipt["convergence_summary"] == runtime_convergence["summary"],
        "Runtime proof receipt drift from runtime convergence summary",
    )

    for path in manifest["receipts"] + manifest["decision_outputs"] + manifest["canonical_inputs"]:
        ensure(not path.startswith("/home/"), f"Absolute path leaked in proof manifest: {path}")
        ensure((repo_root / path).exists(), f"Manifest path missing: {path}")

    ensure(
        set(manifest["receipts"]) == {
            "generated/knowledge/execution-receipt.json",
            "generated/knowledge/approval-receipt.json",
            "generated/knowledge/evidence-receipt.json",
            "generated/knowledge/release-decision-receipt.json",
            "generated/knowledge/runtime-proof-receipt.json",
        },
        "Proof bundle manifest receipt set is incomplete or drifted",
    )

    ensure(
        approval_receipt["approval_state"]["blocking_missing_live_inputs"] is True,
        "Approval receipt must keep live approval state unresolved and blocking",
    )

    print(
        "EXECUTION_PROOF_RUNTIME_OK "
        f"range={args.diff_range} receipts={len(manifest['receipts'])} "
        f"decision_outputs={len(manifest['decision_outputs'])} warnings={runtime_proof_receipt['convergence_summary']['warning']}"
    )


if __name__ == "__main__":
    main()
