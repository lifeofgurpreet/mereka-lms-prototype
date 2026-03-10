#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_OUTPUT = Path("generated/knowledge/execution-receipt.json")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/execution-receipt.schema.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 13 execution receipt.")
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
            raise SystemExit(f"Execution receipt drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_payload(review_decision: dict[str, Any], diff_range: str) -> dict[str, Any]:
    return {
        "receipt_id": "execution-receipt",
        "schema_version": 1,
        "generated_by": "tools/knowledge/build_execution_receipt.py",
        "source_range": diff_range,
        "canonical_inputs": sorted(
            {
                "docs/meta/knowledge/EXECUTION_PROOF_RUNTIME_MODEL.md",
                "generated/knowledge/review-decision.json",
                "generated/knowledge/reviewer-obligations.json",
                "generated/knowledge/evidence-obligations.json",
            }
        ),
        "commands_run": [
            "python3 tools/knowledge/build_review_decision.py --check --repo-root . --range origin/main...HEAD",
            "python3 tools/knowledge/build_reviewer_obligations.py --check --repo-root .",
            "python3 tools/knowledge/build_evidence_obligations.py --check --repo-root .",
            "python3 tools/knowledge/build_read_first_packs.py --check --repo-root .",
            "python3 tools/knowledge/build_release_readiness.py --check --repo-root .",
            "python3 tools/knowledge/build_runtime_evaluation.py --check --repo-root .",
        ],
        "generated_outputs": [
            "generated/knowledge/review-decision.json",
            "generated/knowledge/reviewer-obligations.json",
            "generated/knowledge/evidence-obligations.json",
            "generated/knowledge/read-first-packs.json",
            "generated/knowledge/release-readiness.json",
            "generated/knowledge/runtime-evaluation.json",
        ],
        "execution_scope": {
            "touched_repos": review_decision["touched_repos"],
            "touched_roots": review_decision["touched_roots"],
            "change_classes": review_decision["change_classes"],
        },
        "decision_reference": {
            "severity": review_decision["decision"]["severity"],
            "blocking": review_decision["decision"]["blocking"],
            "selected_skills": review_decision["decision"]["selected_skills"],
        },
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    schema = load_json(repo_root / SCHEMA_PATH)
    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    payload = build_payload(review_decision, args.diff_range)
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_or_check(output_path, serialized, args.check)
    mode = "check" if args.check else "write"
    print(
        "EXECUTION_RECEIPT_OK "
        f"mode={mode} severity={payload['decision_reference']['severity']} "
        f"outputs={len(payload['generated_outputs'])}"
    )


if __name__ == "__main__":
    main()
