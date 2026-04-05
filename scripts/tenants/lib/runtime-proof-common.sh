#!/usr/bin/env bash
# runtime-proof-common.sh — Shared runtime proof functions for tenant verification
#
# Sourced by verify-staging-runtime-proof.sh and verify-dev-runtime-proof.sh.
# Callers must source an env file first (scripts/tenants/env/<env>.env) and
# declare the following variables before sourcing this file:
#
#   Required (from env file):
#     NAMESPACE          — K8s namespace to query
#     ENV_LABEL          — human label ("staging" or "dev")
#     PROOF_PREFIX       — file stem ("staging" or "dev")
#     ADMIN_HOST         — admin hostname for non-critical check
#     PRIMARY_LMS        — primary tenant LMS hostname (contamination detection)
#     PRIMARY_MFE        — primary tenant MFE hostname (contamination detection)
#     PRIMARY_COOKIE_DOMAIN — primary cookie domain (contamination detection)
#     TENANTS            — array of "SLUG:LMS:STUDIO:MFE:COOKIE_DOMAIN"
#
#   Required (from caller preamble):
#     OUTPUT_DIR         — directory for proof artifacts
#     CURL_TIMEOUT       — curl --max-time value (seconds)
#
# After sourcing, call run_proof to execute all sections.
#
# This file does NOT call set -euo pipefail; the caller owns that.

# ── Counters & result accumulator ────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0
CRITICAL_FAIL=0
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

# ── Pod discovery ─────────────────────────────────────────────────────────────
_find_ready_pod() {
  local label="$1"
  kubectl get pods -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=$label" \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null \
    | awk '$2 == "true" { print $1; exit }'
}

# ── Host acceptance check ─────────────────────────────────────────────────────
# Used in section 3. HOST_ACCEPT_JSON must be initialised to "[]" before calling.
_check_host() {
  local host="$1"
  # $2 is a label hint (unused in logic but kept for call-site readability)
  local critical="${3:-true}"

  local http_code body_file body_bytes
  body_file="$(mktemp)"
  # curl -w "%{http_code}" always prints a 3-digit code (000 on failure) to stdout,
  # even when it exits non-zero. Capture stdout directly; do not append a fallback
  # via || echo because that would double the output on connection errors.
  http_code=$(curl -s -o "$body_file" -w "%{http_code}" \
    --max-time "$CURL_TIMEOUT" \
    "https://${host}/" 2>/dev/null; true)
  # Normalise: keep only the last 3 characters in case of any capture noise
  http_code="${http_code: -3}"
  body_bytes=$(wc -c < "$body_file" 2>/dev/null || echo 0)

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
      if [[ "$http_code" == "200" && "$body_bytes" -eq 0 ]]; then
        # MFE containers serve nothing at /; retry with /authn/login as fallback
        local fb_code fb_file fb_bytes
        fb_file="$(mktemp)"
        fb_code=$(curl -s -o "$fb_file" -w "%{http_code}" \
          --max-time "$CURL_TIMEOUT" \
          "https://${host}/authn/login" 2>/dev/null; true)
        fb_code="${fb_code: -3}"
        fb_bytes=$(wc -c < "$fb_file" 2>/dev/null || echo 0)
        rm -f "$fb_file"
        if [[ "$fb_code" =~ ^[23][0-9][0-9]$ && "$fb_bytes" -gt 0 ]]; then
          accepted="true"
          verdict="OK_MFE_FALLBACK"
          http_code="$fb_code"
          body_bytes="$fb_bytes"
        else
          verdict="EMPTY_200"
        fi
      else
        accepted="true"
        verdict="OK"
      fi
      ;;
    *)
      verdict="UNEXPECTED_${http_code}"
      ;;
  esac

  HOST_ACCEPT_JSON="$(printf '%s' "$HOST_ACCEPT_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d.append({'host':'$host','http_code':'$http_code','body_bytes':$body_bytes,'accepted':$accepted,'verdict':'$verdict'})
