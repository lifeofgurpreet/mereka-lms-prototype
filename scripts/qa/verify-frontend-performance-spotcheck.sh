#!/usr/bin/env bash
# Frontend performance spot-check wrapper.
# Runs static budget checks + Paragon runtime/theme artifact checks in one pass.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_URL="${PARAGON_RUNTIME_URL:-}"
REQUIRE_RUNTIME=0

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

usage() {
  cat <<'EOF'
Usage: verify-frontend-performance-spotcheck.sh [--runtime-url <url>] [--require-runtime]

Options:
  --runtime-url <url>  Optional runtime base URL for live theme endpoint checks.
  --require-runtime    Fail if runtime URL checks cannot run.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-url)
      [[ $# -lt 2 ]] && { echo "ERROR: --runtime-url requires a value" >&2; exit 2; }
      RUNTIME_URL="$2"
      shift 2
      ;;
    --require-runtime)
      REQUIRE_RUNTIME=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

echo "=== Frontend Performance Spot-Check ==="

echo "-> Running Lighthouse budget verifier"
if "$REPO_ROOT/scripts/qa/verify-lighthouse-budgets.sh"; then
  pass "Lighthouse budgets passed"
else
  fail "Lighthouse budgets failed"
fi

echo "-> Running Paragon runtime/artifact verifier"
paragon_args=()
if [[ -n "$RUNTIME_URL" ]]; then
  paragon_args+=(--runtime-url "$RUNTIME_URL")
fi
if [[ "$REQUIRE_RUNTIME" == "1" ]]; then
  paragon_args+=(--require-runtime)
fi
if "$REPO_ROOT/scripts/qa/verify-paragon-runtime.sh" "${paragon_args[@]}"; then
  pass "Paragon runtime/artifact checks passed"
else
  fail "Paragon runtime/artifact checks failed"
fi

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
