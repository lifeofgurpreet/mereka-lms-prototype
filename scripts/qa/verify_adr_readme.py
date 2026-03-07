#!/usr/bin/env python3
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_adr_readme import render  # noqa: E402


README = Path("docs/adr/README.md")


def main() -> int:
    expected = render()
    actual = README.read_text(encoding="utf-8")
    if actual != expected:
        print("ADR_README_FAIL")
        print("- docs/adr/README.md is out of sync with docs/adr/manifest.yaml")
        print("- regenerate with: python3 scripts/qa/generate_adr_readme.py")
        return 1
    print("ADR_README_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
