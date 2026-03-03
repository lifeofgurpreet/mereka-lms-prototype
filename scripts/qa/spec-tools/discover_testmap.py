#!/usr/bin/env python3
"""discover_testmap.py

Generate testmap YAML from @covers annotations in source files
plus manual_verifications.yaml for non-automated entries.

Usage:
  python3 discover_testmap.py --spec specs/feature_spec.md --scan-dirs scripts/ tests/
  python3 discover_testmap.py --all-specs specs/ --scan-dirs scripts/ tests/ --format summary
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML required: pip install pyyaml") from exc

COVERS_RE = re.compile(r"(?://|#)\s*@covers\s+((?:AC-[A-Z]*-?\d+(?:\s*,\s*)*)+)")
SPEC_RE = re.compile(r"(?://|#)\s*@spec:\s*(\S+)")
AC_ID_RE = re.compile(r"\b(AC-(?:[A-Z]+-)?(\d{3,}))\b")
SCAN_EXTENSIONS = {".sh", ".py", ".ts", ".js", ".tsx", ".jsx", ".yaml", ".yml"}


def parse_spec_acs(spec_path: Path) -> list[tuple[str, str]]:
    """Extract (ac_id, description) from spec checkbox lines."""
    content = spec_path.read_text(encoding="utf-8")
    acs = []
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith(("- [ ]", "* [ ]")):
            m = AC_ID_RE.search(line)
            if m:
                ac_id = m.group(1)
                desc_match = re.search(r"AC-[A-Z]*-?\d+:\s*(.+)", stripped)
                desc = desc_match.group(1).strip() if desc_match else stripped
                acs.append((ac_id, desc))
    return acs


def scan_file(path: Path) -> dict[str, str]:
    """Returns {ac_id: spec_name} for @covers in file."""
    try:
        content = path.read_text(encoding="utf-8")
    except Exception:
        return {}
    spec_name = None
    for m in SPEC_RE.finditer(content):
        spec_name = m.group(1)
    covers: dict[str, str] = {}
    for m in COVERS_RE.finditer(content):
        ids = [s.strip() for s in m.group(1).split(",") if s.strip()]
        for raw_id in ids:
            ac_match = AC_ID_RE.match(raw_id)
            if ac_match:
                covers[ac_match.group(1)] = spec_name or ""
    return covers


def scan_dirs(
    dirs: list[Path], spec_filter: str | None = None
) -> dict[str, list[Path]]:
    """Scan dirs for @covers. Optionally filter by spec name.

    Returns {ac_id: [file_paths]}
    """
    result: dict[str, list[Path]] = {}
    for d in dirs:
        if not d.exists():
            continue
        for f in sorted(d.rglob("*")):
            if not f.is_file() or f.suffix not in SCAN_EXTENSIONS:
                continue
            covers = scan_file(f)
            for ac_id, spec_name in covers.items():
                if spec_filter and spec_name and spec_filter not in spec_name:
                    continue
                result.setdefault(ac_id, []).append(f)
    return result


def load_manual_verifications(
    manual_file: Path | None, spec_name: str
) -> dict[str, dict]:
    """Load manual/monitoring entries for a spec from centralized file."""
    if not manual_file or not manual_file.exists():
        return {}
    data = yaml.safe_load(manual_file.read_text(encoding="utf-8")) or {}
    entries = data.get("entries", [])
    result: dict[str, dict] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        if entry.get("spec", "") == spec_name or spec_name in entry.get("spec", ""):
            result[entry["id"]] = entry
    return result


def infer_type(file_path: Path) -> str:
    """Infer verification type from file path."""
    if file_path.suffix == ".sh":
        return "shell_verification"
    if file_path.suffix == ".py" and "test" in file_path.name.lower():
        return "unit"
    if file_path.suffix in (".ts", ".tsx", ".js"):
        return "integration"
    return "automated"


def infer_command(file_path: Path, repo_root: Path) -> str:
    """Infer execution command from file path."""
    rel = file_path.relative_to(repo_root)
    if file_path.suffix == ".sh":
        return str(rel)
    if file_path.suffix == ".py":
        return f"pytest {rel}"
    return str(rel)


def generate_testmap(
    spec_path: Path,
    scan_directories: list[Path],
    manual_file: Path | None,
    repo_root: Path,
) -> dict:
    """Generate complete testmap for a spec."""
    acs = parse_spec_acs(spec_path)
    spec_name = spec_path.name

    automated = scan_dirs(scan_directories, spec_filter=spec_name)
    manual_entries = load_manual_verifications(manual_file, spec_name)

    ac_list = []
    unmapped = []

    for ac_id, desc in acs:
        entry: dict = {"id": ac_id, "description": desc}
        verify = []

        if ac_id in automated:
            for fpath in automated[ac_id]:
                verify.append(
                    {
                        "type": "automated",
                        "test_type": infer_type(fpath),
                        "file": str(fpath.relative_to(repo_root)),
                        "command": infer_command(fpath, repo_root),
                    }
                )

        if ac_id in manual_entries:
            me = manual_entries[ac_id]
            for v in me.get("verify", []):
                verify.append(v)

        if verify:
            entry["verify"] = verify
        else:
            unmapped.append(ac_id)
            entry["verify"] = []

        ac_list.append(entry)

    result: dict = {
        "spec": spec_name,
        "acceptance_criteria": ac_list,
    }

    if unmapped:
        result["_unmapped"] = unmapped

    return result


def format_summary(testmap: dict) -> str:
    """Format testmap as a summary."""
    acs = testmap.get("acceptance_criteria", [])
    total = len(acs)
    automated = sum(
        1
        for ac in acs
        if any(v.get("type") == "automated" for v in ac.get("verify", []))
    )
    manual = sum(
        1
        for ac in acs
        if any(v.get("type") == "manual" for v in ac.get("verify", []))
    )
    monitoring = sum(
        1
        for ac in acs
        if any(v.get("type") == "monitoring" for v in ac.get("verify", []))
    )
    unmapped = len(testmap.get("_unmapped", []))

    return (
        f"{testmap['spec']}: {total} ACs | "
        f"automated={automated} manual={manual} monitoring={monitoring} unmapped={unmapped}"
    )


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Generate testmap from @covers annotations."
    )
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--spec", type=str, help="Single spec file")
    group.add_argument(
        "--all-specs", type=str, help="Directory containing *_spec.md files"
    )
    ap.add_argument(
        "--scan-dirs", nargs="+", required=True, help="Directories to scan for @covers"
    )
    ap.add_argument(
        "--manual-file", type=str, default=None, help="Path to manual_verifications.yaml"
    )
    ap.add_argument("--repo-root", type=str, default=".", help="Repo root")
    ap.add_argument(
        "--format", choices=["yaml", "json", "summary"], default="yaml"
    )
    ap.add_argument(
        "--output", type=str, default=None, help="Output file (default: stdout)"
    )
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    scan_directories = [repo_root / d for d in args.scan_dirs]
    manual_file = Path(args.manual_file) if args.manual_file else None

    if args.spec:
        spec_files = [Path(args.spec)]
    else:
        specs_dir = Path(args.all_specs)
        spec_files = sorted(specs_dir.glob("*_spec.md"))

    if not spec_files:
        print("No spec files found.")
        return 0

    outputs = []
    for spec_path in spec_files:
        tm = generate_testmap(spec_path, scan_directories, manual_file, repo_root)

        if args.format == "summary":
            outputs.append(format_summary(tm))
        elif args.format == "yaml":
            outputs.append(
                yaml.dump(
                    tm,
                    default_flow_style=False,
                    sort_keys=False,
                    allow_unicode=True,
                )
            )
        elif args.format == "json":
            import json

            outputs.append(json.dumps(tm, indent=2))

    result = "\n---\n".join(outputs) if args.format == "yaml" else "\n".join(outputs)

    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(result + "\n", encoding="utf-8")
        print(f"Written to {args.output}")
    else:
        print(result)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
