#!/usr/bin/env bash
# @covers AC-EG-004, AC-EG-007
# @spec: multi-site-domains_spec.md
# tenant-onboarding-evidence.sh — Post-deploy evidence bundle with JSON output
#
# Runs branding smoke, auth smoke, and MFE route checks for a tenant,
# producing both log files and a machine-readable JSON summary under var/.
#
# Usage:
#   ./scripts/qa/tenant-onboarding-evidence.sh --slug <slug> --domain <domain> [--env prod|dev]
#
# Output:
#   var/evidence/tenant-onboarding/<slug>-<YYYYMMDD>/
#     ├── evidence-summary.json   (machine-readable)
#     ├── evidence-summary.md     (human-readable)
#     ├── branding-runtime.log
#     ├── auth-smoke.log
#     ├── mfe-route-smoke.log
#     └── mfe-config-<domain>.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SLUG=""
DOMAIN=""
ENV="prod"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="${2:-}"; shift 2 ;;
    --domain) DOMAIN="${2:-}"; shift 2 ;;
    --env) ENV="${2:-prod}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --slug <slug> --domain <domain> [--env prod|dev]"
      echo ""
      echo "Produces post-deploy evidence bundle with JSON + Markdown summaries."
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SLUG" || -z "$DOMAIN" ]]; then
  echo "ERROR: --slug and --domain are required" >&2
  exit 1
fi

TODAY="$(date +%Y%m%d)"
EVIDENCE_DIR="$REPO_ROOT/var/evidence/tenant-onboarding/${SLUG}-${TODAY}"

# Handle same-day re-runs
if [[ -d "$EVIDENCE_DIR" ]]; then
  SEQ=2
  while [[ -d "${EVIDENCE_DIR}-${SEQ}" ]]; do
    SEQ=$((SEQ + 1))
  done
  EVIDENCE_DIR="${EVIDENCE_DIR}-${SEQ}"
fi

mkdir -p "$EVIDENCE_DIR"

GATE_PASS=0
GATE_FAIL=0
GATE_SKIP=0
RESULTS_JSON="[]"

