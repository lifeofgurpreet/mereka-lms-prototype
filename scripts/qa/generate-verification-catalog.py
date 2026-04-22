#!/usr/bin/env python3
"""Generate or verify verification-suite governance catalog artifacts.

Outputs:
- verification/catalogs/verification_catalog.json
- verification/catalogs/VERIFICATION_CATALOG.md
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
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
SCRIPT_REF_PATTERN = re.compile(r"scripts/[A-Za-z0-9_./-]*verify-[A-Za-z0-9_./-]*\.sh")
SPEC_ID_PATTERN = re.compile(r"AC-[A-Z0-9-]+")
RUNTIME_DEPENDENCIES_PATTERN = re.compile(
    r"^#\s*@runtime-dependencies:\s*(?P<deps>[a-z_, -]+)\s*$",
    re.MULTILINE,
)
STATUS_OVERRIDE_KEYS = {
    "owner",
    "tier",
    "cadence",
    "severity",
    "status",
    "kind",
    "mutability",
}
ENV_SCOPE_TOKENS = ("dev", "staging", "prod", "nonprod", "preview")

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
    kind: str
    tier: str
    cadence: str
    severity: str
    mutability: str
    env_scope: list[str]
    spec_ids: list[str]
    runtime_dependencies: list[str]
    ci_entrypoints: list[str]
    canonical: bool
    replaced_by: str
    ci_binding: list[str]
    reference_count: int
    status: str


def load_status_overrides(repo_root: Path) -> dict[str, dict[str, str]]:
    overrides_path = (
        repo_root / "verification/catalogs/verification_status_overrides.json"
    )
    if not overrides_path.exists():
        return {}

    payload = json.loads(overrides_path.read_text(encoding="utf-8"))
    raw_overrides = payload.get("overrides", [])
    if not isinstance(raw_overrides, list):
        return {}

    normalized: dict[str, dict[str, str]] = {}
    for item in raw_overrides:
        if not isinstance(item, dict):
            continue
        path = item.get("path")
        if not isinstance(path, str) or not path:
            continue

        cleaned = {
            key: str(value)
            for key, value in item.items()
            if key in STATUS_OVERRIDE_KEYS and isinstance(value, str) and value
        }
        if cleaned:
            normalized[path] = cleaned
    return normalized


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


def list_tracked_paths(repo_root: Path) -> list[Path]:
    try:
        raw_paths = subprocess.run(
            ["git", "-C", str(repo_root), "ls-files", "-z"],
            check=True,
            capture_output=True,
            text=False,
        ).stdout.split(b"\0")
    except (OSError, subprocess.CalledProcessError):
        return []

    return [repo_root / raw_path.decode("utf-8") for raw_path in raw_paths if raw_path]


def discover_verify_scripts(repo_root: Path) -> list[str]:
    tracked_paths = list_tracked_paths(repo_root)
    if tracked_paths:
        candidates = tracked_paths
    else:
        candidates = list(repo_root.glob("scripts/**/verify-*.sh"))

    script_paths: list[str] = []
    for path in candidates:
        try:
            rel_path = path.relative_to(repo_root)
        except ValueError:
            continue
        if (
            len(rel_path.parts) >= 2
            and rel_path.parts[0] == "scripts"
            and rel_path.name.startswith("verify-")
            and rel_path.suffix == ".sh"
            and "deprecated" not in rel_path.parts
            and path.is_file()
        ):
            script_paths.append(str(rel_path))
    return sorted(set(script_paths))


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


def classify_kind(script_path: str) -> str:
    name = Path(script_path).name
    prefixes = (
        "verify-",
        "audit-",
        "check-",
        "run-",
        "build-",
        "generate-",
        "test-",
        "fix-",
        "sync-",
        "load-",
    )
    for prefix in prefixes:
        if name.startswith(prefix):
            return prefix.rstrip("-")
    return "script"


def classify_mutability(script_path: str, content: str) -> str:
    name = Path(script_path).name
    if name.startswith(("fix-", "repair-", "cleanup-", "load-", "sync-", "apply-", "create-", "provision-", "rollback-")):
        return "mutating"
    if re.search(r"\b(kubectl\s+(apply|delete|patch|replace)|terraform\s+apply|helm\s+upgrade|argocd\s+app\s+sync)\b", content):
        return "destructive"
    if "rm -rf" in content:
        return "mutating"
    return "read-only"


def classify_env_scope(content: str) -> list[str]:
    found = sorted({token for token in ENV_SCOPE_TOKENS if re.search(rf"\b{token}\b", content)})
    return found if found else ["global"]


def classify_runtime_dependencies(content: str) -> list[str]:
    override = RUNTIME_DEPENDENCIES_PATTERN.search(content)
    if override:
        deps = [
            item.strip()
            for item in re.split(r"[, ]+", override.group("deps"))
            if item.strip()
        ]
        allowed = {"none", "cluster", "cloud", "vendor"}
        invalid = sorted(set(deps) - allowed)
        if invalid:
            raise ValueError(
                "Invalid @runtime-dependencies value(s): "
                + ", ".join(invalid)
                + ". Allowed values: "
                + ", ".join(sorted(allowed))
            )
        if "none" in deps and len(set(deps)) > 1:
            raise ValueError("@runtime-dependencies none cannot be combined with other values")
        return sorted(set(deps))

    deps: list[str] = []
    if re.search(r"\bkubectl\b", content):
        deps.append("cluster")
    if re.search(r"\b(gcloud|aws|az)\b", content):
        deps.append("cloud")
    if re.search(r"\b(infisical|stripe|sentry|argocd)\b", content):
        deps.append("vendor")
    if not deps:
        deps.append("none")
    return deps


def load_deprecated_replacement_map(deprecated_manifest: list[dict]) -> dict[str, str]:
    replacements: dict[str, str] = {}
    for item in deprecated_manifest:
        if not isinstance(item, dict):
            continue
        path = item.get("path")
        replacement = item.get("replacement_entrypoint")
        if isinstance(path, str) and path:
            replacements[path] = replacement if isinstance(replacement, str) else ""
    return replacements


def load_basename_contracts(repo_root: Path) -> dict[str, dict]:
    allowlist_path = repo_root / "scripts/qa/fixtures/script-basename-overlap-allowlist.json"
    if not allowlist_path.exists():
        return {}
    payload = json.loads(allowlist_path.read_text(encoding="utf-8"))
    overlaps = payload.get("overlaps", [])
    if not isinstance(overlaps, list):
        return {}
    by_basename: dict[str, dict] = {}
    for item in overlaps:
        if not isinstance(item, dict):
            continue
        basename = item.get("basename")
        if isinstance(basename, str) and basename:
            by_basename[basename] = item
    return by_basename


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
    script_set = set(scripts)
    text_files: list[Path] = []
    excluded_generated = {
        repo_root / "verification/catalogs/verification_catalog.json",
        repo_root / "verification/catalogs/VERIFICATION_CATALOG.md",
    }
    excluded_dirs = {
        ".git",
        ".venv",
        "node_modules",
        "tutor_env",
        "var",
        "__pycache__",
        ".ruff_cache",
        ".pytest_cache",
        ".mypy_cache",
    }
    def should_scan(path: Path) -> bool:
        if path in excluded_generated:
            return False
        if any(part in excluded_dirs for part in path.parts):
            return False
        if not path.is_file():
            return False
        return path.suffix.lower() in TEXT_SUFFIXES or path.name == "Makefile"

    tracked_paths = list_tracked_paths(repo_root)

    if tracked_paths:
        for path in tracked_paths:
            if should_scan(path):
                text_files.append(path)
    else:
        for path in repo_root.rglob("*"):
            if should_scan(path):
                text_files.append(path)

    for file_path in text_files:
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        referenced = {
            match.group(0)
            for match in SCRIPT_REF_PATTERN.finditer(content)
            if match.group(0) in script_set
        }
        for script in referenced:
            counts[script] += 1
    return counts


def build_catalog(repo_root: Path) -> dict:
    script_paths = discover_verify_scripts(repo_root)

    deprecated_manifest_path = (
        repo_root / "verification/manifests/deprecated_verify_scripts.json"
    )
    deprecated_manifest = []
    if deprecated_manifest_path.exists():
        deprecated_manifest = json.loads(
            deprecated_manifest_path.read_text(encoding="utf-8")
        ).get("scripts", [])
    deprecated_replacements = load_deprecated_replacement_map(deprecated_manifest)
    basename_contracts = load_basename_contracts(repo_root)

    ci_static_list = repo_root / ".github/ci-scripts-static.txt"
    ci_static = set(normalize_lines(ci_static_list)) if ci_static_list.exists() else set()

    workflow_refs: set[str] = set()
    for workflow in (repo_root / ".github/workflows").glob("*.y*ml"):
        text = workflow.read_text(encoding="utf-8", errors="ignore")
        workflow_refs.update(SCRIPT_REF_PATTERN.findall(text))

    release_gate_refs: set[str] = set()
    release_gate_path = repo_root / "scripts/qa/run-release-verification-gates.sh"
    if release_gate_path.exists():
        release_gate_refs.update(
            SCRIPT_REF_PATTERN.findall(release_gate_path.read_text(encoding="utf-8", errors="ignore"))
        )

    operations_gate_refs: set[str] = set()
    operations_gate_path = repo_root / "scripts/qa/run-operations-gates.sh"
    if operations_gate_path.exists():
        operations_gate_refs.update(
            SCRIPT_REF_PATTERN.findall(operations_gate_path.read_text(encoding="utf-8", errors="ignore"))
        )

    multisite_gate_refs: set[str] = set()
    multisite_gate_path = repo_root / "scripts/qa/run-multisite-governance-gates.sh"
    if multisite_gate_path.exists():
        multisite_gate_refs.update(
            SCRIPT_REF_PATTERN.findall(multisite_gate_path.read_text(encoding="utf-8", errors="ignore"))
        )

    status_overrides = load_status_overrides(repo_root)
    reference_counts = compute_reference_counts(repo_root, script_paths)

    catalog_entries: list[dict] = []
    overrides_applied = 0
    for script_path in script_paths:
        ci_binding: list[str] = []
        if script_path in ci_static:
            ci_binding.append("ci_static")
        if script_path in workflow_refs:
            ci_binding.append("workflow_direct")
        ci_entrypoints = list(ci_binding)
        if script_path in release_gate_refs:
            ci_entrypoints.append("release_gate")
        if script_path in operations_gate_refs:
            ci_entrypoints.append("operations_gate")
        if script_path in multisite_gate_refs:
            ci_entrypoints.append("multisite_gate")
        ci_entrypoints = sorted(set(ci_entrypoints))

        tier, cadence, severity, status = classify_tier(
            script_path,
            ci_binding,
            reference_counts.get(script_path, 0),
        )

        override = status_overrides.get(script_path, {})
        if override:
            overrides_applied += 1

        content = (repo_root / script_path).read_text(encoding="utf-8", errors="ignore")
        basename_contract = basename_contracts.get(Path(script_path).name, {})
        canonical = True
        if basename_contract.get("contract_type") == "wrapper":
            canonical = basename_contract.get("canonical") == script_path
        elif basename_contract.get("contract_type") == "peer_set":
            canonical = False

        entry = ScriptMeta(
            path=script_path,
            owner=override.get("owner", classify_owner(script_path)),
            kind=override.get("kind", classify_kind(script_path)),
            tier=override.get("tier", tier),
            cadence=override.get("cadence", cadence),
            severity=override.get("severity", severity),
            mutability=override.get("mutability", classify_mutability(script_path, content)),
            env_scope=classify_env_scope(content),
            spec_ids=sorted(set(SPEC_ID_PATTERN.findall(content))),
            runtime_dependencies=classify_runtime_dependencies(content),
            ci_entrypoints=ci_entrypoints,
            canonical=canonical,
            replaced_by=deprecated_replacements.get(script_path, ""),
            ci_binding=ci_binding,
            reference_count=reference_counts.get(script_path, 0),
            status=override.get("status", status),
        )
        catalog_entries.append(
            {
                "path": entry.path,
                "owner": entry.owner,
                "kind": entry.kind,
                "tier": entry.tier,
                "cadence": entry.cadence,
                "severity": entry.severity,
                "mutability": entry.mutability,
                "env_scope": entry.env_scope,
                "spec_ids": entry.spec_ids,
                "runtime_dependencies": entry.runtime_dependencies,
                "ci_entrypoints": entry.ci_entrypoints,
                "canonical": entry.canonical,
                "replaced_by": entry.replaced_by,
                "ci_binding": entry.ci_binding,
                "reference_count": entry.reference_count,
                "status": entry.status,
            }
        )

    by_tier: dict[str, int] = {}
    by_status: dict[str, int] = {}
    by_kind: dict[str, int] = {}
    by_mutability: dict[str, int] = {}
    for item in catalog_entries:
        by_tier[item["tier"]] = by_tier.get(item["tier"], 0) + 1
        by_status[item["status"]] = by_status.get(item["status"], 0) + 1
        by_kind[item["kind"]] = by_kind.get(item["kind"], 0) + 1
        by_mutability[item["mutability"]] = by_mutability.get(item["mutability"], 0) + 1

    return {
        "version": "1",
        "generated_from": "scripts/qa/generate-verification-catalog.py",
        "entrypoints": ENTRYPOINTS,
        "summary": {
            "total_verify_scripts": len(catalog_entries),
            "archived_deprecated_scripts": len(deprecated_manifest),
            "tiers": by_tier,
            "statuses": by_status,
            "kinds": by_kind,
            "mutability": by_mutability,
            "ci_static_bound": sum(1 for x in catalog_entries if "ci_static" in x["ci_binding"]),
            "workflow_direct_bound": sum(
                1 for x in catalog_entries if "workflow_direct" in x["ci_binding"]
            ),
            "status_overrides_applied": overrides_applied,
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
        "Machine-readable source: `verification/catalogs/verification_catalog.json`.",
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
            f"- Status overrides applied: **{summary['status_overrides_applied']}**",
            "",
            "### Tier Distribution",
        ]
    )
    for tier, count in sorted(summary["tiers"].items()):
        lines.append(f"- `{tier}`: {count}")

    lines.extend(["", "### Status Distribution"])
    for status, count in sorted(summary["statuses"].items()):
        lines.append(f"- `{status}`: {count}")

    lines.extend(["", "### Kind Distribution"])
    for kind, count in sorted(summary.get("kinds", {}).items()):
        lines.append(f"- `{kind}`: {count}")

    lines.extend(["", "### Mutability Distribution"])
    for mutability, count in sorted(summary.get("mutability", {}).items()):
        lines.append(f"- `{mutability}`: {count}")

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

    json_path = repo_root / "verification/catalogs/verification_catalog.json"
    md_path = repo_root / "verification/catalogs/VERIFICATION_CATALOG.md"

    json_payload = json.dumps(catalog, indent=2, sort_keys=True) + "\n"
    md_payload = render_markdown(catalog)

    changed_outputs: list[str] = []
    current_json = json_path.read_text(encoding="utf-8") if json_path.exists() else ""
    current_md = md_path.read_text(encoding="utf-8") if md_path.exists() else ""
    if current_json != json_payload:
        changed_outputs.append(str(json_path.relative_to(repo_root)))
    if current_md != md_payload:
        changed_outputs.append(str(md_path.relative_to(repo_root)))

    if args.check:
      if changed_outputs:
        print("Verification catalog drift detected.")
        print("Changed files:")
        for item in changed_outputs:
            print(f"- {item}")
        print("Run: python3 scripts/qa/generate-verification-catalog.py")
        return 1
      print("Verification catalog is up to date.")
      return 0

    changed_json = write_if_changed(json_path, json_payload)
    changed_md = write_if_changed(md_path, md_payload)

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
