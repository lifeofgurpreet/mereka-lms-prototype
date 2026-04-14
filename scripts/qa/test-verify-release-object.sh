#!/usr/bin/env bash
# Seeded-defect self-test for verify-release-object.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="${ROOT_DIR}/scripts/qa/verify-release-object.sh"
tmpdir="$(mktemp -d -t verify-release-object.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

mkdir -p "${tmpdir}/schemas" "${tmpdir}/var/ci"
mkdir -p "${tmpdir}/platform-control-plane/contracts"

cat >"${tmpdir}/platform-control-plane/contracts/release-object-projection-schema.yaml" <<'EOF'
schema_version: "1.0"
contract: "release-object-projection-schema"
required_fields:
  - "schema_version"
  - "release_id"
  - "created_at_utc"
  - "lane"
  - "service_id"
  - "repository"
  - "app_commit_sha"
  - "build_origin_environment"
  - "promotion_target_environment"
  - "tenant_contract"
  - "build"
  - "images"
  - "source_artifacts"
  - "proof_refs"
  - "promotion"
properties:
  schema_version: { type: "string", enum: ["release-object/v1"] }
  release_id: { type: "string", pattern: "^ro-rb-[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z$" }
  created_at_utc: { type: "string", format: "date-time" }
  lane: { type: "string", enum: ["mereka-lms"] }
  service_id: { type: "string", enum: ["mereka-lms"] }
  repository: { type: "string" }
  app_commit_sha: { type: "string", pattern: "^[0-9a-f]{40}$" }
  build_origin_environment: { type: "string", enum: ["dev", "nonprod", "staging", "production", "prod", "rke2-nonprod"] }
  promotion_target_environment: { type: "string", enum: ["dev", "nonprod", "staging", "production", "prod", "rke2-nonprod"], nullable: true }
  contract_family: { type: "string", enum: ["release_object_projection_schema"] }
  contract_version: { type: "string", enum: ["1.0"] }
  contract_ref: { type: "string", pattern: "^Biji-Biji-Initiative/platform-control-plane@[0-9a-f]{40}$" }
  tenant_contract:
    type: "object"
    required_object_fields: ["path", "sha256", "control_plane_ref"]
    object_schema:
      properties:
        path: { type: "string" }
        sha256: { type: "string", pattern: "^[0-9a-f]{64}$" }
        control_plane_ref: { type: "string", pattern: "^Biji-Biji-Initiative/platform-control-plane@[0-9a-f]{40}$" }
  build:
    type: "object"
    required_object_fields: ["workflow", "run_id", "run_attempt", "release_bundle_id"]
    object_schema:
      properties:
        workflow: { type: "string" }
        run_id: { type: "string", pattern: "^[0-9]+$" }
        run_attempt: { type: "string", pattern: "^[0-9]+$" }
        release_bundle_id: { type: "string", pattern: "^rb-[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z$" }
  images:
    type: "object"
    required_object_fields: ["openedx", "mfe"]
    object_schema:
      properties:
        openedx:
          type: "object"
          required_object_fields: ["name", "digest"]
          object_schema:
            properties:
              name: { type: "string" }
              digest: { type: "string", pattern: "^sha256:[0-9a-f]{64}$" }
        mfe:
          type: "object"
          required_object_fields: ["name", "digest"]
          object_schema:
            properties:
              name: { type: "string" }
              digest: { type: "string", pattern: "^sha256:[0-9a-f]{64}$" }
  source_artifacts:
    type: "object"
    required_object_fields: ["release_bundle_json", "build_provenance_json"]
    object_schema:
      properties:
        release_bundle_json: { type: "string" }
        build_provenance_json: { type: "string", nullable: true }
  proof_refs:
    type: "array"
    min_items: 0
  promotion:
    type: "object"
    required_object_fields: ["status", "gitops_repository", "gitops_commit_sha"]
    object_schema:
      properties:
        status: { type: "string", enum: ["build-only", "gitops-linked"] }
        gitops_repository: { type: "string", nullable: true }
        gitops_commit_sha: { type: "string", pattern: "^[0-9a-f]{40}$", nullable: true }
EOF

cat >"${tmpdir}/var/ci/release-object.json" <<'EOF'
{
  "schema_version": "release-object/v1",
  "release_id": "ro-rb-abcdef1234567-20260403T120000Z",
  "created_at_utc": "2026-04-03T12:00:00Z",
  "lane": "mereka-lms",
  "service_id": "mereka-lms",
  "repository": "Biji-Biji-Initiative/mereka-lms",
  "app_commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "build_origin_environment": "dev",
  "promotion_target_environment": null,
  "target_environment": "dev",
  "contract_family": "release_object_projection_schema",
  "contract_version": "1.0",
  "contract_ref": "Biji-Biji-Initiative/platform-control-plane@194e6001c924902e8bf3dafefdc37fc842c56653",
  "tenant_contract": {
    "path": "/tmp/tenant-registry.yaml",
    "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "control_plane_ref": "Biji-Biji-Initiative/platform-control-plane@194e6001c924902e8bf3dafefdc37fc842c56653"
  },
  "build": {
    "workflow": ".github/workflows/build-tutor-images.yml",
    "run_id": "123",
    "run_attempt": "1",
    "release_bundle_id": "rb-abcdef1234567-20260403T120000Z"
  },
  "images": {
    "openedx": {
      "name": "ghcr.io/biji-biji-initiative/mereka-lms/openedx",
      "digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111"
    },
    "mfe": {
      "name": "ghcr.io/biji-biji-initiative/mereka-lms/mfe",
      "digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222"
    }
  },
  "source_artifacts": {
    "release_bundle_json": "/tmp/release-bundle.json",
    "build_provenance_json": null
  },
  "proof_refs": [],
  "promotion": {
    "status": "build-only",
    "gitops_repository": null,
    "gitops_commit_sha": null
  }
}
EOF

REPO_ROOT_OVERRIDE="${tmpdir}" PLATFORM_CONTROL_PLANE_ROOT="${tmpdir}/platform-control-plane" \
  bash "${VERIFY}" "${tmpdir}/var/ci/release-object.json" >/tmp/verify-release-object.out 2>&1

python3 - "${tmpdir}/var/ci/release-object.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["promotion"]["status"] = "gitops-linked"
payload["promotion"]["gitops_repository"] = "Biji-Biji-Initiative/bbi-infrastructure"
payload["promotion"]["gitops_commit_sha"] = None
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if REPO_ROOT_OVERRIDE="${tmpdir}" PLATFORM_CONTROL_PLANE_ROOT="${tmpdir}/platform-control-plane" \
  bash "${VERIFY}" "${tmpdir}/var/ci/release-object.json" >/tmp/verify-release-object.out 2>&1; then
  cat /tmp/verify-release-object.out >&2 || true
  echo "expected gitops-linked object without commit to fail" >&2
  exit 1
fi

grep -q "promotion.gitops_commit_sha missing" /tmp/verify-release-object.out || {
  cat /tmp/verify-release-object.out >&2 || true
  echo "expected gitops commit validation failure" >&2
  exit 1
}

echo "PASS: verify-release-object seeded defects covered"
