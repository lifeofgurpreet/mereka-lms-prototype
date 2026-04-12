#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d -t test-verify-mfe-image-branding.XXXXXX)"
pass_image="codex-test-verify-mfe-image-branding-pass:$$"
fail_image="codex-test-verify-mfe-image-branding-fail:$$"

cleanup() {
  docker image rm -f "$pass_image" "$fail_image" >/dev/null 2>&1 || true
  rm -rf "$tmpdir"
}
trap cleanup EXIT

mkdir -p "$tmpdir/pass/openedx/dist/authn" "$tmpdir/fail/openedx/dist/authn"

cat >"$tmpdir/pass/Dockerfile" <<'EOF'
FROM alpine:3.20
RUN mkdir -p /openedx/dist/authn
COPY openedx/dist/authn/ /openedx/dist/authn/
EOF

cat >"$tmpdir/fail/Dockerfile" <<'EOF'
FROM alpine:3.20
RUN mkdir -p /openedx/dist/authn
COPY openedx/dist/authn/ /openedx/dist/authn/
EOF

cat >"$tmpdir/pass/openedx/dist/authn/index.html" <<'EOF'
<!doctype html>
<html lang="en-us">
  <head>
    <link href="/authn/app.good.css" rel="stylesheet">
  </head>
  <body>
    <div id="root"></div>
    <script type="text/javascript">
      var PARAGON_THEME = (() => {
        const theme = {
          "brand": {
            "themeUrls": {
              "core": { "fileName": "../theme/mereka-brand.min.css" },
              "variants": {
                "light": { "fileName": "../theme/mereka-brand-light.min.css" }
              }
            }
          }
        };
        return theme;
      })();
    </script>
  </body>
</html>
EOF

cat >"$tmpdir/pass/openedx/dist/authn/app.good.css" <<'EOF'
:root {
  --mereka-mfe-gradient: linear-gradient(#111, #222);
}
EOF

cat >"$tmpdir/fail/openedx/dist/authn/index.html" <<'EOF'
<!doctype html>
<html lang="en-us">
  <head>
    <link href="/authn/app.bad.css" rel="stylesheet">
  </head>
  <body>
    <div id="root"></div>
    <script type="text/javascript">
      var PARAGON_THEME = (() => {
        const theme = {
          "brand": {
            "themeUrls": {
              "core": {},
              "variants": {
                "light": {}
              }
            }
          }
        };
        return theme;
      })();
    </script>
  </body>
</html>
EOF

cat >"$tmpdir/fail/openedx/dist/authn/app.bad.css" <<'EOF'
:root {
  --mereka-mfe-gradient: linear-gradient(#111, #222);
}
EOF

docker build -q -t "$pass_image" "$tmpdir/pass" >/dev/null
docker build -q -t "$fail_image" "$tmpdir/fail" >/dev/null

if ! "$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh" "$pass_image" >/tmp/test-verify-mfe-image-branding-pass.log 2>&1; then
  echo "Expected branding verifier to pass for IIFE-based PARAGON_THEME."
  cat /tmp/test-verify-mfe-image-branding-pass.log
  exit 1
fi

if "$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh" "$fail_image" >/tmp/test-verify-mfe-image-branding-fail.log 2>&1; then
  echo "Expected branding verifier to fail when PARAGON_THEME brand URLs are empty."
  cat /tmp/test-verify-mfe-image-branding-fail.log
  exit 1
fi

if ! rg -q "PARAGON_THEME brand URLs are empty" /tmp/test-verify-mfe-image-branding-fail.log; then
  echo "Expected failure log to mention empty PARAGON_THEME brand URLs."
  cat /tmp/test-verify-mfe-image-branding-fail.log
  exit 1
fi

echo "PASS test-verify-mfe-image-branding"
