#!/usr/bin/env python3
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

LEGACY_PAT = re.compile(r"^(bd-|mereka-(?!lms))")


def parse_args():
    p = argparse.ArgumentParser(
        description=(
            "Validate and preview tracker legacy-ID normalization without "
            "touching the source tracker."
        )
    )
    p.add_argument("repo_root", help="Repo root containing .beads/issues.jsonl")
    p.add_argument(
        "--map",
        dest="map_path",
        default=None,
        help=(
            "Path to TRACKER-LEGACY-ID-NORMALIZATION-MAP.json. "
            "Defaults to docs/status/active/TRACKER-LEGACY-ID-NORMALIZATION-MAP.json "
            "under repo_root."
        ),
    )
    p.add_argument(
        "--write-dir",
        default=None,
        help=(
            "Optional directory for preview outputs: normalized-issues.jsonl, "
            "archived-issues.jsonl, and summary.json."
        ),
    )
    return p.parse_args()


def load_jsonl(path: Path):
    rows = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as e:
            raise SystemExit(f"error: invalid JSONL at {path}:{lineno}: {e}") from e
        rows.append(obj)
    return rows


def main():
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    jsonl_path = repo_root / ".beads" / "issues.jsonl"
    if not jsonl_path.exists():
        raise SystemExit(f"error: missing tracker JSONL at {jsonl_path}")

    map_path = Path(args.map_path).resolve() if args.map_path else (
        repo_root / "docs" / "status" / "active" / "TRACKER-LEGACY-ID-NORMALIZATION-MAP.json"
    )
    if not map_path.exists():
        raise SystemExit(f"error: missing normalization map at {map_path}")

    rows = load_jsonl(jsonl_path)
    map_obj = json.loads(map_path.read_text(encoding="utf-8"))
    entries = {entry["old_id"]: entry for entry in map_obj["entries"]}

    legacy_rows = [row for row in rows if LEGACY_PAT.match(row.get("id", ""))]
    legacy_ids = [row["id"] for row in legacy_rows]

    missing_from_map = [iid for iid in legacy_ids if iid not in entries]
    missing_from_jsonl = [iid for iid in entries if iid not in set(legacy_ids)]
    if missing_from_map:
        print("error: unmapped legacy IDs found in JSONL:", file=sys.stderr)
        for iid in missing_from_map:
            print(f"  - {iid}", file=sys.stderr)
        raise SystemExit(1)
    if missing_from_jsonl:
        print("error: map contains IDs not present in JSONL:", file=sys.stderr)
        for iid in missing_from_jsonl:
            print(f"  - {iid}", file=sys.stderr)
        raise SystemExit(1)

    normalized_rows = []
    archived_rows = []
    actions = Counter()
    rename_targets = set()

    for row in rows:
        iid = row.get("id", "")
        entry = entries.get(iid)
        if not entry:
            normalized_rows.append(row)
            continue
        action = entry["action"]
        actions[action] += 1
        if action == "archive":
            archived_rows.append(row)
            continue
        if action == "rename":
            new_id = entry["new_id"]
            if new_id in rename_targets:
                raise SystemExit(f"error: duplicate rename target {new_id}")
            rename_targets.add(new_id)
            new_row = dict(row)
            new_row["id"] = new_id
            normalized_rows.append(new_row)
            continue
        raise SystemExit(f"error: unsupported action {action!r} for {iid}")

    normalized_ids = [row.get("id", "") for row in normalized_rows]
    duplicate_ids = [iid for iid, count in Counter(normalized_ids).items() if count > 1]
    if duplicate_ids:
        print("error: duplicate IDs after normalization:", file=sys.stderr)
        for iid in duplicate_ids:
            print(f"  - {iid}", file=sys.stderr)
        raise SystemExit(1)

    summary = {
        "repo_root": str(repo_root),
        "jsonl_path": str(jsonl_path),
        "map_path": str(map_path),
        "total_rows": len(rows),
        "legacy_rows": len(legacy_rows),
        "action_counts": dict(actions),
        "normalized_rows": len(normalized_rows),
        "archived_rows": len(archived_rows),
    }

    print("=== Tracker Legacy Normalization Preview ===")
    for key, value in summary.items():
        print(f"{key}: {value}")
    print("--- planned renames ---")
    for old_id in sorted(iid for iid, e in entries.items() if e["action"] == "rename"):
        print(f"{old_id} -> {entries[old_id]['new_id']}")
    print("--- planned archives ---")
    for old_id in sorted(iid for iid, e in entries.items() if e["action"] == "archive"):
        print(old_id)

    if args.write_dir:
        out_dir = Path(args.write_dir).resolve()
        out_dir.mkdir(parents=True, exist_ok=True)
        with (out_dir / "normalized-issues.jsonl").open("w", encoding="utf-8") as fh:
            for row in normalized_rows:
                fh.write(json.dumps(row, ensure_ascii=True) + "\n")
        with (out_dir / "archived-issues.jsonl").open("w", encoding="utf-8") as fh:
            for row in archived_rows:
                fh.write(json.dumps(row, ensure_ascii=True) + "\n")
        (out_dir / "summary.json").write_text(
            json.dumps(summary, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
        print(f"wrote_preview_dir: {out_dir}")


if __name__ == "__main__":
    main()
