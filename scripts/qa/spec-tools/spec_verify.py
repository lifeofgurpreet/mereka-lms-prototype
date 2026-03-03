#!/usr/bin/env python3
"""spec_verify.py

Machine-verifies that specs are enforceable via @covers annotations.

Checks:
- AC IDs are stable and unique
- Each AC has @covers annotation in source OR manual entry
- Referenced files exist
- Optional: --run executes verification commands

Usage:
  python3 spec_verify.py specs/ --scan-dirs tests/ scripts/ --repo-root .
  python3 spec_verify.py specs/ --scan-dirs tests/ scripts/ --manual-file specs/manual_verifications.yaml
"""

from __future__ import annotations

import argparse
import re
import shlex
import subprocess
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML required: pip install pyyaml") from exc

COVERS_RE = re.compile(r"(?://|#)\s*@covers\s+((?:AC-[A-Z]*-?\d+(?:\s*,\s*)*)+)")
SPEC_RE = re.compile(r"(?://|#)\s*@spec:\s*(\S+)")
AC_ID_RE = re.compile(r"\b(AC-(?:[A-Z]+-)?(\d{3,}))\b")
SCAN_EXTENSIONS = {".sh", ".py", ".ts", ".js", ".tsx", ".jsx", ".yaml", ".yml"}


def find_markdown_files(p: Path) -> list[Path]:
    if p.is_file():
        return [p]
    return sorted(x for x in p.rglob("*.md") if x.is_file())


def parse_acceptance_criteria(md: str) -> list[tuple[str, str]]:
    """Extract AC IDs + line text from checkbox lines."""
    out: list[tuple[str, str]] = []
    for line in md.splitlines():
        if line.strip().startswith(("- [ ]", "* [ ]")):
            m = AC_ID_RE.search(line)
            if m:
                out.append((m.group(1), line.strip()))
    return out


def is_spec_like(path: Path) -> bool:
    name = path.name.lower()
    parts = path.parts
    return (
        "spec" in name
        or name.endswith(".spec.md")
        or "_spec" in name
        or "specs" in parts
    )


def scan_file_for_covers(path: Path) -> dict[str, str]:
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


def scan_dirs_for_covers(dirs: list[Path]) -> dict[str, list[Path]]:
    """Scan directories for @covers annotations.

    Returns {(spec_name, ac_id) as 'spec_name::ac_id': [file_paths]}.
    Also stores unkeyed ac_id entries for backward compat.
    """
    result: dict[str, list[Path]] = {}
    for d in dirs:
        if not d.exists():
            continue
        for f in sorted(d.rglob("*")):
            if not f.is_file() or f.suffix not in SCAN_EXTENSIONS:
                continue
            covers = scan_file_for_covers(f)
            for ac_id, spec_name in covers.items():
                # Store both scoped and unscoped keys
                if spec_name:
                    result.setdefault(f"{spec_name}::{ac_id}", []).append(f)
                result.setdefault(ac_id, []).append(f)
    return result


def ac_is_covered(ac_id: str, spec_filename: str, index: dict[str, list[Path]]) -> bool:
    """Check if an AC is covered, using spec-scoped matching for non-prefixed IDs."""
    has_prefix = bool(re.match(r"AC-[A-Z]+-\d+", ac_id))
    if has_prefix:
        # Globally unique — any match
        return ac_id in index
    # Non-prefixed — prefer spec-scoped match
    scoped_key = f"{spec_filename}::{ac_id}"
    if scoped_key in index:
        return True
    # Fall back to unscoped only if no spec annotation existed
    if ac_id in index:
        # Check if all files covering this AC are unscoped (no @spec:)
        for f in index[ac_id]:
            covers = scan_file_for_covers(f)
            if ac_id in covers and not covers[ac_id]:
                return True
    return False


def get_covered_files(ac_id: str, spec_filename: str, index: dict[str, list[Path]]) -> list[Path]:
    """Get files that cover an AC for a specific spec."""
    has_prefix = bool(re.match(r"AC-[A-Z]+-\d+", ac_id))
    if has_prefix:
        return index.get(ac_id, [])
    scoped_key = f"{spec_filename}::{ac_id}"
    if scoped_key in index:
        return index[scoped_key]
    return []


def load_manual_verifications(
    manual_file: Path | None, spec_name: str
) -> dict[str, dict]:
    """Load manual/monitoring entries for a spec."""
    if not manual_file or not manual_file.exists():
        return {}
    data = yaml.safe_load(manual_file.read_text(encoding="utf-8")) or {}
    entries = data.get("entries", [])
    result: dict[str, dict] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        entry_spec = entry.get("spec", "")
        if spec_name in entry_spec or entry_spec in spec_name:
            result[entry["id"]] = entry
    return result


