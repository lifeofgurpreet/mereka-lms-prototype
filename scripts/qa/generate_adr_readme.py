#!/usr/bin/env python3
from pathlib import Path

import yaml

MANIFEST = Path("docs/adr/manifest.yaml")
README = Path("docs/adr/README.md")


def render() -> str:
    data = yaml.safe_load(MANIFEST.read_text(encoding="utf-8"))
    adrs = sorted(data.get("adrs", []), key=lambda a: a.get("id", ""))
    accepted = [adr for adr in adrs if (adr.get("decision_status") or "").lower() != "proposed"]
    proposed = [adr for adr in adrs if (adr.get("decision_status") or "").lower() == "proposed"]

    lines = [
        "# Architecture Decision Records",
        "",
        "_Generated from `docs/adr/manifest.yaml`. Do not hand-edit._",
        "",
        "## Navigation",
        "",
        "- [RFC queue](rfc/README.md)",
        "- [ADR templates](templates/README.md)",
        "- [Contradictions register](contradictions-register.md)",
        "- [Manifest](manifest.yaml)",
        "- [Classification map](classification-map.yaml)",
        "- [Status map](status-map.yaml)",
        "",
        "## Metadata surfaces",
        "",
        "- `manifest.yaml` is the authoritative ADR ledger for paths, titles, types, statuses, and rollout state.",
        "- `classification-map.yaml` is a generated auxiliary view derived from `manifest.yaml` for type-based consumers.",
        "- `status-map.yaml` is a generated auxiliary view derived from `manifest.yaml` for status-based consumers.",
        "",
        "## Accepted, historical, and exception ADRs",
        "",
        "| ADR | Title | Status | Type | Path |",
        "|---|---|---|---|---|",
    ]

    for adr in accepted:
        adr_id = adr.get("id", "")
        title = adr.get("title", adr_id)
        status = adr.get("decision_status", "")
        dtype = adr.get("decision_type", "")
        path = adr.get("path", "")
        link = path.replace("docs/adr/", "")
        lines.append(f"| {adr_id} | {title} | {status} | {dtype} | [{link}]({link}) |")

    if proposed:
        lines.extend([
            "",
            "## RFC queue",
            "",
            "Proposed decisions are kept out of the accepted ADR hot path and tracked here until accepted.",
            "",
            "| RFC | Title | Status | Type | Path |",
            "|---|---|---|---|---|",
        ])
        for adr in proposed:
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
