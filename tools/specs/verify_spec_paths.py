#!/usr/bin/env python3
"""Verify spec path placement rules for the twin-root model."""

from __future__ import annotations

import argparse
from pathlib import Path


ALLOWED_ROOT_FILES = {
    "README.md",
    "INDEX.md",
    "catalog.json",
    "IMPLEMENTATION_ORDER.md",
    "manual_verifications.yaml",
    "_TEMPLATE.md",
    "brand-pack-schema.json",
}
ALLOWED_PLAN_FILES = {"README.md", "IMPLEMENTATION_ORDER.md", "manual_verifications.yaml"}
ALLOWED_PROPOSAL_FILES = {"README.md"}
COMPATIBILITY_ROOT_FILES = {"IMPLEMENTATION_ORDER.md", "manual_verifications.yaml", "_TEMPLATE.md"}
COMPATIBILITY_TOKENS = ("superseded", "specs/", "transitional only")


def is_stub_like(path: Path) -> bool:
    text = path.read_text(errors="ignore")[:2000].lower()
    return all(token in text for token in COMPATIBILITY_TOKENS)


def check_root(specs_root: Path, failures: list[str]) -> int:
    checked = 0
    for path in sorted(p for p in specs_root.iterdir() if p.is_file()):
        checked += 1
        name = path.name
        if name.endswith("_spec.md"):
            continue
        if name not in ALLOWED_ROOT_FILES:
            failures.append(f"SPEC_PATH_FAIL root unexpected file {path.relative_to(specs_root.parent).as_posix()}")
            continue
        if name in COMPATIBILITY_ROOT_FILES and not is_stub_like(path):
            failures.append(f"SPEC_PATH_FAIL root compatibility file not stub-like {path.relative_to(specs_root.parent).as_posix()}")
    return checked


def check_plans(plans_root: Path, failures: list[str]) -> int:
    checked = 0
    if not plans_root.exists():
        return checked
    for path in sorted(p for p in plans_root.iterdir() if p.is_file()):
        checked += 1
        name = path.name
        if name.endswith("_plan.md") or name.endswith("_testplan.md"):
            continue
        if name not in ALLOWED_PLAN_FILES:
            failures.append(f"SPEC_PATH_FAIL plans unexpected file {path.relative_to(plans_root.parent.parent).as_posix()}")
    return checked


def check_proposals(proposals_root: Path, failures: list[str]) -> int:
    checked = 0
    if not proposals_root.exists():
        return checked
    for path in sorted(p for p in proposals_root.iterdir() if p.is_file()):
        checked += 1
        name = path.name
        if name.endswith("_proposal.md"):
            continue
        if name not in ALLOWED_PROPOSAL_FILES:
            failures.append(f"SPEC_PATH_FAIL proposals unexpected file {path.relative_to(proposals_root.parent.parent).as_posix()}")
    return checked


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    specs_root = repo_root / "specs"
    failures: list[str] = []

    root_checked = check_root(specs_root, failures)
    plans_checked = check_plans(specs_root / "plans", failures)
    proposals_checked = check_proposals(specs_root / "proposals", failures)

    if failures:
        print("\n".join(failures))
        raise SystemExit(1)

    print(
        "SPEC_PATHS_OK "
        f"root_checked={root_checked} plans_checked={plans_checked} proposals_checked={proposals_checked}"
    )


if __name__ == "__main__":
    main()
