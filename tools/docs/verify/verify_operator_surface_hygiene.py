#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


FORBIDDEN_CI_CD_FILES = {
    "CI_OPTIMIZATION_TRACKER.md",
    "CI_PIPELINE_COST_OPTIMIZATION.md",
    "GITHUB_ACTIONS_COST_MONITORING.md",
    "CI_CEREMONY_REDUCTION_MATRIX_104.md",
    "TUTOR_CONFIG_CI.md",
    "ios-cicd-spec.md",
    "cost-estimate.md",
    "COST_OPTIMIZATION.md",
}

SECRET_PATTERNS = (
    r"temp-keychain-password-123",
    r"KEYCHAIN_PASSWORD\s*[:=]\s*[\"'][^\"']+[\"']",
    r"APP_STORE_CONNECT_(API_KEY_ID|ISSUER_ID)\s*[:=]\s*[\"'][^\"']+[\"']",
    r"APPLE_TEAM_ID\s*[:=]\s*[\"'][^\"']+[\"']",
    r"/home/gurpreet/",
)

FORBIDDEN_LOCAL_LINKS = tuple(f"]({name})" for name in FORBIDDEN_CI_CD_FILES)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    return parser.parse_args()


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    args = parse_args()
    repo = Path(args.repo_root).resolve()
    errors: list[str] = []

    monitoring_dir = repo / "docs/ops/monitoring"
    monitoring_files = sorted(
        p.relative_to(repo).as_posix() for p in monitoring_dir.rglob("*") if p.is_file()
    )
    if monitoring_files != ["docs/ops/monitoring/README.md"]:
        fail(
            errors,
            "docs/ops/monitoring must be a README-only portal; found: "
            + ", ".join(monitoring_files),
        )

    monitoring_readme = (repo / "docs/ops/monitoring/README.md").read_text(encoding="utf-8")
    for leaf in (
        "LOGGING_AND_SENTRY.md",
        "OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md",
        "OBSERVABILITY_ENHANCEMENT_PLAN.md",
        "OBSERVABILITY_OWNERSHIP.md",
        "OBSERVABILITY_PARITY_MATRIX.md",
        "OBSERVABILITY_ROADMAP_MEREKA_LMS.md",
    ):
        if f"]({leaf})" in monitoring_readme or f"({leaf})" in monitoring_readme:
            fail(errors, f"docs/ops/monitoring/README.md still links to local superseded child {leaf}")

    ci_cd_dir = repo / "docs/ops/ci-cd"
    for name in sorted(FORBIDDEN_CI_CD_FILES):
        if (ci_cd_dir / name).exists():
            fail(errors, f"forbidden stale CI/CD file still exists: docs/ops/ci-cd/{name}")

    for md in sorted(ci_cd_dir.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        if "docs/operations/" in text:
            fail(errors, f"{md.relative_to(repo)} still references docs/operations/")
        if "docs/runbooks/operations/" in text or "../runbooks/operations/" in text:
            fail(errors, f"{md.relative_to(repo)} still references docs/runbooks/operations/")
        for pattern in SECRET_PATTERNS:
            if re.search(pattern, text):
                fail(errors, f"{md.relative_to(repo)} matches sensitive/stale operator-doc pattern: {pattern}")

    ci_cd_readme = (repo / "docs/ops/ci-cd/README.md").read_text(encoding="utf-8")
    for marker in FORBIDDEN_LOCAL_LINKS:
        if marker in ci_cd_readme:
            fail(
                errors,
                "docs/ops/ci-cd/README.md still links to removed same-root stale doc "
                + marker.removeprefix("](").removesuffix(")"),
            )

    if errors:
        print("Operator surface hygiene check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Operator surface hygiene check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
