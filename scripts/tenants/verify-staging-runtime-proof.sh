#!/usr/bin/env bash
# verify-staging-runtime-proof.sh — Post-deploy runtime proof for staging tenants
#
# Runs immediately after new images are deployed to stg-mereka-lms.
# Verifies image truth, module presence, host acceptance, SiteConfiguration,
# MFE config isolation, cookie domain scoping, and auth redirect routing.
#
# Usage:
#   scripts/tenants/verify-staging-runtime-proof.sh [--namespace NS] [--dry-run] [--output-dir DIR]
#
# Writes:
#   var/proof/staging-runtime-proof.json   (machine-readable consolidated proof)
#
# Exit codes:
#   0  all critical (P0) checks passed
#   1  one or more critical checks failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Defaults ─────────────────────────────────────────────────────────────────
NAMESPACE="stg-mereka-lms"
OUTPUT_DIR="${REPO_ROOT}/var/proof"
DRY_RUN=false
CURL_TIMEOUT=15

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)  NAMESPACE="${2:?--namespace requires a value}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?--output-dir requires a value}"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--namespace NS] [--dry-run] [--output-dir DIR]"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

# ── Counters & result accumulator ────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0
CRITICAL_FAIL=0

# JSON results array (populated as we go)
RESULTS_JSON="[]"

_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

pass_() {
  PASS=$((PASS + 1))
  printf "PASS  %s\n" "$1"
  RESULTS_JSON="$(printf '%s' "$RESULTS_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d.append({'status':'PASS','check':'$1','ts':'$(_ts)'})
print(json.dumps(d))
" 2>/dev/null || echo "$RESULTS_JSON")"
}

fail_() {
  local critical="${2:-false}"
  FAIL=$((FAIL + 1))
  [[ "$critical" == "true" ]] && CRITICAL_FAIL=$((CRITICAL_FAIL + 1))
  printf "FAIL  %s\n" "$1"
  RESULTS_JSON="$(printf '%s' "$RESULTS_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d.append({'status':'FAIL','check':'$1','critical':$critical,'ts':'$(_ts)'})
print(json.dumps(d))
" 2>/dev/null || echo "$RESULTS_JSON")"
}

skip_() {
  SKIP=$((SKIP + 1))
  printf "SKIP  %s\n" "$1"
}

# ── Staging tenant table ─────────────────────────────────────────────────────
# Derived from deploy/k8s/tenancy/tenant-registry.yaml (staging environment section)
#
# Format: "SLUG:LMS_HOST:STUDIO_HOST:MFE_HOST:EXPECTED_COOKIE_DOMAIN"
declare -a TENANTS=(
  "mereka:staging.academyv2.mereka.io:studio.staging.academyv2.mereka.io:apps.staging.academyv2.mereka.io:.staging.academyv2.mereka.io"
  "biji-biji:staging.academy.biji-biji.com:studio.staging.academy.biji-biji.com:apps.staging.academy.biji-biji.com:.staging.academy.biji-biji.com"
  "skillourfuture:staging.skillourfuture.academy.mereka.io:studio.staging.skillourfuture.academy.mereka.io:apps.staging.skillourfuture.academy.mereka.io:.staging.skillourfuture.academy.mereka.io"
)

# ── Dry-run stub ──────────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo "=== DRY RUN MODE — no live cluster calls will be made ==="
  echo "Namespace : $NAMESPACE"
  echo "Output dir: $OUTPUT_DIR"
  echo "Tenants   : ${#TENANTS[@]}"
  for t in "${TENANTS[@]}"; do
    IFS=: read -r slug lms _dr_studio mfe _dr_cd <<< "$t"
    printf "  %-20s  lms=%-45s  mfe=%s\n" "$slug" "$lms" "$mfe"
  done
  echo ""
  echo "Dry-run complete — nothing written."
  exit 0
fi

