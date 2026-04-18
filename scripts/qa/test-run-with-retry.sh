#!/usr/bin/env bash
# test-run-with-retry.sh — self-contained test suite for scripts/ci/run-with-retry.sh
#
# Runs four seeded-defect fixtures and asserts expected outcomes.
# Exits 0 only when all fixtures pass.
#
# Usage:
#   bash scripts/qa/test-run-with-retry.sh
#
# Bead: mereka-lms-lb4c.2 (S6 promotion reliability)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/ci/run-with-retry.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_pass() {
  PASS_COUNT=$(( PASS_COUNT + 1 ))
  echo "[test-run-with-retry] PASS $*"
}

_fail() {
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  echo "[test-run-with-retry] FAIL $*" >&2
}

# ── helpers ───────────────────────────────────────────────────────────────────

# Fake command factory: writes a small stub that succeeds after N failures.
# Args: dest_path fail_count [exit_code_on_fail]
_make_flaky_cmd() {
  local dest="$1"
  local fail_count="$2"
  local fail_code="${3:-1}"
  local counter_file="${TMP_DIR}/counter_$(basename "$dest")"
  echo "0" > "$counter_file"
  cat > "$dest" <<EOF
#!/usr/bin/env bash
count=\$(cat "$counter_file")
count=\$(( count + 1 ))
echo "\$count" > "$counter_file"
if [[ \$count -le $fail_count ]]; then
  exit $fail_code
fi
exit 0
EOF
  chmod +x "$dest"
}

# ── fixture 1: succeeds on first attempt ──────────────────────────────────────
echo ""
echo "--- Fixture 1: command succeeds on attempt 1 ---"
CMD1="$TMP_DIR/cmd1.sh"
_make_flaky_cmd "$CMD1" 0  # 0 failures → always succeeds

STDOUT1="$TMP_DIR/out1.txt"
STDERR1="$TMP_DIR/err1.txt"
set +e
"$WRAPPER" --max-attempts 3 --delay-seconds 1 --max-total-seconds 30 -- "$CMD1" \
  >"$STDOUT1" 2>"$STDERR1"
EXIT1=$?
set -e

if [[ $EXIT1 -eq 0 ]]; then
  _pass "fixture 1: exit 0"
else
  _fail "fixture 1: expected exit 0, got $EXIT1"
fi

if grep -q "succeeded on attempt 1/3" "$STDERR1"; then
  _pass "fixture 1: 'succeeded on attempt 1/3' in stderr"
else
  _fail "fixture 1: expected 'succeeded on attempt 1/3' in stderr; got: $(cat "$STDERR1")"
fi

if ! grep -q "waiting" "$STDERR1"; then
  _pass "fixture 1: no retry delay emitted"
else
  _fail "fixture 1: unexpected retry delay message in stderr"
fi

# ── fixture 2: fails twice then succeeds on attempt 3 ─────────────────────────
echo ""
echo "--- Fixture 2: fails x2 (exit 1), succeeds on attempt 3 ---"
CMD2="$TMP_DIR/cmd2.sh"
_make_flaky_cmd "$CMD2" 2  # 2 failures → succeeds on call #3

STDERR2="$TMP_DIR/err2.txt"
set +e
# Fixture uses exit 1 for the flaky-then-success path; opt into retrying exit 1
# to exercise the retry-then-success path. Safe default (timeout-only) is
# proven separately by fixture 5.
"$WRAPPER" --max-attempts 3 --delay-seconds 1 --max-total-seconds 60 \
  --retry-on-exit-codes "1,124" -- "$CMD2" \
  >"$TMP_DIR/out2.txt" 2>"$STDERR2"
EXIT2=$?
set -e

if [[ $EXIT2 -eq 0 ]]; then
  _pass "fixture 2: exit 0"
else
  _fail "fixture 2: expected exit 0, got $EXIT2"
fi

if grep -q "succeeded on attempt 3/3" "$STDERR2"; then
  _pass "fixture 2: 'succeeded on attempt 3/3' in stderr"
else
  _fail "fixture 2: expected 'succeeded on attempt 3/3' in stderr; got: $(cat "$STDERR2")"
fi

RETRY_LINES=$(grep -c "waiting" "$STDERR2" || true)
if [[ $RETRY_LINES -eq 2 ]]; then
  _pass "fixture 2: exactly 2 retry-delay messages emitted"
else
  _fail "fixture 2: expected 2 retry-delay messages, got $RETRY_LINES; stderr: $(cat "$STDERR2")"
fi

# ── fixture 3: always fails → exits with last exit code ───────────────────────
echo ""
echo "--- Fixture 3: command always fails (max-attempts exhausted) ---"
CMD3="$TMP_DIR/cmd3.sh"
# Exit 1 is NOT in the safe-default retry-codes set; this fixture explicitly
# opts into retrying exit 1 so it can exercise the exhaustion path. The safe
# default (timeout-only) is proven by fixture 5 below.
_make_flaky_cmd "$CMD3" 99 1  # always returns exit 1 (retryable only when opted in)

