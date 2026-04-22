#!/usr/bin/env bash
# test-emit-build-metrics.sh — self-contained test suite for scripts/ci/emit-build-metrics.sh
#
# Four fixtures covering happy path, graceful-degradation fallback, log parsing,
# and unknown-argument handling. Exits 0 only when all fixtures pass.
#
# Usage:
#   bash scripts/qa/test-emit-build-metrics.sh
#
# Bead: mereka-lms-jj97.11 (build telemetry scorecard burn — self-test axis)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/ci/emit-build-metrics.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_pass() {
  PASS_COUNT=$(( PASS_COUNT + 1 ))
  echo "[test-emit-build-metrics] PASS $*"
}

_fail() {
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  echo "[test-emit-build-metrics] FAIL $*" >&2
}

# ── Fixture 1: happy path — metadata JSON + log file → valid JSON output ─────
# Tests: both inputs present, jq validates output, required top-level keys present,
#        image_family and release_unit_id round-trip correctly.
echo ""
echo "--- Fixture 1: happy path (metadata + log → valid JSON artifact) ---"

FIX1_DIR="$TMP_DIR/fix1"
mkdir -p "$FIX1_DIR"

# Minimal valid buildx metadata JSON
cat > "$FIX1_DIR/metadata.json" <<'JSON'
{
  "buildx.build.duration": 312,
  "containerimage.digest": "sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
}
JSON

# Minimal buildx log with cache import, export, and layer lines
cat > "$FIX1_DIR/buildx.log" <<'LOG'
#3 [internal] load build definition from Dockerfile
#3 CACHED
#4 [stage1 1/3] FROM ghcr.io/example/base:latest
#4 CACHED
#5 [stage1 2/3] RUN apt-get update
#7 importing cache manifest from ghcr.io/example/cache/openedx:main@sha256:1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff
#8 exporting cache
#9 writing manifest sha256:aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222
LOG

set +e
(
  cd "$FIX1_DIR"
  bash "$SCRIPT" \
    --metadata-file "$FIX1_DIR/metadata.json" \
    --log-file "$FIX1_DIR/buildx.log" \
    --image-family openedx \
    --release-unit-id abc123 \
    --workflow-run-id 9000 \
    > "$FIX1_DIR/stdout.txt" 2> "$FIX1_DIR/stderr.txt"
)
EXIT1=$?
set -e

if [[ $EXIT1 -eq 0 ]]; then
  _pass "fixture 1: exit 0"
else
  _fail "fixture 1: expected exit 0, got $EXIT1 — stderr: $(cat "$FIX1_DIR/stderr.txt")"
fi

OUTPUT1="$FIX1_DIR/build-metrics-openedx.json"
if [[ -f "$OUTPUT1" ]]; then
  _pass "fixture 1: output file build-metrics-openedx.json created"
else
  _fail "fixture 1: output file build-metrics-openedx.json not found"
fi

if command -v jq &>/dev/null && [[ -f "$OUTPUT1" ]]; then
  if jq empty "$OUTPUT1" 2>/dev/null; then
    _pass "fixture 1: output is valid JSON"
  else
    _fail "fixture 1: output is not valid JSON — contents: $(cat "$OUTPUT1")"
  fi

  release_id="$(jq -r '.release_unit_id' "$OUTPUT1" 2>/dev/null || true)"
  if [[ "$release_id" == "abc123" ]]; then
    _pass "fixture 1: release_unit_id round-trips correctly"
  else
    _fail "fixture 1: expected release_unit_id=abc123, got '$release_id'"
  fi

  image_family="$(jq -r '.image_family' "$OUTPUT1" 2>/dev/null || true)"
  if [[ "$image_family" == "openedx" ]]; then
    _pass "fixture 1: image_family round-trips correctly"
  else
    _fail "fixture 1: expected image_family=openedx, got '$image_family'"
  fi

  duration="$(jq '.build_duration_seconds' "$OUTPUT1" 2>/dev/null || true)"
  if [[ "$duration" == "312" ]]; then
    _pass "fixture 1: build_duration_seconds extracted from metadata"
  else
    _fail "fixture 1: expected build_duration_seconds=312, got '$duration'"
  fi

  layer_reuse="$(jq '.layer_reuse_count' "$OUTPUT1" 2>/dev/null || true)"
  if [[ "$layer_reuse" == "2" ]]; then
    _pass "fixture 1: layer_reuse_count parsed (2 CACHED lines)"
  else
    _fail "fixture 1: expected layer_reuse_count=2, got '$layer_reuse'"
  fi
fi

if grep -q "PASS emit-build-metrics:" "$FIX1_DIR/stdout.txt" 2>/dev/null; then
  _pass "fixture 1: PASS summary line on stdout"
