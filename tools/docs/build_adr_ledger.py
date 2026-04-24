#!/usr/bin/env python3
"""Generate ADR ledger projections from ADR file frontmatter."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import yaml

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.docs.adr_ledger import (
    ADR_ROOT,
    GENERATED_ROOT,
    build_generated_maps,
    build_index,
    dump_json,
    iter_adr_docs,
    render_history_map,
    render_hot_path,
    render_readme,
    render_rfc_readme,
)


def write_yaml(path: Path, payload: dict) -> None:
    path.write_text(yaml.safe_dump(payload, sort_keys=False, allow_unicode=True), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build ADR ledger generated surfaces.")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    docs = iter_adr_docs()
    GENERATED_ROOT.mkdir(parents=True, exist_ok=True)

    outputs: dict[Path, str] = {
        ADR_ROOT / "README.md": render_readme(docs),
        ADR_ROOT / "rfc" / "README.md": render_rfc_readme(docs),
        GENERATED_ROOT / "hot-path.md": render_hot_path(docs),
        GENERATED_ROOT / "history-map.md": render_history_map(docs),
    }
    outputs_json = {
        GENERATED_ROOT / "decision-index.json": build_index(docs),
    }
    manifest, classification, status = build_generated_maps(docs)
    outputs_yaml = {
        ADR_ROOT / "manifest.yaml": manifest,
        ADR_ROOT / "classification-map.yaml": classification,
        ADR_ROOT / "status-map.yaml": status,
    }

    mismatches: list[str] = []
    for path, text in outputs.items():
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                mismatches.append(str(path))
        else:
            path.write_text(text, encoding="utf-8")
    for path, payload in outputs_json.items():
        rendered = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != rendered:
                mismatches.append(str(path))
        else:
            dump_json(path, payload)
    for path, payload in outputs_yaml.items():
        rendered = yaml.safe_dump(payload, sort_keys=False, allow_unicode=True)
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != rendered:
                mismatches.append(str(path))
        else:
            write_yaml(path, payload)

    if mismatches:
        print("ADR_LEDGER_BUILD_FAIL")
        for path in mismatches:
            print(f"- {path}")
        return 1
    print(f"ADR_LEDGER_BUILD_OK docs={len(docs)} mode={'check' if args.check else 'write'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
