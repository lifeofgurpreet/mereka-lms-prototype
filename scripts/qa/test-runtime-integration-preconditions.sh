#!/usr/bin/env bash
# Seeded regression test for runtime integration script precondition handling.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MFE_SCRIPT="$ROOT_DIR/scripts/qa/test-mfe-oauth-fix.sh"
STRIPE_SCRIPT="$ROOT_DIR/scripts/qa/test-stripe-webhook-delivery.sh"

if [[ ! -x "$MFE_SCRIPT" || ! -x "$STRIPE_SCRIPT" ]]; then
  echo "FAIL required runtime scripts are missing or not executable" >&2
  exit 1
fi

tmpdir="$(mktemp -d -t runtime-integration-preconditions.XXXXXX)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

assert_contains() {
  local needle="$1"
  local file="$2"
  if ! rg -q "$needle" "$file"; then
    echo "FAIL expected '$needle' in $file" >&2
    cat "$file" >&2
    exit 1
  fi
}

# MFE script: offline/non-json surface should SKIP in non-strict mode.
set +e
STRICT_RUNTIME=0 LMS_DOMAIN="127.0.0.1:9" bash "$MFE_SCRIPT" >"$tmpdir/mfe-skip.log" 2>&1
mfe_skip_rc=$?
set -e
if [[ "$mfe_skip_rc" -ne 0 ]]; then
  echo "FAIL expected MFE script to SKIP (exit 0) when STRICT_RUNTIME=0" >&2
  cat "$tmpdir/mfe-skip.log" >&2
  exit 1
fi
assert_contains "SKIP:" "$tmpdir/mfe-skip.log"

# MFE script: strict mode should fail on same precondition.
set +e
STRICT_RUNTIME=1 LMS_DOMAIN="127.0.0.1:9" bash "$MFE_SCRIPT" >"$tmpdir/mfe-strict.log" 2>&1
mfe_strict_rc=$?
set -e
if [[ "$mfe_strict_rc" -eq 0 ]]; then
  echo "FAIL expected MFE script to fail when STRICT_RUNTIME=1" >&2
  cat "$tmpdir/mfe-strict.log" >&2
  exit 1
fi

# Stripe script: missing context/deploy should SKIP in non-strict mode.
set +e
STRICT_RUNTIME=0 CONTEXT_PROD="__missing_context__" bash "$STRIPE_SCRIPT" prod >"$tmpdir/stripe-skip.log" 2>&1
stripe_skip_rc=$?
set -e
if [[ "$stripe_skip_rc" -ne 0 ]]; then
  echo "FAIL expected Stripe script to SKIP (exit 0) when STRICT_RUNTIME=0" >&2
  cat "$tmpdir/stripe-skip.log" >&2
  exit 1
fi
assert_contains "SKIP:" "$tmpdir/stripe-skip.log"

# Stripe script: strict mode should fail on same precondition.
set +e
STRICT_RUNTIME=1 CONTEXT_PROD="__missing_context__" bash "$STRIPE_SCRIPT" prod >"$tmpdir/stripe-strict.log" 2>&1
stripe_strict_rc=$?
set -e
if [[ "$stripe_strict_rc" -eq 0 ]]; then
  echo "FAIL expected Stripe script to fail when STRICT_RUNTIME=1" >&2
  cat "$tmpdir/stripe-strict.log" >&2
  exit 1
fi

echo "PASS test-runtime-integration-preconditions"
