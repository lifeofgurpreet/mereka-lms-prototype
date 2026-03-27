#!/usr/bin/env python3
"""Batch runner for Kajabi → Open edX imports on Tutor K8s clusters."""

from __future__ import annotations

import argparse
import subprocess
import time
from pathlib import Path


def sh(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, **kwargs)


def capture(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()


def get_namespace(explicit: str | None) -> str:
    if explicit:
        return explicit
    return capture(["tutor", "config", "printvalue", "K8S_NAMESPACE"]) or "mereka-lms"


def get_pod(namespace: str, service: str) -> str:
    selector = f"app.kubernetes.io/name={service}"
    cmd = [
        "kubectl",
        "get",
        "pods",
        "-n",
        namespace,
        "-l",
        selector,
        "-o",
        "jsonpath={.items[0].metadata.name}",
    ]
    pod = capture(cmd)
    if not pod:
        raise SystemExit(f"No pod found for selector {selector} in {namespace}")
    return pod


def copy_file(namespace: str, pod: str, src: Path, dest: str) -> None:
    sh(["kubectl", "cp", str(src), f"{namespace}/{pod}:{dest}"])


def remote_cat(namespace: str, pod: str, path: str) -> str | None:
    try:
        out = capture(["kubectl", "exec", "-n", namespace, pod, "--", "cat", path])
        return out
    except subprocess.CalledProcessError:
        return None


def run_batch(
    namespace: str,
    pod: str,
    target: str,
    remote_csv: str,
    settings: str,
    state_file: str,
    offset: int,
    limit: int,
    logs_dir: Path,
) -> int:
    logs_dir.mkdir(parents=True, exist_ok=True)
    log_file = logs_dir / f"{target}_offset_{offset}.log"
    cmd = [
        "kubectl",
        "exec",
        "-n",
        namespace,
        pod,
        "--",
        "python",
        "/tmp/openedx_bulk_import.py",
        target,
        "--csv",
        remote_csv,
        "--settings",
        settings,
        "--offset",
        str(offset),
        "--limit",
        str(limit),
        "--state-file",
        state_file,
    ]
    with log_file.open("w", encoding="utf-8") as log:
        result = subprocess.run(cmd, stdout=log, stderr=log)
    if result.returncode != 0:
        raise RuntimeError(f"Batch starting at {offset} failed; see {log_file}")

    new_offset = remote_cat(namespace, pod, state_file)
    if not new_offset:
        raise SystemExit("State file missing after batch execution")
    return int(new_offset)


def count_rows(csv_path: Path) -> int:
    with csv_path.open(encoding="utf-8") as handle:
        total = sum(1 for _ in handle) - 1
    return max(total, 0)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run batched Open edX imports")
    parser.add_argument("target", choices=["users", "enrollments"], help="Import type")
    parser.add_argument("--csv", required=True, help="Local CSV path")
    parser.add_argument(
        "--remote-csv",
        default=None,
        help="Destination path inside the LMS pod (default: /tmp/<filename>)",
    )
    parser.add_argument("--batch-size", type=int, default=1000)
    parser.add_argument("--settings", default="lms.envs.tutor.production")
    parser.add_argument("--namespace")
    parser.add_argument("--state-file", default=None)
    parser.add_argument("--log-dir", default="scripts/migrations/kajabi/logs")
    parser.add_argument("--skip-upload", action="store_true")
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--retry-delay", type=int, default=10, help="Seconds between retries")
    args = parser.parse_args()

    csv_path = Path(args.csv).resolve()
    if not csv_path.exists():
        raise SystemExit(f"CSV not found: {csv_path}")

    remote_csv = args.remote_csv or f"/tmp/{csv_path.name}"
    state_file = args.state_file or f"/tmp/{args.target}.offset"

    namespace = get_namespace(args.namespace)
    pod = get_pod(namespace, "lms")

    if not args.skip_upload:
        copy_file(namespace, pod, Path("scripts/migrations/kajabi/openedx_bulk_import.py"), "/tmp/openedx_bulk_import.py")
        copy_file(namespace, pod, csv_path, remote_csv)

    total = count_rows(csv_path)
    logs_dir = Path(args.log_dir)

    remote_offset = remote_cat(namespace, pod, state_file)
    offset = int(remote_offset) if remote_offset else 0

    print(f"Starting {args.target} import: total_rows={total} current_offset={offset}")

    while offset < total:
        remaining = total - offset
        batch = min(args.batch_size, remaining)
        print(f"→ Batch offset={offset} size={batch}")
        attempt = 0
        while True:
            try:
                offset = run_batch(
                    namespace,
                    pod,
                    args.target,
                    remote_csv,
                    args.settings,
                    state_file,
                    offset,
                    batch,
                    logs_dir,
                )
                print(f"  ✓ new offset {offset}")
                break
            except RuntimeError as exc:
                attempt += 1
                print(f"  ! {exc}")
                if attempt > args.retries:
                    raise
                print(f"    retrying in {args.retry_delay}s ({attempt}/{args.retries})")
                time.sleep(args.retry_delay)

    print("All batches completed")


if __name__ == "__main__":
    main()
