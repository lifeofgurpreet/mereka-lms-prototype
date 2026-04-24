#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-control-plane-release-bundle-projection.sh"

tmpdir="$(mktemp -d -t verify-control-plane-release-bundle-projection.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/platform-control-plane/contracts"

cat >"$tmpdir/release-bundle.json" <<'EOF'
{
  "schema_version": "1.1",
  "bundle_id": "rb-abcdef1234567-20260307T120000Z",
  "created_at": "2026-03-07T12:00:00Z",
  "repository": "Biji-Biji-Initiative/mereka-lms",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "target_environment": "production",
  "service_id": "mereka-lms",
  "contract_family": "release_bundle_schema",
  "contract_version": "1.1",
  "contract_ref": "Biji-Biji-Initiative/platform-control-plane@194e6001c924902e8bf3dafefdc37fc842c56653",
  "build": {
    "workflow": ".github/workflows/build-tutor-images.yml",
    "run_id": "12345",
    "run_attempt": "1"
  },
  "images": {
    "openedx": {
      "name": "ghcr.io/biji-biji-initiative/mereka-lms/openedx",
      "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    },
    "mfe": {
      "name": "ghcr.io/biji-biji-initiative/mereka-lms/mfe",
      "digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    }
  },
  "artifacts": {
    "sbom": {
      "openedx": "sbom-openedx",
      "mfe": "sbom-mfe"
    },
    "provenance": {
      "artifact_name": "slsa-provenance",
      "openedx_predicate": "var/ci/provenance-openedx.json",
      "mfe_predicate": "var/ci/provenance-mfe.json"
    },
    "vulnerability_scan": {
      "openedx": "trivy-openedx-scan",
      "mfe": "trivy-mfe-scan"
    }
  }
}
EOF

cat >"$tmpdir/platform-control-plane/contracts/release-contracts.yaml" <<'EOF'
schema_version: "1.0"
lanes:
  mereka-lms:
    runtime_profile: "R2"
    source_provenance_class: "S1"
EOF

cat >"$tmpdir/platform-control-plane/contracts/release-bundle-schema.yaml" <<'EOF'
schema_version: "1.1"
required_fields:
  - "bundle_id"
  - "lane"
  - "service_id"
  - "runtime_profile"
  - "source_provenance_class"
  - "created_at"
  - "source_revision"
  - "artifacts"
  - "config_digest"
  - "evidence_pack_ref"
  - "rollback_target"
properties:
  artifacts:
    type: "array"
    min_items: 1
    item_schema:
      required_fields: ["name", "image", "digest"]
EOF

PLATFORM_CONTROL_PLANE_ROOT="$tmpdir/platform-control-plane" \
  bash "$VERIFY" "$tmpdir/release-bundle.json" >/tmp/verify-control-plane-release-bundle-projection.out 2>&1
echo "PASS valid partial control-plane projection"

cat >"$tmpdir/platform-control-plane/contracts/release-contracts.yaml" <<'EOF'
schema_version: "1.0"
lanes: {}
EOF

set +e
PLATFORM_CONTROL_PLANE_ROOT="$tmpdir/platform-control-plane" \
  bash "$VERIFY" "$tmpdir/release-bundle.json" >/tmp/verify-control-plane-release-bundle-projection.out 2>&1
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo "FAIL missing lane contract: expected failure but verifier succeeded" >&2
  cat /tmp/verify-control-plane-release-bundle-projection.out >&2 || true
  exit 1
fi
echo "PASS missing lane contract is rejected"

echo "OK"
