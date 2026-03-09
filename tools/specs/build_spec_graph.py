#!/usr/bin/env python3
"""Generate a machine-readable graph for the spec system."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def rel(path: Path, repo_root: Path) -> str:
    return path.relative_to(repo_root).as_posix()


def build_graph(repo_root: Path) -> dict[str, object]:
    catalog_path = repo_root / "specs" / "catalog.json"
    catalog = json.loads(catalog_path.read_text())
    nodes: list[dict[str, object]] = []
    edges: list[dict[str, str]] = []

    for entry in catalog.get("entries", []):
        spec_path = entry["path"]
        nodes.append(
            {
                "id": spec_path,
                "path": spec_path,
                "title": entry.get("title"),
                "node_type": entry.get("doc_type", "spec"),
                "lane": entry.get("lane"),
                "status": entry.get("status"),
                "spec_class": entry.get("spec_class"),
                "normativity": entry.get("normativity"),
                "owner": entry.get("owner"),
            }
        )

        links = entry.get("links") or {}
        for edge_type, node_type in (
            ("source_spec", "spec"),
            ("source_plan", "plan"),
            ("plan", "plan"),
            ("testplan", "testplan"),
            ("generated_testmap", "generated_testmap"),
            ("legacy_testmap", "legacy_testmap"),
        ):
            target = links.get(edge_type)
            if not target:
                continue
            nodes.append(
                {
                    "id": target,
                    "path": target,
                    "title": Path(target).name,
                    "node_type": node_type,
                }
            )
            edges.append(
                {
                    "source": spec_path,
                    "target": target,
                    "edge_type": edge_type,
                }
            )

    standards = [
        repo_root / "specs" / "standards" / "SPEC_SYSTEM_CHARTER.md",
        repo_root / "specs" / "standards" / "DOCS_SPECS_BOUNDARY.md",
        repo_root / "specs" / "standards" / "SPEC_METADATA_MODEL.md",
        repo_root / "specs" / "standards" / "SPEC_AUTHORING_STANDARD.md",
    ]
    for standard in standards:
        standard_rel = rel(standard, repo_root)
        nodes.append(
            {
                "id": standard_rel,
                "path": standard_rel,
                "title": standard.stem.replace("_", " "),
                "node_type": "standard",
            }
        )

    dedup_nodes: dict[str, dict[str, object]] = {}
    for node in nodes:
        dedup_nodes[node["id"]] = node

    return {
        "generated_by": "tools/specs/build_spec_graph.py",
        "root": "specs",
        "catalog": "specs/catalog.json",
        "node_count": len(dedup_nodes),
        "edge_count": len(edges),
        "nodes": sorted(dedup_nodes.values(), key=lambda item: str(item["id"])),
        "edges": sorted(edges, key=lambda item: (item["source"], item["edge_type"], item["target"])),
    }

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if graph output would change")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    output_path = repo_root / "specs" / "_generated" / "graph.json"
    graph = build_graph(repo_root)
    rendered = json.dumps(graph, indent=2, sort_keys=True) + "\n"

    if args.check:
        current = output_path.read_text() if output_path.exists() else ""
        if current != rendered:
            raise SystemExit("SPEC_GRAPH_DRIFT: specs/_generated/graph.json is out of date")
        print(f"SPEC_GRAPH_OK nodes={graph['node_count']} edges={graph['edge_count']} mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print(f"SPEC_GRAPH_OK nodes={graph['node_count']} edges={graph['edge_count']} mode=write")


if __name__ == "__main__":
    main()
