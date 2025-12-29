#!/usr/bin/env bash
# Run MCT course validation
#
# This script validates all SKILLOURFUTURE courses to identify:
# - Courses with content but no enrollments (orphaned)
# - Courses with enrollments but no content (broken)
# - Courses that are safe to delete
#
# Usage:
#   ./scripts/migrations/mct/run_validation.sh

set -euo pipefail

# Configuration
NAMESPACE="mereka-lms"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_SCRIPT="$SCRIPT_DIR/validate_course_content.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MCT Course Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Get LMS pod
echo -e "${YELLOW}Finding LMS pod...${NC}"
LMS_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

if [ -z "$LMS_POD" ]; then
  echo -e "${RED}ERROR: No LMS pod found in namespace $NAMESPACE${NC}"
  exit 1
fi

echo -e "${GREEN}Found LMS pod: $LMS_POD${NC}"
echo

# Check if validation script exists
if [ ! -f "$VALIDATION_SCRIPT" ]; then
  echo -e "${RED}ERROR: Validation script not found: $VALIDATION_SCRIPT${NC}"
  exit 1
fi

# Copy script to pod
echo -e "${YELLOW}Copying validation script to pod...${NC}"
kubectl cp "$VALIDATION_SCRIPT" "$NAMESPACE/$LMS_POD:/tmp/validate_course_content.py"
echo -e "${GREEN}Script copied${NC}"
echo

# Run validation
echo -e "${YELLOW}Running validation...${NC}"
echo -e "${BLUE}========================================${NC}"
echo

kubectl exec -n "$NAMESPACE" "$LMS_POD" -- python manage.py lms shell < "$VALIDATION_SCRIPT"

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Validation complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review the report above"
echo -e "  2. If broken courses found, see: MCT_DUPLICATE_COURSES_ANALYSIS.md"
echo -e "  3. Run cleanup scripts if needed"
echo
