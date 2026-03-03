#!/usr/bin/env bash
# @covers AC-017
# @spec: secrets-management_spec.md
# Verify dev/local overlay uses *_DEV suffixed keys for Stripe and MySQL.
#
# This is a repo-level guardrail so dev cannot accidentally point at prod payment/db creds.
#
# Usage:
#   ./scripts/qa/verify-dev-prod-secret-separation.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

source "$ROOT_DIR/scripts/shared/ci-skip-guards.sh"
require_command rg || exit 0

failures=0

fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }
pass() { echo "[PASS] $*"; }

es_dev="deploy/k8s/overlays/local/patches/openedx-secrets-dev.yaml"
db_dev="deploy/k8s/overlays/local/patches/database-secrets-dev.yaml"

if [[ ! -f "$es_dev" ]]; then
  fail "Missing $es_dev"
else
  rg -n "MEREKA_LMS_STRIPE_SECRET_KEY_DEV" "$es_dev" >/dev/null || fail "Stripe dev secret key missing in $es_dev"
  rg -n "MEREKA_LMS_STRIPE_PUBLISHABLE_KEY_DEV" "$es_dev" >/dev/null || fail "Stripe dev publishable key missing in $es_dev"
  rg -n "MEREKA_LMS_STRIPE_WEBHOOK_SECRET_DEV" "$es_dev" >/dev/null || fail "Stripe dev webhook secret missing in $es_dev"
  pass "Stripe *_DEV keys present in local overlay"
fi

if [[ ! -f "$db_dev" ]]; then
  fail "Missing $db_dev"
else
  for k in \
    MEREKA_LMS_MYSQL_ROOT_PASSWORD_DEV \
    MEREKA_LMS_MYSQL_PASSWORD_DEV \
    MEREKA_LMS_MYSQL_DISCOVERY_PASSWORD_DEV \
    MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD_DEV \
    MEREKA_LMS_MYSQL_NOTES_PASSWORD_DEV \
    MEREKA_LMS_MYSQL_XQUEUE_PASSWORD_DEV \
    MEREKA_LMS_MYSQL_CREDENTIALS_PASSWORD_DEV; do
    rg -n "$k" "$db_dev" >/dev/null || fail "Missing $k in $db_dev"
  done
  pass "MySQL *_DEV keys present in local overlay"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "FAIL ($failures violation(s))" >&2
  exit 1
fi
echo "OK"

