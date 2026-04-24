from __future__ import annotations

import json
import subprocess
from pathlib import Path

import jsonschema

REPO_ROOT = Path(__file__).resolve().parent.parent
BASELINE_SCHEMA_PATH = REPO_ROOT / "schemas" / "ci-failure-baseline.schema.json"
RELEASE_GATE_PROOF_PATH = REPO_ROOT / "var" / "proof" / "release-gate.json"


def load_baseline_schema() -> dict:
    return json.loads(BASELINE_SCHEMA_PATH.read_text(encoding="utf-8"))


def cleanup_release_gate_proof() -> None:
    RELEASE_GATE_PROOF_PATH.unlink(missing_ok=True)


def failure_detail(
    failure_id: str,
    *,
    severity: str = "medium",
    merge_policy: str = "review_required_if_baseline",
) -> dict:
    return {
        "id": failure_id,
        "jobs": ["Static Validation Scripts (shard-01)"],
        "severity": severity,
        "merge_policy": merge_policy,
        "policy_source": failure_id,
    }


def write_baseline_artifact(
    path: Path,
    *,
    decision: str,
    new_failures: list[str] | None = None,
    shared_failures: list[str] | None = None,
    blocking_shared_failures: list[str] | None = None,
) -> None:
    new_failures = sorted(new_failures or [])
    shared_failures = sorted(shared_failures or [])
    blocking_shared_failures = sorted(blocking_shared_failures or [])

    new_failure_details = [failure_detail(failure_id) for failure_id in new_failures]
    shared_failure_details = [
        failure_detail(
            failure_id,
            severity="high" if failure_id in blocking_shared_failures else "medium",
            merge_policy=(
                "must_block_even_if_baseline"
                if failure_id in blocking_shared_failures
                else "review_required_if_baseline"
            ),
        )
        for failure_id in shared_failures
    ]

    payload = {
        "schema_version": "ci-failure-baseline/v2",
        "repo": "Biji-Biji-Initiative/mereka-lms",
        "workflow": "CI",
        "policy": {
            "path": str(REPO_ROOT / "verification" / "manifests" / "ci_failure_severity_policy.json"),
            "schema_version": "ci-failure-severity-policy/v1",
            "defaults": {
                "severity": "medium",
                "merge_policy": "review_required_if_baseline",
            },
        },
        "branch_run": {
            "run_id": 101,
            "head_sha": "branch-sha",
            "failure_ids": sorted(new_failures + shared_failures),
            "failed_jobs": ["Static Validation Scripts (shard-01)"],
            "failure_details": sorted(
                new_failure_details + shared_failure_details,
                key=lambda detail: detail["id"],
            ),
        },
        "baseline_run": {
            "run_id": 100,
            "head_sha": "main-sha",
            "failure_ids": shared_failures,
            "failed_jobs": ["Static Validation Scripts (shard-01)"],
            "failure_details": shared_failure_details,
        },
        "new_failures": new_failures,
        "resolved_failures": [],
        "shared_failures": shared_failures,
        "new_failure_details": new_failure_details,
        "resolved_failure_details": [],
        "shared_failure_details": shared_failure_details,
        "blocking_shared_failures": blocking_shared_failures,
        "decision": decision,
    }

    jsonschema.validate(payload, load_baseline_schema())
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def test_release_gate_warns_for_mergeable_baseline_debt(tmp_path: Path) -> None:
    cleanup_release_gate_proof()
    artifact_path = tmp_path / "ci-failure-baseline.json"
    write_baseline_artifact(
        artifact_path,
        decision="mergeable_with_baseline_debt",
        shared_failures=["verify-shared-baseline"],
    )

    try:
        result = subprocess.run(
            [
                "bash",
                "scripts/release/release-gate.sh",
                "--skip-cluster",
                "--ci-failure-baseline-json",
                str(artifact_path),
            ],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode == 0, result.stdout + result.stderr
        assert "mergeable with inherited debt" in result.stdout

        proof = json.loads(RELEASE_GATE_PROOF_PATH.read_text(encoding="utf-8"))
        assert proof["verdict"] == "pass"
        assert proof["ci_failure_baseline"]["decision"] == "mergeable_with_baseline_debt"
        assert proof["ci_failure_baseline"]["shared_failures"] == ["verify-shared-baseline"]
        assert proof["ci_failure_baseline"]["artifact_path"] == str(artifact_path.resolve())
    finally:
        cleanup_release_gate_proof()


def test_release_gate_envelope_fails_for_blocking_baseline_policy(tmp_path: Path) -> None:
    cleanup_release_gate_proof()
    artifact_path = tmp_path / "ci-failure-baseline.json"
    write_baseline_artifact(
        artifact_path,
        decision="blocked_on_baseline_policy",
        shared_failures=["verify-secret-classification"],
        blocking_shared_failures=["verify-secret-classification"],
    )

    try:
        result = subprocess.run(
            [
                "bash",
                "scripts/release/emit-proof-envelope.sh",
                "--concern",
                "release-gate",
                "--lane",
                "dev",
                "--skip-cluster",
                "--ci-failure-baseline-json",
                str(artifact_path),
                "--format",
                "json",
            ],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode == 0, result.stdout + result.stderr
        payload = json.loads(result.stdout)
        assert payload["concern"] == "release-gate"
        assert payload["result"] == "fail"
        assert payload["details"]["ci_failure_baseline"]["decision"] == "blocked_on_baseline_policy"
        assert payload["details"]["ci_failure_baseline"]["blocking_shared_failures"] == [
            "verify-secret-classification"
        ]
    finally:
        cleanup_release_gate_proof()
