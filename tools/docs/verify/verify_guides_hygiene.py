#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


FORBIDDEN_GUIDE_FILES = {
    "docs/guides/admin/COURSE_CERTIFICATES_UI.md",
    "docs/guides/integrations/GOOGLE_OAUTH_QUICK_START.md",
    "docs/guides/onboarding/DEVELOPER_ONBOARDING.md",
    "docs/guides/onboarding/DOCUMENTATION_INDEX.md",
    "docs/guides/onboarding/LOCAL_ACCESS_GUIDE.md",
    "docs/guides/onboarding/LOCAL_DEVELOPMENT_GUIDE.md",
    "docs/guides/onboarding/README_LOCAL.md",
    "docs/guides/onboarding/TEAM_SCALING_GUIDE.md",
    "docs/guides/standards/bead-v2-format.md",
}

FORBIDDEN_ADMIN_NAME_PATTERNS = (
    re.compile(r"^DOCS_.*\.md$"),
    re.compile(r"^PR\d+.*CLOSURE.*\.md$"),
)

FORBIDDEN_CREDENTIAL_PATTERNS = (
    re.compile(r"\badmin123\b"),
    re.compile(r"\b0ui3DwG7yQfQTYwXOP7G1NS7\b"),
    re.compile(r"\bUOTbuYNBM0Tw\b"),
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify guides root hygiene.")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    errors: list[str] = []

    for rel in sorted(FORBIDDEN_GUIDE_FILES):
        if (repo_root / rel).exists():
            errors.append(f"forbidden guide file still exists: {rel}")

    admin_dir = repo_root / "docs/guides/admin"
    if admin_dir.exists():
        for child in sorted(admin_dir.iterdir()):
            if not child.is_file():
                continue
            for pattern in FORBIDDEN_ADMIN_NAME_PATTERNS:
                if pattern.match(child.name):
                    errors.append(f"docs/guides/admin contains docs-program artifact: {child.relative_to(repo_root)}")

    onboarding_dir = repo_root / "docs/guides/onboarding"
    if onboarding_dir.exists():
        for md_file in sorted(onboarding_dir.glob("*.md")):
            text = md_file.read_text(encoding="utf-8", errors="ignore")
            if "archive-candidate" in text.lower():
                errors.append(f"archive-candidate stub remains in onboarding root: {md_file.relative_to(repo_root)}")

    guides_root = repo_root / "docs/guides"
    if guides_root.exists():
        for md_file in sorted(guides_root.rglob("*.md")):
            text = md_file.read_text(encoding="utf-8", errors="ignore")
            for pattern in FORBIDDEN_CREDENTIAL_PATTERNS:
                if pattern.search(text):
                    errors.append(
                        f"forbidden credential pattern `{pattern.pattern}` found in {md_file.relative_to(repo_root)}"
                    )

    if errors:
        print("GUIDES_HYGIENE_ERRORS")
        for error in errors:
            print(f"- {error}")
        return 1

    print("GUIDES_HYGIENE_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
