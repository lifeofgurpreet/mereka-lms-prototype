#!/usr/bin/env python3
"""Generate and verify the CI runtime script inventory from script-registry.yaml."""

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


def repo_root_from_path() -> Path:
    return Path(__file__).resolve().parents[2]


def discover_repo_root() -> Path:
    override = os.environ.get("REPO_ROOT_OVERRIDE")
    if override:
        return Path(override).resolve()
    fallback = repo_root_from_path()
    try:
        output = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return fallback
    candidate = Path(output).resolve()
    if (candidate / "scripts/governance/script-registry.yaml").is_file():
        return candidate
    return fallback


def load_registry(path: Path) -> dict:
    payload = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise SystemExit(f"Registry must load as a mapping: {path}")
    return payload


def normalize_categories(payload: dict) -> list[dict[str, str]]:
    inventory = payload.get("ci_runtime_inventory")
    if not isinstance(inventory, dict):
        raise SystemExit("script-registry.yaml missing ci_runtime_inventory mapping")

    categories = inventory.get("categories")
    if not isinstance(categories, list) or not categories:
        raise SystemExit("ci_runtime_inventory.categories must be a non-empty list")

    normalized: list[dict[str, str]] = []
    seen_keys: set[str] = set()
    for index, raw in enumerate(categories, start=1):
        if not isinstance(raw, dict):
            raise SystemExit(f"ci_runtime_inventory.categories[{index}] must be a mapping")
        key = raw.get("key")
        title = raw.get("title")
        description = raw.get("description")
        if not isinstance(key, str) or not key.strip():
            raise SystemExit(f"ci_runtime_inventory.categories[{index}] missing key")
        if not isinstance(title, str) or not title.strip():
            raise SystemExit(f"ci_runtime_inventory.categories[{index}] missing title")
        if not isinstance(description, str) or not description.strip():
            raise SystemExit(f"ci_runtime_inventory.categories[{index}] missing description")
        if key in seen_keys:
            raise SystemExit(f"duplicate ci_runtime_inventory category: {key}")
        seen_keys.add(key)
        normalized.append({"key": key, "title": title, "description": description})
    return normalized


def normalize_entries(
    payload: dict,
    repo_root: Path,
    category_keys: set[str],
) -> list[dict[str, object]]:
    inventory = payload.get("ci_runtime_inventory")
    if not isinstance(inventory, dict):
        raise SystemExit("script-registry.yaml missing ci_runtime_inventory mapping")

    entries = inventory.get("entries")
    if not isinstance(entries, list) or not entries:
        raise SystemExit("ci_runtime_inventory.entries must be a non-empty list")

    normalized: list[dict[str, object]] = []
    seen_keys: set[str] = set()

    for index, raw in enumerate(entries, start=1):
        if not isinstance(raw, dict):
            raise SystemExit(f"ci_runtime_inventory.entries[{index}] must be a mapping")

        script = raw.get("script")
        if not isinstance(script, str) or not script.strip():
            raise SystemExit(f"ci_runtime_inventory.entries[{index}] missing script")

        category = raw.get("category")
        if not isinstance(category, str) or not category.strip():
            raise SystemExit(f"ci_runtime_inventory.entries[{index}] missing category")
        if category not in category_keys:
            raise SystemExit(
                f"ci_runtime_inventory.entries[{index}] references unknown category: {category}"
            )

        args = raw.get("args", [])
        if args is None:
            args = []
        if not isinstance(args, list) or any(not isinstance(item, str) or not item for item in args):
            raise SystemExit(
                f"ci_runtime_inventory.entries[{index}] args must be a list of non-empty strings"
            )

        note = raw.get("note")
        if note is not None and (not isinstance(note, str) or not note.strip()):
            raise SystemExit(
                f"ci_runtime_inventory.entries[{index}] note must be a non-empty string when present"
            )

        key = " ".join([script, *args])
        if key in seen_keys:
            raise SystemExit(f"duplicate ci_runtime_inventory entry: {key}")
        seen_keys.add(key)

        script_path = repo_root / script
        if not script_path.is_file():
            raise SystemExit(f"ci_runtime_inventory entry not found on disk: {script}")
        if not os.access(script_path, os.X_OK):
            raise SystemExit(f"ci_runtime_inventory entry is not executable: {script}")

        normalized.append(
            {
                "script": script,
                "category": category,
                "args": args,
                "note": note.strip() if isinstance(note, str) else None,
            }
        )

    return normalized


