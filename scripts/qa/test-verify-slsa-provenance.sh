#!/usr/bin/env bash
# Seeded-defect self-test for verify-slsa-provenance.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-slsa-provenance.sh"

tmpdir="$(mktemp -d -t verify-slsa-provenance.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows"

write_pass_fixture() {
  cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build
jobs:
  slsa-provenance:
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: sigstore/cosign-installer@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      - run: cosign attest --type slsaprovenance image
      - run: echo "slsa-provenance"
      - run: |
          cat <<'JSON' > provenance.json
          {"materials": [], "subject": []}
          JSON
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-slsa-provenance.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-slsa-provenance.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-slsa-provenance.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixture
run_expect_pass "workflow with pinned cosign + id-token + slsa fields passes"

cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build
jobs:
  slsa-provenance:
    permissions:
      contents: read
    steps:
      - uses: sigstore/cosign-installer@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      - run: cosign attest --type slsaprovenance image
      - run: echo "slsa-provenance"
      - run: |
          cat <<'JSON' > provenance.json
          {"materials": [], "subject": []}
          JSON
EOF
run_expect_fail "missing id-token: write permission is rejected"

echo "OK"