def load_testmap_verifications(repo_root: Path, spec_path: Path) -> dict[str, dict]:
    """Load AC verification entries from specs/testmaps/<spec>.testmap.y*ml."""
    testmaps_dir = repo_root / "specs" / "testmaps"
    candidates = [
        testmaps_dir / f"{spec_path.stem}.testmap.yml",
        testmaps_dir / f"{spec_path.stem}.testmap.yaml",
    ]
    testmap_file = next((p for p in candidates if p.exists()), None)
    if not testmap_file:
        return {}

    data = yaml.safe_load(testmap_file.read_text(encoding="utf-8")) or {}
    ac_entries = data.get("acceptance_criteria", [])
    result: dict[str, dict] = {}
    for entry in ac_entries:
        if not isinstance(entry, dict):
            continue
        ac_id = entry.get("id")
        if not ac_id:
            continue
        result[str(ac_id)] = entry
    return result


def verify_one_spec(
    spec_path: Path,
    scan_dirs: list[Path],
    manual_file: Path | None,
    run: bool,
    repo_root: Path,
) -> list[str]:
    errors: list[str] = []
    md = spec_path.read_text(encoding="utf-8")

    acs = parse_acceptance_criteria(md)
    if not acs:
        errors.append("No Acceptance Criteria checkbox lines with AC-### IDs found.")
        return errors

    ids = [ac_id for ac_id, _ in acs]
    if len(set(ids)) != len(ids):
        errors.append("Duplicate Acceptance Criteria IDs found.")
        return errors

    automated = scan_dirs_for_covers(scan_dirs)
    manual_entries = load_manual_verifications(manual_file, spec_path.name)
    # Treat testmap AC entries as accepted verification mappings.
    # This keeps spec_verify aligned with spec/testmap-driven workflows.
    manual_entries.update(load_testmap_verifications(repo_root, spec_path))
    spec_filename = spec_path.name

    for ac_id, _ac_line in acs:
        is_covered = ac_is_covered(ac_id, spec_filename, automated)
        if not is_covered and ac_id not in manual_entries:
            errors.append(
                f"{ac_id} not covered by any @covers annotation or manual entry"
            )
            continue

        if is_covered:
            covered_files = get_covered_files(ac_id, spec_filename, automated)
            for fpath in covered_files:
                if not fpath.exists():
                    errors.append(f"{ac_id} references non-existent file: {fpath}")

            if run:
                for fpath in covered_files:
                    if fpath.suffix == ".sh":
                        cmd = str(fpath.relative_to(repo_root))
                    elif fpath.suffix == ".py":
                        cmd = f"pytest {fpath.relative_to(repo_root)}"
                    else:
                        continue
                    try:
                        res = subprocess.run(
                            shlex.split(cmd),
                            cwd=str(repo_root),
                            capture_output=True,
                            text=True,
                            check=False,
                            timeout=120,
                        )
                        if res.returncode != 0:
                            errors.append(
                                f"{ac_id} command failed (exit {res.returncode}): {cmd}\n"
                                f"STDERR: {res.stderr[:200]}"
                            )
                    except Exception as e:
                        errors.append(f"{ac_id} failed to execute {cmd}: {e}")

        if ac_id in manual_entries:
            me = manual_entries[ac_id]
            for v in me.get("verify", []):
                vtype = v.get("type", "")
                if vtype == "manual":
                    if not v.get("runbook") or not v.get("section"):
                        errors.append(
                            f"{ac_id} manual verification requires runbook + section."
                        )
                    if not v.get("justification"):
                        errors.append(
                            f"{ac_id} manual verification requires justification."
                        )
                    if v.get("runbook") and not (repo_root / v["runbook"]).exists():
                        errors.append(
                            f"{ac_id} references missing runbook: {v['runbook']}"
                        )
                elif vtype == "monitoring":
                    if not v.get("metric") and not v.get("dashboard"):
                        errors.append(
                            f"{ac_id} monitoring should include metric and/or dashboard."
                        )

    return errors


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Verify specs via @covers annotations."
    )
    ap.add_argument("path", type=str, help="Spec file or folder")
    ap.add_argument("--repo-root", type=str, default=".", help="Repo root")
    ap.add_argument(
        "--scan-dirs",
        nargs="+",
        default=["tests/", "scripts/"],
        help="Dirs to scan for @covers",
    )
    ap.add_argument(
        "--manual-file",
        type=str,
        default=None,
        help="Path to manual_verifications.yaml",
    )
    ap.add_argument(
        "--run", action="store_true", help="Execute verification commands"
    )
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    target = Path(args.path)
    if not target.exists():
        print(f"ERROR: path not found: {target}")
        return 2

    scan_dirs = [repo_root / d for d in args.scan_dirs]
    manual_file = Path(args.manual_file) if args.manual_file else None
    if manual_file is None:
        default_manual = (repo_root / "specs" / "manual_verifications.yaml").resolve()
        if default_manual.exists():
            manual_file = default_manual

    files = find_markdown_files(target)
    spec_files = [f for f in files if is_spec_like(f)]

    if not spec_files:
        print("No spec-like markdown files found.")
        return 0

    any_errors = False
    for f in spec_files:
        errs = verify_one_spec(f, scan_dirs, manual_file, args.run, repo_root)
        if errs:
            any_errors = True
            print(f"\nFAIL {f}")
            for e in errs:
                print("  - " + e.replace("\n", "\n    "))
        else:
            print(f"PASS {f}")

    return 1 if any_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
