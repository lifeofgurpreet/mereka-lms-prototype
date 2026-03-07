#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import yaml


MANIFEST = Path("docs/adr/manifest.yaml")
REL_KEYS = ("depends_on", "read_next", "amends", "supersedes")
BUNDLES = [
    ("00-foundations", "docs/adr/_generated/bundles/00-foundations.md"),
    ("10-auth-and-tenancy", "docs/adr/_generated/bundles/10-auth-and-tenancy.md"),
    ("20-build-and-release", "docs/adr/_generated/bundles/20-build-and-release.md"),
    ("30-frontend", "docs/adr/_generated/bundles/30-frontend.md"),
    ("40-data-and-events", "docs/adr/_generated/bundles/40-data-and-events.md"),
    ("50-commerce", "docs/adr/_generated/bundles/50-commerce.md"),
]


def git_changed_files(diff_range: str) -> list[str]:
    cmd = ["git", "diff", "--name-only", diff_range]
    out = subprocess.check_output(cmd, text=True).strip()
    if not out:
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]


def normalized_tokens(adr: dict) -> set[str]:
    tokens: set[str] = set()
    for key in ("governs", "does_not_govern"):
        for item in adr.get(key, []) or []:
            tokens.update(t for t in item.lower().replace("_", "-").split("-") if t)
    return tokens


def domain_match(changed_path: str, adr: dict) -> bool:
    p = changed_path.lower()
    g = " ".join((adr.get("governs") or [])).lower()
    rules = [
        (("auth", "oidc", "session", "identity"), ("auth", "oidc", "session", "login", "oauth")),
        (("tenant", "multisite", "domain-boundary"), ("tenant", "multisite", "siteconfiguration", "domain")),
        (("frontend", "mfe", "branding"), ("frontend", "mfe", "branding", "theme")),
        (("event", "transport"), ("event", "message", "broker", "stream")),
        (("cache",), ("cache", "redis")),
        (("async", "task"), ("async", "task", "celery", "worker")),
        (("commerce", "payment", "purchase"), ("commerce", "payment", "checkout", "stripe", "gateway")),
        (("data", "pii", "retention"), ("pii", "retention", "data", "privacy")),
        (("gitops", "deploy", "release", "control-plane"), ("gitops", "deploy", "kustomize", "argocd", "release")),
    ]
    for governs_terms, path_terms in rules:
        if any(t in g for t in governs_terms) and any(t in p for t in path_terms):
            return True
    return False


def bundles_for_adr(adr: dict) -> set[str]:
    governs = " ".join((adr.get("governs") or [])).lower()
    out: set[str] = set()
    if adr.get("decision_type") == "foundation":
        out.add("00-foundations")
    if any(k in governs for k in ("auth", "oidc", "session", "tenant", "domain-boundary")):
        out.add("10-auth-and-tenancy")
    if any(k in governs for k in ("build", "release", "deploy", "gitops", "control-plane")):
        out.add("20-build-and-release")
    if any(k in governs for k in ("frontend", "mfe", "branding", "runtime-composition")):
        out.add("30-frontend")
    if any(k in governs for k in ("data", "pii", "event", "cache", "async")):
        out.add("40-data-and-events")
    if any(k in governs for k in ("commerce", "purchase", "payment", "reconciliation")):
        out.add("50-commerce")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve impacted ADRs from changed files.")
    parser.add_argument("--diff-range", default="HEAD~1...HEAD", help="Git diff range used when --changed-file is not set.")
    parser.add_argument("--changed-file", action="append", default=[], help="Explicit changed file (repeatable).")
    parser.add_argument("--json", action="store_true", help="Output JSON.")
    args = parser.parse_args()

    data = yaml.safe_load(MANIFEST.read_text(encoding="utf-8"))
    adrs = data.get("adrs", [])
    adr_by_id = {a["id"]: a for a in adrs}

    changed_files = args.changed_file or git_changed_files(args.diff_range)
    changed_files = sorted(set(changed_files))

    direct: set[str] = set()
    heuristic: set[str] = set()

    for adr in adrs:
        adr_path = adr.get("path", "")
        if adr_path in changed_files:
            direct.add(adr["id"])
            continue
        tokens = normalized_tokens(adr)
        for cf in changed_files:
            c = cf.lower()
            if domain_match(c, adr) or any(tok in c for tok in tokens if len(tok) > 3):
                heuristic.add(adr["id"])
                break

    impacted = set(direct) | set(heuristic)
    frontier = list(impacted)
    while frontier:
        cur = frontier.pop(0)
        adr = adr_by_id.get(cur, {})
        for rel in REL_KEYS:
            for nxt in adr.get(rel, []) or []:
                if nxt in adr_by_id and nxt not in impacted:
                    impacted.add(nxt)
                    frontier.append(nxt)

    ordered = sorted(impacted)
    recommended_bundle_ids: set[str] = set()
    for aid in ordered:
        recommended_bundle_ids.update(bundles_for_adr(adr_by_id[aid]))
    if ordered:
        recommended_bundle_ids.add("00-foundations")
    bundle_path_by_id = {bid: bpath for bid, bpath in BUNDLES}
    recommended_bundles = [
        {"id": bid, "path": bundle_path_by_id[bid]}
        for bid in [b[0] for b in BUNDLES]
        if bid in recommended_bundle_ids
    ]
    payload = {
        "changed_files": changed_files,
        "direct": sorted(direct),
        "heuristic": sorted(heuristic),
        "impacted_adrs": ordered,
        "recommended_bundles": recommended_bundles,
    }

    if args.json:
        print(json.dumps(payload, indent=2))
        return 0

    print("# ADR Impact")
    print("")
    if changed_files:
        print("## Changed files")
        for f in changed_files:
            print(f"- `{f}`")
    else:
        print("- No changed files detected.")
    print("")
    print("## Impacted ADRs")
    if not ordered:
        print("- None")
        return 0
    for aid in ordered:
        adr = adr_by_id[aid]
        print(f"- `{aid}` {adr.get('title', aid)} ({adr.get('path', '')})")
    print("")
    print("## Recommended reading bundles")
    for b in recommended_bundles:
        print(f"- `{b['id']}` ({b['path']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
