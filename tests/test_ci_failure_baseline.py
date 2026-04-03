from __future__ import annotations

import importlib.util
import json
import subprocess
from pathlib import Path

import jsonschema


REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "ci" / "generate_ci_failure_baseline.py"
SCHEMA_PATH = REPO_ROOT / "schemas" / "ci-failure-baseline.schema.json"


def load_module():
    spec = importlib.util.spec_from_file_location("ci_failure_baseline", SCRIPT_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    return module


def load_schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def write_log(path: Path, lines: list[str]) -> None:
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def test_compute_decision_distinguishes_branch_failures(tmp_path: Path) -> None:
    module = load_module()
    branch_dir = tmp_path / "branch"
    baseline_dir = tmp_path / "baseline"
    branch_dir.mkdir()
    baseline_dir.mkdir()

    write_log(
        branch_dir / "Static Validation Scripts (shard-01).txt",
        [
            "FAIL verify-runtime-routing [12/200] (exit 1, 0s)",
            "FAIL verify-shared-baseline [14/200] (exit 1, 0s)",
        ],
    )
    write_log(
        baseline_dir / "Static Validation Scripts (shard-01).txt",
        [
            "FAIL verify-shared-baseline [14/200] (exit 1, 0s)",
        ],
    )

    branch_run = module.load_run_from_logs(
        run_id=100,
        head_sha="branch-sha",
        log_dir=branch_dir,
        failed_jobs=["Static Validation Scripts (shard-01)"],
    )
    baseline_run = module.load_run_from_logs(
        run_id=99,
        head_sha="main-sha",
        log_dir=baseline_dir,
        failed_jobs=["Static Validation Scripts (shard-01)"],
    )
    payload = module.build_payload(
        repo="Biji-Biji-Initiative/mereka-lms",
        workflow="CI",
        branch_run=branch_run,
        baseline_run=baseline_run,
    )

    assert payload["decision"] == "blocked_on_branch_failures"
    assert payload["new_failures"] == ["verify-runtime-routing"]
    assert payload["shared_failures"] == ["verify-shared-baseline"]
    jsonschema.validate(payload, load_schema())


def test_compute_decision_recognizes_baseline_only_failures(tmp_path: Path) -> None:
    module = load_module()
    branch_dir = tmp_path / "branch"
    baseline_dir = tmp_path / "baseline"
    branch_dir.mkdir()
    baseline_dir.mkdir()

    write_log(
        branch_dir / "Static Validation Scripts (shard-02).txt",
        [
            "FAIL verify-shared-baseline [63/200] (exit 1, 0s)",
        ],
    )
    write_log(
        baseline_dir / "Static Validation Scripts (shard-02).txt",
        [
            "FAIL verify-shared-baseline [63/200] (exit 1, 0s)",
            "FAIL verify-old-noise [70/200] (exit 1, 0s)",
        ],
    )

    branch_run = module.load_run_from_logs(
        run_id=100,
        head_sha="branch-sha",
        log_dir=branch_dir,
        failed_jobs=["Static Validation Scripts (shard-02)"],
    )
    baseline_run = module.load_run_from_logs(
        run_id=99,
        head_sha="main-sha",
        log_dir=baseline_dir,
        failed_jobs=["Static Validation Scripts (shard-02)"],
    )
    payload = module.build_payload(
        repo="Biji-Biji-Initiative/mereka-lms",
        workflow="CI",
        branch_run=branch_run,
        baseline_run=baseline_run,
    )

    assert payload["decision"] == "mergeable_with_baseline_debt"
    assert payload["new_failures"] == []
    assert payload["resolved_failures"] == ["verify-old-noise"]
    jsonschema.validate(payload, load_schema())


def test_cli_emits_schema_valid_payload(tmp_path: Path) -> None:
    branch_dir = tmp_path / "branch"
    baseline_dir = tmp_path / "baseline"
    branch_dir.mkdir()
    baseline_dir.mkdir()
    write_log(
        branch_dir / "Static Validation Scripts (shard-03).txt",
        ["FAIL verify-shared-baseline [140/152] (exit 1, 0s)"],
    )
    write_log(
        baseline_dir / "Static Validation Scripts (shard-03).txt",
        ["FAIL verify-shared-baseline [140/152] (exit 1, 0s)"],
    )

    output_path = tmp_path / "ci-failure-baseline.json"
    result = subprocess.run(
        [
            "python3",
            str(SCRIPT_PATH),
            "--repo",
            "Biji-Biji-Initiative/mereka-lms",
            "--branch-log-dir",
            str(branch_dir),
            "--branch-head-sha",
            "branch-sha",
            "--baseline-log-dir",
            str(baseline_dir),
            "--baseline-head-sha",
            "main-sha",
            "--output",
            str(output_path),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr

    payload = json.loads(output_path.read_text(encoding="utf-8"))
    assert payload["decision"] == "mergeable_with_baseline_debt"
    jsonschema.validate(payload, load_schema())