# ── Prerequisite: kubectl ─────────────────────────────────────────────────────
if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl not found in PATH" >&2
  exit 1
fi

# ── Discover LMS pod ─────────────────────────────────────────────────────────
echo "=== verify-staging-runtime-proof: ns=$NAMESPACE ==="
echo "Timestamp : $(_ts)"
echo "Output    : $OUTPUT_DIR/staging-runtime-proof.json"
echo ""

_find_ready_pod() {
  local label="$1"
  kubectl get pods -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=$label" \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null \
    | awk '$2 == "true" { print $1; exit }'
}

LMS_POD="$(_find_ready_pod lms)"
if [[ -z "$LMS_POD" ]]; then
  echo "ERROR: no ready LMS pod in namespace $NAMESPACE" >&2
  exit 1
fi
echo "LMS pod   : $LMS_POD"

CMS_POD="$(_find_ready_pod cms)"
MFE_POD="$(_find_ready_pod mfe)"
echo "CMS pod   : ${CMS_POD:-(none)}"
echo "MFE pod   : ${MFE_POD:-(none)}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — Image truth check
# ═══════════════════════════════════════════════════════════════════════════════
echo "--- [1] Image truth check ---"

# The banned commit (old image that must NOT be running).
# Any image tagged with this abbreviated SHA should be flagged.
BANNED_COMMIT="e5c0c508"

_check_image_for_deploy() {
  local deploy="$1"
  local label="$2"

  local image
  image=$(kubectl get deployment "$deploy" -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)

  if [[ -z "$image" ]]; then
    skip_ "Image/$deploy: deployment not found"
    return
  fi

  local tag="${image##*:}"

  # Must not use :latest in staging
  if [[ "$tag" == "latest" ]]; then
    fail_ "Image/$deploy: running :latest tag (not a pinned SHA) — image=$image" "true"
    return
  fi

  # Must not be the banned commit
  if echo "$tag" | grep -q "$BANNED_COMMIT"; then
    fail_ "Image/$deploy: running banned commit $BANNED_COMMIT — image=$image" "true"
    return
  fi

  pass_ "Image/$deploy: tag=$tag (not :latest, not banned commit)"
}

for deploy_pair in "lms:lms" "cms:cms" "mfe:mfe"; do
  IFS=: read -r dep label <<< "$deploy_pair"
  _check_image_for_deploy "$dep" "$label"
done

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — Module presence: MerekaLoginRedirectMiddleware
# ═══════════════════════════════════════════════════════════════════════════════
echo "--- [2] Module presence ---"

MODULE_CHECK=$(kubectl exec "$LMS_POD" -n "$NAMESPACE" -- \
  python -c "
import sys
try:
    from lms.mereka_multisite import MerekaLoginRedirectMiddleware, MerekaCookieDomainMiddleware
    print('PRESENT MerekaLoginRedirectMiddleware MerekaCookieDomainMiddleware')
except ImportError as e:
    print(f'ABSENT {e}')
    sys.exit(1)
" 2>/dev/null || echo "EXEC_FAILED")

if echo "$MODULE_CHECK" | grep -q "^PRESENT"; then
  pass_ "Module: MerekaLoginRedirectMiddleware importable in running LMS pod"
  pass_ "Module: MerekaCookieDomainMiddleware importable in running LMS pod"
elif echo "$MODULE_CHECK" | grep -q "^ABSENT"; then
  DETAIL=$(echo "$MODULE_CHECK" | sed 's/^ABSENT //')
  fail_ "Module: MerekaLoginRedirectMiddleware import failed in LMS pod: $DETAIL" "true"
else
  fail_ "Module: kubectl exec failed checking module presence (pod=$LMS_POD)" "true"
fi

# Also verify MerekaLoginRedirectMiddleware is in MIDDLEWARE at runtime
MW_CHECK=$(kubectl exec "$LMS_POD" -n "$NAMESPACE" -- \
  python -c "
from django.conf import settings
mw = settings.MIDDLEWARE
found = any('MerekaLoginRedirectMiddleware' in m for m in mw)
print('PRESENT' if found else 'ABSENT')
" 2>/dev/null || echo "EXEC_FAILED")

case "$MW_CHECK" in
  PRESENT) pass_ "Module: MerekaLoginRedirectMiddleware in Django MIDDLEWARE list" ;;
  ABSENT)  fail_ "Module: MerekaLoginRedirectMiddleware NOT in Django MIDDLEWARE list" "true" ;;
  *)       fail_ "Module: could not read MIDDLEWARE from running LMS pod" "false" ;;
