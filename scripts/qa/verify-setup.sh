#!/usr/bin/env bash
# No @covers - setup utility, not a verification script
# Verify Local Setup is Complete and Ready
set -euo pipefail

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

# This script requires a local Tutor development environment with Docker.
# Skip gracefully when prerequisites are not available.
if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: Docker not available (this script requires a local Tutor dev environment)"
  exit 0
fi
if [[ ! -f "tutor_env/config.yml" ]] && [[ ! -d ".venv" ]]; then
  echo "SKIP: No local Tutor environment detected (missing tutor_env/config.yml and .venv)"
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
if [ -f "tutor_env/config.yml" ]; then
    check_pass "Tutor config exists"
    
    # Check for local Docker services
    if grep -q "MYSQL_HOST: mysql" tutor_env/config.yml; then
        check_pass "MySQL host configured for local"
    else
        check_fail "MySQL host not configured for local"
    fi
    
    if grep -q "MONGODB_HOST: mongodb" tutor_env/config.yml; then
        check_pass "MongoDB host configured for local"
    else
        check_fail "MongoDB host not configured for local"
    fi
    
    # Check for cloud IPs
    if grep -q "10\.97\.0\." tutor_env/config.yml; then
        check_fail "Cloud IPs found in config (should use local Docker services)"
    else
        check_pass "No cloud IPs in config"
    fi
else
    check_fail "Tutor config missing"
fi

# Check Docker images
if docker images | grep -q "openedx.*nightly"; then
    check_pass "OpenEdX image exists"
else
    check_fail "OpenEdX image missing (run: tutor images build openedx)"
fi

if docker images | grep -q "openedx-mfe.*nightly"; then
    check_pass "MFE image exists"
else
    check_fail "MFE image missing (run: tutor images build mfe)"
fi

# Check containers
CONTAINERS=$(docker ps --filter "name=tutor_local" --format "{{.Names}}" | wc -l | tr -d ' ')
if [ "$CONTAINERS" -ge 20 ]; then
    check_pass "Containers running: $CONTAINERS"
else
    check_warn "Only $CONTAINERS containers running (expected 20+)"
fi

# Check services
for service in lms cms mfe mysql mongodb redis; do
    if docker ps --filter "name=tutor_local-${service}" --format "{{.Status}}" | grep -q "Up"; then
        check_pass "$service running"
    else
        check_fail "$service not running"
    fi
done

# Check URLs
if curl -s http://localhost >/dev/null 2>&1; then
    check_pass "LMS accessible"
else
    check_fail "LMS not accessible"
fi

if curl -s http://apps.localhost/authn/login >/dev/null 2>&1; then
    check_pass "MFE accessible"
else
    check_fail "MFE not accessible"
fi

# Check database
if docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu -e "SELECT 1;" >/dev/null 2>&1; then
    check_pass "MySQL accessible"
else
    check_fail "MySQL not accessible"
fi

# Check organizations
ORG_COUNT=$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "SELECT COUNT(*) FROM organizations_organization;" 2>/dev/null | tail -1 | tr -d ' ')
if [ "$ORG_COUNT" -ge 2 ]; then
    check_pass "Organizations configured: $ORG_COUNT"
else
    check_fail "Organizations missing (expected 2+, found $ORG_COUNT)"
fi

# Check sites
SITE_COUNT=$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "SELECT COUNT(*) FROM django_site WHERE domain LIKE '%biji%' OR domain LIKE '%skill%';" 2>/dev/null | tail -1 | tr -d ' ')
if [ "$SITE_COUNT" -ge 2 ]; then
    check_pass "Multi-site configured: $SITE_COUNT sites"
else
    check_fail "Multi-site missing (expected 2+ sites, found $SITE_COUNT)"
fi

# Check admin user
ADMIN_EXISTS=$(docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; print('True' if get_user_model().objects.filter(username='admin').exists() else 'False')" 2>/dev/null | tail -1)
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

