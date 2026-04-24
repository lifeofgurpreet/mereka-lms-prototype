#!/usr/bin/env python3
"""Verify docs/concepts/architecture contains only living standards and real overviews."""

from __future__ import annotations

import argparse
from pathlib import Path


ALLOWED_FILES = {
    "docs/concepts/architecture/README.md",
    "docs/concepts/architecture/ARCHITECTURE_CHARTER.md",
    "docs/concepts/architecture/AUTHORIZATION_MODEL.md",
    "docs/concepts/architecture/CONTROL_PLANES.md",
    "docs/concepts/architecture/DATA_GOVERNANCE.md",
    "docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md",
    "docs/concepts/architecture/IDENTITY_DOMAIN_BOUNDARIES.md",
    "docs/concepts/architecture/RELEASE_ROLLOUT_AND_REMOVAL.md",
    "docs/concepts/architecture/TENANT_LIFECYCLE.md",
    "docs/concepts/architecture/TENANT_OPERATING_SYSTEM.md",
    "docs/concepts/architecture/TUTOR_AND_EXTENSION_MODEL.md",
    "docs/concepts/architecture/content-libraries-overview.md",
    "docs/concepts/architecture/enterprise-services-overview.md",
    "docs/concepts/architecture/multi-tenancy-overview.md",
    "docs/concepts/architecture/notification-pipeline-overview.md",
    "docs/concepts/architecture/proctoring-architecture-overview.md",
    "docs/concepts/architecture/purchase-gateway-overview.md",
    "docs/concepts/architecture/bundle-rules.yaml",
    "docs/concepts/architecture/glossary.yaml",
}

STUB_MARKERS = (
    "(Superseded)",
    "This document has moved to:",
    "Use the canonical path above.",
    "Superseded Path Notice",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    root = repo_root / "docs" / "concepts" / "architecture"
    errors: list[str] = []

    for path in sorted(root.rglob("*")):
        if path.is_dir():
            continue
        rel = path.relative_to(repo_root).as_posix()
        if rel not in ALLOWED_FILES:
            errors.append(f"non-canonical file remains in docs/concepts/architecture: {rel}")
            continue
        if path.suffix.lower() == ".md":
            text = path.read_text(encoding="utf-8", errors="ignore")
            for marker in STUB_MARKERS:
                if marker in text:
                    errors.append(f"redirect-only stub marker present in canonical concepts root: {rel}")
                    break

    if errors:
        print("CONCEPTS_ARCHITECTURE_CLEAN_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("CONCEPTS_ARCHITECTURE_CLEAN_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
