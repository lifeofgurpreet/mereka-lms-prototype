#!/usr/bin/env bash
# Import course tarballs from production to populate local content
set -euo pipefail

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
if [[ -f .venv/bin/activate ]]; then
    # shellcheck source=/dev/null
    source .venv/bin/activate
fi

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
mapfile -t TARBALLS < <(find "$TARBALL_DIR" \( -name "*.tar.gz" -o -name "*.tar" \) -print)
if [ ${#TARBALLS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No course tarballs found in ${TARBALL_DIR}${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#TARBALLS[@]} course tarball(s)${NC}"
echo ""

# Ensure CMS service is running
if ! tutor local dc ps --services --filter status=running 2>/dev/null | grep -qx 'cms'; then
    echo -e "${RED}❌ CMS service not running${NC}"
    echo "Run: make tutor-start"
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
    if tutor local dc cp "$tarball" "cms:${TEMP_PATH}"; then
        echo "  ✅ Copied to CMS service"
    else
        echo -e "  ${RED}❌ Failed to copy${NC}"
        ((FAILED++))
        continue
    fi
    
    # Extract tarball
    EXTRACT_DIR="/tmp/$(basename "$BASENAME" .tar.gz)"
    if tutor local dc exec -T cms bash -c "mkdir -p ${EXTRACT_DIR} && tar -xzf ${TEMP_PATH} -C ${EXTRACT_DIR}"; then
        echo "  ✅ Extracted"
    else
        echo -e "  ${RED}❌ Failed to extract${NC}"
        ((FAILED++))
        continue
    fi
    
    # Import course
    # The extracted directory should contain the course data
    if tutor local dc exec -T cms python /openedx/edx-platform/manage.py cms import /tmp "${EXTRACT_DIR}"; then
        echo -e "  ${GREEN}✅ Imported successfully${NC}"
        ((IMPORTED++))
    else
        echo -e "  ${RED}❌ Import failed${NC}"
        ((FAILED++))
    fi
    
    # Cleanup
    tutor local dc exec -T cms rm -rf "${TEMP_PATH}" "${EXTRACT_DIR}" || true
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
