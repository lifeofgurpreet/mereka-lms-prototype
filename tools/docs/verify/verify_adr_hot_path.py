#!/usr/bin/env python3
"""Verify ADR hot path projection is present and bounded."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.docs.adr_ledger import HOT_PATH_IDS


def main() -> int:
    hot_path = Path("docs/adr/_generated/hot-path.md")
    if not hot_path.exists():
        print("ADR_HOT_PATH_FAIL")
        print("- docs/adr/_generated/hot-path.md missing")
        return 1
    text = hot_path.read_text(encoding="utf-8")
    listed = [line for line in text.splitlines() if line.startswith("- [ADR-")]
    if len(listed) > 12:
        print("ADR_HOT_PATH_FAIL")
        print(f"- hot path too large: {len(listed)}")
        return 1
    missing = [adr_id for adr_id in HOT_PATH_IDS if adr_id not in text]
    if missing:
        print("ADR_HOT_PATH_FAIL")
        for adr_id in missing:
            print(f"- missing hot-path ADR: {adr_id}")
        return 1
    print(f"ADR_HOT_PATH_OK count={len(listed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
