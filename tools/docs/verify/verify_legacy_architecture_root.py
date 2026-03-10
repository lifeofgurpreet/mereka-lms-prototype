#!/usr/bin/env python3
"""Verify docs/architecture is retired and not used as a living root."""

from __future__ import annotations

import argparse
from pathlib import Path


ALLOWED_FILE = "docs/architecture/README.md"
EXEMPT_REFERENCERS = {
    "docs/README.md",
    "docs/CONTRIBUTING.md",
    "docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md",
    "docs/guides/standards/DOCUMENTATION_STANDARDS.md",
    "docs/meta/docs-program/REPO_TOPOLOGY_MOVE_LEDGER.md",
    "docs/concepts/architecture/README.md",
    "docs/concepts/architecture/ARCHITECTURE_CHARTER.md",
    "docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md",
    "docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_TRACKER.md",
    "docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_CLOSEOUT.md",
    "docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_REVIEW_HANDOFF.md",
    "docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md",
    "docs/meta/skills/SKILL_RUNTIME_MODEL.yaml",
    "scripts/qa/verify-architecture-doc-path-drift.sh",
    "scripts/qa/test-verify-architecture-doc-path-drift.sh",
    "scripts/qa/verify-theming-generated-artifacts.sh",
    "scripts/qa/verify-superset-runbook.sh",
    "tools/docs/verify/verify-stub-only-transitional-dirs.py",
    "tools/docs/verify/verify-stub-only-transitional-dirs-test.sh",
    "tools/docs/verify/report-nonstub-transitional-files-test.sh",
    "tools/docs/verify/verify-docs-policy.sh",
    "tools/docs/verify/verify_legacy_architecture_root.py",
    "tools/docs/verify/verify_team_handbook.py",
    "tools/skills/verify_agent_pack_schemas.py",
    "tools/skills/verify_skill_runtime.py",
    "tools/skills/verify_agent_pack_runtime.py",
    "tools/skills/build_skill_dependency_graph.py",
}


def iter_text_files(repo_root: Path) -> list[Path]:
    roots = [repo_root / "docs", repo_root / "specs", repo_root / "scripts", repo_root / "deploy", repo_root / "tools"]
    files: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() not in {".md", ".py", ".sh", ".yaml", ".yml", ".json", ".txt", ".tsv"}:
                continue
            rel = path.relative_to(repo_root).as_posix()
            if rel.startswith(
                (
                    "docs/archive/",
                    "docs/evidence/",
                    "docs/status/",
                    "docs/meta/docs-program/root-collapse/",
                    "specs/archive/",
                    "scripts/qa/deprecated/",
                    "generated/",
                )
            ):
                continue
            files.append(path)
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    architecture_root = repo_root / "docs" / "architecture"
    errors: list[str] = []

    if architecture_root.exists():
        for path in sorted(architecture_root.rglob("*")):
            if path.is_dir():
                continue
            rel = path.relative_to(repo_root).as_posix()
            if rel != ALLOWED_FILE:
                errors.append(f"retired root contains non-tombstone file: {rel}")

    for path in iter_text_files(repo_root):
        rel = path.relative_to(repo_root).as_posix()
        if rel.startswith("docs/architecture/"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "docs/architecture/" not in text:
            continue
        if rel in EXEMPT_REFERENCERS:
            continue
        stripped = text.replace("docs/architecture/README.md", "")
        if "docs/architecture/" not in stripped:
            continue
        errors.append(f"active file still references retired architecture root: {rel}")

    if errors:
        print("LEGACY_ARCHITECTURE_ROOT_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    state = "removed" if not architecture_root.exists() else "tombstone_only"
    print(f"LEGACY_ARCHITECTURE_ROOT_OK state={state}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
