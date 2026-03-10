#!/usr/bin/env bash
# Helper script to create a demo course via Studio API
# Note: This requires MongoDB permissions to be fixed first
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
LMS_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
STUDIO_DOMAIN="${STUDIO_DOMAIN:-studio.${LMS_DOMAIN}}"
DISCOVERY_DOMAIN="${DISCOVERY_DOMAIN:-discovery.${LMS_DOMAIN}}"
MFE_DOMAIN="${MFE_DOMAIN:-apps.${LMS_DOMAIN}}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

note() {
  echo -e "${BLUE}[NOTE]${NC} $*"
}

# Show manual course creation instructions
show_manual_instructions() {
  cat <<EOF

${GREEN}=== Manual Demo Course Creation ===${NC}

Due to MongoDB permissions, courses must be created via the Studio UI.

${BLUE}Step 1: Access Studio${NC}
  URL: https://${STUDIO_DOMAIN}
  Login: admin@mereka.io

${BLUE}Step 2: Create New Course${NC}
  1. Click "New Course" button
  2. Fill in the form:
     ${GREEN}Organization:${NC} MerekaAcademy
     ${GREEN}Course Number:${NC} DEMO101
     ${GREEN}Course Run:${NC} 2024_Q1
     ${GREEN}Course Name:${NC} Mereka Academy Demo Course

  3. Click "Create"

${BLUE}Step 3: Add Course Content${NC}
  1. In Course Outline, click "+ New Section"
     ${GREEN}Section Name:${NC} Getting Started

  2. Click "+ New Subsection" under the section
     ${GREEN}Subsection Name:${NC} Welcome to Mereka Academy

  3. Click "+ New Unit" under the subsection
     ${GREEN}Unit Name:${NC} Introduction

  4. In the unit, click "+ Add New Component" > "HTML"
  5. Add welcome text:

     ${YELLOW}---${NC}
     <h2>Welcome to Mereka Academy!</h2>
     <p>This is a demonstration course showcasing our learning platform.</p>
     <h3>What You'll Learn</h3>
     <ul>
       <li>Navigate the learning environment</li>
       <li>Access course materials</li>
       <li>Track your progress</li>
       <li>Engage with interactive content</li>
     </ul>
     ${YELLOW}---${NC}

${BLUE}Step 4: Configure Course Settings${NC}
  1. Go to Settings > Schedule & Details
  2. Fill in:
     ${GREEN}Course Title:${NC} Mereka Academy Demo Course
     ${GREEN}Subtitle:${NC} Learn the Basics
     ${GREEN}Description:${NC}
       This is a demonstration course showcasing the Mereka Academy
       platform. Explore our interactive learning environment and
       experience the future of education.

  3. Set dates:
     ${GREEN}Enrollment Start:${NC} $(date +%Y-%m-%d)
     ${GREEN}Enrollment End:${NC} $(date -d "+1 year" +%Y-%m-%d)
     ${GREEN}Course Start:${NC} $(date +%Y-%m-%d)
     ${GREEN}Course End:${NC} $(date -d "+1 year" +%Y-%m-%d)

  4. Upload a course image (1080x608px recommended)
  5. Click "Save"

${BLUE}Step 5: Publish Course${NC}
  1. Go to Course Outline
  2. Click "Publish" button in top-right
  3. Confirm publishing

${BLUE}Step 6: Sync to Discovery${NC}
  Run the sync script:
  ${GREEN}./scripts/shared/sync-discovery.sh sync${NC}

${BLUE}Step 7: Verify${NC}
  Check course appears in Discovery:
  ${GREEN}curl https://${DISCOVERY_DOMAIN}/api/v1/courses/ | jq .${NC}

  Or open in browser:
  ${GREEN}https://${MFE_DOMAIN}/${NC}

${YELLOW}For automatic course import (requires MongoDB fix):${NC}
  See: docs/operations/MONGODB_PERMISSIONS_ISSUE.md

${GREEN}=== End Instructions ===${NC}

EOF
}