else
  _fail "fixture 1: expected 'PASS emit-build-metrics:' on stdout; got: $(cat "$FIX1_DIR/stdout.txt")"
fi

# ── Fixture 2: graceful degradation — no inputs → exit 0, _warning key set ───
# Tests: script must NOT fail when neither metadata nor log is provided.
#        This is the CI-safe "graceful degradation" contract: never break the build.
echo ""
echo "--- Fixture 2: graceful degradation (no metadata, no log → exit 0 + _warning) ---"

FIX2_DIR="$TMP_DIR/fix2"
mkdir -p "$FIX2_DIR"

set +e
(
  cd "$FIX2_DIR"
  bash "$SCRIPT" \
    --image-family mfe \
    --release-unit-id deadbeef \
    > "$FIX2_DIR/stdout.txt" 2> "$FIX2_DIR/stderr.txt"
)
EXIT2=$?
set -e

if [[ $EXIT2 -eq 0 ]]; then
  _pass "fixture 2: exit 0 (graceful degradation)"
else
  _fail "fixture 2: expected exit 0 for graceful degradation, got $EXIT2"
fi

OUTPUT2="$FIX2_DIR/build-metrics-mfe.json"
if [[ -f "$OUTPUT2" ]]; then
  _pass "fixture 2: empty artifact build-metrics-mfe.json created"
else
  _fail "fixture 2: output file build-metrics-mfe.json not found"
fi

if command -v jq &>/dev/null && [[ -f "$OUTPUT2" ]]; then
  warning_key="$(jq -r '._warning // empty' "$OUTPUT2" 2>/dev/null || true)"
  if [[ -n "$warning_key" ]]; then
    _pass "fixture 2: _warning key present in empty artifact"
  else
    _fail "fixture 2: expected _warning key in empty artifact; got: $(cat "$OUTPUT2")"
  fi

  cache_sources="$(jq -r '.cache_sources | length' "$OUTPUT2" 2>/dev/null || true)"
  if [[ "$cache_sources" == "0" ]]; then
    _pass "fixture 2: cache_sources is empty array"
  else
    _fail "fixture 2: expected cache_sources=[], got length $cache_sources"
  fi

  layer_reuse="$(jq '.layer_reuse_count' "$OUTPUT2" 2>/dev/null || true)"
  if [[ "$layer_reuse" == "null" ]]; then
    _pass "fixture 2: layer_reuse_count is null (no log)"
  else
    _fail "fixture 2: expected layer_reuse_count=null, got '$layer_reuse'"
  fi
fi

# ── Fixture 3: missing file paths → exit 0 + warnings on stderr ──────────────
# Tests: when --metadata-file and --log-file are given but files don't exist,
#        script emits ::warning:: lines to stderr but still exits 0 and produces
#        a valid artifact. Validates CI-safe degradation contract from the script header.
echo ""
echo "--- Fixture 3: non-existent file paths → ::warning:: on stderr + exit 0 ---"

FIX3_DIR="$TMP_DIR/fix3"
mkdir -p "$FIX3_DIR"

set +e
(
  cd "$FIX3_DIR"
  bash "$SCRIPT" \
    --metadata-file "/tmp/does-not-exist-$(date +%s).json" \
    --log-file "/tmp/also-does-not-exist-$(date +%s).log" \
    --image-family openedx \
    --release-unit-id sha_missing \
    > "$FIX3_DIR/stdout.txt" 2> "$FIX3_DIR/stderr.txt"
)
EXIT3=$?
set -e

if [[ $EXIT3 -eq 0 ]]; then
  _pass "fixture 3: exit 0 despite missing file paths"
else
  _fail "fixture 3: expected exit 0 for missing files, got $EXIT3"
fi

if grep -q "::warning::" "$FIX3_DIR/stderr.txt" 2>/dev/null; then
  _pass "fixture 3: ::warning:: emitted to stderr for missing files"
else
  _fail "fixture 3: expected ::warning:: in stderr; got: $(cat "$FIX3_DIR/stderr.txt")"
fi

OUTPUT3="$FIX3_DIR/build-metrics-openedx.json"
if [[ -f "$OUTPUT3" ]]; then
  _pass "fixture 3: output artifact still created despite missing inputs"
else
  _fail "fixture 3: output file build-metrics-openedx.json not found after missing-file run"
fi

# ── Fixture 4: unknown argument → ::warning:: annotation + exits 0 ────────────
# Tests: unrecognized flags must emit a warning but must NOT abort the script.
# This matches the shift-and-warn pattern in the argument parser.
echo ""
echo "--- Fixture 4: unknown argument → ::warning:: but exit 0 ---"

FIX4_DIR="$TMP_DIR/fix4"
mkdir -p "$FIX4_DIR"

