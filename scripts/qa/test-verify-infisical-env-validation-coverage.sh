#!/usr/bin/env bash
# Seeded-defect self-test for verify-infisical-env-validation-coverage.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-infisical-env-validation-coverage.sh"

tmpdir="$(mktemp -d -t verify-infisical-env-validation-coverage.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows"

write_valid_workflow() {
  cat >"$tmpdir/.github/workflows/ci.yml" <<'EOF'
name: CI
env:
  ENABLE_STAGING_ENV: ${{ vars.ENABLE_STAGING_ENV }}
jobs:
  static-validation:
    runs-on: ubuntu-latest
    steps:
      - name: Validate Infisical secrets
        run: |
          STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
          STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh
          if [[ "${ENABLE_STAGING_ENV:-false}" == "true" ]]; then
            STRICT=1 INFISICAL_ENV=staging ./scripts/infra/infisical-validate-mereka-lms.sh
          fi
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-infisical-env-validation-coverage.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-infisical-env-validation-coverage.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-infisical-env-validation-coverage.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_valid_workflow
run_expect_pass "workflow with prod/dev/staging coverage passes"

cat >"$tmpdir/.github/workflows/ci.yml" <<'EOF'
name: CI
jobs:
  static-validation:
    runs-on: ubuntu-latest
    steps:
      - name: Validate Infisical secrets
        run: |
          STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
          STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh
EOF
run_expect_fail "missing staging guard/env wiring is rejected"

echo "OK"