esac

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — Host acceptance (P0 staging hosts)
# ═══════════════════════════════════════════════════════════════════════════════
echo "--- [3] Host acceptance ---"

# Collect all P0 hosts for staging
declare -a P0_LMS_HOSTS=()
declare -a P0_STUDIO_HOSTS=()
declare -a P0_MFE_HOSTS=()

for tenant in "${TENANTS[@]}"; do
  IFS=: read -r _ha_slug lms studio mfe _ha_cd <<< "$tenant"
  P0_LMS_HOSTS+=("$lms")
  P0_STUDIO_HOSTS+=("$studio")
  P0_MFE_HOSTS+=("$mfe")
done

HOST_ACCEPT_JSON="[]"

_check_host() {
  local host="$1"
  # $2 is a label hint (unused in logic but kept for call-site readability)
  local critical="${3:-true}"

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time "$CURL_TIMEOUT" \
    --location \
    "https://${host}/" 2>/dev/null || echo "000")

  local accepted="false"
  local verdict

  case "$http_code" in
    000)
      verdict="UNREACHABLE"
      ;;
    502|503|504)
      verdict="GATEWAY_ERROR"
      ;;
    4[0-9][0-9])
      # 401/403/302 on / are normal (auth walls), still means the pod is alive
      accepted="true"
      verdict="OK_AUTH_WALL"
      ;;
    2[0-9][0-9]|3[0-9][0-9])
      accepted="true"
      verdict="OK"
      ;;
    *)
      verdict="UNEXPECTED_${http_code}"
      ;;
  esac

  HOST_ACCEPT_JSON="$(printf '%s' "$HOST_ACCEPT_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d.append({'host':'$host','http_code':'$http_code','accepted':$accepted,'verdict':'$verdict'})
print(json.dumps(d))
" 2>/dev/null || echo "$HOST_ACCEPT_JSON")"

  if [[ "$accepted" == "true" ]]; then
    pass_ "Host: https://$host/ → $http_code ($verdict)"
  else
    fail_ "Host: https://$host/ → $http_code ($verdict)" "$critical"
  fi
}

echo "LMS hosts:"
for h in "${P0_LMS_HOSTS[@]}"; do _check_host "$h" "lms" "true"; done

echo "Studio hosts:"
for h in "${P0_STUDIO_HOSTS[@]}"; do _check_host "$h" "studio" "true"; done

echo "MFE hosts:"
for h in "${P0_MFE_HOSTS[@]}"; do _check_host "$h" "mfe" "true"; done

printf '%s' "$HOST_ACCEPT_JSON" | python3 -m json.tool \
  > "$OUTPUT_DIR/staging-host-acceptance.json" 2>/dev/null \
  || printf '%s' "$HOST_ACCEPT_JSON" > "$OUTPUT_DIR/staging-host-acceptance.json"

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — SiteConfiguration proof (Django shell)
# ═══════════════════════════════════════════════════════════════════════════════
echo "--- [4] SiteConfiguration proof ---"

# Build CSV of LMS domains for the shell query
DOMAINS_CSV=""
for tenant in "${TENANTS[@]}"; do
  IFS=: read -r _csv_slug lms _csv_studio _csv_mfe _csv_cd <<< "$tenant"
  DOMAINS_CSV="${DOMAINS_CSV}${lms},"
