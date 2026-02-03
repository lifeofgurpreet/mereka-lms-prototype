#!/usr/bin/env bash
# Import course tarballs from production to populate local content
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Import Production Courses                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

TARBALL_DIR="${1:-.}/course_tarballs"
DRY_RUN="${2:-false}"

if [ ! -d "$TARBALL_DIR" ]; then
    echo -e "${YELLOW}⚠️  Tarball directory not found: ${TARBALL_DIR}${NC}"
    echo ""
    echo "Usage: $0 [tarball_dir] [dry_run]"
    echo ""
    echo "First, export courses from production:"
    echo ""
    echo "  # Export top 5 MCT courses"
    echo "  kubectl exec -n mereka-lms deploy/cms -- bash -c '"
    echo "    for course_id in \\"
    echo "      'course-v1:MEREKA+MEKA-2148875088+RUN-2148875088' \\"
    echo "      'course-v1:MEREKA+MEKA-2148861785+RUN-2148861785' \\"
    echo "      'course-v1:MEREKA+MEKA-2148864393+RUN-2148864393' \\"
    echo "      'course-v1:MEREKA+MEKA-2148864407+RUN-2148864407' \\"
    echo "      'course-v1:MEREKA+MEKA-2148864416+RUN-2148864416'; do"
    echo "      echo \"Exporting \$course_id...\""
    echo "      python manage.py cms export /tmp \"\$course_id\""
    echo "      tar -czf /tmp/\${course_id//[:\\/+]/_}.tar.gz -C /tmp \$(basename \$course_id)"
    echo "    done"
    echo "  '"
    echo ""
    echo "  # Download tarballs"
    echo "  mkdir -p $TARBALL_DIR"
    echo "  kubectl cp mereka-lms/\$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}'):/tmp/course-v1_MEREKA_MEKA-2148875088_RUN-2148875088.tar.gz $TARBALL_DIR/"
    echo ""
    exit 1
fi

# Find all tarballs
TARBALLS=($(find "$TARBALL_DIR" -name "*.tar.gz" -o -name "*.tar"))
if [ ${#TARBALLS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No course tarballs found in ${TARBALL_DIR}${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#TARBALLS[@]} course tarball(s)${NC}"
echo ""

# Ensure CMS container is running
if ! docker ps --format '{{.Names}}' | grep -q 'tutor_local-cms-1'; then
    echo -e "${RED}❌ CMS container not running${NC}"
    echo "Run: tutor local start -d"
    exit 1
fi

IMPORTED=0
FAILED=0

for tarball in "${TARBALLS[@]}"; do
    BASENAME=$(basename "$tarball")
    echo -e "${BLUE}→ Processing:${NC} $BASENAME"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "  [DRY RUN] Would copy and import"
        ((IMPORTED++))
        continue
    fi
    
    # Copy tarball into CMS container
    TEMP_PATH="/tmp/${BASENAME}"
    if docker cp "$tarball" "tutor_local-cms-1:${TEMP_PATH}"; then
        echo "  ✅ Copied to container"
    else
        echo -e "  ${RED}❌ Failed to copy${NC}"
        ((FAILED++))
        continue
    fi
    
    # Extract tarball
    EXTRACT_DIR="/tmp/$(basename "$BASENAME" .tar.gz)"
    if docker exec tutor_local-cms-1 bash -c "mkdir -p ${EXTRACT_DIR} && tar -xzf ${TEMP_PATH} -C ${EXTRACT_DIR}"; then
        echo "  ✅ Extracted"
    else
        echo -e "  ${RED}❌ Failed to extract${NC}"
        ((FAILED++))
        continue
    fi
    
    # Import course
    # The extracted directory should contain the course data
    if docker exec tutor_local-cms-1 python /openedx/edx-platform/manage.py cms import /tmp ${EXTRACT_DIR}; then
        echo -e "  ${GREEN}✅ Imported successfully${NC}"
        ((IMPORTED++))
    else
        echo -e "  ${RED}❌ Import failed${NC}"
        ((FAILED++))
    fi
    
    # Cleanup
    docker exec tutor_local-cms-1 rm -rf "${TEMP_PATH}" "${EXTRACT_DIR}" || true
    echo ""
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Import Summary                                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  ✅ Imported: ${IMPORTED}"
echo "  ❌ Failed:   ${FAILED}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ $IMPORTED -gt 0 ]; then
    echo "Courses imported! View them at:"
    echo "  Studio: http://studio.localhost"
    echo "  LMS: http://localhost"
fi



