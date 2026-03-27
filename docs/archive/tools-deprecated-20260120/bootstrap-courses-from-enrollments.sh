#!/usr/bin/env bash
# Create placeholder split courses based on existing enrollments to populate CourseOverview locally
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

LIMIT="10"
MODE="top"  # top | all

for arg in "$@"; do
  case "$arg" in
    --all)
      MODE="all"
      shift
      ;;
    --limit=*)
      LIMIT="${arg#*=}"
      shift
      ;;
  esac
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Bootstrap Courses from Enrollments                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Ensure MySQL and CMS are reachable
if ! docker ps --format '{{.Names}}' | grep -q 'tutor_local-mysql-1'; then
  echo -e "${RED}❌ MySQL container not running (tutor_local-mysql-1)${NC}"
  exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -q 'tutor_local-cms-1'; then
  echo -e "${RED}❌ CMS container not running (tutor_local-cms-1)${NC}"
  exit 1
fi

# Find admin user id (fallback to 1 if not found)
ADMIN_ID=$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu -N -e "SELECT id FROM openedx.auth_user WHERE username='admin' ORDER BY id DESC LIMIT 1;" 2>/dev/null | tr -d ' ' || true)
if [[ -z "${ADMIN_ID:-}" ]]; then
  echo -e "${YELLOW}⚠️  Admin user not found, using ID 1 as fallback${NC}"
  ADMIN_ID="1"
fi

echo -e "${GREEN}Using admin user id:${NC} ${ADMIN_ID}"

# Build query for course ids
COURSE_QUERY="SELECT course_id, COUNT(*) AS cnt FROM openedx.student_courseenrollment GROUP BY course_id ORDER BY cnt DESC"
if [[ "$MODE" == "top" ]]; then
  COURSE_QUERY+=" LIMIT ${LIMIT}"
fi

# Fetch course ids (portable, works with older bash)
COURSE_IDS=()
while IFS=$'\n' read -r line; do
  cid="$(echo "$line" | awk '{print $1}')"
  if [[ -n "$cid" ]]; then
    COURSE_IDS+=("$cid")
  fi
done < <(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu -N -e "$COURSE_QUERY" 2>/dev/null)

if [[ ${#COURSE_IDS[@]} -eq 0 ]]; then
  echo -e "${YELLOW}⚠️  No course_ids found in enrollments${NC}"
  exit 0
fi

echo "Will bootstrap ${#COURSE_IDS[@]} courses (${MODE}; limit=${LIMIT})"

CREATED=0
SKIPPED=0
FAILED=0

create_course() {
  local course_id="$1"
  if [[ "$course_id" =~ ^course-v1:([^+]+)\+([^+]+)\+([^[:space:]]+)$ ]]; then
    local ORG="${BASH_REMATCH[1]}"
    local NUMBER="${BASH_REMATCH[2]}"
    local RUN="${BASH_REMATCH[3]}"
    local NAME="Auto Imported: ${ORG} ${NUMBER} ${RUN}"

    # Check if overview already exists
    local EXISTS
    EXISTS=$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu -N -e "SELECT COUNT(*) FROM openedx.course_overviews_courseoverview WHERE id='${course_id}';" 2>/dev/null | tr -d ' ' || echo "0")
    if [[ "$EXISTS" == "1" ]]; then
      echo -e "${YELLOW}⏭  Exists:${NC} ${course_id}"
      ((SKIPPED++))
      return 0
    fi

    echo "→ Creating ${course_id}"
    if docker exec tutor_local-cms-1 python /openedx/edx-platform/manage.py cms create_course split "$ADMIN_ID" "$ORG" "$NUMBER" "$RUN" "$NAME" 2025-01-01 >/dev/null 2>&1; then
      ((CREATED++))
    else
      echo -e "${RED}❌ Failed to create:${NC} ${course_id}"
      ((FAILED++))
    fi
  else
    echo -e "${YELLOW}⚠️  Unsupported course_id format:${NC} ${course_id}"
    ((SKIPPED++))
  fi
}

for cid in "${COURSE_IDS[@]}"; do
  create_course "$cid"
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Bootstrap Summary                                     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  ✅ Created:  ${CREATED}"
echo "  ⏭  Skipped:  ${SKIPPED}"
echo "  ❌ Failed:   ${FAILED}"
echo "╚══════════════════════════════════════════════════════════════╝"

# Show resulting counts
./scripts/qa/analyze-local-data.sh | sed -n '1,80p'