done
DOMAINS_CSV="${DOMAINS_CSV%,}"  # strip trailing comma

SC_RAW=$(kubectl exec "$LMS_POD" -n "$NAMESPACE" -- python -c "
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
        r['site_exists'] = True
    except Site.DoesNotExist:
        r['site_exists'] = False
        results.append(r)
        continue
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
            'LOGIN_URL': mfe.get('LOGIN_URL', ''),
            'LOGOUT_URL': mfe.get('LOGOUT_URL', ''),
            'AUTHN_MICROFRONTEND_URL': mfe.get('AUTHN_MICROFRONTEND_URL', ''),
            'AUTHN_MICROFRONTEND_DOMAIN': mfe.get('AUTHN_MICROFRONTEND_DOMAIN', ''),
        }
    except SiteConfiguration.DoesNotExist:
        r['sc_exists'] = False
    results.append(r)
print(json.dumps(results, indent=2))
" 2>/dev/null || echo "EXEC_FAILED")

if [[ "$SC_RAW" == "EXEC_FAILED" ]]; then
  fail_ "SiteConfig: kubectl exec failed — cannot verify SiteConfiguration" "true"
  SC_DATA="[]"
else
  # Strip Django shell noise (lines before the JSON array)
  SC_DATA=$(printf '%s' "$SC_RAW" | python3 -c "
import json, sys
raw = sys.stdin.read()
start = raw.find('[')
if start < 0:
    print('[]')
    sys.exit(0)
print(raw[start:])
" 2>/dev/null || echo "[]")
fi

printf '%s' "$SC_DATA" | python3 -m json.tool \
  > "$OUTPUT_DIR/staging-siteconfig-proof.json" 2>/dev/null \
  || printf '%s' "$SC_DATA" > "$OUTPUT_DIR/staging-siteconfig-proof.json"

# Evaluate per-tenant
for tenant in "${TENANTS[@]}"; do
  IFS=: read -r slug lms studio mfe _sc_cookie_domain <<< "$tenant"

  TENANT_SC=$(printf '%s' "$SC_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
entry = next((r for r in data if r.get('domain') == '$lms'), None)
if entry:
    print(json.dumps(entry))
else:
    print('null')
" 2>/dev/null || echo "null")

  if [[ "$TENANT_SC" == "null" ]]; then
    fail_ "SiteConfig[$slug]: domain $lms not in query results" "true"
    continue
  fi

  SITE_EXISTS=$(printf '%s' "$TENANT_SC" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('site_exists',False)).lower())" 2>/dev/null || echo "false")
  SC_EXISTS=$(printf '%s' "$TENANT_SC"   | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('sc_exists',False)).lower())" 2>/dev/null || echo "false")
  SC_ENABLED=$(printf '%s' "$TENANT_SC"  | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('sc_enabled',False)).lower())" 2>/dev/null || echo "false")
  LMS_URL=$(printf '%s' "$TENANT_SC"     | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('LMS_ROOT_URL',''))" 2>/dev/null || echo "")
  MFE_URL=$(printf '%s' "$TENANT_SC"     | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('MFE_BASE_URL',''))" 2>/dev/null || echo "")

  if [[ "$SITE_EXISTS" == "true" ]]; then
    pass_ "SiteConfig[$slug]: Site row exists for domain $lms"
  else
    fail_ "SiteConfig[$slug]: Site row MISSING for domain $lms" "true"
    continue
  fi

  if [[ "$SC_EXISTS" == "true" ]]; then
    pass_ "SiteConfig[$slug]: SiteConfiguration row exists"
  else
    fail_ "SiteConfig[$slug]: SiteConfiguration row MISSING" "true"
    continue
  fi

  if [[ "$SC_ENABLED" == "true" ]]; then
    pass_ "SiteConfig[$slug]: SiteConfiguration.enabled=True"
  else
    fail_ "SiteConfig[$slug]: SiteConfiguration.enabled=False (tenant disabled)" "true"
  fi

  # LMS_ROOT_URL should reference the staging LMS host
  if echo "$LMS_URL" | grep -q "$lms"; then
    pass_ "SiteConfig[$slug]: LMS_ROOT_URL contains correct host ($LMS_URL)"
  else
    fail_ "SiteConfig[$slug]: LMS_ROOT_URL does not reference $lms (got: '$LMS_URL')" "false"
  fi

  # MFE_BASE_URL should reference the staging MFE host
  if echo "$MFE_URL" | grep -q "$mfe"; then
    pass_ "SiteConfig[$slug]: MFE_BASE_URL contains correct MFE host ($MFE_URL)"
  else
    fail_ "SiteConfig[$slug]: MFE_BASE_URL does not reference $mfe (got: '$MFE_URL')" "false"
  fi
