#!/usr/bin/env bash
# Seeded-defect self-test for verify-release-promotion-wiring.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-release-promotion-wiring.sh"

tmpdir="$(mktemp -d -t verify-release-promotion-wiring.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows"

write_pass_fixture() {
  cat >"$tmpdir/.github/workflows/release.yml" <<'EOF'
name: release
jobs:
  create-github-release:
    runs-on: ubuntu-latest
  promote-to-production:
    needs: create-github-release
    environment: production
    permissions:
      contents: write
    steps:
      - run: echo "verify image exists via docker manifest"
      - run: echo "resolve-image-digest"
      - uses: actions/checkout@v4
        with:
          repository: Biji-Biji-Initiative/bbi-infrastructure
      - run: |
          export GITOPS_TOKEN=${{ secrets.GITOPS_TOKEN_BBI_KUBERNATE }}
          ./scripts/infra/release-openedx-gitops.sh \
            --target-env production \
            --require-digests \
            --apply --commit --push
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-release-promotion-wiring.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-release-promotion-wiring.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-release-promotion-wiring.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixture
run_expect_pass "promotion workflow with required guardrails passes"

cat >"$tmpdir/.github/workflows/release.yml" <<'EOF'
name: release
jobs:
  create-github-release:
    runs-on: ubuntu-latest
  promote-to-production:
    needs: create-github-release
    environment: production
    permissions:
      contents: write
    steps:
      - run: |
          export GITOPS_TOKEN=${{ secrets.GITOPS_TOKEN_BBI_KUBERNATE }}
          ./scripts/infra/release-openedx-gitops.sh \
            --target-env production \
            --apply --commit --push
EOF
run_expect_fail "missing --require-digests is rejected"

echo "OK"