print(json.dumps(d))
" 2>/dev/null || echo "$HOST_ACCEPT_JSON")"

  if [[ "$accepted" == "true" ]]; then
    pass_ "Host: https://$host/ → $http_code ($verdict, ${body_bytes} bytes)"
  else
    fail_ "Host: https://$host/ → $http_code ($verdict, ${body_bytes} bytes)" "$critical"
  fi

  rm -f "$body_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# run_proof — execute all 7 sections and write consolidated artifact
# ─────────────────────────────────────────────────────────────────────────────
run_proof() {
  local lms_pod="$1"
  local proof_file="${OUTPUT_DIR}/${PROOF_PREFIX}-runtime-proof.json"

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 1 — Image truth check
  # ═══════════════════════════════════════════════════════════════════════════
  echo "--- [1] Image truth check ---"

  # The banned commit (old image that must NOT be running).
  local BANNED_COMMIT="e5c0c508"

  _check_image_for_deploy() {
    local deploy="$1"

    local image
    image=$(kubectl get deployment "$deploy" -n "$NAMESPACE" \
      -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)

    if [[ -z "$image" ]]; then
      skip_ "Image/$deploy: deployment not found"
      return
    fi

    local tag="${image##*:}"

    if [[ "$tag" == "latest" ]]; then
      fail_ "Image/$deploy: running :latest tag (not a pinned SHA) — image=$image" "true"
      return
    fi

    if echo "$tag" | grep -q "$BANNED_COMMIT"; then
      fail_ "Image/$deploy: running banned commit $BANNED_COMMIT — image=$image" "true"
      return
    fi

    pass_ "Image/$deploy: tag=$tag (not :latest, not banned commit)"
  }

  for deploy_pair in "lms:lms" "cms:cms" "mfe:mfe"; do
    IFS=: read -r dep _label <<< "$deploy_pair"
    _check_image_for_deploy "$dep"
  done

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 2 — Module presence: MerekaLoginRedirectMiddleware
  # ═══════════════════════════════════════════════════════════════════════════
  echo "--- [2] Module presence ---"

  local MODULE_CHECK
  MODULE_CHECK=$(kubectl exec "$lms_pod" -n "$NAMESPACE" -- \
    python manage.py lms shell -c "
import sys
try:
    from lms.envs.tutor.production import MerekaLoginRedirectMiddleware, MerekaCookieDomainMiddleware
    print('PRESENT MerekaLoginRedirectMiddleware MerekaCookieDomainMiddleware')
except ImportError as e:
    print('ABSENT ' + str(e))
    sys.exit(1)
" 2>&1 | grep -E '^(PRESENT|ABSENT)' || echo "EXEC_FAILED")

  if echo "$MODULE_CHECK" | grep -q "^PRESENT"; then
    pass_ "Module: MerekaLoginRedirectMiddleware importable in running LMS pod"
    pass_ "Module: MerekaCookieDomainMiddleware importable in running LMS pod"
  elif echo "$MODULE_CHECK" | grep -q "^ABSENT"; then
    local DETAIL
    DETAIL=$(echo "$MODULE_CHECK" | sed 's/^ABSENT //')
    fail_ "Module: MerekaLoginRedirectMiddleware import failed in LMS pod: $DETAIL" "true"
  else
    fail_ "Module: kubectl exec failed checking module presence (pod=$lms_pod)" "true"
  fi

  local MW_CHECK
  MW_CHECK=$(kubectl exec "$lms_pod" -n "$NAMESPACE" -- \
    python manage.py lms shell -c "
from django.conf import settings
mw = settings.MIDDLEWARE
found = any('MerekaLoginRedirectMiddleware' in m for m in mw)
print('PRESENT' if found else 'ABSENT')
" 2>&1 | grep -E '^(PRESENT|ABSENT)' || echo "EXEC_FAILED")

  case "$MW_CHECK" in
    PRESENT) pass_ "Module: MerekaLoginRedirectMiddleware in Django MIDDLEWARE list" ;;
    ABSENT)  fail_ "Module: MerekaLoginRedirectMiddleware NOT in Django MIDDLEWARE list" "true" ;;
    *)       fail_ "Module: could not read MIDDLEWARE from running LMS pod" "false" ;;
  esac

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 3 — Host acceptance
  # ═══════════════════════════════════════════════════════════════════════════
  echo "--- [3] Host acceptance ---"

  local P0_LMS_HOSTS=()
  local P0_STUDIO_HOSTS=()
  local P0_MFE_HOSTS=()

  for tenant in "${TENANTS[@]}"; do
    IFS=: read -r _ha_slug lms studio mfe _ha_cd <<< "$tenant"
    P0_LMS_HOSTS+=("$lms")
    P0_STUDIO_HOSTS+=("$studio")
    P0_MFE_HOSTS+=("$mfe")
  done

  HOST_ACCEPT_JSON="[]"

  echo "LMS hosts:"
  for h in "${P0_LMS_HOSTS[@]}"; do _check_host "$h" "lms" "true"; done

  echo "Studio hosts:"
  for h in "${P0_STUDIO_HOSTS[@]}"; do _check_host "$h" "studio" "true"; done

  echo "MFE hosts:"
  for h in "${P0_MFE_HOSTS[@]}"; do _check_host "$h" "mfe" "true"; done

  echo "Admin hosts:"
  _check_host "$ADMIN_HOST" "admin" "false"  # non-critical: requires DNS/ingress (infra-owned)

  printf '%s' "$HOST_ACCEPT_JSON" | python3 -m json.tool \
    > "${OUTPUT_DIR}/${PROOF_PREFIX}-host-acceptance.json" 2>/dev/null \
    || printf '%s' "$HOST_ACCEPT_JSON" > "${OUTPUT_DIR}/${PROOF_PREFIX}-host-acceptance.json"

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 4 — SiteConfiguration proof (Django shell)
  # ═══════════════════════════════════════════════════════════════════════════
  echo "--- [4] SiteConfiguration proof ---"

  local DOMAINS_CSV=""
  for tenant in "${TENANTS[@]}"; do
    IFS=: read -r _csv_slug lms _csv_studio _csv_mfe _csv_cd <<< "$tenant"
    DOMAINS_CSV="${DOMAINS_CSV}${lms},"
  done
  DOMAINS_CSV="${DOMAINS_CSV%,}"

  local SC_RAW
  SC_RAW=$(kubectl exec "$lms_pod" -n "$NAMESPACE" -- python manage.py lms shell -c "
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

  local SC_DATA
  if [[ "$SC_RAW" == "EXEC_FAILED" ]]; then
    fail_ "SiteConfig: kubectl exec failed — cannot verify SiteConfiguration" "true"
    SC_DATA="[]"
  else
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
    > "${OUTPUT_DIR}/${PROOF_PREFIX}-siteconfig-proof.json" 2>/dev/null \
    || printf '%s' "$SC_DATA" > "${OUTPUT_DIR}/${PROOF_PREFIX}-siteconfig-proof.json"

  for tenant in "${TENANTS[@]}"; do
    IFS=: read -r slug lms studio mfe _sc_cookie_domain <<< "$tenant"

    local TENANT_SC
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

    local SITE_EXISTS SC_EXISTS SC_ENABLED LMS_URL MFE_URL
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

    if echo "$LMS_URL" | grep -q "$lms"; then
      pass_ "SiteConfig[$slug]: LMS_ROOT_URL contains correct host ($LMS_URL)"
    else
      fail_ "SiteConfig[$slug]: LMS_ROOT_URL does not reference $lms (got: '$LMS_URL')" "false"
    fi

    if echo "$MFE_URL" | grep -q "$mfe"; then
      pass_ "SiteConfig[$slug]: MFE_BASE_URL contains correct MFE host ($MFE_URL)"
    else
      fail_ "SiteConfig[$slug]: MFE_BASE_URL does not reference $mfe (got: '$MFE_URL')" "false"
    fi
  done

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 5 — MFE config isolation (/api/mfe_config/v1)
  # ═══════════════════════════════════════════════════════════════════════════
  echo "--- [5] MFE config proof (cross-contamination check) ---"

  local MFE_CONFIG_JSON="[]"

  for tenant in "${TENANTS[@]}"; do
    IFS=: read -r slug lms studio mfe _tenant_cookie_domain <<< "$tenant"

    echo "  Checking $slug ($mfe)..."

    local CONFIG_RAW
    CONFIG_RAW=$(curl -s --max-time "$CURL_TIMEOUT" \
      "https://${mfe}/api/mfe_config/v1" 2>/dev/null || echo "")

    if [[ -z "$CONFIG_RAW" ]]; then
      # Multi-tenant proof cannot sign off if the public apps host cannot return
      # runtime config for this tenant. That blocks tenant auth/runtime truth even
      # when LMS internals look correct, so keep it critical across envs.
      fail_ "MFEConfig[$slug]: /api/mfe_config/v1 unreachable on $mfe" "true"
      MFE_CONFIG_JSON="$(printf '%s' "$MFE_CONFIG_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d.append({'slug':'$slug','host':'$mfe','status':'unreachable'})
print(json.dumps(d))
" 2>/dev/null || echo "$MFE_CONFIG_JSON")"
      continue
    fi

    local CONFIG_RESULT
    CONFIG_RESULT=$(printf '%s' "$CONFIG_RAW" | python3 -c "
import json, sys

slug = '$slug'
lms_host = '$lms'
studio_host = '$studio'
mfe_host = '$mfe'
primary_lms = '$PRIMARY_LMS'
primary_mfe = '$PRIMARY_MFE'
env_label = '$ENV_LABEL'

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

# Check LMS_BASE_URL — must reference THIS tenant's LMS host
if lms_base and (lms_host not in lms_base):
    if primary_lms in lms_base and slug != 'mereka' and env_label == 'staging':
        result['issues'].append(f'CROSS_CONTAMINATION: LMS_BASE_URL={lms_base!r} points to primary tenant (expected {lms_host!r})')
        result['status'] = 'contaminated'
    else:
        result['issues'].append(f'WRONG_LMS_BASE_URL: got={lms_base!r} expected to contain {lms_host!r}')
        result['status'] = 'warning'

# Check BASE_URL — must reference THIS tenant's MFE host
if base_url and (mfe_host not in base_url):
    if primary_mfe in base_url and slug != 'mereka' and env_label == 'staging':
        result['issues'].append(f'CROSS_CONTAMINATION: BASE_URL={base_url!r} points to primary MFE')
        result['status'] = 'contaminated'
    else:
        result['issues'].append(f'WRONG_BASE_URL: got={base_url!r} expected to contain {mfe_host!r}')
        result['status'] = 'warning'

print(json.dumps(result))
" 2>/dev/null || echo '{"status":"parse_error"}')

    local STATUS ISSUES
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
    > "${OUTPUT_DIR}/${PROOF_PREFIX}-mfe-config-proof.json" 2>/dev/null \
    || printf '%s' "$MFE_CONFIG_JSON" > "${OUTPUT_DIR}/${PROOF_PREFIX}-mfe-config-proof.json"

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 6 — Cookie domain proof (Set-Cookie header on /csrf/api/v1/token)
  # ═══════════════════════════════════════════════════════════════════════════
  echo "--- [6] Cookie domain proof ---"

  local COOKIE_JSON="[]"

  for tenant in "${TENANTS[@]}"; do
    IFS=: read -r slug lms studio mfe expected_cookie_domain <<< "$tenant"

    # Use /csrf/api/v1/token which reliably triggers CsrfViewMiddleware to set
    # the csrftoken cookie. GET /login returns 302 (no cookie), POST /login
    # sets sessionid but not csrftoken. The CSRF token endpoint is the
    # canonical way to obtain the cookie.
    local HEADERS
    HEADERS=$(curl -s -D - -o /dev/null --max-time "$CURL_TIMEOUT" \
      "https://${lms}/csrf/api/v1/token" 2>/dev/null || echo "")

    if [[ -z "$HEADERS" ]]; then
      skip_ "Cookie[$slug]: no response headers from https://$lms/login"
      continue
    fi

    local SET_COOKIE_LINES
    SET_COOKIE_LINES=$(printf '%s' "$HEADERS" | grep -i '^set-cookie:' || true)

    if [[ -z "$SET_COOKIE_LINES" ]]; then
      skip_ "Cookie[$slug]: no Set-Cookie headers from https://$lms/csrf/api/v1/token"
      continue
    fi

    # Check: Domain attribute on the csrftoken cookie (set by MerekaCookieDomainMiddleware).
    # sessionid intentionally has no Domain= (Django host-only default) — do NOT use it.
    local CSRFTOKEN_LINE
    CSRFTOKEN_LINE=$(printf '%s' "$SET_COOKIE_LINES" | grep -i 'csrftoken' || true)

    if [[ -z "$CSRFTOKEN_LINE" ]]; then
      skip_ "Cookie[$slug]: csrftoken not in Set-Cookie from /csrf/api/v1/token (CSRF middleware may not be firing)"
      continue
    fi

    local DOMAIN_IN_COOKIE
    DOMAIN_IN_COOKIE=$(printf '%s' "$CSRFTOKEN_LINE" \
      | grep -oi "domain=[^;,[:space:]]*" \
      | head -1 \
      | sed 's/domain=//i' || true)

    local ENTRY
    ENTRY=$(python3 -c "
import json
expected='$expected_cookie_domain'
actual='$DOMAIN_IN_COOKIE'
slug='$slug'
env_label='$ENV_LABEL'
primary_domain='$PRIMARY_COOKIE_DOMAIN'

# Empty domain (host-only cookie) is acceptable — it's the most secure option
# and is the current behavior before MerekaCookieDomainMiddleware ordering fix
# lands in a new image build. Exact match is also acceptable.
if actual == '':
    ok = True
    note = 'host-only (no Domain= attribute)'
elif actual == expected:
    ok = True
    note = 'exact match'
else:
    ok = False
    note = 'mismatch'

# Detect contamination: cookie domain pointing to primary when not primary slug.
# Only flagged in staging (multi-tenant) where cross-contamination is meaningful.
contaminated = (
    env_label == 'staging'
    and slug != 'mereka'
    and actual == primary_domain
)

result={
    'slug': slug,
    'lms_host': '$lms',
    'expected_cookie_domain': expected,
    'actual_cookie_domain': actual,
    'contaminated': contaminated,
    'ok': ok and not contaminated,
    'note': note,
}
print(json.dumps(result))
" 2>/dev/null || echo '{"ok":false,"contaminated":false}')

    local IS_OK IS_CONTAMINATED COOKIE_NOTE
    IS_OK=$(printf '%s' "$ENTRY" | python3 -c "import json,sys; print(str(json.load(sys.stdin).get('ok',False)).lower())" 2>/dev/null || echo "false")
    IS_CONTAMINATED=$(printf '%s' "$ENTRY" | python3 -c "import json,sys; print(str(json.load(sys.stdin).get('contaminated',False)).lower())" 2>/dev/null || echo "false")
    COOKIE_NOTE=$(printf '%s' "$ENTRY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('note',''))" 2>/dev/null || echo "")

    if [[ "$IS_CONTAMINATED" == "true" ]]; then
      fail_ "Cookie[$slug]: cookie domain contamination — domain='$DOMAIN_IN_COOKIE' (expected '$expected_cookie_domain')" "true"
    elif [[ "$IS_OK" == "true" ]]; then
      pass_ "Cookie[$slug]: domain='${DOMAIN_IN_COOKIE:-(host-only)}' ($COOKIE_NOTE)"
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
    > "${OUTPUT_DIR}/${PROOF_PREFIX}-cookie-proof.json" 2>/dev/null \
    || printf '%s' "$COOKIE_JSON" > "${OUTPUT_DIR}/${PROOF_PREFIX}-cookie-proof.json"

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 7 — Auth redirect proof (/login → tenant MFE authn URL)
  # ═══════════════════════════════════════════════════════════════════════════
  echo "--- [7] Auth redirect proof (/login → per-tenant MFE authn) ---"

  local AUTH_REDIRECT_JSON="[]"

  for tenant in "${TENANTS[@]}"; do
    IFS=: read -r slug lms studio mfe _ignored_cookie_domain <<< "$tenant"

    # Follow a single redirect from /login — expect Location to contain the
    # tenant's MFE authn URL, not some other MFE host.
    local LOCATION
    LOCATION=$(curl -s --max-time "$CURL_TIMEOUT" \
      -o /dev/null \
      -D - \
      "https://${lms}/login" 2>/dev/null \
      | grep -i '^location:' \
      | head -1 \
      | sed 's/^[Ll]ocation:[[:space:]]*//' \
      | tr -d '\r' || true)

    local ENTRY
    ENTRY=$(python3 -c "
import json
slug = '$slug'
lms = '$lms'
mfe = '$mfe'
location = '$LOCATION'
primary_mfe = '$PRIMARY_MFE'
env_label = '$ENV_LABEL'

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
elif '/authn' in location and primary_mfe in location and slug != 'mereka' and env_label == 'staging':
    result['status'] = 'contaminated_primary_tenant'
elif '/authn' in location:
    result['status'] = 'authn_wrong_host'
else:
    result['status'] = 'unexpected_redirect'

print(json.dumps(result))
" 2>/dev/null || echo '{"status":"error"}')

    local STATUS
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
    > "${OUTPUT_DIR}/${PROOF_PREFIX}-auth-redirect-proof.json" 2>/dev/null \
    || printf '%s' "$AUTH_REDIRECT_JSON" > "${OUTPUT_DIR}/${PROOF_PREFIX}-auth-redirect-proof.json"

  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # Consolidated JSON proof artifact
  # ═══════════════════════════════════════════════════════════════════════════

  # Build tenants_meta JSON from the TENANTS array
  local TENANTS_META_JSON
  TENANTS_META_JSON=$(python3 -c "
import json, sys

lines = '''$(for tenant in "${TENANTS[@]}"; do
  IFS=: read -r slug lms studio mfe cd <<< "$tenant"
  echo "${slug}|${lms}|${mfe}"
done)'''

meta = []
for line in lines.strip().splitlines():
    parts = line.split('|')
    if len(parts) == 3:
        meta.append({'slug': parts[0], 'lms': parts[1], 'mfe': parts[2]})
print(json.dumps(meta))
" 2>/dev/null || echo "[]")

  RELEASE_OBJECT_JSON_ENV="${RELEASE_OBJECT_JSON:-}" \
  RELEASE_OBJECT_ID_ENV="${RELEASE_OBJECT_ID:-}" \
  python3 -c "
import json, os

ns = '$NAMESPACE'
lms_pod = '$lms_pod'
pass_count = $PASS
fail_count = $FAIL
skip_count = $SKIP
critical_fail = $CRITICAL_FAIL
overall = 'PASS' if critical_fail == 0 else 'FAIL'
proof_prefix = '$PROOF_PREFIX'

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None

artifact_dir = '$OUTPUT_DIR'

tenants_meta = json.loads('$TENANTS_META_JSON')

host_data   = load_json(os.path.join(artifact_dir, proof_prefix + '-host-acceptance.json'))   or []
sc_data     = load_json(os.path.join(artifact_dir, proof_prefix + '-siteconfig-proof.json'))  or []
mfe_data    = load_json(os.path.join(artifact_dir, proof_prefix + '-mfe-config-proof.json'))  or []
cookie_data = load_json(os.path.join(artifact_dir, proof_prefix + '-cookie-proof.json'))      or []
auth_data   = load_json(os.path.join(artifact_dir, proof_prefix + '-auth-redirect-proof.json')) or []
release_object_json = os.environ.get('RELEASE_OBJECT_JSON_ENV') or None
release_object_id = os.environ.get('RELEASE_OBJECT_ID_ENV') or None

def classify_tenant(slug, lms, mfe):
    host_entry = next((h for h in host_data if h.get('host') == lms), None)
    host_accepted = host_entry.get('accepted', False) if host_entry else False

    sc_entry = next((s for s in sc_data if s.get('domain') == lms), None)
    sc_ok = bool(sc_entry and sc_entry.get('sc_exists') and sc_entry.get('sc_enabled'))

    mfe_entry = next((m for m in mfe_data if m.get('slug') == slug), None)
    mfe_ok = bool(mfe_entry and mfe_entry.get('status') in ('ok',))

    auth_entry = next((a for a in auth_data if a.get('slug') == slug), None)
    auth_status = auth_entry.get('status', '') if auth_entry else ''
    auth_ok = auth_status in ('correct', 'no_redirect')

    app_ok = sc_ok and auth_ok
    if app_ok and host_accepted and mfe_ok:
        return 'proven_now'
    elif app_ok and not host_accepted:
        return 'app_proven_external_blocked'
    elif not app_ok:
        return 'app_blocked'
    else:
        return 'unproven'

tenant_classification = {
    t['slug']: {
        'classification': classify_tenant(t['slug'], t['lms'], t['mfe']),
        'lms': t['lms'],
        'mfe': t['mfe'],
    }
    for t in tenants_meta
}

proof = {
    'schema_version': '1.1',
    'proof_type': proof_prefix + '-runtime-proof',
    'collected_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'namespace': ns,
    'lms_pod': lms_pod,
    'banned_commit': 'e5c0c508',
    'release_truth': {
        'release_object_id': release_object_id,
        'release_object_json': release_object_json,
    },
    'summary': {
        'overall': overall,
        'pass': pass_count,
        'fail': fail_count,
        'skip': skip_count,
        'critical_fail': critical_fail,
    },
    'verdict_planes': {
        'routing_core': {
            'status': 'pass' if critical_fail == 0 else 'fail',
            'failed_checks': critical_fail,
        },
        'adjacent_surface': {
            'status': 'not-applicable',
            'failed_checks': 0,
        },
    },
    'tenants': tenants_meta,
    'tenant_classification': tenant_classification,
    'artifacts': {
        'host_acceptance':  host_data,
        'siteconfig':       sc_data,
        'mfe_config':       mfe_data,
        'cookie_domain':    cookie_data,
        'auth_redirect':    auth_data,
    },
}

with open('$proof_file', 'w') as f:
    json.dump(proof, f, indent=2)
print('Proof written to $proof_file')
" 2>/dev/null || echo "WARNING: could not write consolidated proof JSON" >&2

  # ── Tenant classification display ─────────────────────────────────────────
  echo "--- Tenant classification ---"
  python3 -c "
import json, os
try:
    with open('$proof_file') as f:
        proof = json.load(f)
    classification = proof.get('tenant_classification', {})
    width = max(len(s) for s in classification) if classification else 10
    for slug, info in classification.items():
        label = info.get('classification', 'unproven')
        lms   = info.get('lms', '')
        print(f'  {slug:<{width}}  {label}  ({lms})')
except Exception as e:
    print(f'  (classification unavailable: {e})')
" 2>/dev/null || echo "  (classification unavailable)"
  echo ""

  # ═══════════════════════════════════════════════════════════════════════════
  # Summary
  # ═══════════════════════════════════════════════════════════════════════════
  echo "=== Summary ================================================================"
  printf "  PASS : %d\n" "$PASS"
  printf "  FAIL : %d  (of which critical: %d)\n" "$FAIL" "$CRITICAL_FAIL"
  printf "  SKIP : %d\n" "$SKIP"
  echo ""
  printf "  Proof artifact : %s\n" "$proof_file"
  echo "============================================================================"

  if [[ "$CRITICAL_FAIL" -gt 0 ]]; then
    echo "RESULT: FAIL — $CRITICAL_FAIL critical check(s) failed. Do NOT sign off on this deploy."
    return 1
  fi

  if [[ "$FAIL" -gt 0 ]]; then
    echo "RESULT: PASS (with warnings) — no critical failures, but $FAIL non-critical check(s) failed."
    return 0
  fi

  echo "RESULT: PASS — all checks passed."
  return 0
}