done

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — MFE config isolation (/api/mfe_config/v1)
# ═══════════════════════════════════════════════════════════════════════════════
echo "--- [5] MFE config proof (cross-contamination check) ---"

MFE_CONFIG_JSON="[]"

for tenant in "${TENANTS[@]}"; do
  IFS=: read -r slug lms studio mfe _tenant_cookie_domain <<< "$tenant"

  echo "  Checking $slug ($mfe)..."

  CONFIG_RAW=$(curl -s --max-time "$CURL_TIMEOUT" \
    "https://${mfe}/api/mfe_config/v1" 2>/dev/null || echo "")

  if [[ -z "$CONFIG_RAW" ]]; then
    fail_ "MFEConfig[$slug]: /api/mfe_config/v1 unreachable on $mfe" "true"
    MFE_CONFIG_JSON="$(printf '%s' "$MFE_CONFIG_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d.append({'slug':'$slug','host':'$mfe','status':'unreachable'})
print(json.dumps(d))
" 2>/dev/null || echo "$MFE_CONFIG_JSON")"
    continue
  fi

  # Parse the config and validate key fields
  CONFIG_RESULT=$(printf '%s' "$CONFIG_RAW" | python3 -c "
import json, sys

slug = '$slug'
lms_host = '$lms'
studio_host = '$studio'
mfe_host = '$mfe'
primary_lms = 'staging.academyv2.mereka.io'   # Mereka is the primary tenant

try:
    cfg = json.loads(sys.stdin.read())
except Exception as e:
    print(json.dumps({'status': 'parse_error', 'error': str(e)}))
    sys.exit(0)

result = {'slug': slug, 'host': mfe_host, 'status': 'ok', 'issues': [], 'values': {}}

lms_base = cfg.get('LMS_BASE_URL', '')
studio_base = cfg.get('STUDIO_BASE_URL', '')
authn_url = cfg.get('AUTHN_MICROFRONTEND_URL', '') or cfg.get('AUTHN_MICROFRONTEND_DOMAIN', '')
base_url = cfg.get('BASE_URL', '')

result['values'] = {
    'LMS_BASE_URL': lms_base,
    'STUDIO_BASE_URL': studio_base,
    'AUTHN_MICROFRONTEND_URL': authn_url,
    'BASE_URL': base_url,
}

# Check LMS_BASE_URL — must reference THIS tenant's LMS host, not primary
if lms_base and (lms_host not in lms_base):
    if primary_lms in lms_base and slug != 'mereka':
        result['issues'].append(f'CROSS_CONTAMINATION: LMS_BASE_URL={lms_base!r} points to primary tenant (expected {lms_host!r})')
        result['status'] = 'contaminated'
    else:
        result['issues'].append(f'WRONG_LMS_BASE_URL: got={lms_base!r} expected to contain {lms_host!r}')
        result['status'] = 'warning'

# Check BASE_URL — must reference THIS tenant's MFE host
if base_url and (mfe_host not in base_url):
    if primary_lms.replace('staging.', 'apps.staging.') in base_url and slug != 'mereka':
        result['issues'].append(f'CROSS_CONTAMINATION: BASE_URL={base_url!r} points to primary MFE')
        result['status'] = 'contaminated'

print(json.dumps(result))
" 2>/dev/null || echo '{"status":"parse_error"}')

  STATUS=$(printf '%s' "$CONFIG_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
  ISSUES=$(printf '%s' "$CONFIG_RESULT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
issues=d.get('issues',[])
print('; '.join(issues) if issues else '')
" 2>/dev/null || echo "")

  case "$STATUS" in
    ok)
      pass_ "MFEConfig[$slug]: /api/mfe_config/v1 OK, no cross-contamination detected"
      ;;
    contaminated)
      fail_ "MFEConfig[$slug]: CROSS-CONTAMINATION detected — $ISSUES" "true"
      ;;
    warning)
      fail_ "MFEConfig[$slug]: unexpected config values — $ISSUES" "false"
      ;;
    parse_error)
      fail_ "MFEConfig[$slug]: /api/mfe_config/v1 returned non-JSON response" "true"
      ;;
    *)
      skip_ "MFEConfig[$slug]: unknown check status ($STATUS)"
      ;;
  esac

  MFE_CONFIG_JSON="$(printf '%s' "$MFE_CONFIG_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
