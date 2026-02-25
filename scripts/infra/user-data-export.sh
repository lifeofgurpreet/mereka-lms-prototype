#!/usr/bin/env bash
# user-data-export.sh — DSAR (Data Subject Access Request) export tool.
# Generates a structured archive of all personal data for a given user.
#
# Complies with:
#   GDPR Article 20 — Right to data portability
#   PDPA Malaysia Section 30 — Right of access
#   Open edX OEP-30 — PII annotation and auditing
#
# Output: <output-dir>/user-export-<username>-<date>.tar.gz
#   + SHA-256 checksum file
#
# Data sources:
#   - Open edX LMS (MySQL via Django management commands and REST APIs)
#   - Forum data (MongoDB via forum management commands)
#   - Purchase Gateway (PostgreSQL via kubectl exec)
#   - GCS object storage (profile images, certificates)
#
# Requirements:
#   - kubectl configured with access to the mereka-lms namespace
#   - LMS pod running and reachable via kubectl exec
#   - payments-gateway pod running (for purchase data)
#   - LMS_ADMIN_TOKEN or OPENEDX_API_KEY env var for authenticated API calls
#   - gsutil (gcloud SDK) for GCS object listing
#
# Usage:
#   ./scripts/infra/user-data-export.sh --username <username> --email <email>
#   ./scripts/infra/user-data-export.sh --username alice --email alice@example.com
#   ./scripts/infra/user-data-export.sh --username alice --email alice@example.com \
#       --namespace mereka-lms --output-dir /tmp/exports
#
# @covers AC-PRV-005, AC-PRV-006
# @spec: data-privacy-gdpr-compliance_spec.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NAMESPACE="${NAMESPACE:-mereka-lms}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/dsar-exports}"
LMS_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
GCS_BUCKET="${GCS_BUCKET:-gs://mereka-lms-static}"
USERNAME=""
EMAIL=""
VERBOSE=0

usage() {
  cat <<EOF
Usage: $0 --username <username> --email <email> [OPTIONS]

Required:
  --username <username>   Open edX username of the data subject
  --email <email>         Email address of the data subject

Options:
  --namespace <ns>        K8s namespace (default: mereka-lms)
  --output-dir <dir>      Directory to write the export archive (default: /tmp/dsar-exports)
  --lms-domain <domain>   LMS domain (default: academyv2.mereka.io)
  --gcs-bucket <bucket>   GCS bucket for user files (default: gs://mereka-lms-static)
  --verbose               Enable verbose logging
  -h, --help              Show this help

Environment:
  OPENEDX_API_KEY         LMS REST API key (used for authenticated data API calls)
  NAMESPACE               Override --namespace
  OUTPUT_DIR              Override --output-dir
  GCS_BUCKET              Override --gcs-bucket

Examples:
  # Basic export
  ./scripts/infra/user-data-export.sh --username alice --email alice@example.com

  # Export to custom directory
  OUTPUT_DIR=/secure/exports ./scripts/infra/user-data-export.sh \\
    --username alice --email alice@example.com

Notes:
  - Requires kubectl access to the target cluster
  - The LMS pod must be running for profile, enrollment, and grade data
  - The payments-gateway pod must be running for purchase history
  - GCS object listing requires gsutil / gcloud SDK
  - Review the archive before delivering to the data subject
  - Log the delivery in docs/operations/dsar-register/ (private, not in repo)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username) USERNAME="${2:-}"; shift 2 ;;
    --email) EMAIL="${2:-}"; shift 2 ;;
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    --lms-domain) LMS_DOMAIN="${2:-}"; shift 2 ;;
    --gcs-bucket) GCS_BUCKET="${2:-}"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$USERNAME" || -z "$EMAIL" ]]; then
  echo "ERROR: --username and --email are required" >&2
  usage
  exit 1
fi

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }
debug() { [[ "$VERBOSE" -eq 1 ]] && echo "[DEBUG] $*" || true; }
warn() { echo "[WARN] $*" >&2; }

