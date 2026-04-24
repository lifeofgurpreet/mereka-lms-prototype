#!/usr/bin/env bash
# Sync MongoDB content from production Atlas to local development
set -euo pipefail

# Safety guard: require explicit confirmation for production-mutating operations
if [[ "${CONFIRM:-}" != "yes-i-am-sure" ]]; then
  echo "ERROR: This script mutates production. To proceed, run:"
  echo "  CONFIRM=yes-i-am-sure $0 $*"
  exit 1
fi

DRY_RUN="${DRY_RUN:-true}"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY RUN mode (default). Set DRY_RUN=false to execute the production sync."
  echo "This script drops and replaces local MongoDB databases with production data."
  exit 0
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
export TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
export TUTOR_PLUGINS_ROOT="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$TUTOR_ROOT/plugins}}"
export TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT"
MONGO_TOOLS_IMAGE="${MONGO_TOOLS_IMAGE:-mirror.gcr.io/library/mongo:7.0.28}"
if [[ -f .venv/bin/activate ]]; then
    # shellcheck source=/dev/null
    source .venv/bin/activate
fi

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
    echo "  ATLAS_URI=\$ATLAS_URI ./scripts/infra/sync-mongodb-from-production.sh"
    exit 1
fi

# Check local MongoDB is running
if ! tutor local dc ps --services --filter status=running 2>/dev/null | grep -qx 'mongodb'; then
    echo -e "${RED}❌ Local MongoDB service not running${NC}"
    echo "Run: make tutor-start"
    exit 1
fi

DUMP_DIR="/tmp/mongodb-production-dump-$(date +%s)"
mkdir -p "$DUMP_DIR"

cleanup_sync() {
    rm -rf "$DUMP_DIR"
    tutor local dc exec -T mongodb rm -rf /tmp/mongodb-restore >/dev/null 2>&1 || true
}
trap cleanup_sync EXIT

echo -e "${BLUE}Step 1: Dumping from production Atlas...${NC}"
if ! docker run --rm \
    -v "$DUMP_DIR:/dump" \
    "$MONGO_TOOLS_IMAGE" \
    mongodump \
    --uri="$ATLAS_URI" \
    --out=/dump \
    --gzip; then
    echo -e "${RED}❌ Failed to dump from Atlas${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Dumped from Atlas${NC}"
echo ""

# Check what we got
echo -e "${BLUE}Databases dumped:${NC}"
ls -lh "$DUMP_DIR"
echo ""

echo -e "${BLUE}Step 2: Restoring to local MongoDB...${NC}"

restore_database_dump() {
    local database_name="$1"
    local description="$2"
    local ns_include="${3:-}"
    local source_dir="$DUMP_DIR/$database_name"
    local restore_args=(--gzip --drop)

    if [ ! -d "$source_dir" ]; then
        echo -e "  ${YELLOW}⚠️  No ${database_name} database in dump${NC}"
        return 0
    fi

    echo "  → Restoring ${database_name} database (${description})..."
    tutor local dc exec -T mongodb sh -lc "rm -rf /tmp/mongodb-restore && mkdir -p /tmp/mongodb-restore"
    tutor local dc cp "$source_dir" "mongodb:/tmp/mongodb-restore/$database_name"

    if [ -n "$ns_include" ]; then
        restore_args+=(--nsInclude="$ns_include")
    fi
    restore_args+=(/tmp/mongodb-restore)

    tutor local dc exec -T mongodb mongorestore "${restore_args[@]}"
    tutor local dc exec -T mongodb rm -rf /tmp/mongodb-restore
    echo -e "  ${GREEN}✅ ${database_name} database restored${NC}"
}

# Restore openedx database (course content)
restore_database_dump openedx "course content" "openedx.modulestore.*"

# Restore cs_comments_service (forums) - optional
restore_database_dump cs_comments_service "forums"

echo ""
echo -e "${GREEN}✅ Restore complete!${NC}"
echo ""

# Verify
echo -e "${BLUE}Step 3: Verifying...${NC}"
COURSE_COUNT=$(tutor local dc exec -T mongodb mongosh openedx --quiet --eval "db['modulestore.active_versions'].countDocuments({})")
echo "  Courses in modulestore: $COURSE_COUNT"

if [ "$COURSE_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Success! View courses at:${NC}"
    echo "  Studio: http://studio.localhost"
    echo "  LMS: http://localhost"
    echo "  Login: admin / <your local-only password>"
else
    echo -e "${YELLOW}⚠️  No courses found after restore${NC}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Sync Complete                                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
