#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_RECEIPT_OUTPUT = Path("generated/knowledge/runtime-proof-receipt.json")
DEFAULT_MANIFEST_OUTPUT = Path("generated/knowledge/proof-bundle-manifest.json")
RECEIPT_SCHEMA_PATH = Path("docs/meta/knowledge/schemas/runtime-proof-receipt.schema.json")
MANIFEST_SCHEMA_PATH = Path("docs/meta/knowledge/schemas/proof-bundle-manifest.schema.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 13 runtime proof receipt and proof bundle manifest.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="diff_range", default="origin/main...HEAD")
    parser.add_argument("--receipt-output", default=str(DEFAULT_RECEIPT_OUTPUT))
    parser.add_argument("--manifest-output", default=str(DEFAULT_MANIFEST_OUTPUT))
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


def build_receipt(runtime_convergence: dict[str, Any], release_readiness: dict[str, Any], diff_range: str) -> dict[str, Any]:
    proof_references = [
        {
            "check_id": check["check_id"],
            "status": check["status"],
            "canonical_sources": check["canonical_sources"],
            "evidence": check["evidence"],
        }
        for check in runtime_convergence["checks"]
    ]
    unresolved = sorted(
        set(release_readiness["runtime_convergence_implications"])
        | {
            "live runtime convergence remains out of scope for this repo-truth receipt",
        }
    )
    return {
        "receipt_id": "runtime-proof-receipt",
        "schema_version": 1,
        "generated_by": "tools/knowledge/build_runtime_proof_receipt.py",
        "source_range": diff_range,
        "canonical_inputs": sorted(
            {
                "docs/meta/knowledge/EXECUTION_PROOF_RUNTIME_MODEL.md",
                "generated/skills/runtime-convergence-report.json",
                "generated/knowledge/release-readiness.json",
            }
        ),
        "proof_references": proof_references,
        "unresolved_runtime_inputs": unresolved,
        "convergence_summary": runtime_convergence["summary"],
    }


def build_manifest(diff_range: str) -> dict[str, Any]:
    return {
        "pack_id": "proof-bundle-manifest",
        "schema_version": 1,
        "generated_by": "tools/knowledge/build_runtime_proof_receipt.py",
        "source_range": diff_range,
        "canonical_inputs": sorted(
            {
                "generated/knowledge/execution-receipt.json",
                "generated/knowledge/approval-receipt.json",
                "generated/knowledge/evidence-receipt.json",
                "generated/knowledge/release-decision-receipt.json",
                "generated/knowledge/runtime-proof-receipt.json",
            }
        ),
        "receipts": [
            "generated/knowledge/execution-receipt.json",
            "generated/knowledge/approval-receipt.json",
            "generated/knowledge/evidence-receipt.json",
            "generated/knowledge/release-decision-receipt.json",
            "generated/knowledge/runtime-proof-receipt.json",
        ],
        "decision_outputs": [
            "generated/knowledge/review-decision.json",
            "generated/knowledge/reviewer-obligations.json",
            "generated/knowledge/evidence-obligations.json",
            "generated/knowledge/read-first-packs.json",
            "generated/knowledge/release-readiness.json",
            "generated/knowledge/runtime-evaluation.json",
        ],
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    receipt_output = repo_root / args.receipt_output
    manifest_output = repo_root / args.manifest_output
    receipt_schema = load_json(repo_root / RECEIPT_SCHEMA_PATH)
    manifest_schema = load_json(repo_root / MANIFEST_SCHEMA_PATH)
    runtime_convergence = load_json(repo_root / "generated/skills/runtime-convergence-report.json")
    release_readiness = load_json(repo_root / "generated/knowledge/release-readiness.json")

    receipt = build_receipt(runtime_convergence, release_readiness, args.diff_range)
    manifest = build_manifest(args.diff_range)

    jsonschema.validate(instance=receipt, schema=receipt_schema)
    jsonschema.validate(instance=manifest, schema=manifest_schema)

    receipt_serialized = json.dumps(receipt, indent=2, sort_keys=True) + "\n"
    manifest_serialized = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    write_or_check(receipt_output, receipt_serialized, args.check, "RUNTIME_PROOF_RECEIPT")
    write_or_check(manifest_output, manifest_serialized, args.check, "PROOF_BUNDLE_MANIFEST")

    mode = "check" if args.check else "write"
    print(
        "RUNTIME_PROOF_RECEIPT_OK "
        f"mode={mode} checks={len(receipt['proof_references'])} "
        f"warnings={receipt['convergence_summary']['warning']}"
    )


if __name__ == "__main__":
    main()
