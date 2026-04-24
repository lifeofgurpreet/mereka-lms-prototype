#!/usr/bin/env bash
# bootstrap-enterprise-service-deps.sh — Idempotent bootstrap for enterprise
# service dependencies that live in the LMS and Discovery databases.
#
# Creates or updates:
#   1. LMS OAuth apps for enterprise backend services
#   2. Discovery Partner record for course metadata sync
#   3. Discovery ProgramType records for program metadata
#   4. LMS audit enrollment modes for all courses without one
#   5. Cleanup: disable stale prod-domain SiteConfigurations in dev
#
# Idempotent: safe to re-run. Uses update_or_create / get_or_create throughout.
#
# Usage:
#   scripts/tenants/bootstrap-enterprise-service-deps.sh [--namespace NS] [--dry-run]
#
# Requires: kubectl with access to the target namespace
set -euo pipefail

DRY_RUN=false
NAMESPACE="${NAMESPACE:-mereka-lms-dev}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="${2:?--namespace requires a value}"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--namespace NS] [--dry-run]"
      echo "Bootstrap enterprise service OAuth apps in LMS and Discovery Partner."
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

echo "=== Enterprise Service Dependencies Bootstrap ==="
echo "Namespace: $NAMESPACE"
echo "Dry run:   $DRY_RUN"
echo ""

# ── Discover pods ─────────────────────────────────────────────────────────────
LMS_POD=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || true

if [[ -z "$LMS_POD" ]]; then
  echo "ERROR: No LMS pod found in namespace $NAMESPACE" >&2
  exit 1
fi
echo "LMS pod: $LMS_POD"

DISCOVERY_POD=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=discovery \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || true

if [[ -z "$DISCOVERY_POD" ]]; then
  echo "WARNING: No Discovery pod found — skipping Discovery bootstrap"
fi

# ── 1. LMS OAuth Apps ─────────────────────────────────────────────────────────
echo ""
echo "--- 1. LMS OAuth Apps for Enterprise Services ---"

# Service definitions: client_id|service_user|grant_type|secret_env_var
OAUTH_APPS=(
  "enterprise-catalog-key|enterprise_catalog_worker|client-credentials|ENTERPRISE_CATALOG_OAUTH2_SECRET"
  "enterprise-access-key|enterprise_access_worker|client-credentials|ENTERPRISE_ACCESS_OAUTH2_SECRET"
  "enterprise-subsidy-key|enterprise_subsidy_worker|client-credentials|ENTERPRISE_SUBSIDY_OAUTH2_SECRET"
  "license-manager-key|license_manager_worker|client-credentials|LICENSE_MANAGER_OAUTH2_SECRET"
  "discovery|discovery_worker|client-credentials|DISCOVERY_BACKEND_OAUTH2_SECRET"
)

for entry in "${OAUTH_APPS[@]}"; do
  IFS='|' read -r CLIENT_ID SERVICE_USER GRANT_TYPE SECRET_ENV <<< "$entry"

  echo ""
  echo "  OAuth app: $CLIENT_ID (user=$SERVICE_USER, grant=$GRANT_TYPE)"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] Would create/update OAuth app $CLIENT_ID"
    continue
  fi

  # Read secret from enterprise-secrets, fall back to openedx-secrets
  SECRET_VALUE=$(kubectl get secret enterprise-secrets -n "$NAMESPACE" \
    -o jsonpath="{.data.$SECRET_ENV}" 2>/dev/null | base64 -d 2>/dev/null) || true
  if [[ -z "$SECRET_VALUE" ]]; then
    SECRET_VALUE=$(kubectl get secret openedx-secrets -n "$NAMESPACE" \
      -o jsonpath="{.data.$SECRET_ENV}" 2>/dev/null | base64 -d 2>/dev/null) || true
  fi
  if [[ -z "$SECRET_VALUE" ]]; then
    echo "  WARNING: Secret $SECRET_ENV not found. Using generated fallback."
    SECRET_VALUE="bootstrap-$(openssl rand -hex 16)"
  fi

  kubectl exec -n "$NAMESPACE" "$LMS_POD" -c lms -- \
    python manage.py lms shell -c "
from django.contrib.auth import get_user_model
from oauth2_provider.models import Application
User = get_user_model()
user, u_created = User.objects.get_or_create(
    username='$SERVICE_USER',
    defaults={'is_staff': True, 'is_active': True, 'email': '${SERVICE_USER}@service.internal'}
)
print(f'  user {user.username}: {\"created\" if u_created else \"exists\"}')
app, a_created = Application.objects.update_or_create(
    client_id='$CLIENT_ID',
    defaults={
        'name': '$CLIENT_ID',
        'client_type': Application.CLIENT_CONFIDENTIAL,
        'authorization_grant_type': '$GRANT_TYPE',
        'client_secret': '$SECRET_VALUE',
        'user': user,
        'skip_authorization': False,
    }
)
print(f'  app {app.client_id}: {\"created\" if a_created else \"updated\"}')
" 2>&1 | grep -E "^  (user|app) "

  echo "  OK: $CLIENT_ID"
done

# ── 2. Discovery Partner ──────────────────────────────────────────────────────
echo ""
echo "--- 2. Discovery Partner ---"