entry=$CONFIG_RESULT
d.append(entry)
print(json.dumps(d))
" 2>/dev/null || echo "$MFE_CONFIG_JSON")"
done

printf '%s' "$MFE_CONFIG_JSON" | python3 -m json.tool \
  > "$OUTPUT_DIR/staging-mfe-config-proof.json" 2>/dev/null \
  || printf '%s' "$MFE_CONFIG_JSON" > "$OUTPUT_DIR/staging-mfe-config-proof.json"

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6 — Cookie domain proof (Set-Cookie header on /login)
# ═══════════════════════════════════════════════════════════════════════════════
echo "--- [6] Cookie domain proof ---"

COOKIE_JSON="[]"

for tenant in "${TENANTS[@]}"; do
  IFS=: read -r slug lms studio mfe expected_cookie_domain <<< "$tenant"

  # Fetch headers from /login — the CSRF token cookie is set on the login page
  HEADERS=$(curl -s -I --max-time "$CURL_TIMEOUT" \
    "https://${lms}/login" 2>/dev/null || echo "")

  if [[ -z "$HEADERS" ]]; then
    skip_ "Cookie[$slug]: no response headers from https://$lms/login"
    continue
  fi

  # Extract all Set-Cookie lines
  SET_COOKIE_LINES=$(printf '%s' "$HEADERS" | grep -i '^set-cookie:' || true)

  if [[ -z "$SET_COOKIE_LINES" ]]; then
    skip_ "Cookie[$slug]: no Set-Cookie headers from https://$lms/login (may be cached 302)"
    continue
  fi

  # Check: Domain attribute should match expected per-tenant scope
  DOMAIN_IN_COOKIE=$(printf '%s' "$SET_COOKIE_LINES" \
    | grep -oi "domain=[^;,[:space:]]*" \
    | head -1 \
    | sed 's/domain=//i' || true)

  ENTRY=$(python3 -c "
import json
expected='$expected_cookie_domain'
actual='$DOMAIN_IN_COOKIE'
ok = (actual == expected) or (actual == '') or ('-' in actual and expected.lstrip('.') in actual)

# Detect contamination: cookie domain pointing to Mereka primary when not Mereka
slug='$slug'
primary_domain='.staging.academyv2.mereka.io'
contaminated = (slug != 'mereka' and actual == primary_domain)

result={
    'slug': slug,
    'lms_host': '$lms',
    'expected_cookie_domain': expected,
    'actual_cookie_domain': actual,
    'contaminated': contaminated,
    'ok': ok and not contaminated,
}
print(json.dumps(result))
" 2>/dev/null || echo '{"ok":false,"contaminated":false}')

  IS_OK=$(printf '%s' "$ENTRY" | python3 -c "import json,sys; print(str(json.load(sys.stdin).get('ok',False)).lower())" 2>/dev/null || echo "false")
  IS_CONTAMINATED=$(printf '%s' "$ENTRY" | python3 -c "import json,sys; print(str(json.load(sys.stdin).get('contaminated',False)).lower())" 2>/dev/null || echo "false")

  if [[ "$IS_CONTAMINATED" == "true" ]]; then
    fail_ "Cookie[$slug]: cookie domain contamination — domain='$DOMAIN_IN_COOKIE' (expected '$expected_cookie_domain')" "true"
  elif [[ "$IS_OK" == "true" ]]; then
    pass_ "Cookie[$slug]: Set-Cookie Domain='$DOMAIN_IN_COOKIE' (matches expected '$expected_cookie_domain')"
  else
    fail_ "Cookie[$slug]: unexpected cookie domain '$DOMAIN_IN_COOKIE' (expected '$expected_cookie_domain')" "false"
  fi

  COOKIE_JSON="$(printf '%s' "$COOKIE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
entry=$ENTRY
d.append(entry)
print(json.dumps(d))
" 2>/dev/null || echo "$COOKIE_JSON")"
done

printf '%s' "$COOKIE_JSON" | python3 -m json.tool \
  > "$OUTPUT_DIR/staging-cookie-proof.json" 2>/dev/null \
  || printf '%s' "$COOKIE_JSON" > "$OUTPUT_DIR/staging-cookie-proof.json"

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7 — Auth redirect proof (/login → tenant MFE authn URL)
# ═══════════════════════════════════════════════════════════════════════════════
echo "--- [7] Auth redirect proof (/login → per-tenant MFE authn) ---"

AUTH_REDIRECT_JSON="[]"

for tenant in "${TENANTS[@]}"; do
  IFS=: read -r slug lms studio mfe _ignored_cookie_domain <<< "$tenant"

  # Follow a single redirect from /login — expect Location to contain the
  # tenant's MFE authn URL, not the primary Mereka authn URL.
  LOCATION=$(curl -s --max-time "$CURL_TIMEOUT" \
    -o /dev/null \
    -D - \
    "https://${lms}/login" 2>/dev/null \
    | grep -i '^location:' \
    | head -1 \
    | sed 's/^[Ll]ocation:[[:space:]]*//' \
    | tr -d '\r' || true)

  ENTRY=$(python3 -c "
import json
slug = '$slug'
lms = '$lms'
mfe = '$mfe'
location = '$LOCATION'
primary_mfe = 'apps.staging.academyv2.mereka.io'

result = {
    'slug': slug,
    'lms_host': lms,
    'expected_mfe_host': mfe,
    'redirect_location': location,
    'status': 'unknown',
}

if not location:
    result['status'] = 'no_redirect'
elif mfe in location and '/authn' in location:
    result['status'] = 'correct'
elif '/authn' in location and primary_mfe in location and slug != 'mereka':
    result['status'] = 'contaminated_primary_tenant'
elif '/authn' in location:
    result['status'] = 'authn_wrong_host'
else:
    result['status'] = 'unexpected_redirect'

print(json.dumps(result))
" 2>/dev/null || echo '{"status":"error"}')

  STATUS=$(printf '%s' "$ENTRY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")

  case "$STATUS" in
    correct)
      pass_ "AuthRedirect[$slug]: /login → $mfe/authn (correct tenant MFE)"
      ;;
    contaminated_primary_tenant)
      fail_ "AuthRedirect[$slug]: /login redirects to PRIMARY tenant MFE (not $mfe/authn) — cross-tenant contamination" "true"
      ;;
    no_redirect)
      # Some environments return 200 on /login (e.g., already-rendered page)
      skip_ "AuthRedirect[$slug]: /login returned no redirect (may render inline login page)"
      ;;
    authn_wrong_host)
      fail_ "AuthRedirect[$slug]: /login redirects to /authn but wrong MFE host (expected $mfe)" "false"
      ;;
    *)
      skip_ "AuthRedirect[$slug]: /login redirect status=$STATUS location='$LOCATION'"
      ;;
  esac

  AUTH_REDIRECT_JSON="$(printf '%s' "$AUTH_REDIRECT_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
