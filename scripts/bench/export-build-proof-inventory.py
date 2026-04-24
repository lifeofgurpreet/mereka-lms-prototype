#!/usr/bin/env python3
"""Export a machine-readable inventory of local build proof artifacts."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def repo_root_from_path() -> Path:
    return Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export the local build proof inventory from benchmark metadata and the experiment board."
    )
    parser.add_argument(
        "--bench-root",
        default=".benchmarks",
        help="Benchmark root directory relative to repo root (default: .benchmarks)",
    )
    parser.add_argument(
        "--control-board",
        default="docs/status/active/UV_EXPERIMENT_CONTROL_BOARD_2026-04-10.md",
        help="Artifact verdict board relative to repo root",
    )
    parser.add_argument(
        "--format",
        choices=("json", "markdown"),
        default="json",
        help="Output format (default: json)",
    )
    return parser.parse_args()


def parse_meta(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in raw_line:
            continue
        key, value = raw_line.split("=", 1)
        data[key.strip()] = value.strip()
    return data


def parse_board_registry(path: Path) -> dict[str, dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    pattern = re.compile(
        r"^\|\s*`(?P<label>[^`]+)`\s*\|\s*(?P<benchmark_class>[^|]+?)\s*\|\s*(?P<verdict>[^|]+?)\s*\|\s*(?P<current_role>[^|]+?)\s*\|$"
    )
    for line in path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line.strip())
        if not match:
            continue
        rows[match.group("label")] = {
            "benchmark_class": match.group("benchmark_class").strip(),
            "verdict": match.group("verdict").strip(),
            "current_role": match.group("current_role").strip(),
        }
    return rows


def required_fields(data: dict[str, str], artifact_path: Path) -> list[str]:
    required = [
      "label",
      "target",
      "benchmark_class",
      "build_surface",
      "tutor_root",
      "output_mode",
      "rendered_dockerfile",
      "rendered_dockerfile_sha256",
      "plugin_mirror_dir",
      "plugin_mirror_sha256",
      "log",
    ]
    if artifact_path.parent.name == "bake" or data.get("build_surface") == "bake":
        required.extend(["bake_file", "bake_file_sha256"])
    return required


def proof_lane(benchmark_class: str) -> str:
    return {
        "proof-class": "local-proof-class-throughput",
        "cache-hot validation": "cache-hot-validation",
        "producer-class": "producer-class-substrate",
        "fast-class": "fast-class-substrate",
    }.get(benchmark_class, "unclassified")


def metadata_status(
    *,
    missing_fields: list[str],
    has_board_entry: bool,
) -> str:
    if not missing_fields:
        return "governed"
    if has_board_entry:
        return "legacy-grandfathered"
    return "invalid-incomplete"


def collect_artifacts(bench_root: Path, board_registry: dict[str, dict[str, str]]) -> list[dict[str, object]]:
    artifacts: list[dict[str, object]] = []
    for artifact_path in sorted(bench_root.glob("*/*.meta")):
        data = parse_meta(artifact_path)
        label = data.get("label") or artifact_path.stem.split("-", 1)[-1]
        board_row = board_registry.get(label, {})
        benchmark_class = data.get("benchmark_class") or board_row.get("benchmark_class", "unclassified")
        missing = [field for field in required_fields(data, artifact_path) if not data.get(field)]
        status = metadata_status(missing_fields=missing, has_board_entry=bool(board_row))

        artifacts.append(
            {
                "label": label,
                "artifact_path": artifact_path.relative_to(repo_root_from_path()).as_posix(),
                "artifact_family": artifact_path.parent.name,
                "benchmark_class": benchmark_class,
                "proof_lane": proof_lane(benchmark_class),
                "verdict": board_row.get("verdict", "unclassified"),
                "current_role": board_row.get("current_role", "unclassified"),
                "metadata_status": status,
                "missing_fields": missing,
                "duration_seconds": data.get("duration_seconds"),
                "exit_code": data.get("exit_code"),
                "start_iso": data.get("start_iso"),
                "end_iso": data.get("end_iso"),
                "target": data.get("target"),
                "measurement_mode": data.get("measurement_mode"),
                "build_surface": data.get("build_surface"),
                "output_mode": data.get("output_mode"),
                "build_profile": data.get("build_profile"),
                "custom_app_install_mode": data.get("custom_app_install_mode"),
                "webpack_seconds": data.get("webpack_seconds"),
                "collectstatic_seconds": data.get("collectstatic_seconds"),
                "docker_export_seconds": data.get("docker_export_seconds"),
                "docker_import_seconds": data.get("docker_import_seconds"),
                "cache_export_seconds": data.get("cache_export_seconds"),
                "rdfind_skip_observed": data.get("rdfind_skip_observed"),
                "log": data.get("log"),
            }
        )
    return artifacts


def render_markdown(report: dict[str, object]) -> str:
    lines = [
        "# Build Proof Inventory Export",
        "",
        f"- Bench root: `{report['bench_root']}`",
        f"- Control board: `{report['control_board']}`",
        "",
        "| Label | Benchmark class | Measurement mode | Output mode | Build profile | Install mode | Duration (s) | Docker export (s) | Docker import (s) | Proof lane | Verdict | Metadata status | Missing fields |",
        "|---|---|---|---|---|---|---:|---:|---:|---|---|---|---|",
    ]
    for artifact in report["artifacts"]:
        missing = ", ".join(artifact["missing_fields"]) if artifact["missing_fields"] else "none"
        measurement_mode = artifact["measurement_mode"] or "n/a"
        output_mode = artifact["output_mode"] or "n/a"
        build_profile = artifact["build_profile"] or "n/a"
        install_mode = artifact["custom_app_install_mode"] or "n/a"
        duration = artifact["duration_seconds"] or "n/a"
        docker_export = artifact["docker_export_seconds"] or "n/a"
        docker_import = artifact["docker_import_seconds"] or "n/a"
        lines.append(
            f"| `{artifact['label']}` | {artifact['benchmark_class']} | {measurement_mode} | {output_mode} | {build_profile} | {install_mode} | {duration} | {docker_export} | {docker_import} | {artifact['proof_lane']} | {artifact['verdict']} | {artifact['metadata_status']} | {missing} |"
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    repo_root = repo_root_from_path()
    bench_root = (repo_root / args.bench_root).resolve()
    board_path = (repo_root / args.control_board).resolve()
    board_registry = parse_board_registry(board_path)
    artifacts = collect_artifacts(bench_root, board_registry)

    report = {
        "bench_root": bench_root.relative_to(repo_root).as_posix(),
        "control_board": board_path.relative_to(repo_root).as_posix(),
        "artifact_count": len(artifacts),
        "artifacts": artifacts,
    }

    if args.format == "markdown":
        print(render_markdown(report), end="")
    else:
        print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
