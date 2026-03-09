#!/usr/bin/env python3
"""Generate a machine-readable graph for the spec system."""

from __future__ import annotations

import json
from pathlib import Path


def rel(path: Path, repo_root: Path) -> str:
    return path.relative_to(repo_root).as_posix()


def main() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    catalog_path = repo_root / "specs" / "catalog.json"
    output_path = repo_root / "specs" / "_generated" / "graph.json"

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
                "node_type": "spec",
                "status": entry.get("status"),
                "spec_class": entry.get("spec_class"),
                "normativity": entry.get("normativity"),
                "owner": entry.get("owner"),
            }
        )

        links = entry.get("links") or {}
        for edge_type, node_type in (
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

    graph = {
        "generated_by": "tools/specs/build_spec_graph.py",
        "root": "specs",
        "catalog": "specs/catalog.json",
        "node_count": len(dedup_nodes),
        "edge_count": len(edges),
        "nodes": sorted(dedup_nodes.values(), key=lambda item: str(item["id"])),
        "edges": sorted(edges, key=lambda item: (item["source"], item["edge_type"], item["target"])),
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(graph, indent=2, sort_keys=True) + "\n")
    print(f"SPEC_GRAPH_OK nodes={graph['node_count']} edges={graph['edge_count']}")


if __name__ == "__main__":
    main()