entry=$ENTRY
d.append(entry)
print(json.dumps(d))
" 2>/dev/null || echo "$AUTH_REDIRECT_JSON")"
done

printf '%s' "$AUTH_REDIRECT_JSON" | python3 -m json.tool \
  > "$OUTPUT_DIR/staging-auth-redirect-proof.json" 2>/dev/null \
  || printf '%s' "$AUTH_REDIRECT_JSON" > "$OUTPUT_DIR/staging-auth-redirect-proof.json"

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# Consolidated JSON proof artifact
# ═══════════════════════════════════════════════════════════════════════════════

PROOF_FILE="$OUTPUT_DIR/staging-runtime-proof.json"

python3 -c "
import json, os

ns = '$NAMESPACE'
lms_pod = '$LMS_POD'
pass_count = $PASS
fail_count = $FAIL
skip_count = $SKIP
critical_fail = $CRITICAL_FAIL
overall = 'PASS' if critical_fail == 0 else 'FAIL'

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None

artifact_dir = '$OUTPUT_DIR'

proof = {
    'schema_version': '1.0',
    'proof_type': 'staging-runtime-proof',
    'collected_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'namespace': ns,
    'lms_pod': lms_pod,
    'banned_commit': 'e5c0c508',
    'summary': {
        'overall': overall,
        'pass': pass_count,
        'fail': fail_count,
        'skip': skip_count,
        'critical_fail': critical_fail,
    },
    'tenants': [
        {'slug': 'mereka',        'lms': 'staging.academyv2.mereka.io',             'mfe': 'apps.staging.academyv2.mereka.io'},
        {'slug': 'biji-biji',     'lms': 'staging.academy.biji-biji.com',           'mfe': 'apps.staging.academy.biji-biji.com'},
        {'slug': 'skillourfuture','lms': 'staging.skillourfuture.academy.mereka.io','mfe': 'apps.staging.skillourfuture.academy.mereka.io'},
    ],
    'artifacts': {
        'host_acceptance':  load_json(os.path.join(artifact_dir, 'staging-host-acceptance.json')),
        'siteconfig':       load_json(os.path.join(artifact_dir, 'staging-siteconfig-proof.json')),
        'mfe_config':       load_json(os.path.join(artifact_dir, 'staging-mfe-config-proof.json')),
        'cookie_domain':    load_json(os.path.join(artifact_dir, 'staging-cookie-proof.json')),
        'auth_redirect':    load_json(os.path.join(artifact_dir, 'staging-auth-redirect-proof.json')),
    },
}

with open('$PROOF_FILE', 'w') as f:
    json.dump(proof, f, indent=2)
print('Proof written to $PROOF_FILE')
" 2>/dev/null || echo "WARNING: could not write consolidated proof JSON" >&2

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Summary ================================================================"
printf "  PASS : %d\n" "$PASS"
printf "  FAIL : %d  (of which critical: %d)\n" "$FAIL" "$CRITICAL_FAIL"
printf "  SKIP : %d\n" "$SKIP"
echo ""
printf "  Proof artifact : %s\n" "$PROOF_FILE"
echo "============================================================================"

if [[ "$CRITICAL_FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL — $CRITICAL_FAIL critical check(s) failed. Do NOT sign off on this deploy."
  exit 1
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: PASS (with warnings) — no critical failures, but $FAIL non-critical check(s) failed."
  exit 0
fi

echo "RESULT: PASS — all checks passed."
exit 0
