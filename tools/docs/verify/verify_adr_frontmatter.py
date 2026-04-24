#!/usr/bin/env python3
"""Verify ADR frontmatter completeness and semantics."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.docs.adr_ledger import ADR_ROOT, REQUIRED_KEYS, iter_adr_docs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    docs = iter_adr_docs()
    errors: list[str] = []
    checked = 0
    for doc in docs:
        checked += 1
        missing = [key for key in REQUIRED_KEYS if key not in doc.meta]
        if doc.root_bucket in {"accepted", "rfc"} and missing:
            errors.append(f"{doc.relpath}: missing keys {', '.join(missing)}")
        if doc.root_bucket == "accepted":
            for field in ("Scope", "Non-goals", "Verification"):
                if f"## {field}" not in doc.body:
                    errors.append(f"{doc.relpath}: missing section `## {field}`")
        if doc.meta.get("decision_type") == "exception" and doc.root_bucket == "accepted":
            if not doc.meta.get("expiry_date"):
                errors.append(f"{doc.relpath}: accepted exception missing expiry_date")
            if not doc.meta.get("removal_condition"):
                errors.append(f"{doc.relpath}: accepted exception missing removal_condition")
        if "/home/" in doc.body and doc.root_bucket == "accepted":
            errors.append(f"{doc.relpath}: current-law ADR contains local absolute path")

    if errors:
        print("ADR_FRONTMATTER_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"ADR_FRONTMATTER_OK checked={checked} repo_root={repo_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