STDERR3="$TMP_DIR/err3.txt"
set +e
"$WRAPPER" --max-attempts 2 --delay-seconds 1 --max-total-seconds 30 \
  --retry-on-exit-codes "1,124" -- "$CMD3" \
  >"$TMP_DIR/out3.txt" 2>"$STDERR3"
EXIT3=$?
set -e

if [[ $EXIT3 -ne 0 ]]; then
  _pass "fixture 3: propagated non-zero exit (last exit: $EXIT3)"
else
  _fail "fixture 3: expected non-zero exit, got 0"
fi

if grep -q "giving up after 2 attempt" "$STDERR3"; then
  _pass "fixture 3: 'giving up after 2 attempt(s)' in stderr"
else
  _fail "fixture 3: expected giving-up message in stderr; got: $(cat "$STDERR3")"
fi

# ── fixture 4: command hangs → max-total-seconds stops it ─────────────────────
echo ""
echo "--- Fixture 4: command hangs, stopped by --max-total-seconds ---"
# Use a real sleep longer than our total-second budget; wrap with GNU timeout
# so the subprocess is cleaned up. The wrapper itself sees exit 124 from timeout.
CMD4="$TMP_DIR/cmd4.sh"
cat > "$CMD4" <<'EOF'
#!/usr/bin/env bash
# Simulate a hanging process
sleep 600
EOF
chmod +x "$CMD4"

STDERR4="$TMP_DIR/err4.txt"
START4=$(date +%s)
set +e
# budget: 5s total, single attempt, command sleeps 600s → timeout kicks in
timeout 30 "$WRAPPER" \
  --max-attempts 1 \
  --delay-seconds 1 \
  --max-total-seconds 5 \
  --retry-on-exit-codes "124" \
  -- timeout 3 "$CMD4" \
  >"$TMP_DIR/out4.txt" 2>"$STDERR4"
EXIT4=$?
set -e
END4=$(date +%s)
ELAPSED4=$(( END4 - START4 ))

# exit code: timeout sub-command exits 124, wrapper propagates it
if [[ $EXIT4 -ne 0 ]]; then
  _pass "fixture 4: exited non-zero ($EXIT4) — did not hang"
else
  _fail "fixture 4: expected non-zero exit from hanging command, got 0"
fi

if [[ $ELAPSED4 -lt 30 ]]; then
  _pass "fixture 4: completed in ${ELAPSED4}s (well under 30s hang guard)"
else
  _fail "fixture 4: took ${ELAPSED4}s — possible hang regression"
fi

# ── fixture 5: safe-default — exit 1 is NOT retried ──────────────────────────
# Proves the SAFE-DEFAULT POLICY from run-with-retry.sh: if the caller does
# not pass --retry-on-exit-codes, exit 1 (the canonical "real finding" code
# for scanners) must propagate immediately without retry.
echo ""
echo "--- Fixture 5: default retry set does NOT include exit 1 (safe default) ---"
CMD5="$TMP_DIR/cmd5.sh"
_make_flaky_cmd "$CMD5" 99 1  # always returns exit 1

STDERR5="$TMP_DIR/err5.txt"
START5=$(date +%s)
set +e
# No --retry-on-exit-codes; default is "124" (timeout only).
"$WRAPPER" --max-attempts 5 --delay-seconds 10 --max-total-seconds 120 -- "$CMD5" \
  >"$TMP_DIR/out5.txt" 2>"$STDERR5"
EXIT5=$?
set -e
END5=$(date +%s)
ELAPSED5=$(( END5 - START5 ))

if [[ $EXIT5 -eq 1 ]]; then
  _pass "fixture 5: propagated exit 1 without retry (safe default)"
else
  _fail "fixture 5: expected exit 1 (propagated), got $EXIT5"
fi

if grep -q "non-retryable" "$STDERR5"; then
  _pass "fixture 5: stderr contains 'non-retryable' (default excludes exit 1)"
else
  _fail "fixture 5: expected 'non-retryable' in stderr; got: $(cat "$STDERR5")"
fi

if ! grep -q "waiting" "$STDERR5"; then
  _pass "fixture 5: no retry delay emitted (exit 1 propagates immediately)"
else
  _fail "fixture 5: unexpected retry delay — default must not retry exit 1"
fi

# Must be fast: no delay, no retry. Under 5s is generous (wrapper overhead only).
if [[ $ELAPSED5 -lt 5 ]]; then
  _pass "fixture 5: completed in ${ELAPSED5}s (no retry delay incurred)"
else
  _fail "fixture 5: took ${ELAPSED5}s — default must not add retry latency for exit 1"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Summary: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT}"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "[test-run-with-retry] FAILED" >&2
  exit 1
fi
echo "[test-run-with-retry] ALL FIXTURES PASSED"
