#!/usr/bin/env bash
# Targeted contract tests for correlation header verification script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

run_case() {
  local name="$1"
  local strict_mode="$2"
  local expect_status="$3"
  local expected_contains="$4"
  local caddyfile="$5"

  local tmpdir
  tmpdir="$(mktemp -d -t correlation-test.XXXXXX)"
  local tmp_caddy="$tmpdir/Caddyfile"
  local stdout_file="$tmpdir/stdout.log"
  local stderr_file="$tmpdir/stderr.log"

  printf '%s\n' "$caddyfile" > "$tmp_caddy"

  set +e
  if [[ "$strict_mode" == "strict" ]]; then
    (cd "$REPO_ROOT" && STRICT=1 CADDYFILE="$tmp_caddy" ./scripts/qa/verify-correlation-header-propagation.sh >"$stdout_file" 2>"$stderr_file")
    status=$?
  else
    (cd "$REPO_ROOT" && STRICT=0 CADDYFILE="$tmp_caddy" ./scripts/qa/verify-correlation-header-propagation.sh >"$stdout_file" 2>"$stderr_file")
    status=$?
  fi
  set -e

  if [[ "$status" -ne "$expect_status" ]]; then
    echo "FAIL: $name expected_status=$expect_status observed=$status"
    echo "stdout:"
    sed 's/^/  /' "$stdout_file" || true
    echo "stderr:"
    sed 's/^/  /' "$stderr_file" || true
    FAIL=$((FAIL + 1))
    rm -rf "$tmpdir"
    return
  fi

  if [[ -n "$expected_contains" ]]; then
    if ! rg -q "$expected_contains" "$stdout_file" "$stderr_file"; then
      echo "FAIL: $name missing output marker '$expected_contains'"
      echo "stdout:"
      sed 's/^/  /' "$stdout_file" || true
      echo "stderr:"
      sed 's/^/  /' "$stderr_file" || true
      FAIL=$((FAIL + 1))
      rm -rf "$tmpdir"
      return
    fi
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
  rm -rf "$tmpdir"
}

# Valid: proxy snippet defines both headers; direct reverse_proxy inherits via import.
run_case "valid-proxy-snippet" "strict" 0 "evidence_identity" $'#:placeholder\n\n:80 {\n  route /health* /health\n  reverse_proxy https://backend.test {\n    import proxy\n  }\n}\n\n(proxy) {\n  header_up X-Request-ID {http.request.uuid}\n  header_up traceparent {http.request.header.traceparent}\n}\n\n'

# Valid: snippet can be declared after reverse_proxy and still satisfy import.
run_case "valid-proxy-snippet-after-reverse-proxy" "strict" 0 "evidence_identity" $'#:placeholder\n\n:80 {\n  reverse_proxy https://backend.test {\n    import proxy\n  }\n}\n\n(proxy) {\n  header_up X-Request-ID {http.request.uuid}\n  header_up traceparent {http.request.header.traceparent}\n}\n\n'

# Non-strict mode remains non-fatal even when headers missing; this is contract behavior.
run_case "missing-headers-nonstrict" "nonstrict" 0 "WARN" $'#:placeholder\n\n:80 {\n  reverse_proxy https://backend.test {\n    header_up Host {host}\n  }\n}\n\n(proxy) {\n  header_up X-Request-ID {http.request.uuid}\n  header_up traceparent {http.request.header.traceparent}\n}\n\n'

# Strict mode must fail when headers are missing on direct reverse_proxy.
run_case "missing-headers-strict" "strict" 1 "FAIL: direct reverse_proxy blocks do not forward required headers" $'#:placeholder\n\n:80 {\n  reverse_proxy https://backend.test {\n    header_up Host {host}\n  }\n}\n\n(proxy) {\n  header_up X-Request-ID {http.request.uuid}\n  header_up traceparent {http.request.header.traceparent}\n}\n\n'

# Missing proxy snippet is a strict failure by design in both modes.
run_case "missing-proxy-snippet" "strict" 1 "Could not find \(proxy\)" $'#:placeholder\n\n:80 {\n  reverse_proxy https://backend.test\n}\n\n'

# No direct reverse_proxy blocks should pass when proxy snippet is present.
run_case "no-direct-reverse-proxy" "nonstrict" 0 "no direct reverse_proxy blocks" $'#:placeholder\n\n:80 {\n  import proxy\n}\n\n(proxy) {\n  header_up X-Request-ID {http.request.uuid}\n  header_up traceparent {http.request.header.traceparent}\n}\n\n'

printf 'Result: PASS (%s checks passed), FAIL (%s checks failed)\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
