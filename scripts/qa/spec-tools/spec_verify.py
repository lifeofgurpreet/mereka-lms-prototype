#!/usr/bin/env python3
"""spec_verify.py

Machine-verifies that specs are enforceable.

Copied from team-skills: plugins/core/skills/specs-vs-docs/tools/spec_verify.py
"""

from __future__ import annotations

import argparse
import re
import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import yaml  # type: ignore
except Exception as e:  # pragma: no cover
    raise SystemExit("PyYAML not found. Install with: pip install pyyaml") from e


AC_ID_RE = re.compile(r"\bAC-(\d{3,})\b")


@dataclass
class VerifyEntry:
    type: str  # automated | monitoring | manual
    test_type: Optional[str] = None
    file: Optional[str] = None
    command: Optional[str] = None
    metric: Optional[str] = None
    dashboard: Optional[str] = None
    runbook: Optional[str] = None
    section: Optional[str] = None
    justification: Optional[str] = None


def find_markdown_files(p: Path) -> List[Path]:
    if p.is_file():
        return [p]
    return sorted([x for x in p.rglob("*.md") if x.is_file()])


def parse_acceptance_criteria(md: str) -> List[Tuple[str, str]]:
    """Extract AC IDs + line text from checkbox lines."""
    out: List[Tuple[str, str]] = []
    for line in md.splitlines():
        if line.strip().startswith(("- [ ]", "* [ ]")):
            m = AC_ID_RE.search(line)
            if m:
                out.append((f"AC-{m.group(1)}", line.strip()))
    return out


def load_testmap(path: Path) -> Dict:
    obj = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(obj, dict):
        raise ValueError("testmap must be a YAML mapping")
    return obj


def normalize_verify_entries(ac_item: Dict) -> List[VerifyEntry]:
    entries = ac_item.get("verify", [])
    if not isinstance(entries, list):
        raise ValueError("verify must be a list")
    out: List[VerifyEntry] = []
    for e in entries:
        if not isinstance(e, dict):
            raise ValueError("verify entry must be a mapping")
        out.append(
            VerifyEntry(
                type=str(e.get("type", "")).strip(),
                test_type=(str(e.get("test_type")).strip() if e.get("test_type") else None),
                file=(str(e.get("file")).strip() if e.get("file") else None),
                command=(str(e.get("command")).strip() if e.get("command") else None),
                metric=(str(e.get("metric")).strip() if e.get("metric") else None),
                dashboard=(str(e.get("dashboard")).strip() if e.get("dashboard") else None),
                runbook=(str(e.get("runbook")).strip() if e.get("runbook") else None),
                section=(str(e.get("section")).strip() if e.get("section") else None),
                justification=(str(e.get("justification")).strip() if e.get("justification") else None),
            )
        )
    return out


def is_spec_like(path: Path) -> bool:
    name = path.name.lower()
    parts = path.parts
    return "spec" in name or name.endswith(".spec.md") or "_spec" in name or "specs" in parts


def verify_one_spec(spec_path: Path, require_testmap: bool, run: bool, repo_root: Path) -> List[str]:
    errors: List[str] = []
    md = spec_path.read_text(encoding="utf-8")

    acs = parse_acceptance_criteria(md)
    if not acs:
        errors.append("No Acceptance Criteria checkbox lines with AC-### IDs found.")
        return errors

    ids = [ac_id for ac_id, _ in acs]
    if len(set(ids)) != len(ids):
        errors.append("Duplicate Acceptance Criteria IDs found.")
        return errors

    testmap_path = Path(str(spec_path) + ".testmap.yml")
    if not testmap_path.exists():
        if require_testmap:
            errors.append(f"Missing required testmap: {testmap_path}")
        return errors

    try:
        tm = load_testmap(testmap_path)
    except Exception as e:
        errors.append(f"Failed to parse testmap YAML: {e}")
        return errors

    ac_items = tm.get("acceptance_criteria", [])
    if not isinstance(ac_items, list):
        errors.append("testmap.acceptance_criteria must be a list")
        return errors

    tm_index: Dict[str, Dict] = {}
    for item in ac_items:
        if not isinstance(item, dict) or "id" not in item:
            errors.append("Each acceptance_criteria item must be a mapping with an 'id'")
            continue
        tm_index[str(item["id"]).strip()] = item

    for ac_id, ac_line in acs:
        if ac_id not in tm_index:
            errors.append(f"AC {ac_id} missing from testmap. Spec line: {ac_line}")
            continue

        try:
            entries = normalize_verify_entries(tm_index[ac_id])
        except Exception as e:
            errors.append(f"AC {ac_id} has invalid verify entries: {e}")
            continue

        if not entries:
            errors.append(f"AC {ac_id} has no verification entries in testmap.")
            continue

        for ve in entries:
            if ve.type not in ("automated", "monitoring", "manual"):
                errors.append(f"AC {ac_id} verify.type must be automated|monitoring|manual (got {ve.type!r}).")

            if ve.type == "automated":
                if not ve.command:
                    errors.append(f"AC {ac_id} automated verification missing command.")
                if ve.file:
                    f = (repo_root / ve.file).resolve()
                    if not f.exists():
                        errors.append(f"AC {ac_id} references missing test file: {ve.file}")
                if run and ve.command:
                    try:
                        res = subprocess.run(
                            shlex.split(ve.command),
                            cwd=str(repo_root),
                            capture_output=True,
                            text=True,
                            check=False,
                        )
                        if res.returncode != 0:
                            errors.append(
                                f"AC {ac_id} automated command failed (exit {res.returncode}): {ve.command}\n"
                                f"STDOUT:\n{res.stdout}\nSTDERR:\n{res.stderr}"
                            )
                    except Exception as e:
                        errors.append(f"AC {ac_id} failed to execute command {ve.command!r}: {e}")

            elif ve.type == "monitoring":
                if not ve.metric and not ve.dashboard:
                    errors.append(f"AC {ac_id} monitoring verification should include metric and/or dashboard.")

            elif ve.type == "manual":
                if not ve.runbook or not ve.section:
                    errors.append(f"AC {ac_id} manual verification requires runbook + section.")
                if not ve.justification:
                    errors.append(f"AC {ac_id} manual verification requires justification.")
                if ve.runbook and not (repo_root / ve.runbook).exists():
                    errors.append(f"AC {ac_id} references missing runbook file: {ve.runbook}")

    return errors


def main() -> int:
    ap = argparse.ArgumentParser(description="Verify that specs are machine-enforceable.")
    ap.add_argument("path", type=str, help="A spec file or a folder to scan for specs")
    ap.add_argument("--repo-root", type=str, default=".", help="Repo root for resolving relative paths")
    ap.add_argument("--require-testmap", action="store_true", help="Fail if <spec>.testmap.yml is missing")
    ap.add_argument("--run", action="store_true", help="Execute automated verification commands (best-effort)")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    target = Path(args.path)
    if not target.exists():
        print(f"ERROR: path not found: {target}")
        return 2

    files = find_markdown_files(target)
    spec_files = [f for f in files if is_spec_like(f)]

    if not spec_files:
        print("No spec-like markdown files found.")
        return 0

    any_errors = False
    for f in spec_files:
        errs = verify_one_spec(f, require_testmap=args.require_testmap, run=args.run, repo_root=repo_root)
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
