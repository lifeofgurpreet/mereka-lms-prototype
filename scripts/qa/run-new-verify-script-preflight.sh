#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
#
# Run the governance checks that usually fire when adding or changing
# scripts/qa/verify-*.sh.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/qa/run-new-verify-script-preflight.sh [--check-only]

Options:
  --check-only  Check generated catalog freshness instead of regenerating it.
  --help        Show this help.

Default mode regenerates verification/catalogs/verification_catalog.json and
verification/catalogs/VERIFICATION_CATALOG.md before running the guard suite.
EOF
}

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CHECK_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL python3 is required" >&2
  exit 1
fi

failures=0
results=()

run_step() {
  local label="$1"
  shift

  echo ""
  echo "=== ${label} ==="

  set +e
  (
    cd "$REPO_ROOT"
    "$@"
  )
  local rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "PASS preflight step: ${label}"
    results+=("PASS ${label}")
  else
    echo "FAIL preflight step: ${label} (exit ${rc})"
    results+=("FAIL ${label}")
    failures=$((failures + 1))
  fi
}

echo "=== New verify-script preflight ==="
echo "Repo root: ${REPO_ROOT}"

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  run_step "Verification catalog freshness" \
    python3 scripts/qa/generate-verification-catalog.py --check
else
  run_step "Regenerate verification catalog" \
    python3 scripts/qa/generate-verification-catalog.py
fi

run_step "Staging vocabulary drift" \
  bash scripts/qa/verify-staging-vocabulary-drift.sh
run_step "Script governance orphan allowlist" \
  bash scripts/qa/verify-script-governance-orphans.sh
run_step "SiteConfiguration authority allowlist" \
  bash scripts/qa/verify-siteconfig-authority.sh
run_step "Verify-script reachability allowlist" \
  bash scripts/qa/verify-verify-script-reachability.sh
run_step "Verification sprawl budget" \
  bash scripts/qa/verify-verification-sprawl-budget.sh

echo ""
echo "=== New verify-script preflight summary ==="
printf '%s\n' "${results[@]}"

if [[ "$failures" -gt 0 ]]; then
  echo "FAIL ${failures} preflight step(s) failed"
  exit 1
fi

echo "PASS all new verify-script preflight steps passed"
