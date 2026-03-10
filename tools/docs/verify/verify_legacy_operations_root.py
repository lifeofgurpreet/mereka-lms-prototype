#!/usr/bin/env python3
"""Verify docs/operations is retired and reduced to a tombstone root."""

from __future__ import annotations

import argparse
from pathlib import Path


ALLOWED_FILE = "docs/operations/README.md"
ACTIVE_ROOTS = (
    "docs/README.md",
    "docs/CONTRIBUTING.md",
    "docs/guides/",
    "docs/reference/",
    "docs/policies/",
    "docs/ops/",
    "docs/concepts/architecture/",
    "scripts/qa/",
    "deploy/",
    "infrastructure/",
    ".github/workflows/",
)
EXEMPT_REFERENCERS = {
    "docs/README.md",
    "docs/CONTRIBUTING.md",
    "docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md",
    "docs/guides/admin/DOCS_CMDREF_BACKLOG_20260313.md",
    "docs/guides/standards/DOCUMENTATION_STANDARDS.md",
    "docs/guides/standards/STYLE_GUIDE.md",
    "docs/concepts/architecture/ARCHITECTURE_CHARTER.md",
    "docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md",
    "docs/meta/docs-program/REPO_TOPOLOGY_MOVE_LEDGER.md",
    "docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_TRACKER.md",
    "docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_CLOSEOUT.md",
    "docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_REVIEW_HANDOFF.md",
    "tools/docs/verify/verify_legacy_operations_root.py",
    "tools/docs/verify/verify-docs-policy.sh",
}
SKIP_PREFIXES = (
    "docs/archive/",
    "docs/evidence/",
    "docs/status/",
    "docs/meta/",
    "specs/",
    "generated/",
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
    operations_root = repo_root / "docs" / "operations"
    errors: list[str] = []

    if operations_root.exists():
        for path in sorted(operations_root.rglob("*")):
            if path.is_dir():
                continue
            rel = path.relative_to(repo_root).as_posix()
            if rel != ALLOWED_FILE:
                errors.append(f"retired root contains non-tombstone file: {rel}")

    for path in iter_active_files(repo_root):
        rel = path.relative_to(repo_root).as_posix()
        if rel.startswith("docs/operations/"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "docs/operations/" not in text:
            continue
        if rel in EXEMPT_REFERENCERS:
            continue
        stripped = text.replace("docs/operations/README.md", "")
        if "docs/operations/" not in stripped:
            continue
        errors.append(f"active file still references retired operations root: {rel}")

    if errors:
        print("LEGACY_OPERATIONS_ROOT_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    state = "removed" if not operations_root.exists() else "tombstone_only"
    print(f"LEGACY_OPERATIONS_ROOT_OK state={state}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
