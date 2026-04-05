#!/usr/bin/env python3
"""Resolve and verify canonical release-object bindings for promotion and proof."""
from __future__ import annotations

import argparse
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

    raise SystemExit(f"unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
