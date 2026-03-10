#!/usr/bin/env python3
"""Verify docs/branding is retired and not used as a living root."""

from __future__ import annotations

import argparse
from pathlib import Path


ALLOWED_FILE = "docs/branding/README.md"
EXEMPT_REFERENCERS = {
    "docs/README.md",
    "docs/CONTRIBUTING.md",
    "docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md",
    "docs/guides/README.md",
    "docs/guides/branding/README.md",
    "docs/guides/standards/DOCUMENTATION_STANDARDS.md",
    "docs/meta/docs-program/REPO_TOPOLOGY_MOVE_LEDGER.md",
    "docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_TRACKER.md",
    "docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_CLOSEOUT.md",
    "docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_REVIEW_HANDOFF.md",
    "docs/meta/docs-program/root-collapse/docs-branding-collapse-map.yaml",
    "docs/concepts/architecture/README.md",
    "docs/concepts/architecture/ARCHITECTURE_CHARTER.md",
    "docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md",
    "docs/status/migrations/2026-03-wave-2b-final-closeout.md",
    "docs/evidence/operations/2026-03-wave-2b-final-closeout/README.md",
    "tools/docs/verify/verify-stub-only-transitional-dirs.py",
    "tools/docs/verify/verify-docs-policy.sh",
    "tools/docs/verify/verify_legacy_branding_root.py",
    "tools/docs/verify/verify_team_handbook.py",
}


def iter_text_files(repo_root: Path) -> list[Path]:
    roots = [
        repo_root / "docs",
        repo_root / "specs",
        repo_root / "scripts",
        repo_root / "deploy",
        repo_root / "tools",
        repo_root / "infrastructure",
        repo_root / ".github",
    ]
    files: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() not in {".md", ".py", ".sh", ".yaml", ".yml", ".json", ".txt"}:
                continue
            rel = path.relative_to(repo_root).as_posix()
            if rel.startswith(("docs/archive/", "docs/meta/docs-program/root-collapse/", "generated/")):
                continue
            files.append(path)
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    branding_root = repo_root / "docs" / "branding"
    errors: list[str] = []

    if branding_root.exists():
        for path in sorted(branding_root.rglob("*")):
            if path.is_dir():
                continue
            rel = path.relative_to(repo_root).as_posix()
            if rel != ALLOWED_FILE:
                errors.append(f"retired root contains non-tombstone file: {rel}")

    for path in iter_text_files(repo_root):
        rel = path.relative_to(repo_root).as_posix()
        if rel.startswith("docs/branding/"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "docs/branding/" not in text:
            continue
        if rel in EXEMPT_REFERENCERS:
            continue
        stripped = text.replace("docs/guides/branding/README.md", "")
        if "docs/branding/" not in stripped:
            continue
        errors.append(f"active file still references retired branding root: {rel}")

    if errors:
        print("LEGACY_BRANDING_ROOT_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    state = "removed" if not branding_root.exists() else "tombstone_only"
    print(f"LEGACY_BRANDING_ROOT_OK state={state}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
