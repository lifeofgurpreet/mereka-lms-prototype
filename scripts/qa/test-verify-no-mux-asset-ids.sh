#!/usr/bin/env bash
# Regression tests for verify-no-mux-asset-ids.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-no-mux-asset-ids.sh"

PASS=0
FAIL=0

run_case() {
  local name="$1"
  local expected_status="$2"
  local expected_marker="$3"
  local setup_fn="$4"

  local tmpdir
  tmpdir="$(mktemp -d -t test-verify-no-mux-asset-ids.XXXXXX)"
  local stdout_file="$tmpdir/stdout.log"
  local stderr_file="$tmpdir/stderr.log"

  "$setup_fn" "$tmpdir"

  local status=0
  set +e
  (
    cd "$tmpdir"
    "$VERIFY_SCRIPT" --output-dir "$tmpdir/env" >"$stdout_file" 2>"$stderr_file"
  )
  status=$?
  set -e

  if [[ "$status" -ne "$expected_status" ]]; then
    echo "FAIL: $name expected_status=$expected_status observed=$status"
    echo "stdout:"
    sed 's/^/  /' "$stdout_file" || true
    echo "stderr:"
    sed 's/^/  /' "$stderr_file" || true
    FAIL=$((FAIL + 1))
    rm -rf "$tmpdir"
    return
  fi

  if [[ -n "$expected_marker" ]]; then
    if ! rg -q --fixed-strings "$expected_marker" "$stdout_file" "$stderr_file"; then
      echo "FAIL: $name missing marker '$expected_marker'"
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

setup_missing_artifacts() {
  local tmpdir="$1"
  mkdir -p "$tmpdir"
}

setup_exposed_asset_id() {
  local tmpdir="$1"
  mkdir -p "$tmpdir/exports/mct" "$tmpdir/env/apps/mfe"
  cat >"$tmpdir/exports/mct/mux_upload_complete.json" <<'EOF'
{
  "successful": [
    {
      "mux_asset_id": "n58kT8AhCnMFBJ7e008ok8bA01C7hE4nf2P2TQre9X02Kc",
      "mux_playback_id": "playbackid0123456789abcdef0123456789"
    }
  ]
}
EOF
  cat >"$tmpdir/env/apps/mfe/main.js" <<'EOF'
const leakedAssetId = "n58kT8AhCnMFBJ7e008ok8bA01C7hE4nf2P2TQre9X02Kc";
EOF
}

setup_exposed_credential_pattern() {
  local tmpdir="$1"
  mkdir -p "$tmpdir/env/apps/openedx/templates"
  cat >"$tmpdir/env/apps/openedx/templates/index.html" <<'EOF'
<html><body>const MUX_TOKEN_SECRET = "never-inline-this";</body></html>
EOF
}

run_case \
  "missing-artifacts-is-non-fatal" \
  0 \
  "No Mux asset IDs or credentials exposed in build artifacts" \
  setup_missing_artifacts

run_case \
  "detect-exposed-asset-id" \
  1 \
  "Found asset ID n58kT8AhCnMFBJ7e008ok8bA01C7hE4nf2P2TQre9X02Kc" \
  setup_exposed_asset_id

run_case \
  "detect-credential-pattern" \
  1 \
  "Found credential pattern 'MUX_TOKEN_SECRET'" \
  setup_exposed_credential_pattern

printf 'Result: PASS (%s checks passed), FAIL (%s checks failed)\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
