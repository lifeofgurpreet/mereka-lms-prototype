#!/usr/bin/env python3
"""Executable route resolver — deterministic routing from contracts.

Given changed file paths or a symptom string, returns the owner repo,
owner layer, required skill bundle, required checks, and forbidden
shortcuts.

Consumes:
  - config/change-surface-contracts.yaml (file path → surface)
  - config/skill-routing-contract.yaml (symptom → skill bundle)
  - config/source-of-truth-matrix.yaml (canonical authority)
  - config/ghost-truth-surfaces.yaml (surfaces to warn about)

Usage:
  scripts/agents/resolve-route.py --files deploy/k8s/base/apps/openedx/settings/lms/production.py
  scripts/agents/resolve-route.py --symptom "MFE login page is blank"
  scripts/agents/resolve-route.py --files foo.py --symptom "settings drift"
"""
import argparse
import fnmatch
import json
from pathlib import Path

import yaml


def load_yaml(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f) or {}


def resolve_files(changed_files: list[str], contracts: dict, ghosts: dict) -> list[dict]:
    """Resolve changed files against change-surface contracts."""
    results = []
    surfaces = contracts.get("surfaces", [])
    ghost_surfaces = ghosts.get("surfaces", [])

    for filepath in changed_files:
        matched = False

        # Check ghost truth first
        for ghost in ghost_surfaces:
            pattern = ghost.get("path", "")
            if fnmatch.fnmatch(filepath, pattern):
                results.append({
                    "file": filepath,
                    "type": "ghost_truth_warning",
                    "surface_id": ghost["id"],
                    "class": ghost.get("class", "unknown"),
                    "canonical_source": ghost.get("canonical_source", {}),
                    "warning": f"This file is classified as '{ghost.get('class')}' — not canonical truth",
                })
                matched = True
                break

        # Match against change-surface contracts
        for surface in surfaces:
            for pattern in surface.get("globs", []):
                if fnmatch.fnmatch(filepath, pattern):
                    results.append({
                        "file": filepath,
                        "type": "surface_match",
                        "surface_id": surface["id"],
                        "owner_layer": surface.get("owner_layer", "unknown"),
                        "required_skills": surface.get("required_skills", []),
                        "required_checks": surface.get("required_checks", []),
                        "forbidden": surface.get("forbidden", []),
                    })
                    matched = True
                    break
            if matched:
                break

        if not matched:
            results.append({
                "file": filepath,
                "type": "unmatched",
                "warning": "No contract surface matches this file",
            })

    return results


def resolve_symptom(symptom: str, routing: dict) -> list[dict]:
    """Resolve a symptom string against skill-routing contract."""
    results = []
    routes = routing.get("routes", [])

    # Simple keyword matching — score by overlap
    symptom_lower = symptom.lower()
    scored = []
    for route in routes:
        route_text = f"{route.get('symptom', '')} {route.get('id', '')} {route.get('notes', '')}".lower()
        # Count keyword overlap
        keywords = symptom_lower.split()
        score = sum(1 for kw in keywords if kw in route_text)
        if score > 0:
            scored.append((score, route))

    scored.sort(key=lambda x: -x[0])

    if scored:
        for score, route in scored[:3]:  # top 3 matches
            results.append({
                "type": "symptom_match",
                "route_id": route["id"],
                "symptom_template": route.get("symptom", ""),
                "match_score": score,
                "required_skills": route.get("required_skills", []),
                "recommended_skills": route.get("recommended_skills", []),
                "entry_point": route.get("entry_point", ""),
                "notes": route.get("notes", ""),
            })
    else:
        results.append({
            "type": "no_match",
            "warning": "No skill-routing route matches this symptom",
            "suggestion": "Start with layer-triage to identify the owner layer",
        })

    return results


def main():
    parser = argparse.ArgumentParser(description="Resolve routing from contracts")
    parser.add_argument("--files", nargs="+", help="Changed file paths to resolve")
    parser.add_argument("--symptom", help="Symptom string to resolve")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    args = parser.parse_args()

    if not args.files and not args.symptom:
        parser.error("provide --files, --symptom, or both")

    root = Path(args.repo_root)

    contracts = load_yaml(root / "config/change-surface-contracts.yaml")
    routing = load_yaml(root / "config/skill-routing-contract.yaml")
    ghosts = load_yaml(root / "config/ghost-truth-surfaces.yaml")

    output = {"file_routes": [], "symptom_routes": []}

    if args.files:
        output["file_routes"] = resolve_files(args.files, contracts, ghosts)

    if args.symptom:
        output["symptom_routes"] = resolve_symptom(args.symptom, routing)

    if args.json:
        print(json.dumps(output, indent=2))
    else:
        # Human-readable output
        if output["file_routes"]:
            print("=== File Routing ===")
            for r in output["file_routes"]:
                if r["type"] == "ghost_truth_warning":
                    print(f"  ⚠ {r['file']}: GHOST TRUTH ({r['class']}) — {r['warning']}")
                    cs = r.get("canonical_source", {})
                    if cs:
                        print(f"    Canonical: {cs.get('repo', '?')} → {cs.get('path', '?')}")
                elif r["type"] == "surface_match":
                    print(f"  ✓ {r['file']}: surface={r['surface_id']}, layer={r['owner_layer']}")
                    print(f"    Skills: {', '.join(r['required_skills'])}")
                    if r["forbidden"]:
                        print(f"    Forbidden: {', '.join(r['forbidden'])}")
                else:
                    print(f"  ? {r['file']}: {r['warning']}")
            print()

        if output["symptom_routes"]:
            print("=== Symptom Routing ===")
            for r in output["symptom_routes"]:
                if r["type"] == "symptom_match":
                    print(f"  → {r['route_id']} (score: {r['match_score']})")
                    print(f"    Template: {r['symptom_template']}")
                    print(f"    Required: {', '.join(r['required_skills'])}")
                    if r["recommended_skills"]:
                        print(f"    Recommended: {', '.join(r['recommended_skills'])}")
                    print(f"    Entry: {r['entry_point']}")
                else:
                    print(f"  ? {r['warning']}")
                    print(f"    {r.get('suggestion', '')}")


if __name__ == "__main__":
    main()
