#!/usr/bin/env python3
"""Verify docs/runbooks is retired and reduced to a tombstone root."""

from __future__ import annotations

import argparse
from pathlib import Path


ALLOWED_FILE = "docs/runbooks/README.md"
ACTIVE_ROOTS = (
    "README.md",
    "CLAUDE.md",
    "TRACKER.md",
    "LOCAL_SETUP_COMPLETE.md",
    "MIGRATION_CHECKLIST.md",
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
    "services/",
)
EXEMPT_REFERENCERS = {
    "docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md",
    "docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_CLOSEOUT.md",
    "docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_REVIEW_HANDOFF.md",
    "tools/docs/verify/verify_legacy_runbooks_root.py",
    "tools/docs/verify/verify-docs-policy.sh",
}
SKIP_PREFIXES = (
    "docs/archive/",
    "docs/evidence/",
    "docs/status/",
    "docs/meta/",
    "specs/",
    "generated/",
    "reports/",
    "verification/",
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
    runbooks_root = repo_root / "docs" / "runbooks"
    errors: list[str] = []

    if runbooks_root.exists():
        for path in sorted(runbooks_root.rglob("*")):
            if path.is_dir():
                continue
            rel = path.relative_to(repo_root).as_posix()
            if rel != ALLOWED_FILE:
                errors.append(f"retired root contains non-tombstone file: {rel}")

    for path in iter_active_files(repo_root):
        rel = path.relative_to(repo_root).as_posix()
        if rel.startswith("docs/runbooks/"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "docs/runbooks/" not in text:
            continue
        if rel in EXEMPT_REFERENCERS:
            continue
        stripped = text.replace("docs/runbooks/README.md", "")
        if "docs/runbooks/" not in stripped:
            continue
        errors.append(f"active file still references retired runbooks root: {rel}")

    if errors:
        print("LEGACY_RUNBOOKS_ROOT_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    state = "removed" if not runbooks_root.exists() else "tombstone_only"
    print(f"LEGACY_RUNBOOKS_ROOT_OK state={state}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
