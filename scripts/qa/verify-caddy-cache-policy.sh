#!/usr/bin/env bash
# @spec: multi-site-domains_spec.md
# @covers AC-MSD-012
# Verify Caddy caching policy: tiered Cache-Control headers for static,
# media, API, and default responses. Catches regression to blanket no-store.
set -euo pipefail

PASS=0; FAIL=0; SKIP=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

OUTER_CADDY="deploy/k8s/base/apps/caddy/Caddyfile"
MFE_CADDY="deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"

echo "=== Caddy Cache Policy Verification ==="

# --- Outer Caddy (proxy snippet) ---
echo ""
echo "--- Outer Caddy (proxy snippet) ---"

# 1. Default must be no-cache (not no-store)
if grep -q 'header Cache-Control "no-cache"' "$OUTER_CADDY"; then
  pass "Default Cache-Control is no-cache (allows conditional 304s)"
else
  fail "Default Cache-Control is NOT no-cache — check proxy snippet"
fi

# 2. Must NOT have blanket no-store in proxy snippet
# (it's OK to have no-store scoped to matchers like @api_no_store)
if grep -A2 '(proxy)' "$OUTER_CADDY" | grep -v '@' | grep -q '"no-store"'; then
  fail "Blanket no-store in proxy snippet — kills static asset caching"
else
  pass "No blanket no-store in proxy snippet"
fi

# 3. Static assets matcher must exist
if grep -q '@static_hashed' "$OUTER_CADDY"; then
  pass "Static assets matcher (@static_hashed) exists"
else
  fail "Missing @static_hashed matcher for long-term caching"
fi

# 4. Static assets must have immutable directive
if grep -A1 '@static_hashed' "$OUTER_CADDY" | grep -q 'immutable'; then
  pass "Static assets have immutable Cache-Control"
else
  fail "Static assets missing immutable directive"
fi

# 5. API no-store must be scoped to matchers
if grep -q '@api_no_store' "$OUTER_CADDY"; then
  pass "API no-store is scoped to @api_no_store matcher"
else
  fail "Missing scoped @api_no_store matcher"
fi

# 6. API matcher must cover sensitive endpoints
for path in '/api/\*' '/oauth2/\*' '/login\*' '/admin/\*'; do
  clean="${path//\\/}"
  if grep '@api_no_store' -A3 "$OUTER_CADDY" | grep -qF "$clean"; then
    pass "API no-store covers $clean"
  else
    fail "API no-store missing coverage for $clean"
  fi
done

# --- MFE Caddy ---
echo ""
echo "--- MFE Caddy ---"

# 7. Default must be no-cache
if grep -q 'header Cache-Control "no-cache"' "$MFE_CADDY"; then
  pass "MFE default Cache-Control is no-cache"
else
  fail "MFE default Cache-Control is NOT no-cache"
fi

# 8. Hashed assets must have immutable
if grep -A1 '@hashed' "$MFE_CADDY" | grep -q 'immutable'; then
  pass "MFE hashed assets have immutable Cache-Control"
else
  fail "MFE hashed assets missing immutable directive"
fi

# 9. Theme path must NOT double-nest
if grep -A2 '@mfe_theme_assets' "$MFE_CADDY" | grep -q 'root \* /openedx/dist$'; then
  pass "MFE theme root is /openedx/dist (no double nesting)"
elif grep -A2 '@mfe_theme_assets' "$MFE_CADDY" | grep -q 'root \* /openedx/dist/theme'; then
  fail "MFE theme root is /openedx/dist/theme — causes double path nesting"
else
  pass "MFE theme root check (non-standard but not double-nested)"
fi

# 10. Theme try_files must include /theme{path} first hop
if awk '/@mfe_theme_assets/{flag=1} flag{print} /file_server/{if(flag){exit}}' "$MFE_CADDY" | grep -q 'try_files /theme{path}'; then
  pass "MFE theme try_files checks /theme{path} first (runtime min.css root)"
else
  fail "MFE theme try_files missing /theme{path} first-hop check"
fi

# --- Summary ---
echo ""
echo "=== Summary: $PASS PASS, $FAIL FAIL, $SKIP SKIP ==="
[ "$FAIL" -eq 0 ]
