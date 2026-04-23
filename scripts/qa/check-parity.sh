#!/usr/bin/env bash
# Check parity between local and production environments
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Local/Production Parity Check                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
export TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
export TUTOR_PLUGINS_ROOT="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$TUTOR_ROOT/plugins}}"
export TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT"
if [[ -f .venv/bin/activate ]]; then
    # shellcheck source=/dev/null
    source .venv/bin/activate
fi

# Check if local environment is running
RUNNING_SERVICES="$(tutor local dc ps --services --filter status=running 2>/dev/null || true)"
if ! grep -q . <<<"$RUNNING_SERVICES"; then
    echo -e "${RED}❌ Local environment not running${NC}"
    echo "   Run: make tutor-start"
    exit 1
fi

echo "=== Services Parity ==="
LOCAL_SERVICES="$(printf '%s\n' "$RUNNING_SERVICES" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "Local Tutor services running: ${LOCAL_SERVICES}"
echo ""

echo "=== MFEs Parity ==="
if tutor local exec mfe ls /openedx/dist/ >/dev/null 2>&1; then
    LOCAL_MFES=$(tutor local exec mfe sh -lc 'for path in /openedx/dist/*; do [ -d "$path" ] && basename "$path"; done' 2>/dev/null | sort)
    MFE_COUNT=$(echo "$LOCAL_MFES" | wc -l | tr -d ' ')
    echo "Local MFEs found: ${MFE_COUNT}"
    echo "$LOCAL_MFES" | sed 's/^/  - /'
    echo ""
    echo "Expected MFEs:"
    echo "  - authn, account, profile, learning, learner-dashboard"
    echo "  - course-authoring, gradebook, discussions"
    echo "  - communications, orders, payment, ora-grading"
else
    echo -e "${RED}❌ Cannot access MFE container${NC}"
fi
echo ""

echo "=== Configuration Parity ==="
if [ -f "$TUTOR_ROOT/config.yml" ]; then
    echo "Open edX Version:"
    grep -E "OPENEDX.*VERSION" "$TUTOR_ROOT/config.yml" | head -3 | sed 's/^/  /' || echo "  Not found"
    echo ""
    echo "Plugins:"
    grep -A 5 "PLUGINS:" "$TUTOR_ROOT/config.yml" | head -10 | sed 's/^/  /' || echo "  Not found"
    echo ""
    echo "Database Hosts (should be local Docker services):"
    grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" "$TUTOR_ROOT/config.yml" | sed 's/^/  /' || echo "  Not found"
    echo ""
    if grep -q "10\.97\.0\." "$TUTOR_ROOT/config.yml"; then
        echo -e "${RED}❌ Config contains cloud IPs (should use local Docker services)${NC}"
        echo "   Run: ./scripts/infra/tutor-config-save.sh --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb --set REDIS_HOST=redis --set RUN_MONGODB=true --set DOCKER_IMAGE_OPENEDX=openedx:nightly --set MFE_DOCKER_IMAGE=openedx-mfe:nightly"
    else
        echo -e "${GREEN}✅ Config uses local Docker services${NC}"
    fi
else
    echo -e "${RED}❌ Config file not found${NC}"
fi
echo ""

echo "=== Service Health ==="
SERVICES=("lms" "cms" "mfe" "mysql" "mongodb" "redis")
for service in "${SERVICES[@]}"; do
    if grep -qx "$service" <<<"$RUNNING_SERVICES"; then
        echo -e "${GREEN}✅ ${service}${NC}"
    else
        echo -e "${RED}❌ ${service}${NC}"
    fi
done
echo ""

echo "=== URL Accessibility ==="
URLS=("http://localhost" "http://studio.localhost" "http://apps.localhost/authn/login")
for url in "${URLS[@]}"; do
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302"; then
        echo -e "${GREEN}✅ ${url}${NC}"
    else
        echo -e "${RED}❌ ${url}${NC}"
    fi
done
echo ""

echo "=== MFE Config API ==="
if curl -s "http://localhost/api/mfe_config/v1?mfe=authn" | grep -q "BASE_URL"; then
    echo -e "${GREEN}✅ MFE Config API working${NC}"
else
    echo -e "${RED}❌ MFE Config API not working${NC}"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Parity Check Complete                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "For detailed parity strategy, see: docs/LOCAL_PRODUCTION_PARITY.md"
