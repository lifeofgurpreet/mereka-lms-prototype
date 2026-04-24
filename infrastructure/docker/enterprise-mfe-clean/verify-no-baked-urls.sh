#!/bin/sh
# verify-no-baked-urls.sh
# Post-build guard: fails if enterprise MFE JS bundles contain hardcoded
# environment-specific enterprise service URLs that should be same-origin.
#
# This prevents the class of bug where build-time patch-missing-env.sh bakes
# absolute URLs into bundles, overriding runtime env.config.js values.

set -eu

DIST_DIR="${1:-/openedx/dist}"
FAIL=0

if [ ! -d "$DIST_DIR" ]; then
  echo "[verify-urls] ERROR: dist dir not found: $DIST_DIR"
  exit 1
fi

# Patterns that must NOT appear in built JS bundles.
# These are absolute enterprise service URLs that break cross-environment
# portability and cause cross-origin failures.
FORBIDDEN_PATTERNS="
https://admin\.academyv2\.mereka\.io/api/enterprise
https://admin\.academyv2\.mereka\.dev/api/enterprise
https://admin\.academyv2\.mereka\.io/api/license
https://admin\.academyv2\.mereka\.dev/api/license
https://admin\.academyv2\.mereka\.io/login_refresh
https://admin\.academyv2\.mereka\.dev/login_refresh
"

for pattern in $FORBIDDEN_PATTERNS; do
  [ -z "$pattern" ] && continue
  matches=$(find "$DIST_DIR" -name '*.js' ! -name 'env.config.js' -exec grep -l "$pattern" {} + 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "[verify-urls] FAIL: found forbidden baked URL pattern: $pattern"
    echo "  in: $matches"
    FAIL=1
  fi
done

if [ "$FAIL" = "1" ]; then
  echo "[verify-urls] FAILED: enterprise MFE bundles contain hardcoded environment-specific URLs"
  echo "[verify-urls] These URLs must be empty strings at build time; runtime env.config.js owns them"
  exit 1
fi

echo "[verify-urls] PASS: no forbidden baked URLs found in $DIST_DIR"
