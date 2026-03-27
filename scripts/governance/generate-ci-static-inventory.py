#!/usr/bin/env python3
"""Generate and verify the CI static script inventory from script-registry.yaml."""

from __future__ import annotations

import argparse
import difflib
import json
import os
import subprocess
import sys
from collections import Counter
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover - surfaced as a hard failure
    raise SystemExit("PyYAML is required: pip install pyyaml") from exc


def git_repo_root() -> Path:
    output = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"],
        text=True,
    ).strip()
    return Path(output)


def load_registry(path: Path) -> dict:
    payload = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise SystemExit(f"Registry must load as a mapping: {path}")
    return payload


def normalize_entries(payload: dict, repo_root: Path) -> list[dict[str, object]]:
    inventory = payload.get("ci_static_inventory")
    if not isinstance(inventory, dict):
        raise SystemExit("script-registry.yaml missing ci_static_inventory mapping")

    entries = inventory.get("entries")
    if not isinstance(entries, list) or not entries:
        raise SystemExit("ci_static_inventory.entries must be a non-empty list")

    normalized: list[dict[str, object]] = []
    seen_keys: set[str] = set()

    for index, raw in enumerate(entries, start=1):
        if not isinstance(raw, dict):
            raise SystemExit(f"ci_static_inventory.entries[{index}] must be a mapping")

        script = raw.get("script")
        if not isinstance(script, str) or not script.strip():
            raise SystemExit(f"ci_static_inventory.entries[{index}] missing script")

        args = raw.get("args", [])
        if args is None:
            args = []
        if not isinstance(args, list) or any(not isinstance(item, str) or not item for item in args):
            raise SystemExit(
                f"ci_static_inventory.entries[{index}] args must be a list of non-empty strings"
            )

        key = " ".join([script, *args])
        if key in seen_keys:
            raise SystemExit(f"duplicate ci_static_inventory entry: {key}")
        seen_keys.add(key)

        script_path = repo_root / script
        if not script_path.is_file():
            raise SystemExit(f"ci_static_inventory entry not found on disk: {script}")
        if not os.access(script_path, os.X_OK):
            raise SystemExit(f"ci_static_inventory entry is not executable: {script}")

        normalized.append({"script": script, "args": args})

    return normalized


def normalize_shard_files(payload: dict) -> list[str]:
    inventory = payload.get("ci_static_inventory")
    if not isinstance(inventory, dict):
        raise SystemExit("script-registry.yaml missing ci_static_inventory mapping")

    raw = inventory.get("shard_files", [])
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise SystemExit("ci_static_inventory.shard_files must be a list when present")

    shard_files: list[str] = []
    seen: set[str] = set()
    for index, item in enumerate(raw, start=1):
        if not isinstance(item, str) or not item.strip():
            raise SystemExit(f"ci_static_inventory.shard_files[{index}] must be a non-empty string")
        if item in seen:
            raise SystemExit(f"duplicate ci_static_inventory shard file: {item}")
        seen.add(item)
        shard_files.append(item)
    return shard_files


def normalize_precheck_files(payload: dict) -> list[str]:
    inventory = payload.get("ci_static_inventory")
    if not isinstance(inventory, dict):
        raise SystemExit("script-registry.yaml missing ci_static_inventory mapping")

    raw = inventory.get("precheck_files", [])
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise SystemExit("ci_static_inventory.precheck_files must be a list when present")

    precheck_files: list[str] = []
    seen: set[str] = set()
    for index, item in enumerate(raw, start=1):
        if not isinstance(item, str) or not item.strip():
            raise SystemExit(
                f"ci_static_inventory.precheck_files[{index}] must be a non-empty string"
            )
        if item in seen:
            raise SystemExit(f"duplicate ci_static_inventory precheck file: {item}")
        seen.add(item)
        precheck_files.append(item)
    return precheck_files


def shard_entries(entries: list[dict[str, object]], shard_count: int) -> list[list[dict[str, object]]]:
    if shard_count <= 0:
        return []
    shards: list[list[dict[str, object]]] = [[] for _ in range(shard_count)]
    for index, entry in enumerate(entries):
        shards[index % shard_count].append(entry)
    return shards


def render_inventory(
    entries: list[dict[str, object]],
    registry_path: Path,
    generator_path: Path,
    *,
    shard_label: str | None = None,
) -> str:
    lines = [
        "# AUTO-GENERATED FILE. DO NOT EDIT.",
        f"# Source of truth: {registry_path.as_posix()} (ci_static_inventory)",
        f"# Regenerate: python3 {generator_path.as_posix()} --write",
        "",
    ]
    if shard_label is not None:
        lines.insert(3, f"# Shard: {shard_label}")
    for entry in entries:
        script = str(entry["script"])
        args = [str(item) for item in entry["args"]]
        line = " ".join([script, *args]).rstrip()
        lines.append(line)
    return "\n".join(lines) + "\n"


def build_report(
    entries: list[dict[str, object]],
    registry_path: Path,
    output_path: Path,
    shard_paths: list[Path],
    precheck_files: list[str],
) -> dict[str, object]:
    prefix_counts = Counter()
    entries_with_args = 0
    rendered_entries: list[str] = []
    for entry in entries:
        script = str(entry["script"])
        args = [str(item) for item in entry["args"]]
        prefix = "/".join(script.split("/")[:2]) if "/" in script else script
        prefix_counts[prefix] += 1
        if args:
            entries_with_args += 1
        rendered_entries.append(" ".join([script, *args]).rstrip())

    precheck_set = set(precheck_files)
    sharded_entries = [entry for entry in entries if str(entry["script"]) not in precheck_set]

    return {
        "authority": registry_path.as_posix(),
        "generated_file": output_path.as_posix(),
        "entries_total": len(entries),
        "entries_with_args": entries_with_args,
        "precheck_total": len(precheck_files),
        "precheck_files": precheck_files,
        "sharded_entries_total": len(sharded_entries),
        "prefix_counts": dict(sorted(prefix_counts.items())),
        "entries": rendered_entries,
        "shards": [
            {"generated_file": path.as_posix(), "entries_total": len(shard)}
            for path, shard in zip(
                shard_paths, shard_entries(sharded_entries, len(shard_paths)), strict=True
            )
        ],
    }


