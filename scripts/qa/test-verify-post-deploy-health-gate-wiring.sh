#!/usr/bin/env bash
# Seeded-defect self-test for verify-post-deploy-health-gate-wiring.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-post-deploy-health-gate-wiring.sh"

tmpdir="$(mktemp -d -t verify-post-deploy-health-gate-wiring.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/config"

write_pass_fixtures() {
  cat >"$tmpdir/config/runtime-proof-policy.env" <<'EOF'
AUTHORITATIVE_RUNTIME_PROOF_ENV=staging
POST_DEPLOY_WORKFLOW_RUN_ENV=production
POST_DEPLOY_MANUAL_DEFAULT_ENV=staging
STAGING_RUNTIME_BASE_URL=https://staging.academyv2.mereka.io
PROD_RUNTIME_MODE=parked
PROD_PARKED_STATUS_CONTEXT=post-deploy/production-parked-state
PROD_PARKED_VERIFIER=scripts/qa/verify-prod-parked-state.sh
EOF

  cat >"$tmpdir/.github/workflows/post-deploy-e2e.yml" <<'EOF'
name: post-deploy-e2e
jobs:
  verify:
    steps:
      - run: scripts/qa/verify-post-deploy-gate.sh --mode offline
      - run: |
          context="${{ needs.gate-check.outputs.status_context }}"
      - run: verify-prod-parked-state.sh
EOF

  cat >"$tmpdir/.github/workflows/operations-gates-runtime.yml" <<'EOF'
name: operations-gates-runtime
jobs:
  gates:
    steps:
      - run: ./scripts/qa/run-operations-gates.sh --env prod
EOF

  cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
jobs:
  release:
    steps:
      - run: ./scripts/infra/release-openedx-gitops.sh --verify-runtime
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-post-deploy-health-gate-wiring.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-post-deploy-health-gate-wiring.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-post-deploy-health-gate-wiring.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "all required workflow wiring patterns pass"

cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
jobs:
  release:
    steps:
      - run: ./scripts/infra/release-openedx-gitops.sh
EOF
run_expect_fail "missing --verify-runtime flag is rejected"

echo "OK"
