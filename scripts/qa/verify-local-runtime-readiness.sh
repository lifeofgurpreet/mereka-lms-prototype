#!/usr/bin/env bash
# Read-only local runtime readiness verifier.
# Checks that Tutor local state is initialized enough for authenticated proof:
# - LMS Django shell is reachable
# - proof identity exists and is active
# - Registration exists
# - UserProfile exists
# - Discovery root responds on the documented local readiness surface
# - optional: LMS/Discovery have at least one course record
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
TUTOR_PLUGINS_ROOT="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$TUTOR_ROOT/plugins}}"
TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT"
export TUTOR_ROOT TUTOR_PLUGINS_ROOT TUTOR_PLUGINS_DIR
TUTOR_BIN="${TUTOR_BIN:-$REPO_ROOT/.venv/bin/tutor}"
PROOF_USERNAME="${PROOF_USERNAME:-smoke-test}"
CHECK_CATALOG_DATA=0
READINESS_TIMEOUT="${READINESS_TIMEOUT:-45}"
STATUS_FILE="/tmp/mereka-local-readiness-status.txt"
MYSQL_DATA_DIR="$TUTOR_ROOT/data/mysql"

PASS=0
FAIL=0
WARN=0
CORE_RUNTIME_HEALTHY=1

usage() {
  cat <<'EOF'
Usage:
  verify-local-runtime-readiness.sh [--username USERNAME] [--check-catalog-data]

Options:
  --username USERNAME      Local proof username to validate (default: smoke-test)
  --check-catalog-data     Also require LMS + Discovery to have at least one course
EOF
}

pass() {
  echo "  [PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  [FAIL] $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo "  [WARN] $1"
  WARN=$((WARN + 1))
}

show_tail() {
  local file="$1"
  local lines="${2:-40}"
  [[ -f "$file" ]] || return 0
  echo "  --- tail: $file ---" >&2
  tail -n "$lines" "$file" >&2 || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      PROOF_USERNAME="$2"
      shift 2
      ;;
    --check-catalog-data)
      CHECK_CATALOG_DATA=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -x "$TUTOR_BIN" ]]; then
  echo "Tutor binary not found: $TUTOR_BIN" >&2
  exit 1
fi

tutor_cmd() {
  env \
    TUTOR_ROOT="$TUTOR_ROOT" \
    TUTOR_PLUGINS_ROOT="$TUTOR_PLUGINS_ROOT" \
    TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT" \
    "$TUTOR_BIN" "$@"
}

run_lms_shell() {
  local code="$1"
  timeout "$READINESS_TIMEOUT" \
    env \
      TUTOR_ROOT="$TUTOR_ROOT" \
      TUTOR_PLUGINS_ROOT="$TUTOR_PLUGINS_ROOT" \
      TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT" \
      "$TUTOR_BIN" local exec lms \
    ./manage.py lms shell -c "$code"
}

run_discovery_shell() {
  local code="$1"
  timeout "$READINESS_TIMEOUT" \
    env \
      TUTOR_ROOT="$TUTOR_ROOT" \
      TUTOR_PLUGINS_ROOT="$TUTOR_PLUGINS_ROOT" \
      TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT" \
      "$TUTOR_BIN" local exec discovery \
    ./manage.py shell -c "$code"
}

refresh_local_status() {
  tutor_cmd local dc ps --services --filter status=running >"$STATUS_FILE" 2>&1
}

service_status_is_healthy() {
  local service="$1"
  grep -qx -- "$service" "$STATUS_FILE"
}

