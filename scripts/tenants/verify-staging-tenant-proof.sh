#!/usr/bin/env bash
set -euo pipefail
# verify-staging-tenant-proof.sh — Machine-checkable staging tenant runtime proof
#
# Verifies Site + SiteConfiguration truth, host acceptance, MFE config,
# and cookie domain behavior for all staging tenants.
#
# Usage:
#   scripts/tenants/verify-staging-tenant-proof.sh --namespace NS [--output-dir DIR]
#
# Writes JSON proof artifacts to --output-dir (default: var/proof).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

NAMESPACE=""
OUTPUT_DIR="var/proof"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)   NAMESPACE="${2:?--namespace required}"; shift 2 ;;
    --output-dir)  OUTPUT_DIR="${2:?--output-dir required}"; shift 2 ;;
    -h|--help)     echo "Usage: $0 --namespace NS [--output-dir DIR]"; exit 0 ;;
    *)             echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$NAMESPACE" ]] && { echo "ERROR: --namespace required" >&2; exit 1; }

cd "$REPO_ROOT"
mkdir -p "$OUTPUT_DIR"

# Find ready LMS pod
_POD_LIST=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=lms \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null || true)
LMS_POD=$(echo "$_POD_LIST" | awk '$2 == "true" { print $1; exit }')
[[ -z "$LMS_POD" ]] && { echo "ERROR: no ready LMS pod in namespace $NAMESPACE" >&2; exit 1; }

# Find Caddy pod
CADDY_POD=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=caddy \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[[ -z "$CADDY_POD" ]] && { echo "WARN: no caddy pod, skipping HTTP probes" >&2; }

STAGING_TENANTS=(
  "staging.academyv2.mereka.io"
  "staging.academy.biji-biji.com"
  "staging.skillourfuture.academy.mereka.io"
)

echo "=== verify-staging-tenant-proof: ns=$NAMESPACE lms=$LMS_POD caddy=${CADDY_POD:-none} ===" >&2

# ──────────────────────────────────────────────────────────────
# 1. SiteConfiguration proof
# ──────────────────────────────────────────────────────────────
echo "" >&2
echo "--- SiteConfiguration proof ---" >&2

