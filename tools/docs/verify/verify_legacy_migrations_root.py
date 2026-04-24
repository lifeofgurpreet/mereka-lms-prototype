#!/usr/bin/env python3
"""Verify docs/migrations is retired and reduced to a tombstone root."""

from __future__ import annotations

import argparse
from pathlib import Path


ALLOWED_FILE = "docs/migrations/README.md"
ACTIVE_ROOTS = (
    "README.md",
    "CONTRIBUTING.md",
    "DOCS_REMEDIATION_PLAN_AND_TRACKER.md",
    "catalog.json",
    "docs/README.md",
    "docs/CONTRIBUTING.md",
    "docs/guides/",
    "docs/reference/",
    "docs/policies/",
    "docs/ops/",
    "docs/status/",
    "docs/concepts/",
    "scripts/",
    "specs/",
    ".github/workflows/",
)
EXEMPT_REFERENCERS = {
    "docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_TRACKER.md",
    "docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_CLOSEOUT.md",
    "docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_REVIEW_HANDOFF.md",
    "tools/docs/verify/verify_legacy_migrations_root.py",
    "tools/docs/verify/verify-docs-policy.sh",
    "specs/repository-structure_spec.md",
}
SKIP_PREFIXES = (
    "docs/archive/",
    "docs/evidence/",
    "docs/meta/",
    "generated/",
    "reports/",
    "verification/",
    "specs/_generated/",
)


def iter_active_files(repo_root: Path) -> list[Path]:
    files: list[Path] = []
    for rel_root in ACTIVE_ROOTS:
        root = repo_root / rel_root
        if root.is_file():
            files.append(root)
            continue
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            rel = path.relative_to(repo_root).as_posix()
            if rel.startswith(SKIP_PREFIXES):
                continue
            if path.suffix.lower() not in {".md", ".py", ".sh", ".yaml", ".yml", ".json", ".txt"}:
                continue
            files.append(path)
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    legacy_root = repo_root / "docs" / "migrations"
    errors: list[str] = []

    if legacy_root.exists():
        for path in sorted(legacy_root.rglob("*")):
            if path.is_dir():
                continue
            rel = path.relative_to(repo_root).as_posix()
            if rel != ALLOWED_FILE:
                errors.append(f"retired root contains non-tombstone file: {rel}")

    for path in iter_active_files(repo_root):
        rel = path.relative_to(repo_root).as_posix()
        if rel.startswith("docs/migrations/"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "docs/migrations/" not in text:
            continue
        if rel in EXEMPT_REFERENCERS:
            continue
        stripped = text.replace("docs/migrations/README.md", "")
        if "docs/migrations/" not in stripped:
            continue
        errors.append(f"active file still references retired migrations root: {rel}")

    if errors:
        print("LEGACY_MIGRATIONS_ROOT_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    state = "removed" if not legacy_root.exists() else "tombstone_only"
    print(f"LEGACY_MIGRATIONS_ROOT_OK state={state}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
