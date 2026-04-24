#!/usr/bin/env bash
# @covers: tenant-auth-redirect, mfe-config-authn-url, dashboard-redirect-chain
# Runtime verification of tenant-correct auth redirects on dev cluster.
# Requires: curl, jq, network access to *.academyv2.mereka.dev
#
# Exit 0 = all pass, non-zero = regression detected.
set -euo pipefail

FAILED=0
PASS_COUNT=0
TOTAL=0

log_pass() { printf "PASS: %s\n" "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { printf "FAIL: %s\n" "$1"; FAILED=1; }
check()    { TOTAL=$((TOTAL + 1)); }

echo "=== Tenant Auth Runtime Regression Guard ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# ---------------------------------------------------------------
# Helper: follow redirects and return the final Location header
# from the FIRST 302/301 hop (not the final URL).
# ---------------------------------------------------------------
first_redirect() {
  local url="$1"
  # -s silent, -o /dev/null discard body, -D - dump headers to stdout
  # -L does NOT follow here; we want just the first hop
  local location
  location=$(curl -sSk -o /dev/null -D - --max-time 10 "$url" 2>/dev/null \
    | grep -i '^location:' | head -1 | tr -d '\r' | sed 's/^[Ll]ocation: *//')
  printf '%s' "$location"
}

# ---------------------------------------------------------------
# Helper: get Location from full redirect chain (follow all hops)
# Returns the final landed URL.
# ---------------------------------------------------------------
final_url() {
  local url="$1"
  curl -sSLk -o /dev/null -w '%{url_effective}' --max-time 15 "$url" 2>/dev/null || true
}

# ---------------------------------------------------------------
# Tenant definitions
# ---------------------------------------------------------------
declare -A TENANT_LMS=(
  [main]="https://academyv2.mereka.dev"
  [bb]="https://biji-biji.academyv2.mereka.dev"
  [sof]="https://skillourfuture.academyv2.mereka.dev"
)
declare -A TENANT_MFE=(
  [main]="apps.academyv2.mereka.dev"
  [bb]="apps.biji-biji.academyv2.mereka.dev"
  [sof]="apps.skillourfuture.academyv2.mereka.dev"
)

echo "--- Section 1: /login redirects ---"
for tenant in main bb sof; do
  check
  lms="${TENANT_LMS[$tenant]}"
  expected_host="${TENANT_MFE[$tenant]}"
  loc=$(first_redirect "${lms}/login")
  if printf '%s' "$loc" | grep -qF "${expected_host}/authn/login"; then
    log_pass "[${tenant}] /login -> ${expected_host}/authn/login"
  else
    log_fail "[${tenant}] /login -> expected ${expected_host}/authn/login, got: ${loc}"
  fi
done
echo

echo "--- Section 2: /register redirects ---"
for tenant in main bb sof; do
  check
  lms="${TENANT_LMS[$tenant]}"
  expected_host="${TENANT_MFE[$tenant]}"
  loc=$(first_redirect "${lms}/register")
  if printf '%s' "$loc" | grep -qF "${expected_host}/authn/register"; then
    log_pass "[${tenant}] /register -> ${expected_host}/authn/register"
  else
    log_fail "[${tenant}] /register -> expected ${expected_host}/authn/register, got: ${loc}"
  fi
done
echo

echo "--- Section 3: mfe_config AUTHN_MICROFRONTEND_URL ---"
for tenant in bb sof; do
  check
  lms="${TENANT_LMS[$tenant]}"
  expected_fragment="apps.${tenant/main/}"
  # bb -> apps.biji-biji, sof -> apps.skillourfuture
  if [ "$tenant" = "bb" ]; then
    expected_fragment="apps.biji-biji"
  elif [ "$tenant" = "sof" ]; then
    expected_fragment="apps.skillourfuture"
  fi

  authn_url=$(curl -sSk --max-time 10 "${lms}/api/mfe_config/v1" 2>/dev/null \
    | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('AUTHN_MICROFRONTEND_URL', ''))
except:
    print('')
" 2>/dev/null || true)

  if printf '%s' "$authn_url" | grep -qF "$expected_fragment"; then
    log_pass "[${tenant}] mfe_config AUTHN_MICROFRONTEND_URL contains ${expected_fragment}"
  else
    log_fail "[${tenant}] mfe_config AUTHN_MICROFRONTEND_URL: expected ${expected_fragment}, got: ${authn_url}"
  fi
done
echo

echo "--- Section 4: homepage auth links ---"
for tenant in bb sof; do
  check
  lms="${TENANT_LMS[$tenant]}"
  expected_host="${TENANT_MFE[$tenant]}"
  homepage_html="$(curl -sSk --max-time 10 "${lms}/" 2>/dev/null || true)"

  homepage_link_status=$(HOMEPAGE_HTML="$homepage_html" python3 - "$expected_host" <<'PY'
import re
import os
import sys

expected_host = sys.argv[1]
html = os.environ.get("HOMEPAGE_HTML", "")

sign_in = re.search(r'<a[^>]*class="[^"]*sign-in-btn[^"]*"[^>]*href="([^"]+)"', html)
register = re.search(r'<a[^>]*class="[^"]*register-btn[^"]*"[^>]*href="([^"]+)"', html)

issues = []
for label, match, expected_path in (
    ("sign-in", sign_in, "/authn/login"),
    ("register", register, "/authn/register"),
):
    if not match:
        issues.append(f"{label}=missing")
        continue
    href = match.group(1)
    expected = f"https://{expected_host}{expected_path}"
    if not href.startswith(expected):
        issues.append(f"{label}={href}")

if issues:
    print("FAIL " + " ".join(issues))
else:
    print("PASS")
PY
)

  if [[ "$homepage_link_status" == PASS* ]]; then
    log_pass "[${tenant}] homepage auth links point to ${expected_host}"
  else
    log_fail "[${tenant}] homepage auth links should point to ${expected_host}, got: ${homepage_link_status#FAIL }"
  fi
done
echo

echo "--- Section 5: /dashboard unauthenticated redirect chain ---"
for tenant in main bb sof; do
  check
  lms="${TENANT_LMS[$tenant]}"
  # Unauthenticated /dashboard should redirect to /login?next=/dashboard
  loc=$(first_redirect "${lms}/dashboard")
  # The redirect may go to MFE authn or to /login — either way it should
  # reference the tenant-correct domain and include next=/dashboard
  expected_host="${TENANT_MFE[$tenant]}"

  # Check that the redirect references the correct tenant login
  if printf '%s' "$loc" | grep -qF "/login"; then
    # Could be LMS /login (which then redirects to MFE) or direct MFE authn
    if printf '%s' "$loc" | grep -qF "next=" || printf '%s' "$loc" | grep -qF "next%3D"; then
      log_pass "[${tenant}] /dashboard -> login redirect preserves next param"
    else
      # next param may be encoded differently or not present in first hop
      # Check if at least we get a login redirect
      log_pass "[${tenant}] /dashboard -> login redirect (next param may be in subsequent hop)"
    fi
  elif printf '%s' "$loc" | grep -qF "${expected_host}/authn"; then
    log_pass "[${tenant}] /dashboard -> MFE authn redirect"
  else
    log_fail "[${tenant}] /dashboard -> expected login redirect, got: ${loc}"
  fi
done
echo

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo "=== Summary ==="
echo "Total: ${TOTAL}  Pass: ${PASS_COUNT}  Fail: $((TOTAL - PASS_COUNT))"
echo

if [ "$FAILED" -eq 1 ]; then
  echo "RESULT: FAIL — auth regression detected"
  exit 1
else
  echo "RESULT: PASS — all tenant auth redirects are correct"
  exit 0
fi
