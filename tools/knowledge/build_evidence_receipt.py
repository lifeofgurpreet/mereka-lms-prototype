#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_OUTPUT = Path("generated/knowledge/evidence-receipt.json")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/evidence-receipt.schema.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 13 evidence receipt.")
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
            raise SystemExit(f"Evidence receipt drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_payload(
    evidence_obligations: dict[str, Any],
    review_decision: dict[str, Any],
    diff_range: str,
) -> dict[str, Any]:
    required_classes = sorted(evidence_obligations["required_evidence_packs"])
    blocking = [
        {
            "id": obligation["evidence_class"],
            "type": obligation["obligation_type"],
            "blocking": obligation["blocking"],
        }
        for obligation in evidence_obligations["obligations"]
        if obligation["blocking"]
    ]
    return {
        "receipt_id": "evidence-receipt",
        "schema_version": 1,
        "generated_by": "tools/knowledge/build_evidence_receipt.py",
        "source_range": diff_range,
        "canonical_inputs": sorted(
            {
                "docs/meta/knowledge/EXECUTION_PROOF_RUNTIME_MODEL.md",
                "generated/knowledge/evidence-obligations.json",
                "generated/knowledge/review-decision.json",
                "generated/skills/evidence-sufficiency-map.json",
            }
        ),
        "required_evidence_classes": required_classes,
        "satisfied_evidence_classes": [],
        "missing_evidence_classes": required_classes,
        "status_update_requirements": evidence_obligations["required_status_updates"],
        "blocking_obligations": blocking,
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    schema = load_json(repo_root / SCHEMA_PATH)
    evidence_obligations = load_json(repo_root / "generated/knowledge/evidence-obligations.json")
    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    payload = build_payload(evidence_obligations, review_decision, args.diff_range)
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_or_check(output_path, serialized, args.check)
    mode = "check" if args.check else "write"
    print(
        "EVIDENCE_RECEIPT_OK "
        f"mode={mode} required={len(payload['required_evidence_classes'])} "
        f"blocking={len(payload['blocking_obligations'])}"
    )


if __name__ == "__main__":
    main()