DOMAINS_CSV=$(IFS=,; echo "${STAGING_TENANTS[*]}")
SC_RESULT=$(kubectl exec "$LMS_POD" -n "$NAMESPACE" -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
import json

results = []
for domain in '${DOMAINS_CSV}'.split(','):
    r = {'domain': domain}
    try:
        site = Site.objects.get(domain=domain)
        r['site_id'] = site.id
        r['site_name'] = site.name
    except Site.DoesNotExist:
        r['site_exists'] = False
        results.append(r)
        continue
    r['site_exists'] = True
    try:
        sc = SiteConfiguration.objects.get(site=site)
        r['sc_exists'] = True
        r['sc_enabled'] = sc.enabled
        v = dict(sc.site_values) if sc.site_values else {}
        r['LMS_ROOT_URL'] = v.get('LMS_ROOT_URL', '')
        r['CMS_ROOT_URL'] = v.get('CMS_ROOT_URL', '')
        r['MFE_BASE_URL'] = v.get('MFE_BASE_URL', '')
        r['THEME_NAME'] = v.get('THEME_NAME', '')
        r['course_org_filter'] = v.get('course_org_filter', [])
        mfe = v.get('MFE_CONFIG', {})
        r['MFE_CONFIG'] = {
            'LMS_BASE_URL': mfe.get('LMS_BASE_URL', ''),
            'STUDIO_BASE_URL': mfe.get('STUDIO_BASE_URL', ''),
            'BASE_URL': mfe.get('BASE_URL', ''),
            'FAVICON_URL': mfe.get('FAVICON_URL', ''),
            'LOGO_URL': mfe.get('LOGO_URL', ''),
            'LOGIN_URL': mfe.get('LOGIN_URL', ''),
            'LOGOUT_URL': mfe.get('LOGOUT_URL', ''),
        }
    except SiteConfiguration.DoesNotExist:
        r['sc_exists'] = False
    results.append(r)
print(json.dumps(results, indent=2))
" 2>/dev/null | python3 -c "
import json, sys
# Strip Django shell noise, find JSON array
lines = sys.stdin.read()
start = lines.index('[')
print(lines[start:])
" 2>/dev/null)

echo "$SC_RESULT" > "$OUTPUT_DIR/siteconfig-proof.json"
echo "  wrote siteconfig-proof.json" >&2

# ──────────────────────────────────────────────────────────────
# 2. Host acceptance proof
# ──────────────────────────────────────────────────────────────
echo "" >&2
echo "--- Host acceptance proof ---" >&2

ALL_HOSTS=(
  "staging.academyv2.mereka.io"
  "staging.academy.biji-biji.com"
  "staging.skillourfuture.academy.mereka.io"
  "staging.studio.academyv2.mereka.io"
  "studio.staging.academy.biji-biji.com"
  "studio.staging.skillourfuture.academy.mereka.io"
  "staging.apps.academyv2.mereka.io"
  "apps.staging.academy.biji-biji.com"
  "apps.staging.skillourfuture.academy.mereka.io"
)

HA_RESULTS="["
FIRST=true
if [[ -n "$CADDY_POD" ]]; then
  for HOST in "${ALL_HOSTS[@]}"; do
    HTTP_OUT=$(kubectl exec "$CADDY_POD" -n "$NAMESPACE" -- \
      wget -q -O /dev/null -S --header="Host: $HOST" "http://lms:8000/" 2>&1 | head -3 || true)
    STATUS=$(echo "$HTTP_OUT" | grep -oP 'HTTP/\S+\s+\K\d+' | head -1 || echo "unknown")
    ACCEPTED="false"
    [[ "$STATUS" != "400" && "$STATUS" != "unknown" ]] && ACCEPTED="true"
    [[ "$FIRST" == "true" ]] && FIRST=false || HA_RESULTS+=","
    HA_RESULTS+=$(printf '\n  {"host":"%s","http_status":"%s","accepted":%s}' "$HOST" "$STATUS" "$ACCEPTED")
    echo "  $HOST → $STATUS (accepted=$ACCEPTED)" >&2
  done
fi
HA_RESULTS+="]"

echo "$HA_RESULTS" | python3 -m json.tool > "$OUTPUT_DIR/host-acceptance-proof.json" 2>/dev/null || echo "$HA_RESULTS" > "$OUTPUT_DIR/host-acceptance-proof.json"
echo "  wrote host-acceptance-proof.json" >&2

# ──────────────────────────────────────────────────────────────
# 3. Cookie proof
# ──────────────────────────────────────────────────────────────
echo "" >&2
echo "--- Cookie proof ---" >&2

COOKIE_RESULT=$(kubectl exec "$LMS_POD" -n "$NAMESPACE" -- python manage.py lms shell -c "
from django.conf import settings
import json

result = {
    'SESSION_COOKIE_DOMAIN': settings.SESSION_COOKIE_DOMAIN,
    'SESSION_COOKIE_SAMESITE': settings.SESSION_COOKIE_SAMESITE,
    'SESSION_COOKIE_SECURE': settings.SESSION_COOKIE_SECURE,
    'CSRF_COOKIE_DOMAIN': settings.CSRF_COOKIE_DOMAIN,
    'CSRF_TRUSTED_ORIGINS': getattr(settings, 'CSRF_TRUSTED_ORIGINS', []),
    'cookie_middleware': [m for m in settings.MIDDLEWARE if 'ookie' in m.lower() or 'ereka' in m.lower()],
}
print(json.dumps(result, indent=2))
" 2>/dev/null | python3 -c "
import json, sys
lines = sys.stdin.read()
start = lines.index('{')
print(lines[start:])
" 2>/dev/null)

echo "$COOKIE_RESULT" > "$OUTPUT_DIR/cookie-proof.json"
echo "  wrote cookie-proof.json" >&2

# ──────────────────────────────────────────────────────────────
# 4. Summary
# ──────────────────────────────────────────────────────────────
echo "" >&2
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Count host acceptance results
ACCEPTED_COUNT=0
TOTAL_HOSTS=${#ALL_HOSTS[@]}
if [[ -f "$OUTPUT_DIR/host-acceptance-proof.json" ]]; then
  ACCEPTED_COUNT=$(python3 -c "import json; d=json.load(open('$OUTPUT_DIR/host-acceptance-proof.json')); print(sum(1 for h in d if h.get('accepted')))" 2>/dev/null || echo 0)
fi

cat > "$OUTPUT_DIR/staging-proof-summary.json" <<SUMMARY_EOF
{
  "proof_type": "staging-tenant-runtime-proof",
  "collected_at": "$TIMESTAMP",
  "namespace": "$NAMESPACE",
  "lms_pod": "$LMS_POD",
  "host_acceptance": "$ACCEPTED_COUNT/$TOTAL_HOSTS",
  "artifacts": [
    "siteconfig-proof.json",
    "host-acceptance-proof.json",
    "cookie-proof.json"
  ]
}
SUMMARY_EOF

echo "=== verify-staging-tenant-proof: complete ===" >&2
echo "  host acceptance: $ACCEPTED_COUNT/$TOTAL_HOSTS" >&2
echo "  output: $OUTPUT_DIR/" >&2
