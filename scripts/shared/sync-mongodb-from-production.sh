#!/usr/bin/env bash
# Sync MongoDB content from production Atlas to local development
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Sync MongoDB from Production Atlas                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check for Atlas URI
if [ -z "${ATLAS_URI:-}" ]; then
    echo -e "${YELLOW}⚠️  ATLAS_URI not set${NC}"
    echo ""
    echo "Get the production Atlas URI and set it:"
    echo ""
    echo "  # From Google Secret Manager"
    echo "  ATLAS_URI=\$(gcloud secrets versions access latest --secret=mongodb-atlas-uri)"
    echo ""
    echo "  # Or from production config"
    echo "  ATLAS_URI=\"mongodb+srv://user:pass@cluster.mongodb.net/openedx?retryWrites=true&w=majority\""
    echo ""
    echo "Then run:"
    echo "  ATLAS_URI=\$ATLAS_URI ./scripts/shared/sync-mongodb-from-production.sh"
    exit 1
fi

# Check local MongoDB is running
if ! docker ps --format '{{.Names}}' | grep -q 'tutor_local-mongodb-1'; then
    echo -e "${RED}❌ Local MongoDB container not running${NC}"
    echo "Run: tutor local start -d"
    exit 1
fi

DUMP_DIR="/tmp/mongodb-production-dump-$(date +%s)"
mkdir -p "$DUMP_DIR"

echo -e "${BLUE}Step 1: Dumping from production Atlas...${NC}"
docker run --rm \
    -v "$DUMP_DIR:/dump" \
    mongo:5.0 \
    mongodump \
    --uri="$ATLAS_URI" \
    --out=/dump \
    --gzip

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to dump from Atlas${NC}"
    rm -rf "$DUMP_DIR"
    exit 1
fi

echo -e "${GREEN}✅ Dumped from Atlas${NC}"
echo ""

# Check what we got
echo -e "${BLUE}Databases dumped:${NC}"
ls -lh "$DUMP_DIR"
echo ""

echo -e "${BLUE}Step 2: Restoring to local MongoDB...${NC}"

# Restore openedx database (course content)
if [ -d "$DUMP_DIR/openedx" ]; then
    echo "  → Restoring openedx database (course content)..."
    docker exec -i tutor_local-mongodb-1 mongorestore \
        --gzip \
        --drop \
        --nsInclude="openedx.modulestore.*" \
        --archive < <(cd "$DUMP_DIR" && tar czf - openedx/modulestore.*)
    echo -e "  ${GREEN}✅ openedx database restored${NC}"
else
    echo -e "  ${YELLOW}⚠️  No openedx database in dump${NC}"
fi

# Restore cs_comments_service (forums) - optional
if [ -d "$DUMP_DIR/cs_comments_service" ]; then
    echo "  → Restoring cs_comments_service (forums)..."
    docker exec -i tutor_local-mongodb-1 mongorestore \
        --gzip \
        --drop \
        --archive < <(cd "$DUMP_DIR" && tar czf - cs_comments_service/)
    echo -e "  ${GREEN}✅ cs_comments_service restored${NC}"
else
    echo -e "  ${YELLOW}⚠️  No cs_comments_service in dump${NC}"
fi

echo ""
echo -e "${GREEN}✅ Restore complete!${NC}"
echo ""

# Cleanup
rm -rf "$DUMP_DIR"

# Verify
echo -e "${BLUE}Step 3: Verifying...${NC}"
COURSE_COUNT=$(docker exec tutor_local-mongodb-1 mongosh openedx --quiet --eval "db['modulestore.active_versions'].countDocuments({})")
echo "  Courses in modulestore: $COURSE_COUNT"

if [ "$COURSE_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Success! View courses at:${NC}"
    echo "  Studio: http://studio.localhost"
    echo "  LMS: http://localhost"
    echo "  Login: admin / admin123"
else
    echo -e "${YELLOW}⚠️  No courses found after restore${NC}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Sync Complete                                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"