set +e
(
  cd "$FIX4_DIR"
  bash "$SCRIPT" \
    --image-family openedx \
    --totally-unknown-flag ignored-value \
    > "$FIX4_DIR/stdout.txt" 2> "$FIX4_DIR/stderr.txt"
)
EXIT4=$?
set -e

if [[ $EXIT4 -eq 0 ]]; then
  _pass "fixture 4: exit 0 with unknown argument"
else
  _fail "fixture 4: expected exit 0 with unknown argument, got $EXIT4"
fi

if grep -q "::warning::" "$FIX4_DIR/stderr.txt" 2>/dev/null; then
  _pass "fixture 4: ::warning:: emitted for unknown argument"
else
  _fail "fixture 4: expected ::warning:: for unknown argument; got stderr: $(cat "$FIX4_DIR/stderr.txt")"
fi

if grep -q "totally-unknown-flag" "$FIX4_DIR/stderr.txt" 2>/dev/null; then
  _pass "fixture 4: unknown flag name appears in warning message"
else
  _fail "fixture 4: expected flag name in warning message; got: $(cat "$FIX4_DIR/stderr.txt")"
fi

# ── Fixture 5: cache-health summary consumes metrics JSON, not command strings ─
# Tests: the summary script reports L2 imports from build-metrics JSON and does
# not require stale `cache-from=...` or BUILDKIT_INLINE_CACHE command-log text.
echo ""
echo "--- Fixture 5: cache-health summary from metrics JSON ---"

SUMMARY_SCRIPT="$REPO_ROOT/scripts/ci/summarize-build-cache-health.sh"
FIX5_DIR="$TMP_DIR/fix5"
mkdir -p "$FIX5_DIR"
cat > "$FIX5_DIR/build-metrics-openedx.json" <<'JSON'
{
  "release_unit_id": "abc123",
  "workflow_run_id": "9000",
  "image_family": "openedx",
  "cache_sources": [
    {
      "type": "registry",
      "ref": "ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64",
      "found": true,
      "digest": "sha256:1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff"
    },
    {
      "type": "image",
      "ref": "ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand",
      "found": true,
      "digest": null
    }
  ],
  "cache_export": {"success": false, "digest": null},
  "layer_reuse_count": 94,
  "layer_total_count": 113,
  "build_duration_seconds": 1234,
  "collected_at": "2026-04-22T00:00:00Z"
}
JSON

set +e
(
  cd "$FIX5_DIR"
  bash "$SUMMARY_SCRIPT" \
    --image-family openedx \
    --metrics-file "$FIX5_DIR/build-metrics-openedx.json" \
    --l2-cache-ref ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64 \
    --cache-export-expected false \
    > "$FIX5_DIR/stdout.txt" 2> "$FIX5_DIR/stderr.txt"
)
EXIT5=$?
set -e

if [[ $EXIT5 -eq 0 ]]; then
  _pass "fixture 5: summary exits 0"
else
  _fail "fixture 5: expected exit 0, got $EXIT5"
fi

if grep -q "OK: L2 registry cache import observed" "$FIX5_DIR/stdout.txt"; then
  _pass "fixture 5: L2 registry import is reported from metrics JSON"
else
  _fail "fixture 5: expected L2 registry import summary; got: $(cat "$FIX5_DIR/stdout.txt")"
fi

if grep -q "OK: shared cache export not expected for this event" "$FIX5_DIR/stdout.txt"; then
  _pass "fixture 5: non-main cache export is not treated as failure"
else
  _fail "fixture 5: expected non-main cache export classification; got: $(cat "$FIX5_DIR/stdout.txt")"
fi

set +e
(
  cd "$FIX5_DIR"
  bash "$SUMMARY_SCRIPT" \
    --image-family openedx \
    --metrics-file "$FIX5_DIR/build-metrics-openedx.json" \
    --l2-cache-ref ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64 \
    --cache-export-expected true \
    > "$FIX5_DIR/stdout-export-expected.txt" 2> "$FIX5_DIR/stderr-export-expected.txt"
)
EXIT5B=$?
set -e

if [[ $EXIT5B -eq 0 ]]; then
  _pass "fixture 5b: expected-export mismatch remains non-blocking"
else
  _fail "fixture 5b: expected non-blocking exit 0, got $EXIT5B"
fi

if grep -q "FAIL: shared cache export was expected" "$FIX5_DIR/stdout-export-expected.txt"; then
  _pass "fixture 5b: trusted-main cache export miss is classified explicitly"
else
  _fail "fixture 5b: expected cache export miss classification; got: $(cat "$FIX5_DIR/stdout-export-expected.txt")"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Summary: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT}"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "[test-emit-build-metrics] FAILED" >&2
  exit 1
fi
echo "[test-emit-build-metrics] ALL FIXTURES PASSED"
