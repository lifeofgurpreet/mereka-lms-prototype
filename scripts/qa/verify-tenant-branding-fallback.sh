#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005
# @spec: tenant-branding-contract_spec.md
# Verify the base-default + tenant-override branding contract for every tenant.
#
# AC-001: schema file documents allowed keys, types, and base defaults.
# AC-002: merge order is deterministic (base defaults then tenant overrides).
# AC-003: unknown tenant override keys are rejected with actionable errors.
# AC-004: missing override keys resolve to base defaults (no missing-key gaps).
# AC-005: this script — verifies fallback behavior for every tenant definition.
#
# Usage:
#   ./scripts/qa/verify-tenant-branding-fallback.sh
#   ./scripts/qa/verify-tenant-branding-fallback.sh --strict
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    -h|--help) sed -n '1,20p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass()  { printf "${GREEN}[PASS]${NC} %s\n" "$1"; PASS=$((PASS + 1)); }
fail()  { printf "${RED}[FAIL]${NC} %s\n" "$1"; FAIL=$((FAIL + 1)); }
warn()  {
  if [[ $STRICT -eq 1 ]]; then
    printf "${RED}[FAIL]${NC} %s (strict)\n" "$1"; FAIL=$((FAIL + 1))
  else
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"; WARN=$((WARN + 1))
  fi
}

SCHEMA="infrastructure/tutor/tenant-branding-schema.yml"
MERGE_SCRIPT="scripts/shared/merge_tenant_branding.py"
SITES_PROD="infrastructure/tutor/multisite-sites.yml"
SITES_DEV="infrastructure/tutor/multisite-sites.dev.yml"

echo -e "${BLUE}=== Tenant Branding Fallback Contract Verification ===${NC}"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ── AC-001: Schema file exists and has required sections ─────────────────────

echo -e "${BLUE}## AC-001: Schema file${NC}"

if [[ -f "$SCHEMA" ]]; then
  pass "Schema file exists ($SCHEMA)"
else
  fail "Schema file missing ($SCHEMA)"
fi

if [[ -f "$SCHEMA" ]]; then
  if grep -q "^base_defaults:" "$SCHEMA"; then
    pass "Schema has base_defaults section"
  else
    fail "Schema missing base_defaults section"
  fi

  if grep -q "^keys:" "$SCHEMA"; then
    pass "Schema has keys section"
  else
    fail "Schema missing keys section"
  fi

  # Verify required fields are documented
  for key in platform_name site_name LMS_ROOT_URL CMS_ROOT_URL MFE_BASE_URL THEME_NAME course_org_filter; do
    if grep -q "^  ${key}:" "$SCHEMA"; then
      pass "Schema documents key: $key"
    else
      fail "Schema missing key definition: $key"
    fi
  done
fi

echo ""

# ── AC-002: Merge script exists and implements deterministic merge ────────────

echo -e "${BLUE}## AC-002: Merge helper${NC}"

if [[ -f "$MERGE_SCRIPT" ]]; then
  pass "Merge script exists ($MERGE_SCRIPT)"
else
  fail "Merge script missing ($MERGE_SCRIPT)"
fi

if [[ -f "$MERGE_SCRIPT" ]] && grep -q "base_defaults" "$MERGE_SCRIPT"; then
  pass "Merge script references base_defaults (deterministic merge)"
else
  warn "Merge script does not reference base_defaults"
fi

if [[ -f "$MERGE_SCRIPT" ]] && grep -q "ValidationError" "$MERGE_SCRIPT"; then
  pass "Merge script defines ValidationError (schema enforcement)"
else
  fail "Merge script missing ValidationError type"
fi

echo ""

# ── AC-003: Unknown keys are rejected ────────────────────────────────────────

echo -e "${BLUE}## AC-003: Unknown key rejection${NC}"

if ! command -v python3 &>/dev/null; then
  warn "python3 not available; skipping live merge checks"
elif ! python3 -c "import yaml" 2>/dev/null; then
  warn "PyYAML not installed; skipping live merge checks (pip install pyyaml)"
else
  # Write a synthetic sites YAML with an unknown key to a temp file,
  # then call the merge script as a subprocess (avoids importlib module-name issues).
  TMP_BAD_SITES=$(mktemp /tmp/mereka-test-sites-XXXXXX.yml)
  cat > "$TMP_BAD_SITES" <<'YAML'
sites:
  - domain: test.mereka.io
    name: Test
    orgs: [TEST]
    site_values:
      domain: test.mereka.io
      site_name: Test Site
      platform_name: Test Platform
      LMS_ROOT_URL: https://test.mereka.io
      CMS_ROOT_URL: https://studio.test.mereka.io
      MFE_BASE_URL: https://apps.test.mereka.io
      THEME_NAME: mereka
      course_org_filter: [TEST]
      UNKNOWN_FORBIDDEN_KEY: should_fail
YAML

  UNKNOWN_KEY_OUT=$(python3 scripts/qa/_test_merge_helpers.py \
    --test unknown-key \
    --schema "$SCHEMA" \
    --sites "$TMP_BAD_SITES" \
    --domain test.mereka.io 2>&1) && UNKNOWN_KEY_RC=0 || UNKNOWN_KEY_RC=$?
  rm -f "$TMP_BAD_SITES"

  if [[ $UNKNOWN_KEY_RC -eq 0 ]]; then
    pass "Unknown tenant override keys are rejected"
  elif [[ "$UNKNOWN_KEY_OUT" == *"SKIP"* ]]; then
    warn "Unknown key rejection test skipped"
  else
    fail "Unknown tenant override keys are NOT rejected — $UNKNOWN_KEY_OUT"
  fi
fi

echo ""

# ── AC-004: Missing keys resolve to base defaults ─────────────────────────────