add_result() {
  local gate="$1"
  local status="$2"
  local detail="${3:-}"
  RESULTS_JSON=$(echo "$RESULTS_JSON" | python3 -c "
import json, sys
arr = json.load(sys.stdin)
arr.append({'gate': '$gate', 'status': '$status', 'detail': '$detail'})
json.dump(arr, sys.stdout)
")
  if [[ "$status" == "PASS" ]]; then
    GATE_PASS=$((GATE_PASS + 1))
  elif [[ "$status" == "FAIL" ]]; then
    GATE_FAIL=$((GATE_FAIL + 1))
  else
    GATE_SKIP=$((GATE_SKIP + 1))
  fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Tenant Onboarding Evidence Bundle                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "Slug: $SLUG"
echo "Domain: $DOMAIN"
echo "Environment: $ENV"
echo "Evidence: $EVIDENCE_DIR"
echo ""

# ── Gate 1: Branding runtime ─────────────────────────────────────────────

echo "════ Gate 1: Branding Runtime ════"
if [[ -x "$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh" ]]; then
  OUTPUT=$("$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh" 2>&1) && RC=0 || RC=$?
  echo "$OUTPUT" > "$EVIDENCE_DIR/branding-runtime.log"
  echo "$OUTPUT"
  if [[ "$RC" -eq 0 ]]; then
    add_result "branding-runtime" "PASS"
  else
    add_result "branding-runtime" "FAIL" "exit=$RC"
  fi
else
  echo "SKIP: verify-tenant-branding-runtime.sh not found"
  add_result "branding-runtime" "SKIP" "script not found"
fi

# ── Gate 2: Auth smoke ───────────────────────────────────────────────────

echo ""
echo "════ Gate 2: Auth Smoke ════"
AUTH_URL="https://${DOMAIN}/auth/complete/authentik-oidc/"
AUTH_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$AUTH_URL" 2>/dev/null || echo "000")
LOGIN_URL="https://${DOMAIN}/login"
LOGIN_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$LOGIN_URL" 2>/dev/null || echo "000")

{
  echo "Auth smoke for $DOMAIN"
  echo "  OIDC callback ($AUTH_URL): HTTP $AUTH_CODE"
  echo "  Login page ($LOGIN_URL): HTTP $LOGIN_CODE"
} | tee "$EVIDENCE_DIR/auth-smoke.log"

if [[ "$LOGIN_CODE" == "200" || "$LOGIN_CODE" == "302" ]]; then
  add_result "auth-smoke" "PASS" "login=$LOGIN_CODE oidc=$AUTH_CODE"
  echo "  PASS: Login page reachable"
else
  add_result "auth-smoke" "FAIL" "login=$LOGIN_CODE oidc=$AUTH_CODE"
  echo "  FAIL: Login page returned $LOGIN_CODE"
fi

# ── Gate 3: MFE route smoke ─────────────────────────────────────────────

echo ""
echo "════ Gate 3: MFE Route Smoke ════"
if [[ -x "$REPO_ROOT/scripts/qa/verify-mfe-route-smoke.sh" ]]; then
  OUTPUT=$("$REPO_ROOT/scripts/qa/verify-mfe-route-smoke.sh" --env "$ENV" 2>&1) && RC=0 || RC=$?
  echo "$OUTPUT" > "$EVIDENCE_DIR/mfe-route-smoke.log"
  echo "$OUTPUT" | tail -5
  if [[ "$RC" -eq 0 ]]; then
    add_result "mfe-route-smoke" "PASS"
  else
    add_result "mfe-route-smoke" "FAIL" "exit=$RC"
  fi
else
  echo "SKIP: verify-mfe-route-smoke.sh not found"
  add_result "mfe-route-smoke" "SKIP" "script not found"
fi

# ── Gate 4: MFE config snapshot ──────────────────────────────────────────

echo ""
echo "════ Gate 4: MFE Config Snapshot ════"
SAFE_DOMAIN=$(echo "$DOMAIN" | tr '.' '-')
MFE_CONFIG_URL="https://${DOMAIN}/api/mfe_config/v1"
MFE_CONFIG=$(curl -s --max-time 10 "$MFE_CONFIG_URL" 2>/dev/null || echo "")

if [[ -n "$MFE_CONFIG" ]] && echo "$MFE_CONFIG" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  echo "$MFE_CONFIG" | python3 -m json.tool > "$EVIDENCE_DIR/mfe-config-${SAFE_DOMAIN}.json"
  SITE_NAME=$(echo "$MFE_CONFIG" | python3 -c "import json,sys; print(json.load(sys.stdin).get('SITE_NAME','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")
  echo "  SITE_NAME: $SITE_NAME"
  echo "  Saved: mfe-config-${SAFE_DOMAIN}.json"
  add_result "mfe-config" "PASS" "site_name=$SITE_NAME"
else
  echo "  FAIL: Could not fetch MFE config from $MFE_CONFIG_URL"
  add_result "mfe-config" "FAIL" "url=$MFE_CONFIG_URL"
fi

# ── Gate 5: Domain HTTP reachability ─────────────────────────────────────

echo ""
echo "════ Gate 5: Domain Reachability ════"
DOMAIN_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${DOMAIN}/" 2>/dev/null || echo "000")
echo "  https://${DOMAIN}/ → HTTP $DOMAIN_CODE"

if [[ "$DOMAIN_CODE" == "200" || "$DOMAIN_CODE" == "302" ]]; then
  add_result "domain-reachability" "PASS" "http=$DOMAIN_CODE"
else
  add_result "domain-reachability" "FAIL" "http=$DOMAIN_CODE"
fi

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       EVIDENCE SUMMARY                                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Write JSON summary
python3 -c "
import json, sys
results = json.loads('''$RESULTS_JSON''')
summary = {
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'slug': '$SLUG',
    'domain': '$DOMAIN',
    'environment': '$ENV',
    'evidence_dir': '$EVIDENCE_DIR',
    'gates': {
        'pass': $GATE_PASS,
        'fail': $GATE_FAIL,
        'skip': $GATE_SKIP,
        'total': $GATE_PASS + $GATE_FAIL + $GATE_SKIP
    },
    'results': results
}
print(json.dumps(summary, indent=2))
" > "$EVIDENCE_DIR/evidence-summary.json"

# Write Markdown summary
{
  echo "# Tenant Onboarding Evidence"
  echo "Slug: $SLUG"
  echo "Domain: $DOMAIN"
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Gates: PASS=$GATE_PASS FAIL=$GATE_FAIL SKIP=$GATE_SKIP"
  echo ""
  echo "## Gate Results"
  python3 -c "
import json
results = json.loads('''$RESULTS_JSON''')
for r in results:
    detail = f' ({r[\"detail\"]})' if r.get('detail') else ''
    print(f'- {r[\"status\"]}: {r[\"gate\"]}{detail}')
"
} > "$EVIDENCE_DIR/evidence-summary.md"

# Print summary
cat "$EVIDENCE_DIR/evidence-summary.md"
echo ""
echo "JSON: $EVIDENCE_DIR/evidence-summary.json"
echo "Markdown: $EVIDENCE_DIR/evidence-summary.md"

if [[ "$GATE_FAIL" -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL — $GATE_FAIL gate(s) failed"
  exit 1
fi

echo ""
echo "RESULT: PASS — all evidence gates passed"
exit 0
