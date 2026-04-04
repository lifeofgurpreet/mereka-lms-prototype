#!/usr/bin/env python3
"""Join repo, release, infra, Argo, runtime, and acceptance truths into one ledger."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_IMAGE_REPOS = (
    "ghcr.io/biji-biji-initiative/mereka-lms/openedx",
    "ghcr.io/biji-biji-initiative/mereka-lms/mfe",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary-json", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--app-sha")
    parser.add_argument("--infra-commit-sha")
    parser.add_argument("--argo-app")
    parser.add_argument("--namespace")
    parser.add_argument("--release-object-json", type=Path)
    parser.add_argument("--release-openedx-image")
    parser.add_argument("--release-mfe-image")
    parser.add_argument(
        "--image-repo",
        action="append",
        default=[],
        help="Image repositories to track when discovering live runtime images",
    )
    return parser.parse_args()


def canonical_sha256(payload: Any) -> str:
    rendered = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(rendered).hexdigest()


def parse_image_reference(image_ref: str | None) -> dict[str, Any] | None:
    if not image_ref:
        return None
    digest = ""
    ref_without_digest = image_ref
    if "@" in image_ref:
        ref_without_digest, digest = image_ref.rsplit("@", 1)
    tag = ""
    repository = ref_without_digest
    last_segment = ref_without_digest.rsplit("/", 1)[-1]
    if ":" in last_segment:
        repository, tag = ref_without_digest.rsplit(":", 1)
    return {
        "reference": image_ref,
        "repository": repository,
        "tag": tag or None,
        "digest": digest or None,
    }


def load_release_object(path: Path | None) -> dict[str, Any] | None:
    if not path:
        return None
    try:
        return json.loads(path.resolve().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def git_head_sha() -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def run_json(command: list[str]) -> dict[str, Any] | None:
    result = subprocess.run(
        command,
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def discover_argo_truth(app_name: str | None) -> dict[str, Any]:
    if not app_name:
        return {"status": "unknown", "app_name": None}

    payload = run_json(["kubectl", "get", "application", app_name, "-n", "argocd", "-o", "json"])
    if not payload:
        return {"status": "unknown", "app_name": app_name}

    status = payload.get("status", {})
    return {
        "status": "known",
        "app_name": app_name,
        "sync_status": status.get("sync", {}).get("status"),
        "health_status": status.get("health", {}).get("status"),
        "revision": status.get("sync", {}).get("revision"),
        "reconciled_at": status.get("reconciledAt"),
    }


def discover_runtime_truth(namespace: str | None, tracked_repositories: tuple[str, ...]) -> dict[str, Any]:
    if not namespace:
        return {"status": "unknown", "namespace": None, "deployments": []}

    payload = run_json(["kubectl", "get", "deploy", "-n", namespace, "-o", "json"])
    if not payload:
        return {"status": "unknown", "namespace": namespace, "deployments": []}

    deployments: list[dict[str, Any]] = []
    tracked_images: list[dict[str, Any]] = []
    for item in payload.get("items", []):
        images = []
        for container in item.get("spec", {}).get("template", {}).get("spec", {}).get("containers", []):
            image_ref = container.get("image", "")
            image_payload = parse_image_reference(image_ref)
            if image_payload:
                images.append(image_payload)
                if any(image_payload["repository"] == repo for repo in tracked_repositories):
                    tracked_images.append(image_payload)
        deployments.append(
            {
                "name": item.get("metadata", {}).get("name"),
                "ready_replicas": item.get("status", {}).get("readyReplicas", 0),
                "replicas": item.get("status", {}).get("replicas", 0),
                "images": images,
            }
        )

    unique_images: list[dict[str, Any]] = []
    seen_refs: set[str] = set()
    for image in tracked_images:
        ref = image["reference"]
        if ref in seen_refs:
            continue
        seen_refs.add(ref)
        unique_images.append(image)

    return {
        "status": "known",
        "namespace": namespace,
        "deployments": deployments,
        "tracked_images": unique_images,
    }


def compare_release_to_runtime(
    release_truth: dict[str, Any],
    runtime_truth: dict[str, Any],
) -> list[dict[str, Any]]:
    comparisons: list[dict[str, Any]] = []
    runtime_by_repo = {
        image["repository"]: image for image in runtime_truth.get("tracked_images", []) if image.get("repository")
    }
    for key in ("openedx_image", "mfe_image"):
        release_image = release_truth.get(key)
        if not release_image:
            comparisons.append({"plane": key, "status": "unknown", "reason": "release image missing"})
            continue
        runtime_image = runtime_by_repo.get(release_image["repository"])
        if not runtime_image:
            comparisons.append(
                {
                    "plane": key,
                    "status": "unknown",
                    "reason": f"runtime image missing for {release_image['repository']}",
                }
            )
            continue
        if release_image.get("digest") and runtime_image.get("digest") != release_image.get("digest"):
            comparisons.append(
                {
                    "plane": key,
                    "status": "fail",
                    "reason": f"digest mismatch: expected {release_image['digest']}, got {runtime_image.get('digest')}",
                }
            )
            continue
        comparisons.append({"plane": key, "status": "pass", "reason": "release and runtime digests align"})
    return comparisons


def compute_final_verdict(
    acceptance_truth: dict[str, Any],
    argo_truth: dict[str, Any],
    comparisons: list[dict[str, Any]],
) -> dict[str, Any]:
    reasons: list[str] = []
    status = "pass"

    if acceptance_truth["verdict"]["status"] != "pass":
        status = "fail"
        reasons.append("acceptance proof failed")

    if argo_truth.get("status") == "known":
        if argo_truth.get("sync_status") != "Synced":
            status = "fail"
            reasons.append(f"argo sync is {argo_truth.get('sync_status')}")
        if argo_truth.get("health_status") != "Healthy":
            status = "fail"
            reasons.append(f"argo health is {argo_truth.get('health_status')}")

    for comparison in comparisons:
        if comparison["status"] == "fail":
            status = "fail"
            reasons.append(comparison["reason"])
        elif comparison["status"] == "unknown" and status == "pass":
            status = "partial"
            reasons.append(comparison["reason"])

    if argo_truth.get("status") == "unknown" and status == "pass":
        status = "partial"
        reasons.append("argo truth unavailable")

    if not reasons:
        reasons.append("all known planes align")

    return {"status": status, "reasons": reasons}


def build_payload(
    summary: dict[str, Any],
    *,
    app_sha: str | None,
    infra_commit_sha: str | None,
    argo_truth: dict[str, Any],
    runtime_truth: dict[str, Any],
    release_truth: dict[str, Any],
    release_identity: dict[str, Any] | None,
    summary_path: Path,
    output_path: Path,
) -> dict[str, Any]:
    contract_matrix = summary.get("matrix", {})
    acceptance_truth = {
        "bundle_path": summary.get("artifacts", {}).get("output_dir"),
        "summary_json": str(summary_path),
        "verdict": summary.get("verdict", {}),
        "check_statuses": summary.get("checks", []),
    }
    comparisons = compare_release_to_runtime(release_truth, runtime_truth)
    final_verdict = compute_final_verdict(acceptance_truth, argo_truth, comparisons)

    payload = {
        "schema_version": "runtime-truth-ledger/v1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "lane": summary.get("lane"),
        "environment": summary.get("environment"),
        "tenant_filter": summary.get("tenant_filter"),
        "record_id": f"{summary.get('lane')}:{summary.get('environment')}:{summary.get('tenant_filter') or 'all'}",
        "contract_truth": {
            "source": summary.get("contract", {}).get("source"),
            "source_version": summary.get("contract", {}).get("source_version"),
            "schema_version": summary.get("contract", {}).get("schema_version"),
            "matrix_sha256": canonical_sha256(contract_matrix),
        },
        "repo_truth": {
            "app_commit_sha": app_sha,
            "acceptance_command": f"bin/accept {summary.get('lane')} --env {summary.get('environment')}",
            "acceptance_mode": summary.get("mode"),
            "acceptance_summary_json": str(summary_path),
        },
        "release_truth": release_truth,
        "infra_truth": {
            "status": "known" if infra_commit_sha else "unknown",
            "infra_commit_sha": infra_commit_sha,
        },
        "argo_truth": argo_truth,
        "runtime_truth": runtime_truth,
        "acceptance_truth": acceptance_truth,
        "plane_comparisons": comparisons,
        "final_verdict": final_verdict,
        "artifacts": {
            "truth_ledger_json": str(output_path),
            "acceptance_bundle": summary.get("artifacts", {}).get("output_dir"),
            "acceptance_summary_json": str(summary_path),
        },
    }
    if release_identity:
        payload["release_identity"] = release_identity
    return payload


def main() -> int:
    args = parse_args()
    summary_path = args.summary_json.resolve()
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    if args.output:
        output_path = args.output.resolve()
    else:
        summary_lane = summary.get("lane", "unknown-lane")
        summary_env = summary.get("environment", "unknown-env")
        tenant_key = summary.get("tenant_filter") or "all"
        output_path = (
            REPO_ROOT
            / "generated"
            / "truth-ledger"
            / summary_lane
            / summary_env
            / f"{tenant_key}.json"
        ).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    tracked_repositories = tuple(args.image_repo) if args.image_repo else DEFAULT_IMAGE_REPOS
    release_object = load_release_object(args.release_object_json)
    summary_release_identity = summary.get("release_identity") if isinstance(summary.get("release_identity"), dict) else None
    release_identity = summary_release_identity or (
        {
            "release_id": release_object.get("release_id"),
            "release_bundle_id": release_object.get("build", {}).get("release_bundle_id"),
            "app_commit_sha": release_object.get("app_commit_sha"),
            "release_object_json": str(args.release_object_json.resolve()),
        }
        if release_object and args.release_object_json
        else None
    )
    release_truth = {
        "release_object_id": (release_identity or {}).get("release_id"),
        "release_id": (release_identity or {}).get("release_id"),
        "release_bundle_id": (release_identity or {}).get("release_bundle_id"),
        "release_object_json": str(args.release_object_json.resolve()) if args.release_object_json else None,
        "build_origin_environment": release_object.get("build_origin_environment") if release_object else None,
        "promotion_target_environment": release_object.get("promotion_target_environment") if release_object else None,
        "openedx_image": parse_image_reference(args.release_openedx_image)
        or parse_image_reference(
            f"{release_object['images']['openedx']['name']}@{release_object['images']['openedx']['digest']}"
            if release_object
            and release_object.get("images", {}).get("openedx", {}).get("name")
            and release_object.get("images", {}).get("openedx", {}).get("digest")
            else None
        ),
        "mfe_image": parse_image_reference(args.release_mfe_image)
        or parse_image_reference(
            f"{release_object['images']['mfe']['name']}@{release_object['images']['mfe']['digest']}"
            if release_object
            and release_object.get("images", {}).get("mfe", {}).get("name")
            and release_object.get("images", {}).get("mfe", {}).get("digest")
            else None
        ),
        "proof_refs": release_object.get("proof_refs", []) if release_object else [],
    }
    argo_truth = discover_argo_truth(args.argo_app)
    runtime_truth = discover_runtime_truth(args.namespace, tracked_repositories)
    payload = build_payload(
        summary,
        app_sha=args.app_sha or (release_identity or {}).get("app_commit_sha") or git_head_sha(),
        infra_commit_sha=args.infra_commit_sha,
        argo_truth=argo_truth,
        runtime_truth=runtime_truth,
        release_truth=release_truth,
        release_identity=release_identity,
        summary_path=summary_path,
        output_path=output_path,
    )
    output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
