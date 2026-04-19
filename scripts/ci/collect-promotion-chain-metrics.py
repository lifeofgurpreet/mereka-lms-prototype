#!/usr/bin/env python3
"""collect-promotion-chain-metrics.py — Aggregate S6.1 promotion-chain artifacts.

Enumerates workflow run artifacts matching ``promotion-chain-metrics-*`` from
both the app repo (mereka-lms) and the infra repo (bbi-infrastructure), downloads
each one, parses the JSONL records, groups them by release_unit_id, and computes
end-to-end latency and per-stage gaps.

Design principles (harder-path):
  - Do NOT approximate missing stages.  If argo_sync_finished is absent for a
    release unit, the cell shows "missing" — not a best-guess time.
  - Do NOT filter out partial rows.  A row with only app_merge + bbi_pr_opened
    is valuable signal (shows where the chain stalled).
  - Missing-stage pattern is a first-class output column (STALL_PATTERN).

Usage:
    python3 scripts/ci/collect-promotion-chain-metrics.py \\
        --since-days 7 \\
        --repo Biji-Biji-Initiative/mereka-lms \\
        --infra-repo Biji-Biji-Initiative/bbi-infrastructure \\
        --output var/ci/promotion-chain-summary.md \\
        --format markdown

Bead: mereka-lms-lb4c.6 (S6.1 — collect promotion chain timing)
Doctrine: docs/meta/standing-orders/ Rule 1 — surface truth, do not approximate.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import warnings
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any

# ── Constants ─────────────────────────────────────────────────────────────────

SCHEMA_VERSION = "promotion-chain/v1"

# Ordered stage list — defines the canonical conveyor sequence.
ORDERED_STAGES: list[str] = [
    "app_merge",
    "bbi_pr_opened",
    "bbi_pr_merged",
    "argo_sync_started",
    "argo_sync_finished",
    "pod_image_realized",
]

# Human-readable stage labels for markdown output.
STAGE_LABELS: dict[str, str] = {
    "app_merge":           "App Merge",
    "bbi_pr_opened":       "BBI PR Opened",
    "bbi_pr_merged":       "BBI PR Merged",
    "argo_sync_started":   "Argo Started",
    "argo_sync_finished":  "Argo Finished",
    "pod_image_realized":  "Pod Realized",
}

PRESENT_MARKER = "✓"
MISSING_MARKER = "missing"


# ── gh helpers ─────────────────────────────────────────────────────────────────

def _run_gh(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    """Run a ``gh`` CLI command, returning the completed process."""
    cmd = ["gh"] + args
    return subprocess.run(cmd, capture_output=True, text=True, check=check)


def _gh_api_paginate(endpoint: str) -> list[dict[str, Any]]:
    """Paginate through a gh API endpoint, returning merged list of items."""
    result = _run_gh(["api", "--paginate", endpoint])
    # gh --paginate with JSON array endpoints returns one JSON array per page,
    # possibly separated by newlines.  We join them carefully.
    items: list[dict[str, Any]] = []
    for chunk in result.stdout.strip().split("\n"):
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            parsed = json.loads(chunk)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, list):
            items.extend(parsed)
        elif isinstance(parsed, dict):
            # gh sometimes returns {workflow_runs: [...]} etc.
            for val in parsed.values():
                if isinstance(val, list):
                    items.extend(val)
                    break
    return items


# ── Artifact discovery ─────────────────────────────────────────────────────────

def _list_matching_runs(repo: str, since_days: int) -> list[dict[str, Any]]:
    """Return workflow runs from ``repo`` that are within ``since_days`` days."""
    endpoint = f"repos/{repo}/actions/runs?per_page=100&status=completed"
    try:
        runs = _gh_api_paginate(endpoint)
    except subprocess.CalledProcessError as exc:
        print(
            f"[collect] WARN: failed to list runs for {repo}: {exc.stderr.strip()}",
            file=sys.stderr,
        )
        return []

    cutoff = datetime.now(tz=timezone.utc).timestamp() - since_days * 86400
    recent: list[dict[str, Any]] = []
    for run in runs:
        created_at = run.get("created_at", "")
        try:
            ts = datetime.fromisoformat(created_at.rstrip("Z")).replace(
                tzinfo=timezone.utc
            )
            if ts.timestamp() >= cutoff:
                recent.append(run)
        except (ValueError, AttributeError):
            # Malformed timestamp — skip rather than crash.
            pass
    return recent


def _list_promotion_artifacts(repo: str, run_id: int) -> list[str]:
    """Return artifact names matching ``promotion-chain-metrics-*`` for a run."""
    endpoint = f"repos/{repo}/actions/runs/{run_id}/artifacts?per_page=100"
    try:
        result = _run_gh(["api", endpoint])
        data = json.loads(result.stdout)
        artifacts = data.get("artifacts", [])
        return [
            a["name"]
            for a in artifacts
            if a.get("name", "").startswith("promotion-chain-metrics-")
        ]
    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError):
        return []


def _download_artifact(repo: str, run_id: int, artifact_name: str, dest_dir: str) -> bool:
    """Download artifact into ``dest_dir``. Returns True on success."""
    try:
        _run_gh(
            [
                "run",
                "download",
                str(run_id),
                "--repo", repo,
                "--name", artifact_name,
                "--dir", dest_dir,
            ]
        )
        return True
    except subprocess.CalledProcessError as exc:
        print(
            f"[collect] WARN: could not download artifact '{artifact_name}' "
            f"(run {run_id}, repo {repo}): {exc.stderr.strip()}",
            file=sys.stderr,
        )
        return False


# ── JSONL parsing ──────────────────────────────────────────────────────────────

def _parse_jsonl_file(path: str) -> list[dict[str, Any]]:
    """Parse a JSONL file, returning valid promotion-chain/v1 records only.

    Malformed lines or wrong schema_version are skipped with a warning (never
    raises — missing data is the thing we are measuring, not a fatal error).
    """
    records: list[dict[str, Any]] = []
    try:
        with open(path, encoding="utf-8") as fh:
            for lineno, line in enumerate(fh, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError as exc:
                    warnings.warn(
                        f"[collect] skipping malformed JSON in {path}:{lineno}: {exc}",
                        stacklevel=2,
                    )
                    continue
                if not isinstance(obj, dict):
                    warnings.warn(
                        f"[collect] skipping non-object at {path}:{lineno}",
                        stacklevel=2,
                    )
                    continue
                if obj.get("schema_version") != SCHEMA_VERSION:
                    warnings.warn(
                        f"[collect] skipping record with "
                        f"schema_version={obj.get('schema_version')!r} "
                        f"(expected {SCHEMA_VERSION!r}) at {path}:{lineno}",
                        stacklevel=2,
                    )
                    continue
                if "stage" not in obj or "release_unit_id" not in obj or "epoch_ms" not in obj:
                    warnings.warn(
                        f"[collect] skipping record missing required fields at {path}:{lineno}",
                        stacklevel=2,
                    )
                    continue
                records.append(obj)
    except OSError as exc:
        warnings.warn(f"[collect] could not read {path}: {exc}", stacklevel=2)
    return records


def _walk_jsonl_in_dir(root: str) -> list[dict[str, Any]]:
    """Recursively find all .jsonl files under ``root`` and parse them."""
    records: list[dict[str, Any]] = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for fname in filenames:
            if fname.endswith(".jsonl"):
                records.extend(_parse_jsonl_file(os.path.join(dirpath, fname)))
    return records


# ── Aggregation ───────────────────────────────────────────────────────────────

def _aggregate(records: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """Group records by release_unit_id and pick the earliest epoch_ms per stage.

    When multiple records exist for the same (release_unit_id, stage) — e.g.
    because the workflow was re-run — we keep the earliest epoch_ms, which
    represents the first time the stage was observed.

    Returns a dict: release_unit_id → {stage → record, ...}
    """
    groups: dict[str, dict[str, dict[str, Any]]] = defaultdict(dict)
    for rec in records:
        uid = rec["release_unit_id"]
        stage = rec["stage"]
        if stage not in ORDERED_STAGES:
            # Unknown stage — preserve but do not break the pipeline.
            warnings.warn(f"[collect] unknown stage {stage!r} for release {uid}", stacklevel=2)
            continue
        existing = groups[uid].get(stage)
        if existing is None or rec["epoch_ms"] < existing["epoch_ms"]:
            groups[uid][stage] = rec
    return dict(groups)


# ── Per-release metric computation ────────────────────────────────────────────

def _compute_metrics(uid: str, stage_records: dict[str, Any]) -> dict[str, Any]:
    """Compute derived metrics for one release_unit_id.

    Never approximates missing stages — only computes a value when the required
    stages are both present.  Absent stages yield None.
    """
    # Epoch ms per stage (None if the stage was not observed).
    stage_epochs: dict[str, int | None] = {
        s: stage_records[s]["epoch_ms"] if s in stage_records else None
        for s in ORDERED_STAGES
    }

    app_ms = stage_epochs["app_merge"]
    pod_ms = stage_epochs["pod_image_realized"]
    end_to_end_ms: int | None = None
    if app_ms is not None and pod_ms is not None:
        end_to_end_ms = pod_ms - app_ms

    # Per-stage-to-next gap (seconds).  Only computed when BOTH stages present.
    stage_gaps: dict[str, float | None] = {}
    for i in range(len(ORDERED_STAGES) - 1):
        current = ORDERED_STAGES[i]
        nxt = ORDERED_STAGES[i + 1]
        cur_ms = stage_epochs[current]
        nxt_ms = stage_epochs[nxt]
        key = f"{current}_to_{nxt}_s"
        if cur_ms is not None and nxt_ms is not None:
            stage_gaps[key] = round((nxt_ms - cur_ms) / 1000, 1)
        else:
            stage_gaps[key] = None

    missing_stages = [s for s in ORDERED_STAGES if s not in stage_records]

    # Stall-pattern classification — first-class signal for operators.
    if not missing_stages:
        stall_pattern = "all-present"
    else:
        # Find the last present stage then describe where the chain stalled.
        last_present: str | None = None
        for s in ORDERED_STAGES:
            if s in stage_records:
                last_present = s
            else:
                break
        if last_present is None:
            stall_pattern = "only-app_merge-expected-but-absent"
        else:
            stall_pattern = f"stalled-after-{last_present}"

    # ISO timestamp from the earliest stage (app_merge if present, else first seen).
    first_ts: str = ""
    for s in ORDERED_STAGES:
        if s in stage_records:
            first_ts = stage_records[s].get("timestamp_utc", "")
            break

    return {
        "release_unit_id": uid,
        "first_seen_utc": first_ts,
        "stage_epochs": stage_epochs,
        "end_to_end_ms": end_to_end_ms,
        "stage_gaps": stage_gaps,
        "missing_stages": missing_stages,
        "stall_pattern": stall_pattern,
        "stages_present": [s for s in ORDERED_STAGES if s in stage_records],
    }


# ── Output formatting ─────────────────────────────────────────────────────────

def _fmt_ms(ms: int | None) -> str:
    """Format a millisecond duration as a human-readable string."""
    if ms is None:
        return "n/a"
    total_s = ms // 1000
    hours, rem = divmod(total_s, 3600)
    minutes, seconds = divmod(rem, 60)
    if hours:
        return f"{hours}h{minutes:02d}m{seconds:02d}s"
    if minutes:
        return f"{minutes}m{seconds:02d}s"
    return f"{seconds}s"


def _write_json(metrics: list[dict[str, Any]], path: str) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"schema_version": "promotion-chain-summary/v1", "releases": metrics}, fh, indent=2)
    print(f"[collect] JSON written: {path}", file=sys.stderr)


def _write_markdown(metrics: list[dict[str, Any]], path: str) -> None:
    """Write an operator-friendly markdown table.

    Columns:
      timestamp | release_unit_id[:12] | end-to-end | per-stage (✓/missing) | stall pattern | notes
    """
    lines: list[str] = []
    lines.append("# Promotion Chain Metrics Summary")
    lines.append("")
    lines.append(f"_Generated: {datetime.now(tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}_")
    lines.append("")

    if not metrics:
        lines.append("_No promotion-chain records found in the requested window._")
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        print(f"[collect] Markdown written: {path}", file=sys.stderr)
        return

    # Table header
    stage_cols = " | ".join(STAGE_LABELS[s] for s in ORDERED_STAGES)
    lines.append(
        f"| First Seen (UTC) | Release Unit | End-to-End | {stage_cols} | Stall Pattern |"
    )
    sep_cols = " | ".join(["---"] * (4 + len(ORDERED_STAGES)))
    lines.append(f"| {sep_cols} |")

    for m in sorted(metrics, key=lambda x: x.get("first_seen_utc", "")):
        uid = m["release_unit_id"]
        uid_short = uid[:12]
        ts = m.get("first_seen_utc", "")[:19].replace("T", " ") if m.get("first_seen_utc") else "unknown"
        e2e = _fmt_ms(m.get("end_to_end_ms"))
        stage_cells = []
        for s in ORDERED_STAGES:
            if s in m.get("stages_present", []):
                stage_cells.append(PRESENT_MARKER)
            else:
                stage_cells.append(MISSING_MARKER)
        stage_str = " | ".join(stage_cells)
        stall = m.get("stall_pattern", "")
        lines.append(f"| {ts} | `{uid_short}` | {e2e} | {stage_str} | {stall} |")

    lines.append("")
    lines.append("## Stage Gap Detail")
    lines.append("")
    lines.append("Per-stage transition times where both boundary stages were observed:")
    lines.append("")

    for m in sorted(metrics, key=lambda x: x.get("first_seen_utc", "")):
        uid = m["release_unit_id"]
        gaps = m.get("stage_gaps", {})
        present = m.get("stages_present", [])
        if len(present) < 2:
            continue
        lines.append(f"**`{uid[:12]}`** ({m.get('stall_pattern', '')})")
        for i in range(len(ORDERED_STAGES) - 1):
            a = ORDERED_STAGES[i]
            b = ORDERED_STAGES[i + 1]
            key = f"{a}_to_{b}_s"
            val = gaps.get(key)
            if val is not None:
                lines.append(f"  - {STAGE_LABELS[a]} → {STAGE_LABELS[b]}: **{val}s**")
        lines.append("")

    lines.append("---")
    lines.append(
        "_Missing stages are not approximated.  "
        "Partial rows indicate where the promotion chain stalled._"
    )
    lines.append("")
    lines.append(
        "_Doctrine: [Truth Repair Doctrine](../../docs/meta/standing-orders/) Rule 1 — "
        "surface truth, do not approximate._"
    )

    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"[collect] Markdown written: {path}", file=sys.stderr)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Aggregate S6.1 promotion-chain artifacts and compute conveyor latency."
    )
    parser.add_argument(
        "--since-days",
        type=int,
        default=7,
        metavar="N",
        help="How many days back to search for artifacts (default: 7)",
    )
    parser.add_argument(
        "--repo",
        default="Biji-Biji-Initiative/mereka-lms",
        metavar="OWNER/REPO",
        help="App repo to search (default: Biji-Biji-Initiative/mereka-lms)",
    )
    parser.add_argument(
        "--infra-repo",
        default="Biji-Biji-Initiative/bbi-infrastructure",
        metavar="OWNER/REPO",
        help="Infra repo to search (default: Biji-Biji-Initiative/bbi-infrastructure)",
    )
    parser.add_argument(
        "--output",
        required=True,
        metavar="PATH",
        help="Output file path (required)",
    )
    parser.add_argument(
        "--format",
        choices=["json", "markdown"],
        default="markdown",
        help="Output format: json or markdown (default: markdown)",
    )
    args = parser.parse_args()

    repos = [args.repo, args.infra_repo]
    all_records: list[dict[str, Any]] = []
    download_failures = 0

    with tempfile.TemporaryDirectory(prefix="pcc-artifacts-") as tmpdir:
        for repo in repos:
            print(f"[collect] scanning repo: {repo} (last {args.since_days} days)", file=sys.stderr)
            runs = _list_matching_runs(repo, args.since_days)
            print(f"[collect]   found {len(runs)} completed runs", file=sys.stderr)

            for run in runs:
                run_id = run.get("id")
                if not run_id:
                    continue
                artifact_names = _list_promotion_artifacts(repo, run_id)
                if not artifact_names:
                    continue
                print(
                    f"[collect]   run {run_id}: {len(artifact_names)} promotion-chain artifact(s)",
                    file=sys.stderr,
                )
                for name in artifact_names:
                    dest = os.path.join(tmpdir, repo.replace("/", "_"), str(run_id), name)
                    os.makedirs(dest, exist_ok=True)
                    ok = _download_artifact(repo, run_id, name, dest)
                    if ok:
                        found = _walk_jsonl_in_dir(dest)
                        print(
                            f"[collect]     {name}: {len(found)} record(s)",
                            file=sys.stderr,
                        )
                        all_records.extend(found)
                    else:
                        download_failures += 1

    print(
        f"[collect] total records parsed: {len(all_records)} "
        f"(download failures: {download_failures})",
        file=sys.stderr,
    )

    # ── Aggregate ────────────────────────────────────────────────────────────
    groups = _aggregate(all_records)
    metrics = [_compute_metrics(uid, stage_records) for uid, stage_records in groups.items()]
    metrics.sort(key=lambda x: x.get("first_seen_utc", ""))

    print(
        f"[collect] unique release units: {len(metrics)}",
        file=sys.stderr,
    )

    # ── Write output ─────────────────────────────────────────────────────────
    if args.format == "json":
        _write_json(metrics, args.output)
    else:
        _write_markdown(metrics, args.output)

    # Missing artifacts are NOT an error — they are the thing we are measuring.
    # We exit 1 only on catastrophic gh failures.
    if download_failures > 0 and len(all_records) == 0:
        print(
            "[collect] WARN: all artifact downloads failed and no records were parsed. "
            "Check gh authentication and repo permissions.",
            file=sys.stderr,
        )
        # Still exit 0 — the collector is observability-only; it must never gate work.
        # A completely empty run is a warning, not a blocker.

    return 0


if __name__ == "__main__":
    sys.exit(main())
