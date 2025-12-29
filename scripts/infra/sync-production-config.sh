#!/usr/bin/env bash
# Sync Production Configuration to Local (Read-Only)
# This helps verify local matches production configuration
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Production Configuration Sync (Read-Only)             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Install kubectl to sync production config.${NC}"
    exit 1
fi

# Check if we can access cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot access Kubernetes cluster. Check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${BLUE}Fetching production configuration...${NC}"
echo ""

# Get Organizations
echo "=== Organizations ==="
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from organizations.models import Organization
for org in Organization.objects.all():
    print(f'{org.short_name}|{org.name}|{org.active}')
" 2>/dev/null | while IFS='|' read -r short_name name active; do
    echo "  $short_name: $name (active: $active)"
done || echo -e "${YELLOW}⚠️  Could not fetch organizations${NC}"
echo ""

# Get Sites
echo "=== Sites ==="
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
for site in Site.objects.all():
    print(f'{site.domain}|{site.name}')
" 2>/dev/null | while IFS='|' read -r domain name; do
    echo "  $domain: $name"
done || echo -e "${YELLOW}⚠️  Could not fetch sites${NC}"
echo ""

# Get User Counts
echo "=== User Statistics ==="
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
total = User.objects.count()
active = User.objects.filter(is_active=True).count()
print(f'total|{total}')
print(f'active|{active}')
" 2>/dev/null | while IFS='|' read -r type count; do
    echo "  $type: $count"
done || echo -e "${YELLOW}⚠️  Could not fetch user statistics${NC}"
echo ""

# Get Course Counts
echo "=== Course Statistics ==="
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from course_overviews.models import CourseOverview
from organizations.models import Organization
total = CourseOverview.objects.count()
print(f'total|{total}')
for org in Organization.objects.all():
    count = CourseOverview.objects.filter(org=org.short_name).count()
    print(f'{org.short_name}|{count}')
" 2>/dev/null | while IFS='|' read -r org count; do
    if [ "$org" = "total" ]; then
        echo "  Total courses: $count"
    else
        echo "  $org: $count courses"
    fi
done || echo -e "${YELLOW}⚠️  Could not fetch course statistics${NC}"
echo ""

# Check MFE
echo "=== MFE Status ==="
if curl -sI https://apps.staging.academy.mereka.io/authn/login 2>&1 | grep -q "200\|302"; then
    echo -e "${GREEN}  ✅ MFE authn URL accessible${NC}"
else
    echo -e "${YELLOW}  ⚠️  MFE authn URL not accessible${NC}"
fi

MFE_CONFIG=$(curl -s 'https://staging.academy.mereka.io/api/mfe_config/v1?mfe=authn' 2>&1)
if echo "$MFE_CONFIG" | grep -q "BASE_URL"; then
    echo -e "${GREEN}  ✅ MFE config API working${NC}"
else
    echo -e "${YELLOW}  ⚠️  MFE config API not working${NC}"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Sync Complete                                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Compare with local: ./tools/analyze-local-data.sh"

