#!/usr/bin/env python3
"""Build a unified docs/specs knowledge graph from the Wave 4 catalog."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


def load_catalog(path: Path) -> dict:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError(f"{path} must be a JSON object")
    return data


def build_graph(repo_root: Path) -> dict[str, object]:
    catalog = load_catalog(repo_root / "generated" / "catalogs" / "knowledge-catalog.json")
    nodes: list[dict[str, object]] = []
    edges: list[dict[str, str]] = []

    for entry in catalog.get("entries", []):
        path = entry["path"]
        root = entry.get("root")
        lane = entry.get("lane")
        classification = entry.get("classification")
        nodes.append(
            {
                "id": path,
                "path": path,
                "title": entry.get("title"),
                "root": root,
                "lane": lane,
                "classification": classification,
                "status": entry.get("status"),
                "owner": entry.get("owner"),
                "node_type": f"{root}:{lane}",
            }
        )
        if root in {"docs", "specs"}:
            edges.append({"source": root, "target": path, "edge_type": "contains"})
        edges.append({"source": f"lane:{root}:{lane}", "target": path, "edge_type": "classifies"})
        edges.append(
            {
                "source": f"classification:{classification}",
                "target": path,
                "edge_type": "classifies",
            }
        )

    summary_nodes = [
        {"id": "docs", "path": "docs", "title": "docs", "node_type": "root"},
        {"id": "specs", "path": "specs", "title": "specs", "node_type": "root"},
    ]
    for lane_name in sorted(catalog.get("lanes", {})):
        summary_nodes.append(
            {
                "id": f"lane:{lane_name}",
                "path": f"lane:{lane_name}",
                "title": lane_name,
                "node_type": "lane",
            }
        )
    for classification in sorted(catalog.get("classifications", {})):
        summary_nodes.append(
            {
                "id": f"classification:{classification}",
                "path": f"classification:{classification}",
                "title": classification,
                "node_type": "classification",
            }
        )

    dedup_nodes: dict[str, dict[str, object]] = {}
    for node in [*summary_nodes, *nodes]:
        dedup_nodes[node["id"]] = node

    return {
        "generated_by": "tools/knowledge/build_knowledge_graph.py",
        "catalog": "generated/catalogs/knowledge-catalog.json",
        "node_count": len(dedup_nodes),
        "edge_count": len(edges),
        "nodes": sorted(dedup_nodes.values(), key=lambda item: str(item["id"])),
        "edges": sorted(edges, key=lambda item: (item["source"], item["edge_type"], item["target"])),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default="generated/graphs/knowledge-graph.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    graph = build_graph(repo_root)
    rendered = json.dumps(graph, indent=2, sort_keys=True) + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("KNOWLEDGE_GRAPH_DRIFT")
        print(f"KNOWLEDGE_GRAPH_OK nodes={graph['node_count']} edges={graph['edge_count']} mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print(f"KNOWLEDGE_GRAPH_OK nodes={graph['node_count']} edges={graph['edge_count']} mode=write")


if __name__ == "__main__":
    main()