def render_inventory(
    categories: list[dict[str, str]],
    entries: list[dict[str, object]],
    registry_path: Path,
    generator_path: Path,
) -> str:
    lines = [
        "# AUTO-GENERATED FILE. DO NOT EDIT.",
        f"# Source of truth: {registry_path.as_posix()} (ci_runtime_inventory)",
        f"# Regenerate: python3 {generator_path.as_posix()} --write",
        "# Runtime inventory is for live-context validation paths, not the offline",
        "# static-validation CI runner.",
        "#",
        "# Categories:",
    ]
    for category in categories:
        lines.append(f"#   {category['key']:<16} — {category['description']}")

    grouped: dict[str, list[dict[str, object]]] = {category["key"]: [] for category in categories}
    for entry in entries:
        grouped[str(entry["category"])].append(entry)

    for category in categories:
        bucket = grouped[category["key"]]
        if not bucket:
            continue
        lines.extend(
            [
                "",
                f"# ── {category['title']} ─────────────────────────────────────────────────────",
            ]
        )
        for entry in bucket:
            script = str(entry["script"])
            args = [str(item) for item in entry["args"]]
            rendered = " ".join([script, *args]).rstrip()
            comment = str(entry["category"])
            note = entry.get("note")
            if isinstance(note, str) and note:
                comment = f"{comment} ({note})"
            lines.append(f"{rendered}  # {comment}")
    return "\n".join(lines) + "\n"


def build_report(
    categories: list[dict[str, str]],
    entries: list[dict[str, object]],
    registry_path: Path,
    output_path: Path,
) -> dict[str, object]:
    category_titles = {item["key"]: item["title"] for item in categories}
    category_counts = Counter()
    entries_with_args = 0
    entries_with_notes = 0
    rendered_entries: list[dict[str, object]] = []

    for entry in entries:
        category = str(entry["category"])
        category_counts[category] += 1
        args = [str(item) for item in entry["args"]]
        if args:
            entries_with_args += 1
        note = entry.get("note")
        if isinstance(note, str) and note:
            entries_with_notes += 1
        rendered_entries.append(
            {
                "script": str(entry["script"]),
                "category": category,
                "category_title": category_titles.get(category, category),
                "args": args,
                "note": note,
            }
        )

    return {
        "authority": registry_path.as_posix(),
        "generated_file": output_path.as_posix(),
        "entries_total": len(entries),
        "entries_with_args": entries_with_args,
        "entries_with_notes": entries_with_notes,
        "category_counts": dict(sorted(category_counts.items())),
        "entries": rendered_entries,
    }


def print_report(report: dict[str, object], fmt: str, show_entries: bool) -> None:
    if fmt == "json":
        print(json.dumps(report, indent=2))
        return

    print(f"Authority: {report['authority']}")
    print(f"Generated file: {report['generated_file']}")
    print(f"Entries: {report['entries_total']}")
    print(f"Entries with args: {report['entries_with_args']}")
    print(f"Entries with notes: {report['entries_with_notes']}")
    print("Category counts:")
    for category, count in report["category_counts"].items():
        print(f"  {category}: {count}")
    if show_entries:
        print("Entries:")
        for entry in report["entries"]:
            rendered = " ".join([entry["script"], *entry["args"]]).rstrip()
            suffix = entry["category"]
            if entry.get("note"):
                suffix = f"{suffix} ({entry['note']})"
            print(f"  {rendered}  # {suffix}")


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


def main() -> int:
    repo_root = discover_repo_root()
    default_registry = repo_root / "scripts/governance/script-registry.yaml"
    default_generator = repo_root / "scripts/governance/generate-ci-runtime-inventory.py"

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
        help="Output file path (defaults to ci_runtime_inventory.generated_file)",
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
    inventory = payload.get("ci_runtime_inventory") or {}
    generated_file = inventory.get("generated_file")
    if not isinstance(generated_file, str) or not generated_file:
        raise SystemExit("ci_runtime_inventory.generated_file must be a non-empty string")

    output_path = (repo_root / generated_file).resolve() if args.out is None else args.out.resolve()
    categories = normalize_categories(payload)
    entries = normalize_entries(payload, repo_root, {item["key"] for item in categories})
    rendered = render_inventory(
        categories,
        entries,
        registry_path.relative_to(repo_root),
        default_generator.relative_to(repo_root),
    )

    if args.write:
        output_path.write_text(rendered, encoding="utf-8")
        print(f"WROTE: {output_path}")
        return 0

    if args.check:
        return check_current(rendered, output_path)

    report = build_report(entries=entries, categories=categories, registry_path=registry_path.relative_to(repo_root), output_path=output_path.relative_to(repo_root))
    print_report(report, args.format, args.show_entries)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
