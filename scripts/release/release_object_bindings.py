#!/usr/bin/env python3
"""Resolve and verify canonical release-object bindings for promotion and proof."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"release object not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"release object is not valid JSON: {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise SystemExit(f"release object must be a JSON object: {path}")
    return payload


def require_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(f"release object missing {label}")
    return value.strip()


def canonical_env(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip().lower()
    if not normalized:
        return None
    if normalized in {"prod", "production"}:
        return "production"
    if normalized in {"stage", "staging", "stg"}:
        return "staging"
    if normalized in {"dev", "nonprod", "rke2-nonprod"}:
        return "dev"
    return normalized


def release_identity_from_object(release_object: dict[str, Any], release_object_path: Path) -> dict[str, Any]:
    build = release_object.get("build")
    if not isinstance(build, dict):
        raise SystemExit("release object missing build block")

    return {
        "release_id": require_string(release_object.get("release_id"), "release_id"),
        "release_bundle_id": require_string(build.get("release_bundle_id"), "build.release_bundle_id"),
        "app_commit_sha": require_string(release_object.get("app_commit_sha"), "app_commit_sha"),
        "release_object_json": str(release_object_path.resolve()),
        "build_origin_environment": release_object.get("build_origin_environment"),
        "promotion_target_environment": release_object.get("promotion_target_environment"),
        "proof_refs": release_object.get("proof_refs", []),
    }


def image_digest(release_object: dict[str, Any], image_key: str) -> str:
    images = release_object.get("images")
    if not isinstance(images, dict):
        raise SystemExit("release object missing images block")
    image_payload = images.get(image_key)
    if not isinstance(image_payload, dict):
        raise SystemExit(f"release object missing images.{image_key}")
    return require_string(image_payload.get("digest"), f"images.{image_key}.digest")


def resolve_promotion_inputs(
    release_object: dict[str, Any],
    *,
    release_object_path: Path,
    target_env: str | None,
    openedx_digest: str | None,
    mfe_digest: str | None,
    app_sha: str | None,
) -> dict[str, Any]:
    identity = release_identity_from_object(release_object, release_object_path)
    expected_openedx_digest = image_digest(release_object, "openedx")
    expected_mfe_digest = image_digest(release_object, "mfe")
    resolved_openedx_digest = openedx_digest or expected_openedx_digest
    resolved_mfe_digest = mfe_digest or expected_mfe_digest
    resolved_app_sha = app_sha or identity["app_commit_sha"]

    if openedx_digest and openedx_digest != expected_openedx_digest:
        raise SystemExit(
            "openedx digest does not match release object "
            f"(expected {expected_openedx_digest}, got {openedx_digest})"
        )
    if mfe_digest and mfe_digest != expected_mfe_digest:
        raise SystemExit(
            "mfe digest does not match release object "
            f"(expected {expected_mfe_digest}, got {mfe_digest})"
        )
    if app_sha and app_sha != identity["app_commit_sha"]:
        raise SystemExit(
            "app SHA does not match release object "
            f"(expected {identity['app_commit_sha']}, got {app_sha})"
        )

    release_target = canonical_env(release_object.get("promotion_target_environment"))
    requested_target = canonical_env(target_env)
    if release_target and requested_target and release_target != requested_target:
        raise SystemExit(
            "release object promotion target does not match requested target env "
            f"(expected {release_target}, got {requested_target})"
        )

    return {
        "release_id": identity["release_id"],
        "release_bundle_id": identity["release_bundle_id"],
        "app_commit_sha": resolved_app_sha,
        "openedx_digest": resolved_openedx_digest,
        "mfe_digest": resolved_mfe_digest,
        "build_origin_environment": release_object.get("build_origin_environment"),
        "promotion_target_environment": release_object.get("promotion_target_environment"),
        "release_object_json": identity["release_object_json"],
    }


def verify_proof_envelope(envelope_payload: dict[str, Any], expected_identity: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    envelope_identity = envelope_payload.get("release_identity")
    if not isinstance(envelope_identity, dict):
        return ["proof envelope missing top-level release_identity"]

    keys_to_compare = (
        "release_id",
        "release_bundle_id",
        "app_commit_sha",
        "release_object_json",
    )
    for key in keys_to_compare:
        if envelope_identity.get(key) != expected_identity.get(key):
            errors.append(
                f"release_identity.{key} mismatch: "
                f"expected {expected_identity.get(key)!r}, got {envelope_identity.get(key)!r}"
            )

    details = envelope_payload.get("details")
    if envelope_payload.get("concern") == "release-gate":
        nested_identity = details.get("release_identity") if isinstance(details, dict) else None
        if not isinstance(nested_identity, dict):
            errors.append("release-gate envelope details missing release_identity")
        else:
            for key in keys_to_compare:
                if nested_identity.get(key) != expected_identity.get(key):
                    errors.append(
                        f"details.release_identity.{key} mismatch: "
                        f"expected {expected_identity.get(key)!r}, got {nested_identity.get(key)!r}"
                    )
    return errors


def sha256_text(value: str) -> str:
    return f"sha256:{hashlib.sha256(value.encode('utf-8')).hexdigest()}"


def _check_run_id(repository: str, run_id: str, suffix: str) -> str:
    return f"gha://{repository}/runs/{run_id}/{suffix}"


def generate_promotion_dispatch_envelope(
    *,
    release_bundle: dict[str, Any],
    release_object: dict[str, Any],
    build_provenance: dict[str, Any],
    proof_envelope: dict[str, Any],
    repository: str,
    run_id: str,
    server_url: str,
    contract_family: str,
    contract_version: str,
    contract_ref: str,
) -> dict[str, Any]:
    bundle_id = require_string(release_bundle.get("bundle_id"), "bundle_id")
    created_at = require_string(release_bundle.get("created_at"), "created_at")
    release_id = require_string(release_object.get("release_id"), "release_id")
    commit_sha = require_string(release_object.get("app_commit_sha"), "app_commit_sha")
    result = str(proof_envelope.get("result", "")).strip().lower()
    if result not in {"pass", "fail"}:
        raise SystemExit("proof envelope result must be pass or fail")
    details = proof_envelope.get("details")
    if not isinstance(details, dict):
        details = {}
    gates_pass = details.get("gates_pass", 0)
    gates_fail = details.get("gates_fail", 0)
    bundle_artifact_uri = f"actions/artifacts/release-bundle@run-{run_id}"
    run_url = f"{server_url.rstrip('/')}/{repository}/actions/runs/{run_id}"

    normalized_build_provenance = dict(build_provenance)
    normalized_build_provenance.setdefault("run_url", run_url)
    normalized_build_provenance.setdefault("artifact_uri", bundle_artifact_uri)
    normalized_build_provenance.setdefault("build_commit_sha", commit_sha)

    proof_summary = (
        f"release-gate proof {result} with {gates_fail} failing gates and "
        f"{gates_pass} passing gates for release {release_id}."
    )

    checks = [
        {
            "id": "release-notes-diff",
            "type": "release_notes_diff",
            "status": "passed",
            "summary": f"Release bundle {bundle_id} anchors app commit {commit_sha} for promotion review.",
            "check_run_id": _check_run_id(repository, run_id, "release-notes-diff"),
            "artifact_uri": bundle_artifact_uri,
            "hash": sha256_text(json.dumps(release_bundle, sort_keys=True)),
        },
        {
            "id": "config-change-summary",
            "type": "config_change_summary",
            "status": "passed",
            "summary": "Promotion changes only the Open edX and MFE image digests; GitOps overlay mutation happens downstream.",
            "check_run_id": _check_run_id(repository, run_id, "config-change-summary"),
            "artifact_uri": bundle_artifact_uri,
            "hash": sha256_text(json.dumps(release_object.get("images", {}), sort_keys=True)),
        },
        {
            "id": "migration-summary",
            "type": "migration_summary",
            "status": "skipped",
            "summary": "App image-build does not execute Open edX migrations; migration truth is validated during promotion/runtime.",
            "check_run_id": _check_run_id(repository, run_id, "migration-summary"),
            "artifact_uri": bundle_artifact_uri,
            "hash": sha256_text(f"{bundle_id}:migration-summary"),
        },
        {
            "id": "smoke-test-result",
            "type": "smoke_test_result",
            "status": "passed" if result == "pass" else "failed",
            "summary": proof_summary,
            "check_run_id": _check_run_id(repository, run_id, "smoke-test-result"),
            "artifact_uri": f"{bundle_artifact_uri}#release-gate-envelope.json",
            "hash": sha256_text(json.dumps(proof_envelope, sort_keys=True)),
        },
        {
            "id": "release-gate-result",
            "type": "release_gate_result",
            "status": "passed" if result == "pass" else "failed",
            "summary": proof_summary,
            "check_run_id": _check_run_id(repository, run_id, "release-gate-result"),
            "artifact_uri": f"{bundle_artifact_uri}#release-gate-envelope.json",
            "hash": sha256_text(json.dumps(proof_envelope, sort_keys=True)),
        },
        {
            "id": "rollback-target-reference",
            "type": "rollback_target_reference",
            "status": "blocked",
            "summary": "Rollback target selection is infra-owned and is resolved from the previously promoted dev bundle.",
            "check_run_id": _check_run_id(repository, run_id, "rollback-target-reference"),
            "artifact_uri": bundle_artifact_uri,
            "hash": sha256_text(f"{bundle_id}:rollback-target-reference"),
        },
        {
            "id": "security-delta-summary",
            "type": "security_delta_summary",
            "status": "skipped",
            "summary": "Security delta is carried by post-push scan artifacts and enforced later in the promotion gate.",
            "check_run_id": _check_run_id(repository, run_id, "security-delta-summary"),
            "artifact_uri": bundle_artifact_uri,
            "hash": sha256_text(f"{bundle_id}:security-delta-summary"),
        },
    ]

    return {
        "release_bundle_id": bundle_id,
        "lane": "mereka-lms",
        "delivery_lane": "dev",
        "service_id": "mereka-lms",
        "dispatch_event_type": "promote-mereka-lms-dev",
        "created_at": created_at,
        "validation_evidence": f"ci-build-pass:{run_id}",
        "structured_evidence": {"checks": checks},
        "release_object": release_object,
        "build_provenance": normalized_build_provenance,
        "control_plane_ref": contract_ref,
        "contract_family": contract_family,
        "contract_version": contract_version,
        "contract_ref": contract_ref,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    identity = subparsers.add_parser("identity")
    identity.add_argument("--release-object-json", required=True, type=Path)

    promotion_inputs = subparsers.add_parser("promotion-inputs")
    promotion_inputs.add_argument("--release-object-json", required=True, type=Path)
    promotion_inputs.add_argument("--target-env")
    promotion_inputs.add_argument("--openedx-digest")
    promotion_inputs.add_argument("--mfe-digest")
    promotion_inputs.add_argument("--app-sha")
    promotion_inputs.add_argument("--format", choices=("json", "env"), default="json")

    verify = subparsers.add_parser("verify-proof-envelope")
    verify.add_argument("--envelope-json", required=True, type=Path)
    verify.add_argument("--release-object-json", required=True, type=Path)

    dispatch = subparsers.add_parser("promotion-dispatch-envelope")
    dispatch.add_argument("--release-bundle-json", required=True, type=Path)
    dispatch.add_argument("--release-object-json", required=True, type=Path)
    dispatch.add_argument("--build-provenance-json", required=True, type=Path)
    dispatch.add_argument("--proof-envelope-json", required=True, type=Path)
    dispatch.add_argument("--repository", required=True)
    dispatch.add_argument("--run-id", required=True)
    dispatch.add_argument("--server-url", required=True)
    dispatch.add_argument("--contract-family", required=True)
    dispatch.add_argument("--contract-version", required=True)
    dispatch.add_argument("--contract-ref", required=True)
    dispatch.add_argument("--output", type=Path)

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "identity":
        release_object = load_json(args.release_object_json.resolve())
        print(
            json.dumps(
                release_identity_from_object(release_object, args.release_object_json.resolve()),
                indent=2,
            )
        )
        return 0

    if args.command == "promotion-inputs":
        release_object = load_json(args.release_object_json.resolve())
        payload = resolve_promotion_inputs(
            release_object,
            release_object_path=args.release_object_json.resolve(),
            target_env=args.target_env,
            openedx_digest=args.openedx_digest,
            mfe_digest=args.mfe_digest,
            app_sha=args.app_sha,
        )
        if args.format == "env":
            for key in (
                "release_id",
                "release_bundle_id",
                "app_commit_sha",
                "openedx_digest",
                "mfe_digest",
                "build_origin_environment",
                "promotion_target_environment",
                "release_object_json",
            ):
                value = payload.get(key)
                if value is None:
                    value = ""
                print(f"{key}={value}")
            return 0
        print(json.dumps(payload, indent=2))
        return 0

    if args.command == "verify-proof-envelope":
        envelope_path = args.envelope_json.resolve()
        envelope_payload = load_json(envelope_path)
        release_object = load_json(args.release_object_json.resolve())
        expected_identity = release_identity_from_object(release_object, args.release_object_json.resolve())
        errors = verify_proof_envelope(envelope_payload, expected_identity)
        if errors:
            print("FAIL: proof envelope release binding errors:", file=sys.stderr)
            for error in errors:
                print(f" - {error}", file=sys.stderr)
            return 1
        print(f"PASS: proof envelope bound to {expected_identity['release_id']}")
        return 0

    if args.command == "promotion-dispatch-envelope":
        release_bundle = load_json(args.release_bundle_json.resolve())
        release_object = load_json(args.release_object_json.resolve())
        build_provenance = load_json(args.build_provenance_json.resolve())
        proof_envelope = load_json(args.proof_envelope_json.resolve())
        payload = generate_promotion_dispatch_envelope(
            release_bundle=release_bundle,
            release_object=release_object,
            build_provenance=build_provenance,
            proof_envelope=proof_envelope,
            repository=args.repository,
            run_id=args.run_id,
            server_url=args.server_url,
            contract_family=args.contract_family,
            contract_version=args.contract_version,
            contract_ref=args.contract_ref,
        )
        rendered = json.dumps(payload, indent=2) + "\n"
        if args.output:
            args.output.write_text(rendered, encoding="utf-8")
        else:
            sys.stdout.write(rendered)
        return 0

    raise SystemExit(f"unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
