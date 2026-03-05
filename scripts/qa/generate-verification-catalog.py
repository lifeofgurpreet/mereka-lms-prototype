#!/usr/bin/env python3
"""Generate or verify verification-suite governance catalog artifacts.

Outputs:
- docs/operations/verification/verification_catalog.json
- docs/operations/verification/VERIFICATION_CATALOG.md
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path

TEXT_SUFFIXES = {
    ".md",
    ".yml",
    ".yaml",
    ".sh",
    ".py",
    ".json",
    ".txt",
}

ENTRYPOINTS = [
    {
        "name": "Static release-blocking gates",
        "entrypoint": "scripts/qa/run-release-verification-gates.sh",
        "scope": "PR + push static verification suite from .github/ci-scripts-static.txt",
    },
    {
        "name": "Operations runtime gates",
        "entrypoint": "scripts/qa/run-operations-gates.sh",
        "scope": "Consolidated runtime governance gate (auth, multisite, observability, backups)",
    },
    {
        "name": "Multisite runtime gates",
        "entrypoint": "scripts/qa/run-multisite-governance-gates.sh",
        "scope": "Tenant/multisite runtime governance checks",
    },
]


@dataclass(frozen=True)
class ScriptMeta:
    path: str
    owner: str
    tier: str
    cadence: str
    severity: str
    ci_binding: list[str]
    reference_count: int
    status: str


def normalize_lines(path: Path) -> list[str]:
    lines: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        clean = stripped.split(" #", 1)[0].strip()
        if not clean:
            continue
        lines.append(clean.split()[0])
    return sorted(set(lines))


def classify_owner(script_path: str) -> str:
    name = Path(script_path).name
    joined = f"{script_path} {name}".lower()
    if any(k in joined for k in ["token", "branding", "paragon", "mfe", "a11y", "ux", "ui"]):
        return "frontend-platform"
    if any(k in joined for k in ["auth", "oidc", "sso", "jwt", "csrf", "oauth"]):
        return "identity-access"
    if any(k in joined for k in ["tenant", "multisite", "enterprise", "site-"]):
        return "multisite-governance"
    if any(k in joined for k in ["k8s", "gitops", "deploy", "argo", "atlas", "velero", "tutor", "infra"]):
        return "platform-infra"
    if any(k in joined for k in ["observability", "sentry", "slo", "alert", "dr", "security", "secret"]):
        return "sre-security"
    if any(k in joined for k in ["migration", "kajabi", "mct", "video"]):
        return "migration-platform"
    return "platform-core"


def classify_tier(path: str, ci_binding: list[str], reference_count: int) -> tuple[str, str, str, str]:
    lowered = path.lower()
    if ci_binding:
        return "release_blocking", "per_pr_and_push", "high", "active"

    runtime_hint = any(
        key in lowered
        for key in ["runtime", "public", "post-deploy", "operations", "rollout", "smoke"]
    )
    if runtime_hint:
        return "periodic_runtime", "scheduled_or_post_deploy", "medium", "active"

    if reference_count <= 1:
        return "exploratory_manual", "on_demand", "low", "deprecated_candidate"

    return "exploratory_manual", "on_demand", "low", "manual_only"


def compute_reference_counts(repo_root: Path, scripts: list[str]) -> dict[str, int]:
    counts = dict.fromkeys(scripts, 0)
    text_files: list[Path] = []
    excluded_generated = {
        repo_root / "docs/operations/verification/verification_catalog.json",
        repo_root / "docs/operations/verification/VERIFICATION_CATALOG.md",
    }
    for path in repo_root.rglob("*"):
        if not path.is_file():
            continue
        if path in excluded_generated:
            continue
        if any(part in {".git", "node_modules", "tutor_env", "var"} for part in path.parts):
            continue
        if path.suffix.lower() in TEXT_SUFFIXES or path.name == "Makefile":
            text_files.append(path)

    for file_path in text_files:
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for script in scripts:
            if script in content:
                counts[script] += 1
    return counts


def build_catalog(repo_root: Path) -> dict:
    script_paths = sorted(
        str(path.relative_to(repo_root))
        for path in repo_root.glob("scripts/**/verify-*.sh")
        if path.is_file()
        and "deprecated" not in path.parts
    )

    deprecated_manifest_path = (
        repo_root / "docs/operations/verification/deprecated_verify_scripts.json"
    )
    deprecated_manifest = []
    if deprecated_manifest_path.exists():
        deprecated_manifest = json.loads(
            deprecated_manifest_path.read_text(encoding="utf-8")
        ).get("scripts", [])

    ci_static_list = repo_root / ".github/ci-scripts-static.txt"
    ci_static = set(normalize_lines(ci_static_list)) if ci_static_list.exists() else set()

    workflow_refs: set[str] = set()
    workflow_pattern = re.compile(r"scripts/[A-Za-z0-9_./-]*verify-[A-Za-z0-9_./-]*\.sh")
    for workflow in (repo_root / ".github/workflows").glob("*.y*ml"):
        text = workflow.read_text(encoding="utf-8", errors="ignore")
        workflow_refs.update(workflow_pattern.findall(text))

    reference_counts = compute_reference_counts(repo_root, script_paths)

    catalog_entries: list[dict] = []
    for script_path in script_paths:
        ci_binding: list[str] = []
        if script_path in ci_static:
            ci_binding.append("ci_static")
        if script_path in workflow_refs:
            ci_binding.append("workflow_direct")

        tier, cadence, severity, status = classify_tier(
            script_path,
            ci_binding,
            reference_counts.get(script_path, 0),
        )

        entry = ScriptMeta(
            path=script_path,
            owner=classify_owner(script_path),
            tier=tier,
            cadence=cadence,
            severity=severity,
            ci_binding=ci_binding,
            reference_count=reference_counts.get(script_path, 0),
            status=status,
        )
        catalog_entries.append(
            {
                "path": entry.path,
                "owner": entry.owner,
                "tier": entry.tier,
                "cadence": entry.cadence,
                "severity": entry.severity,
                "ci_binding": entry.ci_binding,
                "reference_count": entry.reference_count,
                "status": entry.status,
            }
        )

    by_tier: dict[str, int] = {}
    by_status: dict[str, int] = {}
    for item in catalog_entries:
        by_tier[item["tier"]] = by_tier.get(item["tier"], 0) + 1
        by_status[item["status"]] = by_status.get(item["status"], 0) + 1

    return {
        "version": "1",
        "generated_from": "scripts/qa/generate-verification-catalog.py",
        "entrypoints": ENTRYPOINTS,
        "summary": {
            "total_verify_scripts": len(catalog_entries),
            "archived_deprecated_scripts": len(deprecated_manifest),
            "tiers": by_tier,
            "statuses": by_status,
            "ci_static_bound": sum(1 for x in catalog_entries if "ci_static" in x["ci_binding"]),
            "workflow_direct_bound": sum(
                1 for x in catalog_entries if "workflow_direct" in x["ci_binding"]
            ),
        },
        "scripts": catalog_entries,
        "deprecated_archive": deprecated_manifest,
    }


def render_markdown(catalog: dict) -> str:
    summary = catalog["summary"]
    deprecated = [x for x in catalog["scripts"] if x["status"] == "deprecated_candidate"]

    lines = [
        "# Verification Catalog",
        "",
        "Machine-readable source: `docs/operations/verification/verification_catalog.json`.",
        "",
        "## Core Entrypoints",
    ]
    for item in catalog["entrypoints"]:
        lines.append(
            f"- `{item['entrypoint']}` — **{item['name']}**: {item['scope']}"
        )

    lines.extend(
        [
            "",
            "## Summary",
            f"- Total `verify-*.sh` scripts: **{summary['total_verify_scripts']}**",
            f"- Archived deprecated scripts: **{summary['archived_deprecated_scripts']}**",
            f"- CI static-bound scripts: **{summary['ci_static_bound']}**",
            f"- Workflow-direct bound scripts: **{summary['workflow_direct_bound']}**",
            "",
            "### Tier Distribution",
        ]
    )
    for tier, count in sorted(summary["tiers"].items()):
        lines.append(f"- `{tier}`: {count}")

    lines.extend(["", "### Status Distribution"])
    for status, count in sorted(summary["statuses"].items()):
        lines.append(f"- `{status}`: {count}")

    lines.extend(["", "## Deprecated Candidates", ""])
    if not deprecated:
        lines.append("- None")
    else:
        lines.append("Scripts currently not CI-bound and with near-zero references:")
        for item in deprecated:
            lines.append(
                f"- `{item['path']}` (owner: `{item['owner']}`, refs: {item['reference_count']})"
            )

    lines.extend(["", "## Archived Deprecated Scripts", ""])
    archived = catalog.get("deprecated_archive", [])
    if not archived:
        lines.append("- None")
    else:
        for item in archived:
            lines.append(
                f"- `{item['path']}` → `{item['replacement_entrypoint']}` ({item['reason']})"
            )

    lines.extend(
        [
            "",
            "## Lifecycle Policy",
            "- `release_blocking`: MUST stay bound to CI static or direct workflow execution.",
            "- `periodic_runtime`: SHOULD run via scheduled/runtime gates (`run-operations-gates.sh`, multisite gates).",
            "- `exploratory_manual`: MAY run on-demand; candidates can be deprecated or archived once replacement exists.",
        ]
    )
    return "\n".join(lines) + "\n"


def write_if_changed(path: Path, content: str) -> bool:
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if generated files are stale")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    catalog = build_catalog(repo_root)

    json_path = repo_root / "docs/operations/verification/verification_catalog.json"
    md_path = repo_root / "docs/operations/verification/VERIFICATION_CATALOG.md"

    json_payload = json.dumps(catalog, indent=2, sort_keys=True) + "\n"
    md_payload = render_markdown(catalog)

    changed_json = write_if_changed(json_path, json_payload)
    changed_md = write_if_changed(md_path, md_payload)

    if args.check:
      if changed_json or changed_md:
        print("Verification catalog drift detected.")
        print("Run: python3 scripts/qa/generate-verification-catalog.py")
        return 1
      print("Verification catalog is up to date.")
      return 0

    updated = []
    if changed_json:
      updated.append(str(json_path.relative_to(repo_root)))
    if changed_md:
      updated.append(str(md_path.relative_to(repo_root)))

    if updated:
      print("Updated:")
      for item in updated:
        print(f"- {item}")
    else:
      print("No changes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