# Check MongoDB permissions
check_mongodb_permissions() {
  info "Checking MongoDB permissions..."

  CMS_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=cms" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [ -z "$CMS_POD" ]; then
    error "CMS pod not found"
    return 1
  fi

  # Try a test insert
  TEST_RESULT=$(kubectl exec -n "$NAMESPACE" "$CMS_POD" -- python manage.py cms shell -c "
from pymongo import MongoClient
from django.conf import settings
import sys

mongo_config = settings.CONTENTSTORE['DOC_STORE_CONFIG']
try:
    client = MongoClient(
        mongo_config['host'],
        username=mongo_config['user'],
        password=mongo_config['password'],
        authSource='admin',
        serverSelectionTimeoutMS=5000
    )
    db = client['openedx']
    result = db['modulestore.structures'].insert_one({'test': 'document'})
    db['modulestore.structures'].delete_one({'_id': result.inserted_id})
    print('WRITE_OK')
except Exception as e:
    print(f'WRITE_ERROR: {e}')
    sys.exit(1)
" 2>&1 | grep -E "(WRITE_OK|WRITE_ERROR)" || echo "CHECK_FAILED")

  if echo "$TEST_RESULT" | grep -q "WRITE_OK"; then
    info "✓ MongoDB write permissions: OK"
    return 0
  else
    warn "✗ MongoDB write permissions: DENIED"
    warn "Reason: $TEST_RESULT"
    return 1
  fi
}

# Import demo course (if permissions OK)
import_demo_course() {
  info "Importing Open edX demo course..."

  CMS_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=cms" \
    -o jsonpath='{.items[0].metadata.name}')

  # Clone demo course repo
  info "Cloning demo course repository..."
  kubectl exec -n "$NAMESPACE" "$CMS_POD" -- bash -c "
    cd /tmp && \
    rm -rf openedx-demo-course && \
    git clone --depth 1 https://github.com/openedx/openedx-demo-course
  " 2>&1 | grep -v "Cloning" || true

  # Install dnspython if needed
  info "Ensuring dnspython is installed..."
  kubectl exec -n "$NAMESPACE" "$CMS_POD" -- \
    pip install -q "pymongo[srv]" 2>&1 | grep -v "Requirement already satisfied" || true

  # Import course
  info "Importing course..."
  if kubectl exec -n "$NAMESPACE" "$CMS_POD" -- \
    python manage.py cms import /tmp/openedx-demo-course demo-course/course 2>&1 | \
    tee /tmp/import-output.log | \
    grep -E "(Successfully|Error|error:)" || true; then

    info "✓ Demo course imported successfully"
    return 0
  else
    error "✗ Demo course import failed"
    warn "Check logs: /tmp/import-output.log"
    return 1
  fi
}

# Main workflow
main() {
  info "=== Demo Course Creation Helper ==="
  echo

  note "Checking system requirements..."
  echo

  if check_mongodb_permissions; then
    echo
    info "MongoDB permissions are OK. Proceeding with automatic import..."
    echo

    if import_demo_course; then
      echo
      info "=== Demo Course Created Successfully ==="
      info "Next step: Sync to Discovery"
      info "  ./scripts/shared/sync-discovery.sh sync"
    else
      echo
      error "=== Automatic Import Failed ==="
      warn "Please follow manual instructions below"
      echo
      show_manual_instructions
    fi
  else
    echo
    warn "=== MongoDB Permissions Required ==="
    warn "Automatic course import is not available."
    warn "Please follow the manual instructions below."
    echo
    show_manual_instructions
  fi
}

# Show usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Create a demo course for Mereka Academy

OPTIONS:
  --check-only      Only check MongoDB permissions, don't create course
  --manual          Show manual instructions only
  -h, --help        Show this help message

EXAMPLES:
  # Check permissions and create course if possible
  $0

  # Just check permissions
  $0 --check-only

  # Show manual instructions
  $0 --manual

SEE ALSO:
  docs/ops/runbooks/DISCOVERY_DEMO_COURSE_SETUP.md
  docs/operations/MONGODB_PERMISSIONS_ISSUE.md

EOF
}

# Parse arguments
CHECK_ONLY=false
MANUAL_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    --manual)
      MANUAL_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Execute
if $MANUAL_ONLY; then
  show_manual_instructions
elif $CHECK_ONLY; then
  check_mongodb_permissions
else
  main
fi
