#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_OUTPUT = Path("generated/knowledge/approval-receipt.json")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/approval-receipt.schema.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 13 approval receipt.")
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
            raise SystemExit(f"Approval receipt drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_payload(
    reviewer_obligations: dict[str, Any],
    release_readiness: dict[str, Any],
    diff_range: str,
) -> dict[str, Any]:
    return {
        "receipt_id": "approval-receipt",
        "schema_version": 1,
        "generated_by": "tools/knowledge/build_approval_receipt.py",
        "source_range": diff_range,
        "canonical_inputs": sorted(
            {
                "docs/meta/knowledge/EXECUTION_PROOF_RUNTIME_MODEL.md",
                "generated/knowledge/reviewer-obligations.json",
                "generated/knowledge/release-readiness.json",
            }
        ),
        "required_reviewers": reviewer_obligations["required_reviewer_groups"],
        "escalation_reviewers": reviewer_obligations["escalation_reviewers"],
        "unresolved_live_inputs": release_readiness["missing_reviewer_inputs"],
        "approval_state": {
            "modeled_only": True,
            "blocking_missing_live_inputs": bool(release_readiness["missing_reviewer_inputs"]),
        },
        "release_status_reference": {
            "release_status": release_readiness["release_status"],
            "missing_reviewer_inputs": release_readiness["missing_reviewer_inputs"],
        },
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    schema = load_json(repo_root / SCHEMA_PATH)
    reviewer_obligations = load_json(repo_root / "generated/knowledge/reviewer-obligations.json")
    release_readiness = load_json(repo_root / "generated/knowledge/release-readiness.json")
    payload = build_payload(reviewer_obligations, release_readiness, args.diff_range)
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_or_check(output_path, serialized, args.check)
    mode = "check" if args.check else "write"
    print(
        "APPROVAL_RECEIPT_OK "
        f"mode={mode} required={len(payload['required_reviewers'])} "
        f"unresolved={len(payload['unresolved_live_inputs'])}"
    )


if __name__ == "__main__":
    main()
