#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify Authentik apply scripts enforce explicit confirmation and prod safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADMIN_SCRIPT="$REPO_ROOT/scripts/infra/ensure-authentik-admin.sh"
OIDC_SCRIPT="$REPO_ROOT/scripts/infra/ensure-authentik-oidc-redirect-uris.sh"
MFA_SCRIPT="$REPO_ROOT/scripts/infra/ensure-authentik-admin-mfa.sh"
HARDENING_SCRIPT="$REPO_ROOT/scripts/infra/ensure-authentik-hardening.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -qE "$pattern" "$file"; then
    pass "$message"
  else
    fail "$message"
  fi
}

echo "=== Authentik Apply Guardrails ==="
echo

for script in "$ADMIN_SCRIPT" "$OIDC_SCRIPT" "$MFA_SCRIPT" "$HARDENING_SCRIPT"; do
  if [[ -f "$script" ]]; then
    pass "$(basename "$script") exists"
    require_pattern "$script" 'set -euo pipefail' "$(basename "$script") uses strict bash mode"
    require_pattern "$script" 'ALLOW_PROD_APPLY' "$(basename "$script") has prod apply guard variable"
    require_pattern "$script" 'CREATE_PREOP_BACKUP' "$(basename "$script") has pre-op backup control variable"
    require_pattern "$script" 'Refusing --apply without explicit confirmation token' "$(basename "$script") blocks apply without confirmation token"
    require_pattern "$script" 'Refusing --apply on prod-like context' "$(basename "$script") blocks prod-like apply without explicit override"
    require_pattern "$script" 'velero backup create' "$(basename "$script") includes Velero pre-op backup action"
  else
    fail "Missing script: ${script#$REPO_ROOT/}"
  fi
done

require_pattern "$ADMIN_SCRIPT" 'CONFIRM_ENSURE_AUTHENTIK_ADMIN' 'ensure-authentik-admin has confirmation variable'
require_pattern "$ADMIN_SCRIPT" 'CONFIRM_TOKEN="ENSURE_AUTHENTIK_ADMIN"' 'ensure-authentik-admin has explicit confirmation token'

require_pattern "$OIDC_SCRIPT" 'CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS' 'ensure-authentik-oidc-redirect-uris has confirmation variable'
require_pattern "$OIDC_SCRIPT" 'CONFIRM_TOKEN="ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS"' 'ensure-authentik-oidc-redirect-uris has explicit confirmation token'

require_pattern "$MFA_SCRIPT" 'CONFIRM_ENSURE_AUTHENTIK_ADMIN_MFA' 'ensure-authentik-admin-mfa has confirmation variable'
require_pattern "$MFA_SCRIPT" 'CONFIRM_TOKEN="ENSURE_AUTHENTIK_ADMIN_MFA"' 'ensure-authentik-admin-mfa has explicit confirmation token'

require_pattern "$HARDENING_SCRIPT" 'CONFIRM_ENSURE_AUTHENTIK_HARDENING' 'ensure-authentik-hardening has confirmation variable'
require_pattern "$HARDENING_SCRIPT" 'CONFIRM_TOKEN="ENSURE_AUTHENTIK_HARDENING"' 'ensure-authentik-hardening has explicit confirmation token'
require_pattern "$HARDENING_SCRIPT" 'CONFIRM_ENSURE_AUTHENTIK_ADMIN="ENSURE_AUTHENTIK_ADMIN"' 'ensure-authentik-hardening passes admin child confirmation token'
require_pattern "$HARDENING_SCRIPT" 'CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS="ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS"' 'ensure-authentik-hardening passes oidc child confirmation token'
require_pattern "$HARDENING_SCRIPT" 'CONFIRM_ENSURE_AUTHENTIK_ADMIN_MFA="ENSURE_AUTHENTIK_ADMIN_MFA"' 'ensure-authentik-hardening passes mfa child confirmation token'

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