if [[ -z "$DISCOVERY_POD" ]]; then
  echo "  SKIPPED: No Discovery pod"
elif [[ "$DRY_RUN" == "true" ]]; then
  echo "  [DRY RUN] Would create/update Discovery Partner 'mereka'"
else
  LMS_DOMAIN=$(kubectl get deploy lms -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MEREKA_LMS_DOMAIN")].value}' 2>/dev/null) || true
  LMS_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.dev}"

  kubectl exec -n "$NAMESPACE" "$DISCOVERY_POD" -c discovery -- \
    python manage.py shell -c "
from course_discovery.apps.core.models import Partner
from django.contrib.sites.models import Site
site, _ = Site.objects.get_or_create(
    domain='$LMS_DOMAIN',
    defaults={'name': 'Mereka Academy'}
)
partner, created = Partner.objects.update_or_create(
    short_code='mereka',
    defaults={
        'name': 'Mereka Academy',
        'site': site,
        'courses_api_url': 'http://lms:8000/api/courses/v1/',
        'organizations_api_url': 'http://lms:8000/api/organizations/v0/',
        # This stack does not expose the legacy LMS programs API that course-discovery
        # expects at /api/programs/v1/programs/. Leave the URL empty so the partner
        # bootstrap skips ProgramsApiDataLoader instead of hard-failing refresh.
        'programs_api_url': '',
        'marketing_site_api_url': '',
        'lms_url': 'http://lms:8000',
        'lms_admin_url': 'http://lms:8000/admin',
        'studio_url': 'http://cms:8000',
    }
)
status = 'created' if created else 'updated'
print(f'  Partner {partner.short_code}: {status} (site={partner.site.domain})')
" 2>&1 | grep -E "^  Partner"

  echo "  OK: Discovery Partner 'mereka'"
fi

# ── 3. Discovery ProgramTypes ─────────────────────────────────────────────────
echo ""
echo "--- 3. Discovery ProgramTypes ---"

if [[ -z "$DISCOVERY_POD" ]]; then
  echo "  SKIPPED: No Discovery pod"
elif [[ "$DRY_RUN" == "true" ]]; then
  echo "  [DRY RUN] Would create/update Discovery ProgramTypes"
else
  kubectl exec -n "$NAMESPACE" "$DISCOVERY_POD" -c discovery -- \
    python manage.py shell -c "
from course_discovery.apps.course_metadata.models import ProgramType

PROGRAM_TYPES = [
    ('xseries', 'XSeries'),
    ('micromasters', 'MicroMasters'),
    ('microbachelors', 'MicroBachelors'),
    ('professional-certificate', 'Professional Certificate'),
    ('professional-program', 'Professional Program'),
    ('masters', 'Masters'),
]

for slug, name in PROGRAM_TYPES:
    pt, created = ProgramType.objects.get_or_create(
        slug=slug,
        defaults={'name_t': name}
    )
    status = 'created' if created else 'exists'
    print(f'  {pt.slug}: {status}')
" 2>&1 | grep -E "^  "

  echo "  OK: ProgramTypes"
fi

# ── 4. LMS Audit Enrollment Modes ────────────────────────────────────────────
echo ""
echo "--- 4. LMS Audit Enrollment Modes ---"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "  [DRY RUN] Would ensure audit mode on all courses"
else
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -c lms -- \
    python manage.py lms shell -c "
from common.djangoapps.course_modes.models import CourseMode
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview

total = CourseOverview.objects.count()
created = 0
for course in CourseOverview.objects.all():
    _, was_created = CourseMode.objects.get_or_create(
        course_id=course.id,
        mode_slug='audit',
        defaults={
            'mode_display_name': 'Audit',
            'min_price': 0,
            'currency': 'usd',
        }
    )
    if was_created:
        created += 1

print(f'  courses={total} created={created} already_existed={total - created}')
" 2>&1 | grep -E "^  courses="

  echo "  OK: Audit modes"
fi

# ── 5. Disable Stale Prod-Domain SiteConfigurations ──────────────────────────
echo ""
echo "--- 5. Stale Site Cleanup ---"

if [[ ! "$NAMESPACE" =~ dev ]]; then
  echo "  SKIPPED: stale prod-domain cleanup is restricted to dev namespaces"
elif [[ "$DRY_RUN" == "true" ]]; then
  echo "  [DRY RUN] Would disable stale prod-domain SiteConfigurations"
else
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -c lms -- \
    python manage.py lms shell -c "
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

# Prod domains that should not be active in a dev namespace
STALE_DOMAINS = [
    'academyv2.mereka.io',
    'academy.biji-biji.com',
    'skillourfuture.academy.mereka.io',
    'lms-dev.mereka.dev',
]

for domain in STALE_DOMAINS:
    try:
        sc = SiteConfiguration.objects.get(site__domain=domain)
        if sc.enabled:
            sc.enabled = False
            sc.save()
            print(f'  {domain}: disabled')
        else:
            print(f'  {domain}: already disabled')
    except SiteConfiguration.DoesNotExist:
        print(f'  {domain}: no config (skip)')
" 2>&1 | grep -E "^  "

  echo "  OK: Stale sites"
fi

echo ""
echo "=== Bootstrap Complete ==="
