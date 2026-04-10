#!/usr/bin/env bash
# Seeded-defect self-test for verify-release-object.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="${ROOT_DIR}/scripts/qa/verify-release-object.sh"
tmpdir="$(mktemp -d -t verify-release-object.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

mkdir -p "${tmpdir}/schemas" "${tmpdir}/var/ci"
cp "${ROOT_DIR}/schemas/release-object.schema.json" "${tmpdir}/schemas/release-object.schema.json"

cat >"${tmpdir}/var/ci/release-object.json" <<'EOF'
{
  "schema_version": "release-object/v1",
  "release_id": "ro-rb-abcdef1234567-20260403T120000Z",
  "created_at_utc": "2026-04-03T12:00:00Z",
  "service_id": "mereka-lms",
  "repository": "Biji-Biji-Initiative/mereka-lms",
  "app_commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "build_origin_environment": "dev",
  "promotion_target_environment": null,
  "target_environment": "dev",
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

REPO_ROOT_OVERRIDE="${tmpdir}" bash "${VERIFY}" "${tmpdir}/var/ci/release-object.json" >/tmp/verify-release-object.out 2>&1

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

if REPO_ROOT_OVERRIDE="${tmpdir}" bash "${VERIFY}" "${tmpdir}/var/ci/release-object.json" >/tmp/verify-release-object.out 2>&1; then
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