def print_report(report: dict[str, object], fmt: str, show_entries: bool) -> None:
    if fmt == "json":
        print(json.dumps(report, indent=2))
        return

    print(f"Authority: {report['authority']}")
    print(f"Generated file: {report['generated_file']}")
    print(f"Entries: {report['entries_total']}")
    print(f"Entries with args: {report['entries_with_args']}")
    print(f"Serial precheck entries: {report['precheck_total']}")
    if report["precheck_files"]:
        print("Precheck files:")
        for entry in report["precheck_files"]:
            print(f"  {entry}")
    if report["shards"]:
        print("Shards:")
        for shard in report["shards"]:
            print(f"  {shard['generated_file']}: {shard['entries_total']}")
    print("Entry prefixes:")
    for prefix, count in report["prefix_counts"].items():
        print(f"  {prefix}: {count}")
    if show_entries:
        print("Entries:")
        for entry in report["entries"]:
            print(f"  {entry}")


def check_current(expected: str, output_path: Path) -> int:
    if not output_path.is_file():
        print(f"FAIL: generated file missing: {output_path}", file=sys.stderr)
        return 1

    current = output_path.read_text(encoding="utf-8")
    if current == expected:
        print(f"PASS: {output_path} is current")
        return 0

    diff = difflib.unified_diff(
        current.splitlines(),
        expected.splitlines(),
        fromfile=f"{output_path.as_posix()} (current)",
        tofile=f"{output_path.as_posix()} (expected)",
        lineterm="",
    )
    print("\n".join(diff), file=sys.stderr)
    print(f"FAIL: {output_path} is stale; regenerate it", file=sys.stderr)
    return 1


def resolve_static_targets(
    *,
    repo_root: Path,
    registry_path: Path,
    generator_path: Path,
    output_path: Path,
    entries: list[dict[str, object]],
    shard_files: list[str],
    precheck_files: list[str],
    include_shards: bool,
) -> list[tuple[Path, str]]:
    targets: list[tuple[Path, str]] = [
        (
            output_path,
            render_inventory(entries, registry_path.relative_to(repo_root), generator_path.relative_to(repo_root)),
        )
    ]
    if include_shards and shard_files:
        precheck_set = set(precheck_files)
        sharded_entries = [entry for entry in entries if str(entry["script"]) not in precheck_set]
        shards = shard_entries(sharded_entries, len(shard_files))
        for index, shard_file in enumerate(shard_files, start=1):
            targets.append(
                (
                    (repo_root / shard_file).resolve(),
                    render_inventory(
                        shards[index - 1],
                        registry_path.relative_to(repo_root),
                        generator_path.relative_to(repo_root),
                        shard_label=f"{index}/{len(shard_files)}",
                    ),
                )
            )
    return targets


def main() -> int:
    repo_root = git_repo_root()
    default_registry = repo_root / "scripts/governance/script-registry.yaml"
    default_generator = repo_root / "scripts/governance/generate-ci-static-inventory.py"

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--registry",
        type=Path,
        default=default_registry,
        help="Path to script-registry.yaml",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Output file path (defaults to ci_static_inventory.generated_file)",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write the generated inventory file",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if the generated inventory differs from the committed file",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Output format for report mode",
    )
    parser.add_argument(
        "--show-entries",
        action="store_true",
        help="Include every generated entry in report mode",
    )
    args = parser.parse_args()

    if args.write and args.check:
        raise SystemExit("--write and --check are mutually exclusive")

    registry_path = args.registry.resolve()
    payload = load_registry(registry_path)
    inventory = payload.get("ci_static_inventory") or {}
    generated_file = inventory.get("generated_file")
    if not isinstance(generated_file, str) or not generated_file:
        raise SystemExit("ci_static_inventory.generated_file must be a non-empty string")
    shard_files = normalize_shard_files(payload)
    precheck_files = normalize_precheck_files(payload)

    output_path = (repo_root / generated_file).resolve() if args.out is None else args.out.resolve()
    entries = normalize_entries(payload, repo_root)
    entry_scripts = {str(entry["script"]) for entry in entries}
    for script in precheck_files:
        if script not in entry_scripts:
            raise SystemExit(
                f"ci_static_inventory.precheck_files entry is not registered in entries: {script}"
            )
    targets = resolve_static_targets(
        repo_root=repo_root,
        registry_path=registry_path,
        generator_path=default_generator,
        output_path=output_path,
        entries=entries,
        shard_files=shard_files,
        precheck_files=precheck_files,
        include_shards=args.out is None,
    )

    if args.write:
        for path, rendered in targets:
            path.write_text(rendered, encoding="utf-8")
            print(f"WROTE: {path}")
        return 0

    if args.check:
        failures = 0
        for path, rendered in targets:
            failures |= check_current(rendered, path)
        return failures

    report = build_report(
        entries,
        registry_path.relative_to(repo_root),
        output_path.relative_to(repo_root),
        [(repo_root / shard_file).resolve().relative_to(repo_root) for shard_file in shard_files] if args.out is None else [],
        precheck_files,
    )
    print_report(report, args.format, args.show_entries)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
