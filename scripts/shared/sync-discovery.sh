#!/usr/bin/env bash
# Sync course metadata to Discovery service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
DISCOVERY_LABEL="app.kubernetes.io/name=discovery"
LMS_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
STUDIO_DOMAIN="${STUDIO_DOMAIN:-studio.${LMS_DOMAIN}}"
DISCOVERY_DOMAIN="${DISCOVERY_DOMAIN:-discovery.${LMS_DOMAIN}}"
DISCOVERY_URL="https://${DISCOVERY_DOMAIN}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Get Discovery pod
get_discovery_pod() {
  kubectl get pods -n "$NAMESPACE" -l "$DISCOVERY_LABEL" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || {
    error "No Discovery pod found"
    exit 1
  }
}

# Check if Discovery is running
check_discovery_status() {
  info "Checking Discovery service status..."
  DISCOVERY_POD=$(get_discovery_pod)

  if [ -z "$DISCOVERY_POD" ]; then
    error "Discovery pod not found"
    exit 1
  fi

  POD_STATUS=$(kubectl get pod -n "$NAMESPACE" "$DISCOVERY_POD" -o jsonpath='{.status.phase}')

  if [ "$POD_STATUS" != "Running" ]; then
    error "Discovery pod is not running (status: $POD_STATUS)"
    exit 1
  fi

  info "Discovery pod: $DISCOVERY_POD (status: $POD_STATUS)"
}

# Check course count in LMS
check_lms_courses() {
  info "Checking courses in LMS..."
  LMS_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=lms" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

  if [ -z "$LMS_POD" ]; then
    warn "LMS pod not found, skipping course count check"
    return
  fi

  COURSE_COUNT=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c \
    "from openedx.core.djangoapps.content.course_overviews.models import CourseOverview; print(CourseOverview.objects.count())" \
    2>/dev/null | grep -E '^[0-9]+$' || echo "0")

  info "Total courses in LMS: $COURSE_COUNT"

  if [ "$COURSE_COUNT" -eq 0 ]; then
    warn "No courses found in LMS. Create courses via Studio first:"
    warn "  https://${STUDIO_DOMAIN}"
    return 1
  fi

  return 0
}

# Refresh course metadata in Discovery
refresh_metadata() {
  info "Refreshing course metadata in Discovery..."
  DISCOVERY_POD=$(get_discovery_pod)

  kubectl exec -n "$NAMESPACE" "$DISCOVERY_POD" -- \
    python manage.py refresh_course_metadata "$@" 2>&1 | \
    grep -v "UserWarning: The 'django-fsm'" || true

  if [ $? -eq 0 ]; then
    info "✓ Course metadata refreshed successfully"
  else
    error "✗ Failed to refresh course metadata"
    exit 1
  fi
}

# Update search index
update_index() {
  info "Updating Discovery search index..."
  DISCOVERY_POD=$(get_discovery_pod)

  kubectl exec -n "$NAMESPACE" "$DISCOVERY_POD" -- \
    python manage.py update_index --disable-change-limit 2>&1 | \
    grep -v "UserWarning: The 'django-fsm'" || true

  if [ $? -eq 0 ]; then
    info "✓ Search index updated successfully"
  else
    warn "Search index update failed (may not be configured)"
  fi
}

# Show Discovery course count
show_course_count() {
  info "Checking courses in Discovery..."
  DISCOVERY_POD=$(get_discovery_pod)

  COURSE_COUNT=$(kubectl exec -n "$NAMESPACE" "$DISCOVERY_POD" -- \
    python manage.py shell -c \
    "from course_discovery.apps.course_metadata.models import Course; print(Course.objects.count())" \
    2>/dev/null | grep -E '^[0-9]+$' || echo "0")

  info "Total courses in Discovery: $COURSE_COUNT"
}

# Clear Discovery cache
clear_cache() {
  info "Clearing Discovery cache..."
  DISCOVERY_POD=$(get_discovery_pod)

  kubectl exec -n "$NAMESPACE" "$DISCOVERY_POD" -- \
    python manage.py shell -c \
    "from django.core.cache import cache; cache.clear(); print('Cache cleared')" 2>&1 | \
    grep -v "UserWarning: The 'django-fsm'" || true

  info "✓ Cache cleared"
}

# Main sync operation
sync_courses() {
  info "=== Discovery Course Sync ==="
  echo

  check_discovery_status
  echo

  if ! check_lms_courses; then
    warn "Sync aborted: No courses to sync"
    exit 0
  fi
  echo

  refresh_metadata "$@"
  echo

  update_index
  echo

  show_course_count
  echo

  info "=== Sync Complete ==="
  info "View courses at: ${DISCOVERY_URL}/api/v1/courses/"
}

# Usage information
usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Sync course metadata to Discovery service

COMMANDS:
  sync              Full sync: refresh metadata + update index (default)
  refresh           Refresh course metadata only
  index             Update search index only
  status            Check Discovery service status
  count             Show course counts in LMS and Discovery
  clear-cache       Clear Discovery cache

OPTIONS:
  --all             Refresh all courses (default: only changed)
  -h, --help        Show this help message

EXAMPLES:
  # Full sync (default)
  $0
  $0 sync

  # Refresh all courses
  $0 sync --all

  # Only refresh metadata
  $0 refresh

  # Check status
  $0 status

  # Show course counts
  $0 count

SEE ALSO:
  docs/operations/DISCOVERY_DEMO_COURSE_SETUP.md

EOF
}

# Parse arguments
COMMAND="sync"
REFRESH_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    sync|refresh|index|status|count|clear-cache)
      COMMAND="$1"
      shift
      ;;
    --all)
      REFRESH_ARGS+=("--all")
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

# Execute command
case "$COMMAND" in
  sync)
    sync_courses "${REFRESH_ARGS[@]}"
    ;;
  refresh)
    check_discovery_status
    refresh_metadata "${REFRESH_ARGS[@]}"
    ;;
  index)
    check_discovery_status
    update_index
    ;;
  status)
    check_discovery_status
    check_lms_courses || true
    show_course_count
    ;;
  count)
    check_lms_courses || true
    show_course_count
    ;;
  clear-cache)
    check_discovery_status
    clear_cache
    ;;
  *)
    error "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
