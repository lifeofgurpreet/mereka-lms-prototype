#!/usr/bin/env bash
# No @covers - setup utility, not a verification script
# Verify Local Setup is Complete and Ready
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
TUTOR_PLUGINS_ROOT="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$TUTOR_ROOT/plugins}}"
export TUTOR_ROOT TUTOR_PLUGINS_ROOT
export TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT"
if [[ -f ".venv/bin/activate" ]]; then
    # shellcheck source=/dev/null
    source .venv/bin/activate
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    PASSED=$((PASSED + 1))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    FAILED=$((FAILED + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

mysql_query() {
    local database="$1"
    local query="$2"

    if [[ -n "$database" ]]; then
        tutor local exec mysql env \
            MYSQL_DATABASE="$database" \
            MYSQL_QUERY="$query" \
            sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -Nse "$MYSQL_QUERY"'
    else
        tutor local exec mysql env \
            MYSQL_QUERY="$query" \
            sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -Nse "$MYSQL_QUERY"'
    fi
}

# This script requires a local Tutor development environment with Docker.
# Skip gracefully when prerequisites are not available.
if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: Docker not available (this script requires a local Tutor dev environment)"
  exit 0
fi
if [[ ! -f "$TUTOR_ROOT/config.yml" ]] && [[ ! -d ".venv" ]]; then
  echo "SKIP: No local Tutor environment detected (missing $TUTOR_ROOT/config.yml and .venv)"
  exit 0
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Local Setup Verification                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check Python environment
if [ -d ".venv" ]; then
    check_pass "Python virtual environment exists"
else
    check_fail "Python virtual environment missing"
fi

# Check Tutor config
if [ -f "$TUTOR_ROOT/config.yml" ]; then
    check_pass "Tutor config exists"
    
    # Check for local Docker services
    if grep -q "MYSQL_HOST: mysql" "$TUTOR_ROOT/config.yml"; then
        check_pass "MySQL host configured for local"
    else
        check_fail "MySQL host not configured for local"
    fi
    
    if grep -q "MONGODB_HOST: mongodb" "$TUTOR_ROOT/config.yml"; then
        check_pass "MongoDB host configured for local"
    else
        check_fail "MongoDB host not configured for local"
    fi
    
    # Check for cloud IPs
    if grep -q "10\.97\.0\." "$TUTOR_ROOT/config.yml"; then
        check_fail "Cloud IPs found in config (should use local Docker services)"
    else
        check_pass "No cloud IPs in config"
    fi
else
    check_fail "Tutor config missing"
fi

# Check Docker images
if docker image inspect openedx:nightly >/dev/null 2>&1; then
    check_pass "OpenEdX image exists"
else
    check_fail "OpenEdX image missing (run: make local-build-openedx)"
fi

if docker image inspect openedx-mfe:nightly >/dev/null 2>&1; then
    check_pass "MFE image exists"
else
    check_fail "MFE image missing (run: make local-build-mfe)"
fi

# Check containers
RUNNING_SERVICES="$(tutor local dc ps --services --filter status=running 2>/dev/null || true)"
SERVICE_COUNT="$(printf '%s\n' "$RUNNING_SERVICES" | sed '/^$/d' | wc -l | tr -d ' ')"
if [ "$SERVICE_COUNT" -gt 0 ]; then
    check_pass "Tutor services running: $SERVICE_COUNT"
else
    check_warn "No Tutor services reported running"
fi

# Check services
for service in lms cms mfe mysql mongodb redis; do
    if grep -qx "$service" <<<"$RUNNING_SERVICES"; then
        check_pass "$service running"
    else
        check_fail "$service not running"
    fi
done

http_status() {
    local url="$1"
    curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$url" 2>/dev/null || true
}

# Check URLs
LMS_STATUS="$(http_status http://localhost)"
if [[ " 200 302 " == *" ${LMS_STATUS:-000} "* ]]; then
    check_pass "LMS accessible (HTTP ${LMS_STATUS})"
else
    check_fail "LMS not accessible (HTTP ${LMS_STATUS:-000})"
fi

MFE_STATUS="$(http_status http://apps.localhost/authn/login)"
if [[ " 200 302 " == *" ${MFE_STATUS:-000} "* ]]; then
    check_pass "MFE accessible (HTTP ${MFE_STATUS})"
else
    check_fail "MFE not accessible (HTTP ${MFE_STATUS:-000})"
fi

# Check database
if mysql_query "" "SELECT 1;" >/dev/null 2>&1; then
    check_pass "MySQL accessible"
else
    check_fail "MySQL not accessible"
fi

# Check canonical local bootstrap readiness
BOOTSTRAP_READINESS_LOG="$(mktemp)"
if ./scripts/infra/verify-local-bootstrap-readiness.sh >"$BOOTSTRAP_READINESS_LOG" 2>&1; then
    check_pass "Local bootstrap readiness contract passes"
else
    check_fail "Local bootstrap readiness contract failed"
    sed 's/^/  /' "$BOOTSTRAP_READINESS_LOG"
fi
rm -f "$BOOTSTRAP_READINESS_LOG"

# Check admin user
ADMIN_EXISTS="$(tutor local exec lms python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; print('True' if get_user_model().objects.filter(username='admin').exists() else 'False')" 2>/dev/null | tail -1 || true)"
if [ "$ADMIN_EXISTS" = "True" ]; then
    check_pass "Admin user exists"
else
    check_fail "Admin user missing"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Verification Summary                                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  ✅ Passed: $PASSED"
echo "  ❌ Failed: $FAILED"
echo "  ⚠️  Warnings: $WARNINGS"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ Setup is complete and ready!${NC}"
    exit 0
else
    echo -e "${RED}❌ Setup incomplete. Fix issues above and run again.${NC}"
    echo ""
    echo "Quick fix: ./scripts/shared/setup-local.sh"
    exit 1
fi
