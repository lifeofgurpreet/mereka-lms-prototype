#!/usr/bin/env python3
"""Generate a machine-readable governance census for tracked scripts."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import Counter, defaultdict
from datetime import UTC, datetime
from pathlib import Path

SCRIPT_SUFFIXES = {".sh", ".py"}
TEXT_SUFFIXES = {
    ".md",
    ".txt",
    ".json",
    ".yml",
    ".yaml",
    ".sh",
    ".py",
    ".env",
}
SCRIPT_REF_PATTERN = re.compile(r"(scripts/[A-Za-z0-9_./-]+\.(?:sh|py))")
EXCLUDED_REFERENCE_PREFIXES = (
    "scripts/qa/fixtures/",
    "docs/archive/",
    "var/",
    ".beads/",
)

READ_ONLY_PREFIXES = (
    "verify-",
    "audit-",
    "check-",
    "scan-",
    "lint-",
    "validate-",
    "list-",
    "test-",
)
MUTATING_PREFIXES = (
    "fix-",
    "repair-",
    "sync-",
    "apply-",
    "create-",
    "provision-",
    "bootstrap-",
    "import-",
    "export-",
    "deploy-",
    "release-",
    "promote-",
    "rollback-",
    "offboard-",
    "onboard-",
)
DESTRUCTIVE_TOKENS = ("delete", "purge", "drop", "truncate", "prune", "retire")
RUNTIME_DEPENDENCIES = (
    ("kubectl", "kubernetes"),
    ("terraform", "terraform"),
    ("helm", "helm"),
    ("argocd", "argocd"),
    ("gcloud", "gcp"),
    ("aws ", "aws"),
    ("docker", "docker"),
    ("tutor ", "tutor"),
    ("velero", "velero"),
)
ENV_SCOPE_KEYS = {
    "prod": ("prod", "production"),
    "staging": ("staging",),
    "dev": ("dev", "development"),
    "nonprod": ("nonprod",),
    "preview": ("preview",),
    "local": ("local", "localhost", "kind"),
}


def git_repo_root() -> Path:
    out = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"],
        text=True,
    ).strip()
    return Path(out)


def git_ls_files(repo_root: Path, scope: str | None = None) -> list[str]:
    cmd = ["git", "-C", str(repo_root), "ls-files"]
    if scope:
        cmd.append(scope)
    out = subprocess.check_output(cmd, text=True)
    return [line.strip() for line in out.splitlines() if line.strip()]


def load_tracked_scripts(repo_root: Path) -> list[str]:
    scripts: list[str] = []
    for rel in git_ls_files(repo_root, "scripts"):
        suffix = Path(rel).suffix.lower()
        if suffix in SCRIPT_SUFFIXES and (repo_root / rel).is_file():
            scripts.append(rel)
    return sorted(set(scripts))


def text_files_for_reference_scan(repo_root: Path) -> list[str]:
    files: list[str] = []
    for rel in git_ls_files(repo_root):
        if any(rel.startswith(prefix) for prefix in EXCLUDED_REFERENCE_PREFIXES):
            continue
        path = Path(rel)
        if path.name == "Makefile" or path.suffix.lower() in TEXT_SUFFIXES:
            files.append(rel)
    return files


def classify_kind(script_path: str) -> str:
    name = Path(script_path).name.lower()
    for prefix, kind in (
        ("verify-", "verify"),
        ("audit-", "audit"),
        ("check-", "check"),
        ("run-", "run"),
        ("build-", "build"),
        ("generate-", "generate"),
        ("fix-", "fix"),
        ("repair-", "repair"),
        ("sync-", "sync"),
        ("migrate-", "migrate"),
    ):
        if name.startswith(prefix):
            return kind
    return "other"


def classify_mutability(script_path: str, content: str) -> str:
    name = Path(script_path).name.lower()
    lowered = content.lower()
    if "/lib/" in script_path or name.startswith("test-"):
        return "read_only"
    if any(token in name for token in DESTRUCTIVE_TOKENS):
        return "destructive"
    if name.startswith(READ_ONLY_PREFIXES):
        return "read_only"
    if name.startswith(MUTATING_PREFIXES):
        return "mutating"
    if script_path.endswith(".py"):
        return "unknown"
    if "kubectl delete" in lowered or "rm -rf" in lowered:
        return "destructive"
    if any(token in lowered for token in ("kubectl apply", "terraform apply", "argocd app sync")):
        return "mutating"
    return "unknown"


def infer_env_scope(content: str) -> list[str]:
    lowered = content.lower()
    scopes: set[str] = set()
    for scope, needles in ENV_SCOPE_KEYS.items():
        if any(needle in lowered for needle in needles):
            scopes.add(scope)
    if not scopes:
        scopes.add("global")
    return sorted(scopes)


def infer_runtime_dependencies(content: str) -> list[str]:
    lowered = content.lower()
    deps = {name for token, name in RUNTIME_DEPENDENCIES if token in lowered}
    return sorted(deps)


def infer_callers(script_path: str, refs: list[str], ci_static_members: set[str]) -> dict[str, list[str]]:
    buckets: dict[str, list[str]] = defaultdict(list)
    for ref in refs:
        if ref.startswith(".github/workflows/"):
            buckets["ci_workflow"].append(ref)
        elif ref == "Makefile" or ref.startswith("makefile"):
            buckets["makefile"].append(ref)
        elif ref.startswith("scripts/"):
            buckets["script"].append(ref)
        elif ref.startswith("docs/"):
            buckets["docs"].append(ref)
        elif ref.startswith("deploy/") or ref.startswith("infrastructure/"):
            buckets["infra"].append(ref)
        elif ref.startswith(".github/"):
            buckets["github"].append(ref)
        else:
            buckets["other"].append(ref)
    if script_path in ci_static_members:
        buckets["ci_static_contract"].append(".github/ci-scripts-static.txt")
    return {key: sorted(set(value)) for key, value in buckets.items()}


def classify_status(script_path: str, callers: dict[str, list[str]]) -> str:
    name = Path(script_path).name
    if "/lib/" in script_path:
        return "supporting_library"
    if name.startswith("test-"):
        return "test_support"
    if callers.get("ci_workflow") or callers.get("ci_static_contract"):
        return "active_authoritative"
    if callers:
        return "active_manual"
    return "orphan_candidate"


def classify_risk(mutability: str, env_scope: list[str], status: str) -> str:
    if status in {"supporting_library", "test_support"}:
        return "low"
    if mutability == "destructive":
        return "critical"
    if mutability == "mutating" and any(scope in env_scope for scope in ("prod", "staging", "nonprod")):
        return "high"
    if mutability == "mutating":
        return "medium"
    if mutability == "unknown":
        return "medium"
    return "low"


def render_summary_markdown(catalog: dict) -> str:
    summary = catalog["summary"]
    lines = [
        "# Script Governance Census",
        "",
        f"- Generated at: `{catalog['generated_at']}`",
        f"- Total scripts: **{summary['total_scripts']}**",
        f"- Active authoritative: **{summary['statuses'].get('active_authoritative', 0)}**",
        f"- Active manual: **{summary['statuses'].get('active_manual', 0)}**",
        f"- Orphan candidates: **{summary['statuses'].get('orphan_candidate', 0)}**",
        f"- Dangerous (high/critical): **{summary['dangerous_scripts']}**",
        "",
        "## Top Orphan Candidates",
    ]
    for path in catalog["orphan_candidates"][:50]:
        lines.append(f"- `{path}`")
    lines.extend(["", "## Top Dangerous Scripts"])
    for path in catalog["dangerous_scripts"][:50]:
        lines.append(f"- `{path}`")
    lines.append("")
    return "\n".join(lines)


def build_catalog(repo_root: Path) -> dict:
    scripts = load_tracked_scripts(repo_root)
    text_files = text_files_for_reference_scan(repo_root)
    script_set = set(scripts)
    references: dict[str, set[str]] = {script: set() for script in scripts}

    for rel in text_files:
        path = repo_root / rel
        try:
            content = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for match in SCRIPT_REF_PATTERN.findall(content):
            if match in script_set and match != rel:
                references[match].add(rel)

    ci_static_members = set()
    ci_static_path = repo_root / ".github/ci-scripts-static.txt"
    if ci_static_path.exists():
        for line in ci_static_path.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            ci_static_members.add(stripped.split()[0])

    entries: list[dict] = []
    for script_path in scripts:
        content = (repo_root / script_path).read_text(encoding="utf-8", errors="ignore")
        kind = classify_kind(script_path)
        mutability = classify_mutability(script_path, content)
        env_scope = infer_env_scope(content)
        callers = infer_callers(
            script_path=script_path,
            refs=sorted(references.get(script_path, set())),
            ci_static_members=ci_static_members,
        )
        status = classify_status(script_path, callers)
        risk = classify_risk(mutability, env_scope, status)
        supports_dry_run = ("--dry-run" in content) or ("DRY_RUN" in content)
        idempotence_signal = (
            "declared"
            if ("idempotent" in content.lower() or "idempotency" in content.lower())
            else ("dry_run_supported" if supports_dry_run else "unknown")
        )

        entries.append(
            {
                "path": script_path,
                "kind": kind,
                "mutability": mutability,
                "status": status,
                "risk_level": risk,
                "env_scope": env_scope,
                "supports_dry_run": supports_dry_run,
                "idempotence_signal": idempotence_signal,
                "runtime_dependencies": infer_runtime_dependencies(content),
                "caller_types": sorted(callers.keys()),
                "callers": callers,
                "total_references": sum(len(v) for v in callers.values()),
            }
        )

    by_kind = Counter(item["kind"] for item in entries)
    by_mutability = Counter(item["mutability"] for item in entries)
    by_status = Counter(item["status"] for item in entries)
    by_risk = Counter(item["risk_level"] for item in entries)

    orphan_candidates = sorted(
        item["path"] for item in entries if item["status"] == "orphan_candidate"
    )
    dangerous_scripts = sorted(
        item["path"] for item in entries if item["risk_level"] in {"high", "critical"}
    )

    return {
        "version": "1",
        "generated_at": datetime.now(UTC).isoformat(),
        "generated_from": "scripts/qa/generate-script-governance-catalog.py",
        "summary": {
            "total_scripts": len(entries),
            "kinds": dict(sorted(by_kind.items())),
            "mutability": dict(sorted(by_mutability.items())),
            "statuses": dict(sorted(by_status.items())),
            "risks": dict(sorted(by_risk.items())),
            "orphan_candidates": len(orphan_candidates),
            "dangerous_scripts": len(dangerous_scripts),
        },
        "orphan_candidates": orphan_candidates,
        "dangerous_scripts": dangerous_scripts,
        "scripts": sorted(entries, key=lambda item: item["path"]),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=git_repo_root(),
        help="Repository root (defaults to git toplevel).",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("var/evidence/script-governance/latest/script_governance_catalog.json"),
        help="Output JSON path.",
    )
    parser.add_argument(
        "--summary-out",
        type=Path,
        default=Path("var/evidence/script-governance/latest/summary.md"),
        help="Output summary markdown path.",
    )
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    catalog = build_catalog(repo_root)

    out_path = args.out
    if not out_path.is_absolute():
        out_path = repo_root / out_path
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")

    summary_path = args.summary_out
    if not summary_path.is_absolute():
        summary_path = repo_root / summary_path
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(render_summary_markdown(catalog), encoding="utf-8")

    print(f"Wrote catalog: {out_path}")
    print(f"Wrote summary: {summary_path}")
    print(
        "Totals:",
        f"scripts={catalog['summary']['total_scripts']}",
        f"orphans={catalog['summary']['orphan_candidates']}",
        f"dangerous={catalog['summary']['dangerous_scripts']}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
