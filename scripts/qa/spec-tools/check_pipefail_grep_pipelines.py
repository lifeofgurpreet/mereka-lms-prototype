#!/usr/bin/env python3
"""Detect pipefail-prone quiet grep pipelines in shell verifiers."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections.abc import Iterable, Sequence
from dataclasses import asdict, dataclass
from pathlib import Path

DEFAULT_SCAN_DIRS = ("scripts/qa", "scripts/infra", "scripts/lib")
STATIC_INVENTORIES = (".github/ci-scripts-static.txt", ".github/ci-scripts-static-shard-*.txt")
RUNTIME_INVENTORIES = (".github/ci-scripts-runtime.txt",)
PRODUCER_RE = re.compile(r"(^|[;&|({]\s*|then\s+|if\s+)!?\s*(echo|printf)\b")
GREP_COMMAND_RE = re.compile(r"^grep\s+(?P<options>(?:-[A-Za-z]+\s+|--[A-Za-z0-9-]+(?:=[^\s]+)?\s+)*)")


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    classification: str
    text: str


def strip_inline_comment(line: str) -> str:
    in_single = False
    in_double = False
    escaped = False
    for index, char in enumerate(line):
        if escaped:
            escaped = False
            continue
        if char == "\\":
            escaped = True
            continue
        if char == "'" and not in_double:
            in_single = not in_single
            continue
        if char == '"' and not in_single:
            in_double = not in_double
            continue
        if char == "#" and not in_single and not in_double:
            return line[:index]
    return line


def has_pipefail(text: str) -> bool:
    return "pipefail" in text


def has_quiet_grep_pipeline(line: str) -> bool:
    candidate = strip_inline_comment(line).strip()
    if not candidate or candidate.startswith("#"):
        return False
    if "|" not in candidate or "$" not in candidate:
        return False
    producer, consumer = candidate.split("|", 1)
    if not PRODUCER_RE.search(producer):
        return False
    match = GREP_COMMAND_RE.match(consumer.strip())
    if not match:
        return False
    options = match.group("options").split()
    return any(option.startswith("-") and not option.startswith("--") and "q" in option for option in options)


def iter_shell_files(repo_root: Path, scan_dirs: Sequence[str]) -> Iterable[Path]:
    for scan_dir in scan_dirs:
        root = repo_root / scan_dir
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.sh")):
            if any(part in {".git", "node_modules", "tutor_env", "var"} for part in path.parts):
                continue
            yield path


def load_inventory_paths(repo_root: Path, patterns: Sequence[str]) -> set[str]:
    paths: set[str] = set()
    for pattern in patterns:
        for inventory in sorted(repo_root.glob(pattern)):
            for raw_line in inventory.read_text(encoding="utf-8").splitlines():
                line = raw_line.split("#", 1)[0].strip()
                if not line:
                    continue
                token = line.split()[0]
                if token.endswith(".sh"):
                    paths.add(token.removeprefix("./"))
    return paths


def classify_path(path: str, static_paths: set[str], runtime_paths: set[str]) -> str:
    if "/deprecated/" in path or path.startswith("scripts/qa/deprecated/"):
        return "deprecated"
    if path in static_paths:
        return "active_static_gate"
    if path in runtime_paths:
        return "active_runtime_gate"
    return "low_risk_helper"


def scan_repo(repo_root: Path, scan_dirs: Sequence[str] = DEFAULT_SCAN_DIRS) -> list[Finding]:
    static_paths = load_inventory_paths(repo_root, STATIC_INVENTORIES)
    runtime_paths = load_inventory_paths(repo_root, RUNTIME_INVENTORIES)
    findings: list[Finding] = []

    for path in iter_shell_files(repo_root, scan_dirs):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if not has_pipefail(text):
            continue
        rel_path = path.relative_to(repo_root).as_posix()
        classification = classify_path(rel_path, static_paths, runtime_paths)
        for line_number, line in enumerate(text.splitlines(), start=1):
            if has_quiet_grep_pipeline(line):
                findings.append(
                    Finding(
                        path=rel_path,
                        line=line_number,
                        classification=classification,
                        text=line.strip(),
                    )
                )
    return findings


def load_allowlist(path: Path | None) -> list[dict[str, str]]:
    if path is None:
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        records = data.get("allowlist", [])
    else:
        records = data
    if not isinstance(records, list):
        raise SystemExit(f"allowlist must be a JSON list: {path}")
    return records


def is_allowed(finding: Finding, allowlist: Sequence[dict[str, str]]) -> bool:
    for record in allowlist:
        if record.get("path") != finding.path:
            continue
        if record.get("classification") not in (None, finding.classification):
            continue
        match = record.get("match")
        if match and match not in finding.text:
            continue
        return True
    return False


def summarize(findings: Sequence[Finding]) -> dict[str, int]:
    summary = {
        "total": len(findings),
        "active_static_gate": 0,
        "active_runtime_gate": 0,
        "deprecated": 0,
        "low_risk_helper": 0,
    }
    for finding in findings:
        summary[finding.classification] += 1
    return summary


def parse_fail_on(value: str) -> set[str]:
    if value == "all":
        return {"active_static_gate", "active_runtime_gate", "deprecated", "low_risk_helper"}
    return {item.strip() for item in value.split(",") if item.strip()}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--scan-dir", action="append", dest="scan_dirs")
    parser.add_argument("--allowlist", type=Path)
    parser.add_argument("--fail-on", default="active_static_gate")
    parser.add_argument("--inventory-only", action="store_true")
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    repo_root = args.repo_root.resolve()
    scan_dirs = tuple(args.scan_dirs or DEFAULT_SCAN_DIRS)
    allowlist = load_allowlist(args.allowlist)
    findings = scan_repo(repo_root, scan_dirs)
    unallowed = [finding for finding in findings if not is_allowed(finding, allowlist)]
    fail_classifications = parse_fail_on(args.fail_on)
    blockers = [] if args.inventory_only else [
        finding for finding in unallowed if finding.classification in fail_classifications
    ]
    payload = {
        "summary": summarize(findings),
        "unallowed_summary": summarize(unallowed),
        "blocker_count": len(blockers),
        "findings": [asdict(finding) for finding in findings],
        "blockers": [asdict(finding) for finding in blockers],
    }

    if args.json_output:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        summary = payload["summary"]
        print(
            "Inventory: "
            f"total={summary['total']} "
            f"active_static_gate={summary['active_static_gate']} "
            f"active_runtime_gate={summary['active_runtime_gate']} "
            f"deprecated={summary['deprecated']} "
            f"low_risk_helper={summary['low_risk_helper']}"
        )
        if blockers:
            print(
                "FAIL: unreviewed pipefail-prone quiet grep pipelines remain in "
                + ", ".join(sorted(fail_classifications))
            )
            for finding in blockers:
                print(f"{finding.path}:{finding.line}: {finding.text}")
        else:
            print("PASS: no unreviewed pipefail-prone quiet grep pipelines in blocking classes")

    return 1 if blockers else 0


if __name__ == "__main__":
    sys.exit(main())
