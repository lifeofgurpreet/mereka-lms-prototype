#!/usr/bin/env python3
"""score-tier-a-scripts.py — emit 5-axis first-class scorecard as JSON.

Computes the Script First-Class Program scorecard (introduced in
docs/ops/evidence/script-first-class-tier-0-discovery-2026-04-18.md) as
machine-readable JSON. Phase 1 scope: 10 hardcoded Tier-A scripts from the
Phase 0 evidence bundle. Phase 2 (future) auto-discovers Tier-A membership
from the governance census.

Bead: mereka-lms-q69f.4

The 5 axes, each scored 0 (no), 0.5 (weak), or 1 (yes) — max 5.0:

  1. ci_reachable       — Is the script referenced by a file under
                          .github/workflows/*.yml?
  2. self_test_present  — Does scripts/qa/test-<basename>.sh exist and get
                          invoked somewhere (registry, another test, CI)?
  3. runbook_mapped     — Is the script named as an action step in a
                          docs/ops/runbooks/*.md file?
  4. manifest_strict    — Is the script in script-registry.yaml's
                          ci_static_inventory.entries? (STRICT registration)
                          Fall back to ALLOWLIST (0.5) if present in
                          verify-script-reachability-allowlist.json or
                          script-governance-active-unregistered-allowlist.txt.
                          NONE → 0.
  5. fresh_modification — Last commit within LAST_MOD_THRESHOLD_DAYS (30d
                          default) gets 1.0; 90d gets 0.5; older gets 0.

Usage:
  python3 scripts/governance/score-tier-a-scripts.py
  python3 scripts/governance/score-tier-a-scripts.py --json
  python3 scripts/governance/score-tier-a-scripts.py --threshold 3.5
  python3 scripts/governance/score-tier-a-scripts.py --auto-discover  # Phase 2

Phase 2 auto-discovery criteria:
  A script is Tier-A when the governance catalog reports:
    - status == "inventory_authoritative" (registered in script-registry.yaml)
    - "github" in caller_types (CI-reachable)
    - path matches scripts/governance/, scripts/qa/verify-*, or scripts/ci/
  The catalog is regenerated on demand via
  scripts/qa/generate-script-governance-catalog.py.

Exit codes:
  0  success (and, if --threshold given, all scripts meet/exceed it)
  1  at least one script below threshold (only if --threshold given)
  2  usage or environment error

Refs:
  - Evidence: docs/ops/evidence/script-first-class-tier-0-discovery-2026-04-18.md
  - Doctrine Rule 4: helpers ship with call site OR wire-in bead
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

LAST_MOD_THRESHOLD_FRESH_DAYS = 30
LAST_MOD_THRESHOLD_STALE_DAYS = 90

# Phase 1 hardcoded Tier-A shortlist. Matches the 10 scripts in the Phase 0
# evidence bundle. Phase 2 will auto-discover this from the governance
# census, removing the hardcode.
TIER_A_SCRIPTS = [
    "scripts/governance/generate-current-operator-state.sh",
    "scripts/governance/validate-registry.sh",
    "scripts/governance/generate-ci-static-inventory.py",
    "scripts/governance/generate-ci-runtime-inventory.py",
    "scripts/ci/emit-promotion-chain-metrics.sh",
    "scripts/ci/run-with-retry.sh",
    "scripts/qa/verify-pods-on-digest.sh",
    "scripts/governance/verify-runbook-executable.sh",
    "scripts/governance/verify-retraction-sweep.sh",
    "scripts/qa/audit-velero.sh",
]


def repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True,
    )
    return Path(out.stdout.strip())


def workflow_files(root: Path) -> list[Path]:
    wf_dir = root / ".github" / "workflows"
    if not wf_dir.is_dir():
        return []
    return sorted(wf_dir.glob("*.yml"))


def score_ci_reachable(root: Path, script: str) -> float:
    # Check direct references in workflow YAML
    for wf in workflow_files(root):
        try:
            if script in wf.read_text(encoding="utf-8"):
                return 1.0
        except UnicodeDecodeError:
            continue
    # Check inventory shard files (scripts dispatched via run-scripts-parallel.sh)
    inventory_files = [
        root / ".github" / "ci-scripts-static.txt",
        root / ".github" / "ci-scripts-runtime.txt",
    ]
    inventory_files.extend(sorted((root / ".github").glob("ci-scripts-static-shard-*.txt")))
    for inv in inventory_files:
        if inv.is_file():
            try:
                for line in inv.read_text(encoding="utf-8").splitlines():
                    # Strip inline comments — shard files use "path  # comment"
                    # Inventory lines: "path [args]  # comment"
                    # Strip comment, then take the first whitespace-separated
                    # token — args after the script path don't change the path.
                    token = line.split("#", 1)[0].strip().split()
                    if token and token[0] == script:
                        return 1.0
            except UnicodeDecodeError:
                continue
    # Check composite actions
    actions_dir = root / ".github" / "actions"
    if actions_dir.is_dir():
        for act in actions_dir.rglob("action.yml"):
            try:
                if script in act.read_text(encoding="utf-8"):
                    return 1.0
            except UnicodeDecodeError:
                continue
    return 0.0


def score_self_test(root: Path, script: str) -> float:
    base = Path(script).stem
    # Strip known verifier prefixes to find the canonical test name.
    # Accepted forms:
    #   scripts/qa/test-<base>.sh
    #   scripts/qa/test-<base-without-verify-prefix>.sh
    candidates = [
        root / f"scripts/qa/test-{base}.sh",
    ]
    if base.startswith("verify-"):
        candidates.append(root / f"scripts/qa/test-{base}.sh")
    for c in candidates:
        if c.is_file():
            return 1.0
    # Weak-credit if any test-*.sh references this script by path
    for t in (root / "scripts/qa").glob("test-*.sh"):
        try:
            if script in t.read_text(encoding="utf-8"):
                return 0.5
        except UnicodeDecodeError:
            continue
    return 0.0


def score_runbook_mapped(root: Path, script: str) -> float:
    runbook_dir = root / "docs" / "ops" / "runbooks"
    if not runbook_dir.is_dir():
        return 0.0
    base = Path(script).name
    for rb in runbook_dir.rglob("*.md"):
        try:
            content = rb.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if script in content:
            return 1.0  # full path mentioned
        if base in content:
            return 0.5  # only basename — weaker but still runbook-aware
    return 0.0


def score_manifest(root: Path, script: str) -> tuple[float, str]:
    """Return (score, label) where label in {STRICT, ALLOWLIST, NONE}."""
    registry = root / "scripts/governance/script-registry.yaml"
    if registry.is_file():
        content = registry.read_text(encoding="utf-8")
        # Match "- script: <path>" under ci_static_inventory.entries
        if f"- script: {script}" in content:
            return (1.0, "STRICT")
    # Allowlist fallback
    allowlists = [
        root / "scripts/qa/fixtures/verify-script-reachability-allowlist.json",
        root / "scripts/qa/fixtures/script-governance-active-unregistered-allowlist.txt",
    ]
    for al in allowlists:
        if al.is_file():
            try:
                if script in al.read_text(encoding="utf-8"):
                    return (0.5, "ALLOWLIST")
            except UnicodeDecodeError:
                continue
    return (0.0, "NONE")


def score_fresh_modification(root: Path, script: str) -> tuple[float, int]:
    """Return (score, days_since_last_commit)."""
    full = root / script
    if not full.is_file():
        return (0.0, -1)
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "log", "-1", "--format=%ct", "--", script],
            capture_output=True, text=True, check=True,
        )
        ts = out.stdout.strip()
        if not ts:
            return (0.0, -1)
        import time
        age_days = int((time.time() - int(ts)) / 86400)
    except Exception:
        return (0.0, -1)
    if age_days <= LAST_MOD_THRESHOLD_FRESH_DAYS:
        return (1.0, age_days)
    if age_days <= LAST_MOD_THRESHOLD_STALE_DAYS:
        return (0.5, age_days)
    return (0.0, age_days)


def auto_discover_tier_a(root: Path) -> list[str]:
    """Phase 2 — derive Tier-A membership from the governance catalog.

    Criteria: inventory_authoritative status + github caller_types + path
    under scripts/governance/, scripts/qa/verify-*, or scripts/ci/.
    """
    import tempfile
    catalog_out = Path(tempfile.mkdtemp()) / "gov-cat.json"
    generator = root / "scripts/qa/generate-script-governance-catalog.py"
    if not generator.is_file():
        raise RuntimeError(
            f"auto-discover requires {generator} (generator not found)"
        )
    subprocess.run(
        ["python3", str(generator), "--repo-root", str(root),
         "--out", str(catalog_out), "--summary-out", "/dev/null"],
        check=True, capture_output=True,
    )
    d = json.loads(catalog_out.read_text(encoding="utf-8"))
    tier_a: list[str] = []
    for s in d.get("scripts", []):
        path = s.get("path", "")
        if s.get("status") != "inventory_authoritative":
            continue
        if "github" not in s.get("caller_types", []):
            continue
        if not (
            path.startswith("scripts/governance/")
            or path.startswith("scripts/qa/verify-")
            or path.startswith("scripts/ci/")
        ):
            continue
        tier_a.append(path)
    return sorted(tier_a)


def score_all(root: Path, script_list: list[str] | None = None) -> list[dict]:
    records = []
    for script in (script_list if script_list is not None else TIER_A_SCRIPTS):
        full = root / script
        exists = full.is_file()
        ci = score_ci_reachable(root, script) if exists else 0.0
        st = score_self_test(root, script) if exists else 0.0
        rb = score_runbook_mapped(root, script) if exists else 0.0
        mf, mf_label = score_manifest(root, script) if exists else (0.0, "MISSING")
        fm, fm_days = score_fresh_modification(root, script) if exists else (0.0, -1)
        total = ci + st + rb + mf + fm
        records.append({
            "script": script,
            "exists": exists,
            "ci_reachable": ci,
            "self_test_present": st,
            "runbook_mapped": rb,
            "manifest_registration": mf,
            "manifest_label": mf_label,
            "fresh_modification": fm,
            "days_since_last_commit": fm_days,
            "total_score": round(total, 1),
            "max_score": 5.0,
        })
    return records


def format_table(records: list[dict]) -> str:
    lines = []
    lines.append(
        f"{'script':<60} {'CI':>3} {'ST':>4} {'RB':>3} {'MAN':>5} {'FR':>3} {'TOTAL':>6}"
    )
    lines.append("-" * 95)
    for r in records:
        lines.append(
            f"{r['script']:<60} "
            f"{r['ci_reachable']:>3.1f} "
            f"{r['self_test_present']:>4.1f} "
            f"{r['runbook_mapped']:>3.1f} "
            f"{r['manifest_registration']:>5.1f} "
            f"{r['fresh_modification']:>3.1f} "
            f"{r['total_score']:>6.1f}"
        )
    lines.append("")
    total = sum(r["total_score"] for r in records)
    avg = total / len(records) if records else 0
    lines.append(
        f"AGGREGATE: mean={avg:.2f}/5  sum={total:.1f}/{len(records)*5.0:.0f}  n={len(records)}"
    )
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--json", action="store_true",
                    help="emit JSON instead of table")
    ap.add_argument("--threshold", type=float, default=None,
                    help="fail (exit 1) if any script scores below this threshold")
    ap.add_argument("--auto-discover", action="store_true",
                    help="Phase 2: derive Tier-A from governance catalog instead of hardcoded list")
    args = ap.parse_args()

    root = repo_root()
    if args.auto_discover:
        try:
            tier_a_list = auto_discover_tier_a(root)
        except Exception as exc:
            print(f"auto-discover failed: {exc}", file=sys.stderr)
            return 2
        print(f"AUTO-DISCOVERED {len(tier_a_list)} Tier-A scripts via governance catalog",
              file=sys.stderr)
        records = score_all(root, script_list=tier_a_list)
    else:
        records = score_all(root)

    if args.json:
        print(json.dumps(
            {
                "phase": 2 if args.auto_discover else 1,
                "discovery_mode": "auto" if args.auto_discover else "hardcoded",
                "records": records,
                "max_score": 5.0,
            },
            indent=2, sort_keys=True,
        ))
    else:
        print(format_table(records))

    if args.threshold is not None:
        below = [r for r in records if r["total_score"] < args.threshold]
        if below:
            print(f"\nFAIL: {len(below)} script(s) below threshold {args.threshold}:",
                  file=sys.stderr)
            for r in below:
                print(f"  {r['script']}: {r['total_score']}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
