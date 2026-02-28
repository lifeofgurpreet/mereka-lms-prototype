#!/usr/bin/env bash
# Frontend performance spot-check wrapper.
# Runs static budget checks + Paragon runtime/theme artifact checks in one pass.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_URL="${PARAGON_RUNTIME_URL:-}"
REQUIRE_RUNTIME=0
ENVIRONMENT=""

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

usage() {
  cat <<'EOF'
Usage: verify-frontend-performance-spotcheck.sh [--runtime-url <url>] [--require-runtime]

Options:
  --env <prod|dev>    Resolve runtime URL automatically from shared domain config.
  --runtime-url <url>  Optional runtime base URL for live theme endpoint checks.
  --require-runtime    Fail if runtime URL checks cannot run.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -lt 2 ]] && { echo "ERROR: --env requires a value" >&2; exit 2; }
      ENVIRONMENT="$2"
      shift 2
      ;;
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

if [[ -n "$ENVIRONMENT" ]]; then
  case "$ENVIRONMENT" in
    prod|dev) ;;
    *)
      echo "ERROR: --env must be prod or dev (got: $ENVIRONMENT)" >&2
      exit 2
      ;;
  esac

  # shellcheck source=scripts/shared/config.sh
  source "$REPO_ROOT/scripts/shared/config.sh"
  if [[ -z "$RUNTIME_URL" ]]; then
    if [[ "$ENVIRONMENT" == "prod" ]]; then
      RUNTIME_URL="https://${MFE_DOMAIN}"
    else
      RUNTIME_URL="https://${DEV_MFE_DOMAIN}"
    fi
  fi
fi

if [[ -n "$RUNTIME_URL" ]]; then
  normalized_runtime_url="$(python3 - "$RUNTIME_URL" <<'PY'
import sys
from urllib.parse import urlparse
raw = (sys.argv[1] or "").strip()
if "://" not in raw:
    raw = f"https://{raw}"
parsed = urlparse(raw)
if not parsed.netloc:
    print("")
else:
    print(f"{parsed.scheme or 'https'}://{parsed.netloc}")
PY
)"
  if [[ -z "$normalized_runtime_url" ]]; then
    echo "ERROR: Invalid runtime URL: $RUNTIME_URL" >&2
    exit 2
  fi
  if [[ "$normalized_runtime_url" != "$RUNTIME_URL" ]]; then
    echo "INFO: Normalized runtime URL to origin: $normalized_runtime_url (from $RUNTIME_URL)"
  fi
  RUNTIME_URL="$normalized_runtime_url"
fi

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
