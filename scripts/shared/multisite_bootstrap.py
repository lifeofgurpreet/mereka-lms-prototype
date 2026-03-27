#!/usr/bin/env python3
"""Compatibility shim for the retired direct-SQL multisite bootstrap path.

Canonical operator entrypoint:
  scripts/infra/apply-multisite-config.sh

Canonical implementation helper:
  scripts/shared/multisite_bootstrap_django.py

This wrapper keeps old invocations from failing opaquely while blocking the
legacy direct database / Cloud SQL connector mode that can drift away from the
repo-owned multisite definitions.
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPER_PATH = REPO_ROOT / "scripts" / "shared" / "multisite_bootstrap_django.py"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, add_help=False)
    parser.add_argument("--env")
    parser.add_argument("--host")
    parser.add_argument("--port", type=int)
    parser.add_argument("--user")
    parser.add_argument("--password")
    parser.add_argument("--database")
    parser.add_argument("--use-connector", action="store_true")
    parser.add_argument("--instance")
    parser.add_argument("--ip-type")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--scope", choices=["full", "sites"])
    parser.add_argument("-h", "--help", action="store_true")
    return parser


def legacy_direct_db_flags(args: argparse.Namespace) -> list[str]:
    flagged: list[str] = []
    if args.env is not None:
        flagged.append("--env")
    if args.host is not None:
        flagged.append("--host")
    if args.port is not None:
        flagged.append("--port")
    if args.user is not None:
        flagged.append("--user")
    if args.password is not None:
        flagged.append("--password")
    if args.database is not None:
        flagged.append("--database")
    if args.use_connector:
        flagged.append("--use-connector")
    if args.instance is not None:
        flagged.append("--instance")
    if args.ip_type is not None:
        flagged.append("--ip-type")
    return flagged


def build_forward_args(args: argparse.Namespace, unknown: list[str]) -> list[str]:
    if args.help:
        return ["--help"]

    forward = list(unknown)
    if args.check:
        forward.append("--check")
    if args.scope:
        forward.extend(["--scope", args.scope])
    if args.apply:
        forward.append("--apply")
    elif args.dry_run or not args.check:
        # Preserve the legacy contract where omitting --apply means preview only.
        forward.append("--dry-run")
    return forward


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args, unknown = parser.parse_known_args(argv)

    if args.apply and args.dry_run:
        print("ERROR: choose either --apply or --dry-run, not both.", file=sys.stderr)
        return 2

    retired_flags = legacy_direct_db_flags(args)
    if retired_flags:
        print(
            "ERROR: scripts/shared/multisite_bootstrap.py no longer supports "
            "direct SQL or Cloud SQL connector mode.",
            file=sys.stderr,
        )
        print(
            "Use scripts/infra/apply-multisite-config.sh as the canonical operator "
            "entrypoint, or run scripts/shared/multisite_bootstrap_django.py inside "
            "an LMS/CMS pod.",
            file=sys.stderr,
        )
        print(
            f"Unsupported legacy flags: {', '.join(sorted(retired_flags))}",
            file=sys.stderr,
        )
        return 2

    if not HELPER_PATH.exists():
        print(f"ERROR: missing helper script: {HELPER_PATH}", file=sys.stderr)
        return 1

    print(
        "[compat] scripts/shared/multisite_bootstrap.py is a compatibility shim; "
        "prefer scripts/infra/apply-multisite-config.sh",
        file=sys.stderr,
    )
    forward_args = build_forward_args(args, unknown)
    return subprocess.call([sys.executable, str(HELPER_PATH), *forward_args])


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