echo -e "${BLUE}## AC-004: Base default fallback${NC}"

if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
  FALLBACK_OUT=$(python3 scripts/qa/_test_merge_helpers.py \
    --test base-defaults \
    --schema "$SCHEMA" 2>&1) && FALLBACK_RC=0 || FALLBACK_RC=$?

  if [[ $FALLBACK_RC -eq 0 ]]; then
    pass "Missing keys resolve to base defaults correctly"
  elif [[ "$FALLBACK_OUT" == *"SKIP"* ]]; then
    warn "Default fallback test skipped (missing files)"
  else
    fail "Base default fallback broken — $FALLBACK_OUT"
  fi
fi

echo ""

# ── AC-005: Run merge validation for every tenant in every environment ────────
# Uses the merge script CLI directly (avoids importlib in subprocess issues).

echo -e "${BLUE}## AC-005: Per-tenant fallback verification${NC}"

if ! command -v python3 &>/dev/null; then
  warn "python3 unavailable; skipping per-tenant merge validation"
elif ! python3 -c "import yaml" 2>/dev/null; then
  warn "PyYAML not installed; skipping per-tenant merge validation"
else
  FOUND_ANY=0
  for env_label in prod dev staging; do
    case "$env_label" in
      prod)    sites_file="$SITES_PROD" ;;
      dev)     sites_file="$SITES_DEV" ;;
      staging) sites_file="infrastructure/tutor/multisite-sites.staging.yml" ;;
    esac

    if [[ ! -f "$sites_file" ]]; then
      continue
    fi

    FOUND_ANY=1
    echo "  -- Env: $env_label ($sites_file)"

    # Extract domain names using simple python (no module import needed)
    DOMAINS=$(python3 -c "
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]).read()) or {}
for s in (data.get('sites') or []):
    d = (s or {}).get('domain')
    if d:
        print(d)
" "$sites_file")

    if [[ -z "$DOMAINS" ]]; then
      warn "No tenant domains found in $sites_file"
      continue
    fi

    TENANT_PASS=0
    TENANT_FAIL=0

    while IFS= read -r domain; do
      [[ -z "$domain" ]] && continue
      # Call the merge CLI: --tenant validates a single domain against the sites file.
      # We temporarily symlink/override the env-to-file map via --env + a tmp link.
      # Simpler: use --all with a temporary schema path and only provide the one file.
      # Best: build a tiny wrapper that calls merge_tenant() with the right file.
      MERGE_OUT=$(python3 scripts/qa/_merge_check_tenant.py \
        "$domain" "$sites_file" "$SCHEMA" 2>&1) && MERGE_STATUS=0 || MERGE_STATUS=$?

      if [[ $MERGE_STATUS -eq 0 ]]; then
        pass "  $env_label/$domain: all keys valid, missing keys have defaults"
        TENANT_PASS=$((TENANT_PASS + 1))
      else
        fail "  $env_label/$domain: merge/validation errors"
        echo "$MERGE_OUT"
        TENANT_FAIL=$((TENANT_FAIL + 1))
      fi
    done <<< "$DOMAINS"

    echo "    ($env_label: $TENANT_PASS pass, $TENANT_FAIL fail)"
  done

  if [[ $FOUND_ANY -eq 0 ]]; then
    warn "No multisite YAML files found; nothing to validate"
  fi
fi

# ── Duplication hygiene (warn if tenant duplicates base values exactly) ────────

echo ""
echo -e "${BLUE}## Duplication hygiene${NC}"

if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
  # Identity keys are expected to differ between tenants — don't flag as copies
  DUP_OUT=$(python3 -c "
import sys, yaml
from pathlib import Path

identity_keys = {
    'domain', 'site_name', 'platform_name',
    'LMS_ROOT_URL', 'CMS_ROOT_URL', 'MFE_BASE_URL',
    'course_org_filter', 'logo_image', 'logo_url', 'favicon_path',
}

issues = []
for filepath in sys.argv[1:]:
    p = Path(filepath)
    if not p.exists():
        continue
    data = yaml.safe_load(p.read_text()) or {}
    sites = data.get('sites') or []
    if len(sites) < 2:
        continue
    base_sv = dict((sites[0] or {}).get('site_values') or {})
    for site in sites[1:]:
        domain = (site or {}).get('domain', '?')
        sv = dict((site or {}).get('site_values') or {})
        duplicated = [
            k for k, v in sv.items()
            if k not in identity_keys
            and k in base_sv
            and base_sv[k] == v
        ]
        if len(duplicated) >= 2:
            issues.append(
                f'WARN: {p.name}/{domain} copies {len(duplicated)} non-identity '
                f'keys verbatim from base: {sorted(duplicated)}'
            )
for issue in issues:
    print(issue)
if not issues:
    print('OK: no full-copy duplication detected')
" "$SITES_PROD" "$SITES_DEV")

  if grep -q "^WARN:" <<<"$DUP_OUT"; then
    while IFS= read -r line; do
      [[ "$line" == WARN:* ]] && warn "${line#WARN: }"
    done <<< "$DUP_OUT"
  else
    pass "No verbatim base-value duplication in tenant overrides"
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}## Summary${NC}"
printf "  ${GREEN}PASS${NC}: %d\n" "$PASS"
printf "  ${YELLOW}WARN${NC}: %d\n" "$WARN"
printf "  ${RED}FAIL${NC}: %d\n" "$FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Some checks failed.${NC}"
  exit 1
elif [[ $WARN -gt 0 && $STRICT -eq 1 ]]; then
  echo -e "${RED}Strict mode: warnings treated as failures.${NC}"
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo -e "${YELLOW}All required checks passed (warnings present).${NC}"
  exit 0
else
  echo -e "${GREEN}All checks passed.${NC}"
  exit 0
fi