EXPORT_DATE=$(date -u +%Y-%m-%d)
EXPORT_DIR="${OUTPUT_DIR}/user-export-${USERNAME}-${EXPORT_DATE}"
ARCHIVE_NAME="user-export-${USERNAME}-${EXPORT_DATE}.tar.gz"

log "Starting DSAR export for username='$USERNAME' email='$EMAIL'"
log "Export directory: $EXPORT_DIR"

mkdir -p \
  "$EXPORT_DIR/profile" \
  "$EXPORT_DIR/learning" \
  "$EXPORT_DIR/forum" \
  "$EXPORT_DIR/commerce" \
  "$EXPORT_DIR/consent" \
  "$EXPORT_DIR/audit" \
  "$EXPORT_DIR/files"

# ── Locate pods ───────────────────────────────────────────────────────────────

LMS_POD=""
PG_POD=""

set +e
LMS_POD=$(kubectl get pod -n "$NAMESPACE" -l "app.kubernetes.io/name=lms" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
PG_POD=$(kubectl get pod -n "$NAMESPACE" -l "app=payments-gateway" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
set -e

if [[ -z "$LMS_POD" ]]; then
  warn "No running LMS pod found in namespace '$NAMESPACE' — profile and learning data will be incomplete"
fi

if [[ -z "$PG_POD" ]]; then
  warn "No running payments-gateway pod found — purchase history will be skipped"
fi

# ── 1. Profile data (auth_user + auth_userprofile) ────────────────────────────
# OEP-30: DIRECT PII — name, email, username
# OEP-30: QUASI PII  — DOB, gender, country, language, city

log "Exporting profile data..."

if [[ -n "$LMS_POD" ]]; then
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "
import json, sys
from django.contrib.auth import get_user_model
from student.models import UserProfile

User = get_user_model()
try:
    u = User.objects.get(username='${USERNAME}')
except User.DoesNotExist:
    print(json.dumps({'error': 'user not found', 'username': '${USERNAME}'}))
    sys.exit(0)

try:
    p = UserProfile.objects.get(user=u)
    profile = {
        'year_of_birth': p.year_of_birth,
        'gender': p.gender,
        'language': p.language,
        'country': str(p.country) if p.country else None,
        'city': p.city,
        'bio': p.bio,
        'phone_number': str(p.phone_number) if p.phone_number else None,
    }
except UserProfile.DoesNotExist:
    profile = {}

data = {
    'username': u.username,
    'email': u.email,
    'first_name': u.first_name,
    'last_name': u.last_name,
    'date_joined': u.date_joined.isoformat(),
    'last_login': u.last_login.isoformat() if u.last_login else None,
    'is_active': u.is_active,
    'profile': profile,
}
print(json.dumps(data, default=str, indent=2))
" 2>/dev/null > "$EXPORT_DIR/profile/user.json"

  log "  Profile: exported to profile/user.json"

  # Social auth (SSO identities)
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "
import json
from social_django.models import UserSocialAuth
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    u = User.objects.get(username='${USERNAME}')
except User.DoesNotExist:
    print(json.dumps([]))
    exit()
entries = list(UserSocialAuth.objects.filter(user=u).values(
    'provider', 'uid', 'created', 'modified'))
print(json.dumps(entries, default=str, indent=2))
" 2>/dev/null > "$EXPORT_DIR/profile/social_auth.json"

  log "  Social auth: exported to profile/social_auth.json"
else
  echo '{"error": "LMS pod unavailable"}' > "$EXPORT_DIR/profile/user.json"
  echo '[]' > "$EXPORT_DIR/profile/social_auth.json"
fi

# ── 2. Learning activity (enrollments, grades, certificates) ──────────────────
# OEP-30: BEHAVIORAL PII

log "Exporting learning activity..."

if [[ -n "$LMS_POD" ]]; then
  # Enrollments
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "
import json
from student.models import CourseEnrollment
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    u = User.objects.get(username='${USERNAME}')
except User.DoesNotExist:
    print(json.dumps([]))
    exit()
enrollments = list(CourseEnrollment.objects.filter(user=u).values(
    'course_id', 'created', 'is_active', 'mode'))
print(json.dumps(enrollments, default=str, indent=2))
" 2>/dev/null > "$EXPORT_DIR/learning/enrollments.json"

  # Grades
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "
import json
from lms.djangoapps.grades.models import PersistentCourseGrade
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    u = User.objects.get(username='${USERNAME}')
except User.DoesNotExist:
    print(json.dumps([]))
    exit()
grades = list(PersistentCourseGrade.objects.filter(user_id=u.id).values(
    'course_id', 'percent_grade', 'letter_grade', 'passed_timestamp',
    'created', 'modified'))
print(json.dumps(grades, default=str, indent=2))
" 2>/dev/null > "$EXPORT_DIR/learning/grades.json"

  # Certificates
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "
import json
from lms.djangoapps.certificates.models import GeneratedCertificate
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    u = User.objects.get(username='${USERNAME}')
except User.DoesNotExist:
    print(json.dumps([]))
    exit()
certs = list(GeneratedCertificate.objects.filter(user=u).values(
    'course_id', 'status', 'grade', 'mode', 'created_date', 'modified_date',
    'download_url', 'verify_uuid'))
print(json.dumps(certs, default=str, indent=2))
" 2>/dev/null > "$EXPORT_DIR/learning/certificates.json"

  log "  Enrollments: learning/enrollments.json"
  log "  Grades: learning/grades.json"
  log "  Certificates: learning/certificates.json"
else
  echo '[]' > "$EXPORT_DIR/learning/enrollments.json"
  echo '[]' > "$EXPORT_DIR/learning/grades.json"
  echo '[]' > "$EXPORT_DIR/learning/certificates.json"
fi

# ── 3. Forum data (MongoDB via forum management command) ──────────────────────
# OEP-30: BEHAVIORAL + DIRECT (authorship)

log "Exporting forum data..."

if [[ -n "$LMS_POD" ]]; then
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "
import json
# Forum v2 (Python) — query via forum API module
try:
    from forum.models import CommentThread, Comment
    threads = list(CommentThread.objects.filter(
        author_username='${USERNAME}'
    ).values('_id', 'course_id', 'title', 'body', 'created_at', 'updated_at', 'comment_count'))
    comments = list(Comment.objects.filter(
        author_username='${USERNAME}'
    ).values('_id', 'course_id', 'body', 'created_at', 'updated_at'))
    print(json.dumps({'threads': threads, 'comments': comments}, default=str, indent=2))
except Exception as e:
    print(json.dumps({'error': str(e), 'note': 'forum data may require direct MongoDB query'}))
" 2>/dev/null > "$EXPORT_DIR/forum/posts.json"

  log "  Forum posts: forum/posts.json"
else
  echo '{"error": "LMS pod unavailable"}' > "$EXPORT_DIR/forum/posts.json"
fi

# ── 4. Purchase history (PostgreSQL) ──────────────────────────────────────────
# OEP-30: DIRECT PII (buyer_email, stripe IDs) + BEHAVIORAL

log "Exporting purchase history..."

if [[ -n "$PG_POD" ]]; then
  kubectl exec -n "$NAMESPACE" "$PG_POD" -- \
    python -c "
import json, sys, os
sys.path.insert(0, '/app')
try:
    from app.database import get_session
    from app.models.order import Order
    from app.models.entitlement import Entitlement

    result = {}
    with get_session() as db:
        orders = db.query(Order).filter(Order.buyer_email == '${EMAIL}').all()
        result['orders'] = [
            {
                'id': str(o.id),
                'course_id': o.course_id,
                'amount': str(o.amount),
                'currency': o.currency,
                'status': o.status,
                'created_at': o.created_at.isoformat() if o.created_at else None,
            }
            for o in orders
        ]
        entitlements = db.query(Entitlement).filter(
            Entitlement.recipient_email == '${EMAIL}'
        ).all()
        result['entitlements'] = [
            {
                'id': str(e.id),
                'course_id': e.course_id,
                'claimed': e.is_claimed,
                'created_at': e.created_at.isoformat() if e.created_at else None,
            }
            for e in entitlements
        ]
    print(json.dumps(result, default=str, indent=2))
except Exception as ex:
    print(json.dumps({'error': str(ex)}))
" 2>/dev/null > "$EXPORT_DIR/commerce/orders.json"

  log "  Commerce data: commerce/orders.json"
else
  echo '{"error": "payments-gateway pod unavailable — skipped"}' > "$EXPORT_DIR/commerce/orders.json"
fi

# ── 5. Consent records ─────────────────────────────────────────────────────────
# OEP-30: BEHAVIORAL (consent decisions)

log "Exporting consent records..."

if [[ -n "$LMS_POD" ]]; then
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "
import json
try:
    from consent.models import DataSharingConsent
    from django.contrib.auth import get_user_model
    User = get_user_model()
    u = User.objects.get(username='${USERNAME}')
    records = list(DataSharingConsent.objects.filter(
        username=u.username
    ).values('course_id', 'granted', 'created', 'modified'))
    print(json.dumps(records, default=str, indent=2))
except Exception as e:
    print(json.dumps({'error': str(e)}))
" 2>/dev/null > "$EXPORT_DIR/consent/consent_records.json"

  log "  Consent records: consent/consent_records.json"
else
  echo '[]' > "$EXPORT_DIR/consent/consent_records.json"
fi

# ── 6. GCS file listing (profile images, certificates) ────────────────────────

log "Listing GCS user files..."

GCS_FILES_JSON="[]"
if command -v gsutil >/dev/null 2>&1; then
  set +e
  GCS_PROFILE=$(gsutil ls "${GCS_BUCKET}/profile-images/${USERNAME}*" 2>/dev/null || true)
  GCS_CERTS=$(gsutil ls "${GCS_BUCKET}/certificates/*${USERNAME}*" 2>/dev/null || true)
  set -e

  ALL_FILES=""
  [[ -n "$GCS_PROFILE" ]] && ALL_FILES="$GCS_PROFILE"$'\n'"$GCS_CERTS" || ALL_FILES="$GCS_CERTS"

  if [[ -n "$ALL_FILES" ]]; then
    # Convert newline-separated paths to JSON array
    GCS_FILES_JSON=$(echo "$ALL_FILES" | grep -v '^$' | \
      python3 -c "import sys, json; print(json.dumps(sys.stdin.read().splitlines()))")
  fi
  log "  GCS files listed: $(echo "$GCS_FILES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0) objects"
else
  warn "gsutil not available — GCS file listing skipped"
fi

echo "$GCS_FILES_JSON" > "$EXPORT_DIR/files/gcs_objects.json"

# ── 7. Export metadata ─────────────────────────────────────────────────────────

log "Writing export metadata..."

METADATA=$(cat <<EOF
{
  "export_version": "1.0",
  "export_date": "${EXPORT_DATE}",
  "requested_username": "${USERNAME}",
  "requested_email": "${EMAIL}",
  "namespace": "${NAMESPACE}",
  "lms_domain": "${LMS_DOMAIN}",
  "oep30_reference": "https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0030-arch-pii-markup-and-auditing.html",
  "data_categories": ["DIRECT", "QUASI", "BEHAVIORAL", "UNIQUE_ID"],
  "legal_basis": {
    "gdpr_article": "20 (Right to data portability)",
    "pdpa_section": "30 (Right of access)",
    "regulation": "GDPR 2016/679, PDPA Malaysia 2010"
  },
  "contents": {
    "profile/user.json": "auth_user + auth_userprofile (DIRECT, QUASI PII)",
    "profile/social_auth.json": "SSO provider associations (DIRECT PII)",
    "learning/enrollments.json": "Course enrollments (BEHAVIORAL PII)",
    "learning/grades.json": "Course grades (BEHAVIORAL PII)",
    "learning/certificates.json": "Issued certificates (DIRECT + BEHAVIORAL PII)",
    "forum/posts.json": "Forum threads and comments authored by user (BEHAVIORAL PII)",
    "commerce/orders.json": "Purchase history and entitlements (DIRECT + BEHAVIORAL PII)",
    "consent/consent_records.json": "Data sharing consent decisions (BEHAVIORAL PII)",
    "files/gcs_objects.json": "GCS object paths (profile images, certificate PDFs)"
  },
  "retention_policy_reference": "docs/operations/DATA_RETENTION_POLICY.md",
  "generated_by": "scripts/infra/user-data-export.sh"
}
EOF
)

echo "$METADATA" > "$EXPORT_DIR/audit/export_metadata.json"

# ── 8. README ─────────────────────────────────────────────────────────────────

cat > "$EXPORT_DIR/README.txt" <<EOF
Mereka Academy — Personal Data Export
======================================

Username : ${USERNAME}
Email    : ${EMAIL}
Date     : ${EXPORT_DATE}
Format   : JSON (machine-readable); CSV summaries where noted

This archive contains all personal data held by Mereka Academy for the
above data subject, exported in compliance with:
  - GDPR Article 20 (Right to data portability)
  - PDPA Malaysia Section 30 (Right of access)
  - Open edX OEP-30 (PII annotation framework)

Contents
--------
profile/user.json
  Your account information: username, email, name, date joined, profile
  fields (year of birth, gender, language, country, city, bio).

profile/social_auth.json
  Single Sign-On (SSO) identity associations (e.g. Authentik provider).

learning/enrollments.json
  Courses you have enrolled in, with enrollment dates and modes.

learning/grades.json
  Your final grades for each course.

learning/certificates.json
  Certificates issued to you, including course IDs and download URLs.

forum/posts.json
  Discussion threads and comments you have authored.

commerce/orders.json
  Your purchase history and course entitlements.
  Note: payment card numbers are NOT stored by Mereka Academy (handled
  by Stripe). Stripe customer data may require a separate request to
  Stripe at https://support.stripe.com/

consent/consent_records.json
  Records of your data sharing consent decisions.

files/gcs_objects.json
  List of files stored on Mereka Academy servers associated with your
  account (profile photo, certificate PDFs).

audit/export_metadata.json
  Technical metadata about this export (version, date, legal basis).

Retention Notice
----------------
Financial records (orders) are retained for 7 years under Companies
Act 2016 (Malaysia). PII fields in financial records are anonymized
when you exercise your right to erasure; financial totals are retained.

Backup Notice
-------------
Your data may persist in encrypted backup archives for up to 90 days
after live systems are cleared following an erasure request.

Questions
---------
Contact: privacy@mereka.io
EOF

# ── 9. Create archive + checksum ──────────────────────────────────────────────

log "Creating archive..."

mkdir -p "$OUTPUT_DIR"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

tar -czf "$ARCHIVE_PATH" -C "$OUTPUT_DIR" "$(basename "$EXPORT_DIR")"
CHECKSUM=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')
echo "$CHECKSUM  $ARCHIVE_NAME" > "${ARCHIVE_PATH}.sha256"

log ""
log "Export complete."
log "  Archive : $ARCHIVE_PATH"
log "  Checksum: ${ARCHIVE_PATH}.sha256  (SHA-256: $CHECKSUM)"
log ""
log "Next steps:"
log "  1. Review the archive contents before delivery."
log "  2. Deliver via secure link (7-day expiry) or encrypted email."
log "  3. Log delivery in docs/operations/dsar-register/ (private, not in repo)."
log "  4. Confirm delivery to data subject within 30-day DSAR SLA."
log ""
log "  To list contents: tar -tzf $ARCHIVE_PATH"
log "  To verify checksum: sha256sum -c ${ARCHIVE_PATH}.sha256"
