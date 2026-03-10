#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_OUTPUT = Path("generated/knowledge/release-decision-receipt.json")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/release-decision-receipt.schema.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 13 release decision receipt.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="diff_range", default="origin/main...HEAD")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def write_or_check(path: Path, content: str, check: bool) -> None:
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != content:
            raise SystemExit(f"Release decision receipt drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_payload(
    review_decision: dict[str, Any],
    release_readiness: dict[str, Any],
    diff_range: str,
) -> dict[str, Any]:
    return {
        "receipt_id": "release-decision-receipt",
        "schema_version": 1,
        "generated_by": "tools/knowledge/build_release_decision_receipt.py",
        "source_range": diff_range,
        "canonical_inputs": sorted(
            {
                "docs/meta/knowledge/EXECUTION_PROOF_RUNTIME_MODEL.md",
                "generated/knowledge/review-decision.json",
                "generated/knowledge/release-readiness.json",
                "generated/knowledge/execution-receipt.json",
                "generated/knowledge/approval-receipt.json",
                "generated/knowledge/evidence-receipt.json",
            }
        ),
        "release_status": release_readiness["release_status"],
        "dependent_receipts": [
            "generated/knowledge/execution-receipt.json",
            "generated/knowledge/approval-receipt.json",
            "generated/knowledge/evidence-receipt.json",
        ],
        "affected_repos": release_readiness["affected_repos"],
        "affected_contracts": release_readiness["affected_contracts"],
        "unresolved_inputs": sorted(
            set(release_readiness["missing_reviewer_inputs"])
            | set(release_readiness["missing_evidence"])
        ),
        "explanation": sorted(
            set(release_readiness["why"])
            | {
                f"decision severity is {review_decision['decision']['severity']}",
                f"blocking decision state is {review_decision['decision']['blocking']}",
            }
        ),
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    schema = load_json(repo_root / SCHEMA_PATH)
    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    release_readiness = load_json(repo_root / "generated/knowledge/release-readiness.json")
    payload = build_payload(review_decision, release_readiness, args.diff_range)
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_or_check(output_path, serialized, args.check)
    mode = "check" if args.check else "write"
    print(
        "RELEASE_DECISION_RECEIPT_OK "
        f"mode={mode} status={payload['release_status']} "
        f"dependent_receipts={len(payload['dependent_receipts'])}"
    )


if __name__ == "__main__":
    main()
