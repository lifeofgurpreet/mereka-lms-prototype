#!/usr/bin/env bash
# Comprehensive test suite for local Open edX environment
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0

test_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((FAILED++))
}

test_warn() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Comprehensive Local Environment Test Suite             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 1. Container Health Checks
echo "=== 1. Container Health ==="
CONTAINERS=$(docker ps --filter "name=tutor_local" --format "{{.Names}}" | wc -l | tr -d ' ')
if [ "$CONTAINERS" -ge 23 ]; then
    test_pass "Containers running: $CONTAINERS"
else
    test_fail "Expected 23+ containers, found: $CONTAINERS"
fi

# Check critical services
for service in lms cms mfe mysql mongodb redis; do
    if docker ps --filter "name=tutor_local-${service}" --format "{{.Status}}" | grep -q "Up"; then
        test_pass "$service container running"
    else
        test_fail "$service container not running"
    fi
done
echo ""

# 2. Database Connectivity
echo "=== 2. Database Connectivity ==="
if docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu -e "SELECT 1;" >/dev/null 2>&1; then
    test_pass "MySQL connection"
else
    test_fail "MySQL connection failed"
fi

if docker exec tutor_local-mongodb-1 mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    test_pass "MongoDB connection"
else
    test_fail "MongoDB connection failed"
fi

if docker exec tutor_local-redis-1 redis-cli ping >/dev/null 2>&1; then
    test_pass "Redis connection"
else
    test_fail "Redis connection failed"
fi
echo ""

# 3. Database Data
echo "=== 3. Database Data ==="
USER_COUNT=$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "SELECT COUNT(*) FROM auth_user;" 2>/dev/null | tail -1 | tr -d ' ')
if [ -n "$USER_COUNT" ] && [ "$USER_COUNT" -gt 0 ]; then
    test_pass "Users in database: $USER_COUNT"
else
    test_warn "No users found in database (may be fresh install)"
fi

ENROLLMENT_COUNT=$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "SELECT COUNT(*) FROM student_courseenrollment;" 2>/dev/null | tail -1 | tr -d ' ')
if [ -n "$ENROLLMENT_COUNT" ] && [ "$ENROLLMENT_COUNT" -gt 0 ]; then
    test_pass "Enrollments in database: $ENROLLMENT_COUNT"
else
    test_warn "No enrollments found"
fi
echo ""

# 4. Service URLs
echo "=== 4. Service URLs ==="
URLS=(
    "http://localhost"
    "http://studio.localhost"
    "http://apps.localhost/authn/login"
    "http://discovery.localhost"
    "http://ecommerce.localhost"
    "http://localhost:8088"
)

for url in "${URLS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
        test_pass "$url (HTTP $HTTP_CODE)"
    else
        test_fail "$url (HTTP $HTTP_CODE)"
    fi
done
echo ""

# 5. MFE Configuration
echo "=== 5. MFE Configuration ==="
MFE_CONFIG=$(curl -s "http://localhost/api/mfe_config/v1?mfe=authn" 2>/dev/null)
if echo "$MFE_CONFIG" | grep -q "BASE_URL"; then
    test_pass "MFE Config API responding"
    LOGIN_URL=$(echo "$MFE_CONFIG" | python3 -c "import sys, json; print(json.load(sys.stdin).get('LOGIN_URL', 'NOT FOUND'))" 2>/dev/null || echo "NOT FOUND")
    if [ "$LOGIN_URL" != "NOT FOUND" ]; then
        test_pass "Login URL configured: $LOGIN_URL"
    else
        test_warn "Login URL not found in MFE config"
    fi
else
    test_fail "MFE Config API not responding"
fi
echo ""

# 6. Admin User
echo "=== 6. Admin User ==="
ADMIN_EXISTS=$(docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; print('True' if get_user_model().objects.filter(username='admin').exists() else 'False')" 2>/dev/null | tail -1)
if [ "$ADMIN_EXISTS" = "True" ]; then
    test_pass "Admin user exists"
    
    ADMIN_ACTIVE=$(docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; u = get_user_model().objects.get(username='admin'); print('True' if u.is_active and u.is_staff and u.is_superuser else 'False')" 2>/dev/null | tail -1)
    if [ "$ADMIN_ACTIVE" = "True" ]; then
        test_pass "Admin user is active, staff, and superuser"
    else
        test_fail "Admin user missing required flags"
    fi
else
    test_fail "Admin user does not exist"
fi
echo ""

# 7. Configuration Parity
echo "=== 7. Configuration Parity ==="
if grep -q "10\.97\.0\." tutor_env/config.yml 2>/dev/null; then
    test_fail "Cloud IPs found in config"
else
    test_pass "No cloud IPs in config"
fi

if grep -q "MYSQL_HOST: mysql" tutor_env/config.yml 2>/dev/null; then
    test_pass "MySQL host configured correctly"
else
    test_fail "MySQL host not configured correctly"
fi
echo ""

# 8. MFEs Available
echo "=== 8. MFEs Available ==="
MFE_COUNT=$(docker exec tutor_local-mfe-1 ls -la /openedx/dist/ 2>/dev/null | grep "^d" | wc -l | tr -d ' ')
if [ "$MFE_COUNT" -ge 12 ]; then
    test_pass "MFEs available: $MFE_COUNT"
else
    test_fail "Expected 12+ MFEs, found: $MFE_COUNT"
fi
echo ""

# 9. Superset Analytics
echo "=== 9. Superset Analytics ==="
if curl -s http://localhost:8088 >/dev/null 2>&1; then
    test_pass "Superset accessible at http://localhost:8088"
else
    test_fail "Superset not accessible"
fi

if grep -q "ASPECTS_SUPERSET_DATABASE_HOST: clickhouse" tutor_env/config.yml 2>/dev/null; then
    test_pass "Superset database host configured correctly"
else
    test_fail "Superset database host not configured correctly"
fi
echo ""

# Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Test Summary                                            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  ✅ Passed: $PASSED"
echo "  ❌ Failed: $FAILED"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Review output above.${NC}"
    exit 1
fi

