#!/usr/bin/env bash
# Fix admin login issues (too many attempts, cache, sessions)
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Fixing Admin Login Issues                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

echo "1. Clearing Django cache..."
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.core.cache import cache; cache.clear(); print('✅ Cache cleared')" 2>&1 | grep -E "(Cache cleared|✅)"

echo "2. Clearing all sessions..."
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.sessions.models import Session; count = Session.objects.all().count(); Session.objects.all().delete(); print(f'✅ Cleared {count} sessions')" 2>&1 | grep -E "(Cleared|✅)"

echo "3. Resetting admin password and flags..."
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    u = User.objects.get(username='admin')
except User.DoesNotExist:
    u = User.objects.create_user('admin', 'admin@mereka.academy', 'admin123')
    print('✅ Created admin user')
u.set_password('admin123')
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
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Login URLs:"
echo "  LMS: http://localhost/login"
echo "  MFE: http://apps.localhost/authn/login"
echo "  Admin Panel: http://localhost/admin"

