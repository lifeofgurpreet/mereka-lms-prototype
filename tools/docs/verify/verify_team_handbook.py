#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
HANDBOOK_ROOT = REPO_ROOT / "docs/guides/platform"
REFERENCE_ROOT = REPO_ROOT / "docs/reference/platform"
GENERATED_ROOT = REPO_ROOT / "generated/platform"

REQUIRED_HANDBOOK_PAGES = [
    HANDBOOK_ROOT / "PLATFORM_START_HERE.md",
    HANDBOOK_ROOT / "OPENEDX_FOR_TEAM_MEMBERS.md",
    HANDBOOK_ROOT / "COURSE_AUTHORING_QUICKSTART.md",
    HANDBOOK_ROOT / "OPENEDX_SETTINGS_MATRIX.md",
    HANDBOOK_ROOT / "MULTI_TENANCY_EXPLAINED.md",
    HANDBOOK_ROOT / "SUPPORT_AND_ESCALATION.md",
    HANDBOOK_ROOT / "SOURCE_MAP.md",
]

REQUIRED_GENERATED_DOCS = [
    REFERENCE_ROOT / "DOMAIN_AND_ACCESS_REFERENCE.md",
    REFERENCE_ROOT / "TEAM_TOPOLOGY_REFERENCE.md",
]

REQUIRED_GENERATED_JSON = [
    GENERATED_ROOT / "domain-access-reference.json",
    GENERATED_ROOT / "team-topology-reference.json",
]

REQUIRED_FOOTER_FIELDS = [
    "Canonical internal sources",
    "Official external references",
    "Owner",
    "Last reviewed",
    "Applies to",
    "What is tenant-specific",
    "What is platform-wide",
    "What must be escalated",
]

PRIMARY_SURFACE_REQUIREMENTS = {
    "PLATFORM_START_HERE.md": ["../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md", "../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md"],
    "OPENEDX_FOR_TEAM_MEMBERS.md": ["../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md", "../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md"],
    "COURSE_AUTHORING_QUICKSTART.md": ["../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md"],
    "OPENEDX_SETTINGS_MATRIX.md": ["../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md"],
    "MULTI_TENANCY_EXPLAINED.md": ["../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md", "../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md"],
    "SUPPORT_AND_ESCALATION.md": ["../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md", "../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md"],
}

TRANSITIONAL_PREFIXES = (
    "docs/archive/",
    "docs/operations/",
    "docs/onboarding/",
    "docs/branding/",
    "docs/runbooks/",
    "docs/architecture/",
)
LEGACY_MARKERS = ("legacy", "historical", "superseded", "archive", "transitional")
BACKTICK_PATH_RE = re.compile(r"`([^`]+)`")

EXTERNAL_ROOTS = {
    "bbi-infrastructure/": Path("/home/gurpreet/projects/k8s/bbi-infrastructure"),
    "platform-control-plane/": Path("/home/gurpreet/projects/platform-control-plane"),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify the Wave 14 team handbook structure and drift rules.")
    parser.add_argument("--repo-root", default=str(REPO_ROOT))
    return parser.parse_args()


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def run_check(command: list[str], repo_root: Path) -> None:
    subprocess.run(command, cwd=repo_root, check=True)


def verify_required_pages() -> None:
    for path in REQUIRED_HANDBOOK_PAGES + REQUIRED_GENERATED_DOCS + REQUIRED_GENERATED_JSON:
        ensure(path.exists(), f"Missing required handbook surface: {path.relative_to(REPO_ROOT)}")


def verify_footer_blocks() -> None:
    for path in REQUIRED_HANDBOOK_PAGES:
        if path.name == "SOURCE_MAP.md":
            continue
        text = path.read_text()
        ensure("## Metadata" in text, f"Handbook page missing metadata footer section: {path.relative_to(REPO_ROOT)}")
        for field in REQUIRED_FOOTER_FIELDS:
            ensure(f"- {field}:" in text, f"Handbook page missing footer field '{field}': {path.relative_to(REPO_ROOT)}")


def verify_generated_markdown_banners() -> None:
    for path in REQUIRED_GENERATED_DOCS:
        text = path.read_text()
        ensure(text.startswith("<!-- Generated file. Do not hand-edit. -->"), f"Generated reference missing banner: {path.relative_to(REPO_ROOT)}")


def verify_required_reference_links() -> None:
    for filename, required_links in PRIMARY_SURFACE_REQUIREMENTS.items():
        text = (HANDBOOK_ROOT / filename).read_text()
        for link in required_links:
            ensure(link in text, f"Handbook page missing required generated-reference link '{link}': docs/guides/platform/{filename}")


def verify_transitional_links() -> None:
    for path in REQUIRED_HANDBOOK_PAGES:
        text = path.read_text()
        for line in text.splitlines():
            for prefix in TRANSITIONAL_PREFIXES:
                if prefix in line:
                    lowered = line.lower()
                    ensure(
                        any(marker in lowered for marker in LEGACY_MARKERS),
                        f"Handbook page uses transitional/archive path as primary surface: {path.relative_to(REPO_ROOT)} :: {line.strip()}",
                    )


def resolve_source_map_path(raw: str) -> Path | None:
    if raw.startswith("docs/") or raw.startswith("generated/") or raw.startswith("tools/") or raw.startswith("scripts/"):
        return REPO_ROOT / raw
    for prefix, root in EXTERNAL_ROOTS.items():
        if raw.startswith(prefix):
            return root / raw[len(prefix) :]
    return None


def verify_source_map_paths() -> None:
    text = (HANDBOOK_ROOT / "SOURCE_MAP.md").read_text()
    checked = 0
    for raw in BACKTICK_PATH_RE.findall(text):
        candidate = resolve_source_map_path(raw)
        if candidate is None:
            continue
        checked += 1
        ensure(candidate.exists(), f"Dead SOURCE_MAP path: {raw}")
    ensure(checked > 0, "SOURCE_MAP path scan found no resolvable paths")


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    ensure(repo_root == REPO_ROOT.resolve(), f"verify_team_handbook.py expects repo root {REPO_ROOT}")

    verify_required_pages()
    verify_footer_blocks()
    verify_generated_markdown_banners()
    verify_required_reference_links()
    verify_transitional_links()
    verify_source_map_paths()

    run_check(["python3", "tools/docs/build_domain_access_reference.py", "--check", "--repo-root", "."], repo_root)
    run_check(["python3", "tools/docs/build_team_topology_reference.py", "--check", "--repo-root", "."], repo_root)

    print(
        "TEAM_HANDBOOK_OK "
        f"pages={len(REQUIRED_HANDBOOK_PAGES)} generated_docs={len(REQUIRED_GENERATED_DOCS)} generated_json={len(REQUIRED_GENERATED_JSON)}"
    )


if __name__ == "__main__":
    main()
