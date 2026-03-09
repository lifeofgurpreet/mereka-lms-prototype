#!/usr/bin/env bash
# Seeded-defect self-test for verify-release-bundle.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-release-bundle.sh"

tmpdir="$(mktemp -d -t verify-release-bundle.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/infrastructure/ci" "$tmpdir/var/ci"

cat >"$tmpdir/infrastructure/ci/release-bundle.schema.json" <<'EOF'
{
  "type": "object",
  "required": [
    "schema_version",
    "bundle_id",
    "commit_sha",
    "images",
    "target_environment",
    "build"
  ]
}
EOF

write_valid_bundle() {
  cat >"$tmpdir/var/ci/release-bundle.json" <<'EOF'
{
  "schema_version": "1.0.0",
  "bundle_id": "rb-abcdef1234567-20260307T120000Z",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "images": {
    "openedx": {
      "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    },
    "mfe": {
      "digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    }
  },
  "target_environment": "production",
  "build": {
    "run_id": "12345",
    "run_attempt": "1"
  },
  "service_id": "mereka-lms",
  "contract_family": "release-bundle",
  "contract_version": "1.0",
  "contract_ref": "Biji-Biji-Initiative/platform-control-plane@5fffde1a"
}
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" "$tmpdir/var/ci/release-bundle.json" >/tmp/verify-release-bundle.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" "$tmpdir/var/ci/release-bundle.json" >/tmp/verify-release-bundle.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-release-bundle.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_valid_bundle
run_expect_pass "valid release bundle passes schema and digest checks"

cat >"$tmpdir/var/ci/release-bundle.json" <<'EOF'
{
  "schema_version": "1.0.0",
  "bundle_id": "rb-abcdef1234567-20260307T120000Z",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "images": {
    "openedx": {
      "digest": "sha256:invaliddigest"
    },
    "mfe": {
      "digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    }
  },
  "target_environment": "production",
  "build": {
    "run_id": "12345",
    "run_attempt": "1"
  },
  "service_id": "mereka-lms",
  "contract_family": "release-bundle",
  "contract_version": "1.0",
  "contract_ref": "Biji-Biji-Initiative/platform-control-plane@5fffde1a"
}
EOF
run_expect_fail "invalid image digest is rejected"

echo "OK"
