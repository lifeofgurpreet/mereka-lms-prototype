#!/usr/bin/env python3
"""run_spec_compliance.py — Execute automated testmap commands and report pass/fail.

Reads all testmaps, finds automated verify entries with existing files,
executes their commands, and reports which ACs actually PASS vs FAIL.

Commands are classified as:
- repo-local: Can run without cluster/cloud (grep, bash scripts on local files)
- infra-dependent: Needs kubectl, curl to live services, Infisical, gh CLI, etc.

Usage:
  # Run only repo-local commands (safe, no infra needed)
  python3 scripts/qa/spec-tools/run_spec_compliance.py --mode local

  # Run all commands (needs live cluster)
  python3 scripts/qa/spec-tools/run_spec_compliance.py --mode all

  # Dry run — show what would execute
  python3 scripts/qa/spec-tools/run_spec_compliance.py --dry-run

  # JSON output
  python3 scripts/qa/spec-tools/run_spec_compliance.py --mode local --format json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML required: pip install pyyaml") from exc

# Patterns that indicate a command needs live infrastructure
INFRA_PATTERNS = [
    re.compile(r"\bkubectl\b"),
    re.compile(r"\bkubectl\s"),
    re.compile(r"\bcurl\s"),
    re.compile(r"\bgh\s"),
    re.compile(r"\binfisical\b"),
    re.compile(r"\bgcloud\b"),
    re.compile(r"\bdocker\s"),
    re.compile(r"\bhelm\b"),
    re.compile(r"\bargocd\b"),
    re.compile(r"https?://"),
    re.compile(r"\bport-forward\b"),
    re.compile(r"tutor_env/"),  # needs tutor env generated
]

TIMEOUT_SECONDS = 30


@dataclass
class VerifyResult:
    spec: str
    ac_id: str
    command: str
    file: str
    mode: str  # "local" or "infra"
    status: str = "pending"  # "pass", "fail", "skip", "timeout", "error"
    exit_code: int = -1
    duration_s: float = 0.0
    output_tail: str = ""


def classify_command(cmd: str) -> str:
    """Classify a command as 'local' or 'infra'."""
    for pat in INFRA_PATTERNS:
        if pat.search(cmd):
            return "infra"
    return "local"


def execute_command(cmd: str, repo_root: Path, timeout: int = TIMEOUT_SECONDS) -> tuple[int, float, str]:
    """Execute a command and return (exit_code, duration_s, tail_output)."""
    start = time.monotonic()
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "TERM": "dumb", "NO_COLOR": "1"},
        )
        duration = time.monotonic() - start
        output = (result.stdout + result.stderr).strip()
        tail = "\n".join(output.splitlines()[-5:]) if output else ""
        return result.returncode, duration, tail
    except subprocess.TimeoutExpired:
        duration = time.monotonic() - start
        return 124, duration, f"(timed out after {timeout}s)"
    except Exception as e:
        duration = time.monotonic() - start
        return 1, duration, str(e)


def collect_entries(testmaps_dir: Path, repo_root: Path) -> list[dict]:
    """Collect all automated verify entries with existing files."""
    entries = []
    for tm_file in sorted(testmaps_dir.glob("*.yaml")):
        with open(tm_file) as f:
            data = yaml.safe_load(f)
        if not data or "acceptance_criteria" not in data:
            continue

        spec_name = tm_file.stem.replace("_testmap", "")

        for ac in data["acceptance_criteria"]:
            ac_id = ac.get("id", "?")
            for v in ac.get("verify", []):
                if v.get("type") != "automated":
                    continue
                fpath = v.get("file", "")
                cmd = v.get("command", "").strip()
                if not cmd:
                    continue
                exists = os.path.exists(repo_root / fpath) if fpath else False
                if not exists:
                    continue
                entries.append({
                    "spec": spec_name,
                    "ac_id": str(ac_id),
                    "file": fpath,
                    "command": cmd,
                    "mode": classify_command(cmd),
                })
    return entries


def format_text(results: list[VerifyResult]) -> str:
    """Format results as text table."""
    lines = []

    # Group by spec
    specs: dict[str, list[VerifyResult]] = {}
    for r in results:
        specs.setdefault(r.spec, []).append(r)

    total = len(results)
    passed = sum(1 for r in results if r.status == "pass")
    failed = sum(1 for r in results if r.status == "fail")
    skipped = sum(1 for r in results if r.status == "skip")
    errors = sum(1 for r in results if r.status in ("timeout", "error"))

    lines.append("=== Spec Compliance Report ===")
    lines.append("")

    for spec_name in sorted(specs.keys()):
        spec_results = specs[spec_name]
        spec_pass = sum(1 for r in spec_results if r.status == "pass")
        spec_total = len(spec_results)
        lines.append(f"  {spec_name} ({spec_pass}/{spec_total} pass)")

        for r in spec_results:
            icon = {"pass": "PASS", "fail": "FAIL", "skip": "SKIP", "timeout": "T/O ", "error": "ERR "}
            status_str = icon.get(r.status, r.status.upper())
            cmd_short = r.command[:70] + ("..." if len(r.command) > 70 else "")
            lines.append(f"    {status_str}  {r.ac_id:<12s} {cmd_short}")
            if r.status == "fail" and r.output_tail:
                for tl in r.output_tail.splitlines()[:3]:
                    lines.append(f"           {tl[:100]}")

        lines.append("")

    lines.append("=== Summary ===")
    lines.append(f"Total: {total} | Pass: {passed} | Fail: {failed} | Skip: {skipped} | Error/Timeout: {errors}")
    if total - skipped > 0:
        pass_rate = passed / (total - skipped) * 100
        lines.append(f"Pass rate (executed): {pass_rate:.1f}% ({passed}/{total - skipped})")

    return "\n".join(lines)


def format_json_output(results: list[VerifyResult]) -> str:
    """Format results as JSON."""
    total = len(results)
    passed = sum(1 for r in results if r.status == "pass")
    failed = sum(1 for r in results if r.status == "fail")
    skipped = sum(1 for r in results if r.status == "skip")

    output = {
        "summary": {
            "total": total,
            "passed": passed,
            "failed": failed,
            "skipped": skipped,
            "pass_rate_executed": round(passed / (total - skipped) * 100, 1) if (total - skipped) > 0 else 0,
        },
        "results": [
            {
                "spec": r.spec,
                "ac_id": r.ac_id,
                "command": r.command,
                "file": r.file,
                "mode": r.mode,
                "status": r.status,
                "exit_code": r.exit_code,
                "duration_s": round(r.duration_s, 2),
            }
            for r in results
        ],
    }
    return json.dumps(output, indent=2)


def main() -> int:
    ap = argparse.ArgumentParser(description="Run automated testmap commands and report compliance.")
    ap.add_argument("--testmaps-dir", default="specs/testmaps/", help="Testmaps directory")
    ap.add_argument("--repo-root", default=".", help="Repo root")
    ap.add_argument("--mode", choices=["local", "infra", "all"], default="local",
                    help="Which commands to run: local (repo-only), infra (cluster-only), all")
    ap.add_argument("--dry-run", action="store_true", help="Show commands without executing")
    ap.add_argument("--format", choices=["text", "json"], default="text", help="Output format")
    ap.add_argument("--timeout", type=int, default=TIMEOUT_SECONDS, help="Per-command timeout (seconds)")
    ap.add_argument("--output", type=str, help="Write output to file")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    testmaps_dir = Path(args.testmaps_dir)

    entries = collect_entries(testmaps_dir, repo_root)
    if not entries:
        print("No automated entries with existing files found.")
        return 0

    # Deduplicate: same command might appear for multiple ACs
    seen_commands: set[str] = set()
    results: list[VerifyResult] = []

    for entry in entries:
        cmd = entry["command"]
        cmd_mode = entry["mode"]

        # Determine if we should run, skip, or just list
        should_run = False
        if args.mode == "all":
            should_run = True
        elif args.mode == "local" and cmd_mode == "local":
            should_run = True
        elif args.mode == "infra" and cmd_mode == "infra":
            should_run = True

        vr = VerifyResult(
            spec=entry["spec"],
            ac_id=entry["ac_id"],
            command=cmd,
            file=entry["file"],
            mode=cmd_mode,
        )

        if not should_run:
            vr.status = "skip"
            results.append(vr)
            continue

        if args.dry_run:
            vr.status = "skip"
            results.append(vr)
            continue

        # Skip duplicate commands (same command may verify multiple ACs)
        if cmd in seen_commands:
            # Find the previous result for this command
            for prev in results:
                if prev.command == cmd and prev.status != "skip":
                    vr.status = prev.status
                    vr.exit_code = prev.exit_code
                    vr.duration_s = 0
                    vr.output_tail = "(same command, result reused)"
                    break
            else:
                vr.status = "skip"
            results.append(vr)
            continue

        seen_commands.add(cmd)

        # Execute
        exit_code, duration, tail = execute_command(cmd, repo_root, timeout=args.timeout)
        vr.exit_code = exit_code
        vr.duration_s = duration
        vr.output_tail = tail

        if exit_code == 0:
            vr.status = "pass"
        elif exit_code == 124:
            vr.status = "timeout"
        else:
            vr.status = "fail"

        results.append(vr)

        # Progress indicator
        executed = sum(1 for r in results if r.status != "skip")
        total_to_run = sum(1 for e in entries if (args.mode == "all") or (args.mode == "local" and e["mode"] == "local") or (args.mode == "infra" and e["mode"] == "infra"))
        status_icon = "+" if vr.status == "pass" else "-" if vr.status == "fail" else "?"
        print(f"  [{executed}/{total_to_run}] {status_icon} {entry['ac_id']}: {cmd[:60]}...", file=sys.stderr)

    if args.format == "json":
        output = format_json_output(results)
    else:
        output = format_text(results)

    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(output + "\n")
        print(f"Report written to {args.output}")
    else:
        print(output)

    # Exit code: 0 if all executed tests pass, 1 if any fail
    failed = sum(1 for r in results if r.status in ("fail", "timeout", "error"))
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
