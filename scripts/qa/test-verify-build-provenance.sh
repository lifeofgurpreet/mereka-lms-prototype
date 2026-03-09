#!/usr/bin/env bash
# Seeded-defect self-test for verify-build-provenance.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-build-provenance.sh"

tmpdir="$(mktemp -d -t verify-build-provenance.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/var/ci"

write_valid_record() {
  cat >"$tmpdir/var/ci/build-provenance.json" <<'EOF'
{
  "schema_version": "1.0.0",
  "repository": "Biji-Biji-Initiative/mereka-lms",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "target_environment": "production",
  "release_bundle_id": "rb-abcdef1234567-20260307T120000Z",
  "images": {
    "openedx_digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "mfe_digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  },
  "gitops": {
    "repository": "Biji-Biji-Initiative/bbi-infrastructure",
    "commit_sha": "fedcba9876543210fedcba9876543210fedcba98"
  }
}
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" "$tmpdir/var/ci/build-provenance.json" >/tmp/verify-build-provenance.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" "$tmpdir/var/ci/build-provenance.json" >/tmp/verify-build-provenance.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-build-provenance.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_valid_record
run_expect_pass "valid build provenance passes contract"

cat >"$tmpdir/var/ci/build-provenance.json" <<'EOF'
{
  "schema_version": "1.0.0",
  "repository": "Biji-Biji-Initiative/mereka-lms",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "target_environment": "production",
  "release_bundle_id": "rb-abcdef1234567-20260307T120000Z",
  "images": {
    "openedx_digest": "sha256:notvalid",
    "mfe_digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  },
  "gitops": {
    "repository": "Biji-Biji-Initiative/bbi-infrastructure",
    "commit_sha": "fedcba9876543210fedcba9876543210fedcba98"
  }
}
EOF
run_expect_fail "invalid openedx digest is rejected"

echo "OK"
