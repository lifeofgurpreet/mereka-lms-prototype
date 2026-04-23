#!/usr/bin/env bash
# Fix admin login issues (too many attempts, cache, sessions)
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Fixing Admin Login Issues                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
export TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
export TUTOR_PLUGINS_ROOT="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$TUTOR_ROOT/plugins}}"
export TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT"
if [[ -f .venv/bin/activate ]]; then
  # shellcheck source=/dev/null
  source .venv/bin/activate
fi

LOCAL_ADMIN_USERNAME="${LOCAL_ADMIN_USERNAME:-admin}"
LOCAL_ADMIN_EMAIL="${LOCAL_ADMIN_EMAIL:-admin@mereka.academy}"
LOCAL_ADMIN_CREDENTIALS_FILE="${LOCAL_ADMIN_CREDENTIALS_FILE:-$TUTOR_ROOT/local-admin-credentials.txt}"
if [[ -z "${LOCAL_ADMIN_PASSWORD:-}" ]]; then
  LOCAL_ADMIN_PASSWORD="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"
fi
mkdir -p "$(dirname "$LOCAL_ADMIN_CREDENTIALS_FILE")"
umask 077
{
  printf 'username=%s\n' "$LOCAL_ADMIN_USERNAME"
  printf 'email=%s\n' "$LOCAL_ADMIN_EMAIL"
  printf 'password=%s\n' "$LOCAL_ADMIN_PASSWORD"
} > "$LOCAL_ADMIN_CREDENTIALS_FILE"

echo "1. Clearing Django cache..."
tutor local exec lms python /openedx/edx-platform/manage.py lms shell -c "from django.core.cache import cache; cache.clear(); print('✅ Cache cleared')" 2>&1 | grep -E "(Cache cleared|✅)"

echo "2. Clearing all sessions..."
tutor local exec lms python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.sessions.models import Session; count = Session.objects.all().count(); Session.objects.all().delete(); print(f'✅ Cleared {count} sessions')" 2>&1 | grep -E "(Cleared|✅)"

echo "3. Resetting admin password and flags..."
tutor local exec lms env \
  LOCAL_ADMIN_USERNAME="$LOCAL_ADMIN_USERNAME" \
  LOCAL_ADMIN_EMAIL="$LOCAL_ADMIN_EMAIL" \
  LOCAL_ADMIN_PASSWORD="$LOCAL_ADMIN_PASSWORD" \
  python /openedx/edx-platform/manage.py lms shell -c "
import os
from django.contrib.auth import get_user_model
User = get_user_model()
username = os.environ['LOCAL_ADMIN_USERNAME']
email = os.environ['LOCAL_ADMIN_EMAIL']
password = os.environ['LOCAL_ADMIN_PASSWORD']
try:
    u = User.objects.get(username=username)
except User.DoesNotExist:
    u = User.objects.create_user(username, email, password)
    print('✅ Created admin user')
u.email = email
u.set_password(password)
u.is_active = True
u.is_staff = True
u.is_superuser = True
u.save()
print('✅ Admin password reset and flags set')
" 2>&1 | grep -E "(Created|reset|✅)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Admin Login Fix Complete                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "You can now login with:"
echo "  Username: $LOCAL_ADMIN_USERNAME"
echo "  Password file: $LOCAL_ADMIN_CREDENTIALS_FILE"
echo ""
echo "Login URLs:"
echo "  LMS: http://localhost/login"
echo "  MFE: http://apps.localhost/authn/login"
echo "  Admin Panel: http://localhost/admin"
