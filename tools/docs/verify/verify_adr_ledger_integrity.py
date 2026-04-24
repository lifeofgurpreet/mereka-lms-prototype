#!/usr/bin/env python3
"""Verify ADR placement and generated ledger integrity."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.docs.adr_ledger import HOT_PATH_IDS, iter_adr_docs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    docs = iter_adr_docs()
    errors: list[str] = []
    seen_ids: set[str] = set()
    for doc in docs:
        if doc.id in seen_ids:
            errors.append(f"duplicate id: {doc.id}")
        seen_ids.add(doc.id)
        if doc.root_bucket == "accepted" and doc.meta["decision_status"] != "accepted":
            errors.append(f"{doc.relpath}: non-accepted ADR in accepted root")
        if doc.root_bucket == "historical" and doc.meta["decision_status"] == "proposed":
            errors.append(f"{doc.relpath}: proposed ADR must not live in historical")
        if doc.root_bucket == "rfc" and doc.meta["decision_status"] != "proposed":
            errors.append(f"{doc.relpath}: non-proposed ADR in RFC queue")
        for key in ("related_specs", "related_runbooks", "related_evidence"):
            for ref in doc.meta.get(key, []) or []:
                if ref.startswith("http"):
                    continue
                if not (repo_root / ref).exists():
                    errors.append(f"{doc.relpath}: dead reference in {key}: {ref}")

    accepted = [doc for doc in docs if doc.root_bucket == "accepted"]
    if len(accepted) > 18:
        errors.append(f"accepted root too large: {len(accepted)}")
    hot_missing = [adr_id for adr_id in HOT_PATH_IDS if adr_id not in seen_ids]
    if hot_missing:
        errors.append(f"hot path references missing ADRs: {', '.join(hot_missing)}")

    if errors:
        print("ADR_LEDGER_INTEGRITY_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"ADR_LEDGER_INTEGRITY_OK docs={len(docs)} accepted={len(accepted)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
