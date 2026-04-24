#!/usr/bin/env python3
"""Bulk-import generated Kajabi course packages into Tutor Open edX."""

from __future__ import annotations

import argparse
import csv
import os
import subprocess
from pathlib import Path

BASE_DIR = "/tmp/kajabi-import"


def run(cmd, **kwargs):
    print("➜", " ".join(cmd))
    subprocess.run(cmd, check=True, **kwargs)


def ensure_tutor_available():
    try:
        subprocess.run(["tutor", "--version"], check=True, capture_output=True)
    except FileNotFoundError as exc:
        raise SystemExit("tutor command not found; source ops/tutor-env.sh first") from exc


def load_manifest(path: Path):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        yield from reader


def build_tutor_cmd(service: str, backend: str, bash_script: str) -> list[str]:
    if backend == "local":
        return ["tutor", "local", "run", service, "bash", "-c", bash_script]
    if backend == "k8s":
        return ["tutor", "k8s", "exec", service, "--", "bash", "-c", bash_script]
    raise SystemExit(f"Unsupported Tutor backend: {backend}")


def import_course(
    row,
    packages_root: Path,
    keep_temp: bool,
    dry_run: bool,
    backend: str,
    service: str,
    namespace: str | None,
):
    package_rel = row["package_path"]
    kajabi_id = row["kajabi_course_id"]
    course_key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
    tarball = packages_root / package_rel
    if not tarball.exists():
        print(f"! Skipping {kajabi_id}: tarball not found at {tarball}")
        return False

    slug = Path(package_rel).parent.name or Path(package_rel).stem

    print(f"Importing Kajabi {kajabi_id} -> {course_key}")
    if dry_run:
        return True

    cleanup = "" if keep_temp else "rm -f \"$TMP\" && rm -rf \"$DEST\";"
    bash_script = (
        "set -euo pipefail; "
        f"BASE={BASE_DIR}; SLUG={slug}; RUN_ID={row['run']}; DEST=$BASE/$SLUG; TMP=$DEST.tgz; "
        "mkdir -p \"$BASE\"; "
        "rm -rf \"$DEST\" \"$TMP\"; "
        "mkdir -p \"$DEST\"; "
        "cat > \"$TMP\"; "
        "tar -xzf \"$TMP\" -C \"$DEST\"; "
        "COURSE_XML=\"$DEST/course.xml\" RUN_ID=\"$RUN_ID\" python -c \"from xml.etree import ElementTree as ET; import os; path=os.environ['COURSE_XML']; run=os.environ['RUN_ID']; "
        "tree=ET.parse(path); root=tree.getroot(); root.set('url_name', run); root.set('run', run); tree.write(path, encoding='utf-8');\"; "
        "./manage.py cms import \"$BASE\" \"$SLUG\" --settings=tutor.production; "
        f"{cleanup}"
    )

    env = None
    if backend == "k8s" and namespace:
        env = {**os.environ, "TUTOR_K8S_NAMESPACE": namespace}

    with tarball.open("rb") as handle:
        run(build_tutor_cmd(service, backend, bash_script), stdin=handle, env=env)

    return True


def main():
    parser = argparse.ArgumentParser(description="Import course packages into Open edX")
    parser.add_argument("--manifest", required=True, help="Path to course_packages_manifest.csv")
    parser.add_argument("--packages-root", required=True, help="Directory containing the tarballs")
    parser.add_argument("--limit", type=int, default=None, help="Stop after importing N courses")
    parser.add_argument(
        "--only",
        nargs="*",
        help="Optional Kajabi course IDs to import (space-separated). Defaults to all.",
    )
    parser.add_argument("--keep-temp", action="store_true", help="Leave extracted files in /tmp")
    parser.add_argument("--dry-run", action="store_true", help="Show plan without running tutor commands")
    parser.add_argument(
        "--backend",
        choices=["local", "k8s"],
        default="local",
        help="Tutor backend to target (local docker vs k8s)",
    )
    parser.add_argument(
        "--service",
        default="cms",
        help="Tutor service name to run manage.py import from",
    )
    parser.add_argument(
        "--k8s-namespace",
        help="Override TUTOR_K8S_NAMESPACE when using --backend k8s",
    )
    args = parser.parse_args()

    ensure_tutor_available()

    manifest_path = Path(args.manifest)
    packages_root = Path(args.packages_root)
    if not manifest_path.exists():
        raise SystemExit(f"Manifest not found: {manifest_path}")
    if not packages_root.exists():
        raise SystemExit(f"Packages root not found: {packages_root}")

    count = 0
    selected = set(args.only) if args.only else None

    for row in load_manifest(manifest_path):
        if selected and row["kajabi_course_id"] not in selected:
            continue
        ok = import_course(
            row,
            packages_root,
            args.keep_temp,
            args.dry_run,
            args.backend,
            args.service,
            args.k8s_namespace,
        )
        if ok:
            count += 1
        if args.limit and count >= args.limit:
            break

    print(f"Imported {count} course(s)")


if __name__ == "__main__":
    main()