diagnose_mysql_datadir() {
  [[ -d "$MYSQL_DATA_DIR" ]] || return 0
  if [[ -d "$MYSQL_DATA_DIR/mysql" ]] && [[ -z "$(find "$MYSQL_DATA_DIR/mysql" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    warn "MySQL datadir looks half-initialized: $MYSQL_DATA_DIR/mysql is empty"
  fi
  if [[ ! -f "$MYSQL_DATA_DIR/ibdata1" ]]; then
    warn "MySQL datadir is missing ibdata1: $MYSQL_DATA_DIR/ibdata1"
  fi
}

echo ""
echo "========================================================================"
echo "Local Runtime Readiness"
echo "Repo root: $REPO_ROOT"
echo "Tutor root: $TUTOR_ROOT"
echo "Tutor plugins root: $TUTOR_PLUGINS_ROOT"
echo "Proof username: $PROOF_USERNAME"
echo "========================================================================"
echo ""

echo "--- Section 0: Core local service health ---"
if refresh_local_status; then
  pass "Tutor Compose running service list is readable"
else
  fail "Could not read Tutor Compose running service list"
  show_tail "$STATUS_FILE" 80
fi

for service in lms discovery mysql; do
  if service_status_is_healthy "$service"; then
    pass "Service is running: $service"
  else
    fail "Service is not running: $service"
    CORE_RUNTIME_HEALTHY=0
    if [[ "$service" == "mysql" ]]; then
      diagnose_mysql_datadir
    fi
  fi
done
echo ""

if [[ "$CORE_RUNTIME_HEALTHY" -ne 1 ]]; then
  warn "Skipping shell and identity checks until core Tutor local services are healthy"
  echo "========================================================================"
  echo "Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN"
  echo "========================================================================"
  exit 1
fi

echo "--- Section 1: LMS shell reachability ---"
if run_lms_shell "from django.contrib.auth import get_user_model; print(get_user_model().objects.exists())" >/tmp/mereka-local-readiness-lms.txt 2>/tmp/mereka-local-readiness-lms.err; then
  pass "LMS Django shell is reachable"
else
  fail "LMS Django shell is not reachable"
  show_tail /tmp/mereka-local-readiness-lms.err 50
fi
echo ""

echo "--- Section 2: Proof identity completeness ---"
if run_lms_shell "from django.contrib.auth import get_user_model; U=get_user_model(); u=U.objects.filter(username='$PROOF_USERNAME').first(); print('exists=' + str(bool(u))); print('active=' + str(bool(u and u.is_active)))" >/tmp/mereka-proof-user.txt 2>/tmp/mereka-proof-user.err; then
  if grep -q '^exists=True$' /tmp/mereka-proof-user.txt; then
    pass "Proof user exists"
  else
    fail "Proof user missing: $PROOF_USERNAME"
  fi
  if grep -q '^active=True$' /tmp/mereka-proof-user.txt; then
    pass "Proof user is active"
  else
    fail "Proof user is not active: $PROOF_USERNAME"
  fi
else
  fail "Could not query proof user: $PROOF_USERNAME"
  show_tail /tmp/mereka-proof-user.err 50
fi

if run_lms_shell "from django.contrib.auth import get_user_model; from common.djangoapps.student.models import Registration; U=get_user_model(); u=U.objects.filter(username='$PROOF_USERNAME').first(); print(bool(u and Registration.objects.filter(user=u).exists()))" >/tmp/mereka-proof-reg.txt 2>/tmp/mereka-proof-reg.err; then
  if grep -qx 'True' /tmp/mereka-proof-reg.txt; then
    pass "Proof user has Registration"
  else
    fail "Proof user missing Registration"
  fi
else
  fail "Could not query Registration for proof user"
  show_tail /tmp/mereka-proof-reg.err 50
fi

if run_lms_shell "from django.contrib.auth import get_user_model; from common.djangoapps.student.models import UserProfile; U=get_user_model(); u=U.objects.filter(username='$PROOF_USERNAME').first(); print(bool(u and UserProfile.objects.filter(user=u).exists()))" >/tmp/mereka-proof-profile.txt 2>/tmp/mereka-proof-profile.err; then
  if grep -qx 'True' /tmp/mereka-proof-profile.txt; then
    pass "Proof user has UserProfile"
  else
    fail "Proof user missing UserProfile"
  fi
else
  fail "Could not query UserProfile for proof user"
  show_tail /tmp/mereka-proof-profile.err 50
fi
echo ""

echo "--- Section 3: Discovery readiness surface ---"
if curl -fsSI http://discovery.localhost >/tmp/mereka-discovery-head.txt 2>/tmp/mereka-discovery-head.err; then
  pass "Discovery root responds on documented local surface"
else
  fail "Discovery root is not responding on http://discovery.localhost"
  show_tail /tmp/mereka-discovery-head.err 20
fi

if curl -fsS http://discovery.localhost/health/ >/tmp/mereka-discovery-health.txt 2>/tmp/mereka-discovery-health.err; then
  pass "Discovery /health/ responds"
else
  warn "Discovery /health/ is not available locally"
fi
echo ""

if [[ "$CHECK_CATALOG_DATA" -eq 1 ]]; then
  echo "--- Section 4: Catalog data presence ---"
  if run_lms_shell "from openedx.core.djangoapps.content.course_overviews.models import CourseOverview; print(CourseOverview.objects.count())" >/tmp/mereka-lms-course-count.txt 2>/tmp/mereka-lms-course-count.err; then
    LMS_COUNT="$(tr -d '[:space:]' </tmp/mereka-lms-course-count.txt)"
    if [[ "$LMS_COUNT" =~ ^[0-9]+$ && "$LMS_COUNT" -gt 0 ]]; then
      pass "LMS has course records ($LMS_COUNT)"
    else
      fail "LMS has no course records"
    fi
  else
    fail "Could not query LMS course records"
    show_tail /tmp/mereka-lms-course-count.err 50
  fi

  if run_discovery_shell "from course_discovery.apps.course_metadata.models import Course; print(Course.objects.count())" >/tmp/mereka-discovery-course-count.txt 2>/tmp/mereka-discovery-course-count.err; then
    DISCOVERY_COUNT="$(tr -d '[:space:]' </tmp/mereka-discovery-course-count.txt)"
    if [[ "$DISCOVERY_COUNT" =~ ^[0-9]+$ && "$DISCOVERY_COUNT" -gt 0 ]]; then
      pass "Discovery has synced course records ($DISCOVERY_COUNT)"
    else
      fail "Discovery has no synced course records"
    fi
  else
    fail "Could not query Discovery course records"
    show_tail /tmp/mereka-discovery-course-count.err 50
  fi
  echo ""
fi

echo "========================================================================"
echo "Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN"
echo "========================================================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
