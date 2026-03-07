#!/usr/bin/env python3
from pathlib import Path
import yaml


MANIFEST = Path("docs/adr/manifest.yaml")
README = Path("docs/adr/README.md")


def render() -> str:
    data = yaml.safe_load(MANIFEST.read_text(encoding="utf-8"))
    adrs = sorted(data.get("adrs", []), key=lambda a: a.get("id", ""))

    lines = [
        "# Architecture Decision Records",
        "",
        "_Generated from `docs/adr/manifest.yaml`. Do not hand-edit._",
        "",
        "| ADR | Title | Status | Type | Path |",
        "|---|---|---|---|---|",
    ]

    for adr in adrs:
        adr_id = adr.get("id", "")
        title = adr.get("title", adr_id)
        status = adr.get("decision_status", "")
        dtype = adr.get("decision_type", "")
        path = adr.get("path", "")
        link = path.replace("docs/adr/", "")
        lines.append(f"| {adr_id} | {title} | {status} | {dtype} | [{link}]({link}) |")

    return "\n".join(lines) + "\n"


def main() -> int:
    README.write_text(render(), encoding="utf-8")
    print("ADR_README_GENERATED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
