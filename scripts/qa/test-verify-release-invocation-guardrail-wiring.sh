#!/usr/bin/env bash
# Seeded-defect self-test for verify-release-invocation-guardrail-wiring.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-release-invocation-guardrail-wiring.sh"

tmpdir="$(mktemp -d -t verify-release-invocation-guardrail-wiring.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/infra" "$tmpdir/.github/workflows"

write_pass_fixtures() {
  cat >"$tmpdir/scripts/infra/canonical-release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CONFIRM_CANONICAL_RELEASE="${CONFIRM_CANONICAL_RELEASE:-false}"
CONFIRM_PUSH_CANONICAL_RELEASE="${CONFIRM_PUSH_CANONICAL_RELEASE:-false}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-false}"
CONFIRM_RELEASE_OPENEDX_GITOPS="RELEASE_OPENEDX_GITOPS"
CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS="PUSH_RELEASE_OPENEDX_GITOPS"
EOF
  chmod +x "$tmpdir/scripts/infra/canonical-release.sh"

  cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
jobs:
  build:
    steps:
      - run: |
          CONFIRM_RELEASE_OPENEDX_GITOPS=RELEASE_OPENEDX_GITOPS \
          CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS=PUSH_RELEASE_OPENEDX_GITOPS \
          ALLOW_PROD_APPLY=true \
          ./scripts/infra/release-openedx-gitops.sh
EOF

  cat >"$tmpdir/scripts/infra/create-release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "CONFIRM_RELEASE_OPENEDX_GITOPS=RELEASE_OPENEDX_GITOPS"
echo "CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS=PUSH_RELEASE_OPENEDX_GITOPS"
EOF
  chmod +x "$tmpdir/scripts/infra/create-release.sh"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-release-invocation-guardrail-wiring.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-release-invocation-guardrail-wiring.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-release-invocation-guardrail-wiring.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "guardrail env propagation wiring passes"

cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
jobs:
  build:
    steps:
      - run: |
          CONFIRM_RELEASE_OPENEDX_GITOPS=RELEASE_OPENEDX_GITOPS \
          CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS=PUSH_RELEASE_OPENEDX_GITOPS \
          ./scripts/infra/release-openedx-gitops.sh
EOF
run_expect_fail "missing ALLOW_PROD_APPLY in workflow wiring is rejected"

echo "OK"
