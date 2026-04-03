#!/usr/bin/env python3
"""Compare a branch CI fail set to the current main baseline fail set."""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from collections import defaultdict
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
FAILURE_RE = re.compile(r"FAIL ((?:verify|test-verify|test-build|test-generate|audit)-[A-Za-z0-9._/-]+)")
SCHEMA_VERSION = "ci-failure-baseline/v1"


def git_remote_repo() -> str:
    output = subprocess.check_output(
        ["git", "config", "--get", "remote.origin.url"],
        cwd=REPO_ROOT,
        text=True,
    ).strip()
    if output.startswith("git@github.com:"):
        return output.removeprefix("git@github.com:").removesuffix(".git")
    if output.startswith("https://github.com/"):
        return output.removeprefix("https://github.com/").removesuffix(".git")
    raise SystemExit(f"Unsupported origin URL for GitHub repo detection: {output}")


def github_api_json(url: str, token: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read().decode("utf-8"))


def github_api_bytes(url: str, token: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(request) as response:
        return response.read()


def download_run_logs(repo: str, run_id: int, token: str, dest_dir: Path) -> None:
    archive_bytes = github_api_bytes(
        f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/logs",
        token,
    )
    with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp:
        tmp.write(archive_bytes)
        tmp_path = Path(tmp.name)
    try:
        with zipfile.ZipFile(tmp_path) as archive:
            archive.extractall(dest_dir)
    finally:
        tmp_path.unlink(missing_ok=True)


def fetch_run_jobs(repo: str, run_id: int, token: str) -> list[dict[str, Any]]:
    jobs: list[dict[str, Any]] = []
    page = 1
    while True:
        payload = github_api_json(
            f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/jobs?per_page=100&page={page}",
            token,
        )
        jobs.extend(payload.get("jobs", []))
        if not payload.get("jobs") or len(payload.get("jobs", [])) < 100:
            return jobs
        page += 1


def parse_failure_details(log_dir: Path, failed_jobs: list[str] | None = None) -> tuple[list[str], list[dict[str, Any]]]:
    failure_jobs = set(failed_jobs or [])
    by_id: dict[str, set[str]] = defaultdict(set)

    for log_file in sorted(log_dir.glob("*.txt")):
        job_name = log_file.stem
        text = log_file.read_text(encoding="utf-8", errors="ignore")
        for match in FAILURE_RE.finditer(text):
            by_id[match.group(1)].add(job_name)

    if failed_jobs:
        covered_jobs = {job for jobs in by_id.values() for job in jobs}
        for job_name in failure_jobs - covered_jobs:
            by_id[f"job::{job_name}"].add(job_name)

    failure_ids = sorted(by_id)
    details = [{"id": failure_id, "jobs": sorted(by_id[failure_id])} for failure_id in failure_ids]
    return failure_ids, details


def load_run_from_logs(
    *,
    run_id: int | None,
    head_sha: str | None,
    log_dir: Path,
    failed_jobs: list[str] | None = None,
) -> dict[str, Any]:
    failure_ids, failure_details = parse_failure_details(log_dir, failed_jobs)
    return {
        "run_id": run_id,
        "head_sha": head_sha,
        "failure_ids": failure_ids,
        "failed_jobs": sorted(failed_jobs or []),
        "failure_details": failure_details,
    }


def compute_decision(branch_run: dict[str, Any], baseline_run: dict[str, Any]) -> dict[str, Any]:
    branch_set = set(branch_run["failure_ids"])
    baseline_set = set(baseline_run["failure_ids"])
    new_failures = sorted(branch_set - baseline_set)
    resolved_failures = sorted(baseline_set - branch_set)
    shared_failures = sorted(branch_set & baseline_set)

    if not branch_set:
        decision = "clean"
    elif new_failures:
        decision = "blocked_on_branch_failures"
    else:
        decision = "mergeable_with_baseline_debt"

    return {
        "new_failures": new_failures,
        "resolved_failures": resolved_failures,
        "shared_failures": shared_failures,
        "decision": decision,
    }


def build_payload(
    *,
    repo: str,
    workflow: str,
    branch_run: dict[str, Any],
    baseline_run: dict[str, Any],
) -> dict[str, Any]:
    comparison = compute_decision(branch_run, baseline_run)
    return {
        "schema_version": SCHEMA_VERSION,
        "repo": repo,
        "workflow": workflow,
        "branch_run": branch_run,
        "baseline_run": baseline_run,
        **comparison,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=git_remote_repo())
    parser.add_argument("--workflow", default="CI")
    parser.add_argument("--branch-run-id", type=int)
    parser.add_argument("--branch-head-sha")
    parser.add_argument("--branch-log-dir", type=Path)
    parser.add_argument("--baseline-run-id", type=int)
    parser.add_argument("--baseline-head-sha")
    parser.add_argument("--baseline-log-dir", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--github-token-env", default="GITHUB_TOKEN")
    args = parser.parse_args()

    if not args.branch_run_id and not args.branch_log_dir:
        raise SystemExit("Provide --branch-run-id or --branch-log-dir")
    if not args.baseline_run_id and not args.baseline_log_dir:
        raise SystemExit("Provide --baseline-run-id or --baseline-log-dir")
    return args


def resolve_run(
    *,
    repo: str,
    run_id: int | None,
    head_sha: str | None,
    log_dir: Path | None,
    token: str | None,
) -> dict[str, Any]:
    failed_jobs: list[str] | None = None
    if run_id is not None:
        if token is None:
            raise SystemExit("Run-id mode requires a GitHub token")
        if log_dir is None:
            log_dir = Path(tempfile.mkdtemp(prefix=f"ci-run-{run_id}-"))
            download_run_logs(repo, run_id, token, log_dir)
        jobs = fetch_run_jobs(repo, run_id, token)
        failed_jobs = sorted(
            job["name"]
            for job in jobs
            if job.get("conclusion") == "failure"
        )
    assert log_dir is not None
    return load_run_from_logs(run_id=run_id, head_sha=head_sha, log_dir=log_dir, failed_jobs=failed_jobs)


def main() -> int:
    args = parse_args()
    token = os.environ.get(args.github_token_env) if (args.branch_run_id or args.baseline_run_id) else None

    branch_run = resolve_run(
        repo=args.repo,
        run_id=args.branch_run_id,
        head_sha=args.branch_head_sha,
        log_dir=args.branch_log_dir,
        token=token,
    )
    baseline_run = resolve_run(
        repo=args.repo,
        run_id=args.baseline_run_id,
        head_sha=args.baseline_head_sha,
        log_dir=args.baseline_log_dir,
        token=token,
    )
    payload = build_payload(
        repo=args.repo,
        workflow=args.workflow,
        branch_run=branch_run,
        baseline_run=baseline_run,
    )

    rendered = json.dumps(payload, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
        print(args.output)
        return 0

    sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
