#!/usr/bin/env python3
"""Verify docs/architecture remains the canonical stable architecture root."""

from __future__ import annotations

import argparse
from pathlib import Path


REQUIRED_FILES = {
    "docs/architecture/README.md",
    "docs/architecture/PLATFORM_AUTHORITY_MAP.md",
}
STALE_PATTERNS = (
    "retired architecture root",
    "legacy architecture root",
    "retained as the only allowed architecture-root tombstone",
    "only allowed architecture-root tombstone",
    "docs/architecture/** contains no substantive files beyond the tombstone",
    "docs/architecture/README.md is a tombstone",
    "docs/architecture/README.md stays as a tombstone-only redirect",
)
EXEMPT_REFERENCERS = {
    "tools/docs/verify/verify_legacy_architecture_root.py",
    "docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_TRACKER.md",
    "docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_CLOSEOUT.md",
    "docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_REVIEW_HANDOFF.md",
    "docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_TRACKER.md",
    "docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md",
    "docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_REVIEW_HANDOFF.md",
    "docs/meta/docs-program/WAVE9_CLOSEOUT.md",
    "docs/meta/docs-program/WAVE9_REVIEW_HANDOFF.md",
    "docs/meta/knowledge/WAVE10_CLOSEOUT.md",
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
                    "docs/meta/docs-program/WAVE_",
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

    if not architecture_root.exists():
        errors.append("canonical architecture root missing: docs/architecture/")
    else:
        for rel in sorted(REQUIRED_FILES):
            if not (repo_root / rel).exists():
                errors.append(f"required architecture authority file missing: {rel}")

    for path in iter_text_files(repo_root):
        rel = path.relative_to(repo_root).as_posix()
        if rel in EXEMPT_REFERENCERS:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        lowered = text.lower()
        for pattern in STALE_PATTERNS:
            if pattern in lowered:
                errors.append(f"active file still describes docs/architecture as retired: {rel}")
                break

    if errors:
        print("ARCHITECTURE_ROOT_AUTHORITY_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"ARCHITECTURE_ROOT_AUTHORITY_OK required={len(REQUIRED_FILES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
