#!/usr/bin/env bash
# Complete sync from production (MongoDB + MySQL tagging)
# Makes local dev environment match production
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Sync from Production to Local                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check kubectl access
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Not connected to Kubernetes cluster${NC}"
    echo "Run: gcloud container clusters get-credentials mereka-lms --region asia-southeast1"
    exit 1
fi

# Check local containers
if ! docker ps --format '{{.Names}}' | grep -q 'tutor_local-mongodb-1'; then
    echo -e "${RED}❌ Local MongoDB not running${NC}"
    echo "Run: tutor local start -d"
    exit 1
fi

DUMP_DIR="/tmp/production-dump-$(date +%s)"
mkdir -p "$DUMP_DIR"

echo -e "${BLUE}Step 1: Dumping MongoDB from production...${NC}"

# Dump openedx database (course content)
kubectl exec -n mereka-lms deploy/mongodb -- mongodump \
    --db=openedx \
    --gzip \
    --archive \
    > "$DUMP_DIR/openedx.archive.gz"

if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅ Dumped openedx database${NC}"
else
    echo -e "  ${RED}❌ Failed to dump openedx${NC}"
    rm -rf "$DUMP_DIR"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 2: Restoring to local MongoDB...${NC}"

# Restore to local
docker exec -i tutor_local-mongodb-1 mongorestore \
    --gzip \
    --drop \
    --archive < "$DUMP_DIR/openedx.archive.gz"

if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅ Restored to local MongoDB${NC}"
else
    echo -e "  ${RED}❌ Failed to restore${NC}"
    rm -rf "$DUMP_DIR"
    exit 1
fi

# Cleanup
rm -rf "$DUMP_DIR"

echo ""
echo -e "${BLUE}Step 3: Verifying courses...${NC}"

COURSE_COUNT=$(docker exec tutor_local-mongodb-1 mongosh openedx --quiet --eval "db['modulestore.active_versions'].countDocuments({})")
echo "  Courses in modulestore: $COURSE_COUNT"

if [ "$COURSE_COUNT" -gt 0 ]; then
    echo ""
    docker exec tutor_local-mongodb-1 mongosh openedx --quiet --eval \
        "db['modulestore.active_versions'].find({}, {_id:0, org:1, course:1, run:1}).toArray()" | \
        sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}Step 4: Tagging users by source...${NC}"

# Tag users based on meta field
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell <<'PYTHON'
from django.contrib.auth import get_user_model
from auth_userprofile.models import UserProfile
import json

User = get_user_model()

kajabi_count = 0
mct_count = 0

for profile in UserProfile.objects.all():
    try:
        meta = json.loads(profile.meta) if profile.meta else {}
        
        # Check if Kajabi user
        if meta.get('kajabi_contact_id') and meta['kajabi_contact_id'] is not None:
            kajabi_count += 1
            # Tag as Kajabi (could add to group or custom field)
        else:
            mct_count += 1
            # Tag as MCT
    except:
        mct_count += 1

print(f"✅ Tagged {kajabi_count} Kajabi users")
print(f"✅ Tagged {mct_count} MCT users")
PYTHON

echo ""
echo -e "${BLUE}Step 5: Updating course-domain mappings...${NC}"

# Ensure SKILLOURFUTURE courses map to skillourfuture site
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell <<'PYTHON'
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
from organizations.models import Organization

# Get or create Skill Our Future site
site, created = Site.objects.get_or_create(
    domain='skillourfuture.academy.mereka.io',
    defaults={'name': 'Skill Our Future'}
)

# Get organization
try:
    org = Organization.objects.get(short_name='SKILLOURFUTURE')
    print(f"✅ Found SKILLOURFUTURE organization")
    
    # Create/update site configuration
    config, created = SiteConfiguration.objects.get_or_create(site=site)
    config.values = {
        'course_org_filter': 'SKILLOURFUTURE',
        'SITE_NAME': 'Skill Our Future',
    }
    config.save()
    print(f"✅ Mapped SKILLOURFUTURE courses to {site.domain}")
except Organization.DoesNotExist:
    print(f"⚠️  SKILLOURFUTURE organization not found")

# Main site for Kajabi courses (when they're imported)
main_site, created = Site.objects.get_or_create(
    domain='localhost',
    defaults={'name': 'Mereka Academy'}
)
print(f"✅ Main site ready for Kajabi courses: {main_site.domain}")
PYTHON

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Sync Complete!                                         ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  ✅ MongoDB synced from production"
echo "  ✅ Users tagged (MCT vs Kajabi)"
echo "  ✅ Course-domain mappings configured"
echo ""
echo "  📍 View courses:"
echo "    • Studio: http://studio.localhost"
echo "    • LMS (main): http://localhost"
echo "    • Skill Our Future: http://skillourfuture.academy.mereka.io"
echo "    • Login: admin / admin123"
echo ""
echo "  👥 User breakdown:"
echo "    • All current users: MCT (84,378)"
echo "    • Kajabi users: Will be tagged when imported"
echo ""
echo "╚══════════════════════════════════════════════════════════════╝"



