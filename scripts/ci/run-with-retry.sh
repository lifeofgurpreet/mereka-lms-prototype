#!/usr/bin/env bash
# run-with-retry.sh — bounded-retry wrapper for transient tool failures.
#
# Wraps a command with configurable retry logic bounded by both attempt count
# AND total elapsed time. Designed to absorb transient Trivy/Cosign/SBOM
# failures that would otherwise gate the promotion dispatch chain.
#
# Usage:
#   run-with-retry.sh [OPTIONS] -- COMMAND [ARGS...]
#
# Options:
#   --max-attempts N         Maximum number of attempts (default: 3)
#   --delay-seconds N        Base delay between retries in seconds; grows
#                            exponentially: delay * 2^(attempt-1) (default: 10)
#   --max-total-seconds N    Hard wall-clock limit across all attempts (default: 300)
#   --retry-on-exit-codes X  Comma-separated list of exit codes that trigger
#                            retry (default: "124" — timeout only). All other
#                            exit codes propagate immediately without retry.
#
# Behaviour:
#   - Exits 0 on success; prints "[run-with-retry] succeeded on attempt N/M" to stderr.
#   - On each retryable failure: prints attempt/exit/delay info to stderr and waits.
#   - After exhausting attempts OR exceeding max-total-seconds: prints giving-up
#     message to stderr and exits with the last command's exit code.
#   - Non-retryable exit codes propagate immediately (no retry, no extra delay).
#   - Does NOT swallow stdout/stderr from the wrapped command.
#
# SAFE-DEFAULT POLICY:
#   The default retry set is "124" (GNU timeout's wall-clock-expiry exit code),
#   NOT exit 1. Exit 1 is the canonical "real failure" code for most scanners
#   and policy tools — Trivy, pip-audit, Cosign, TruffleHog, and gitleaks all
#   use exit 1 to mean "a real finding was discovered". If exit 1 is in the
#   retry set, a single transient hiccup can get retried, but so can a real
#   vulnerability finding, which can get a green build when the scan should
#   have failed. Callers that genuinely want to retry transient exit-1
#   conditions (e.g. a network-fetch step that returns 1 on transient DNS
#   failure) MUST pass --retry-on-exit-codes "1" or "1,124" explicitly so the
#   intent is visible at the call site.
#
# Example (wrapping trivy — only timeout is retried, real findings fail fast):
#   run-with-retry.sh --max-attempts 3 --delay-seconds 15 \
#     --max-total-seconds 600 --retry-on-exit-codes "124" \
#     -- timeout 300 trivy image --exit-code 1 --severity HIGH,CRITICAL "$IMAGE"
#
# Example (transient network fetch — caller explicitly opts into retrying exit 1):
#   run-with-retry.sh --max-attempts 3 --retry-on-exit-codes "1" \
#     -- curl -fsSL "$REGISTRY_META_URL" -o /tmp/meta.json
#
# Bead: mereka-lms-lb4c.2 (S6 promotion reliability)
set -euo pipefail

# ── defaults ──────────────────────────────────────────────────────────────────
MAX_ATTEMPTS=3
DELAY_SECONDS=10
MAX_TOTAL_SECONDS=300
# Default to timeout-only. See SAFE-DEFAULT POLICY above for why exit 1 is
# deliberately NOT retried by default.
RETRY_CODES="124"

# ── argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-attempts)
      MAX_ATTEMPTS="$2"; shift 2 ;;
    --delay-seconds)
      DELAY_SECONDS="$2"; shift 2 ;;
    --max-total-seconds)
      MAX_TOTAL_SECONDS="$2"; shift 2 ;;
    --retry-on-exit-codes)
      RETRY_CODES="$2"; shift 2 ;;
    --)
      shift; break ;;
    *)
      echo "[run-with-retry] ERROR: unknown option: $1" >&2
      exit 2 ;;
  esac
done

if [[ $# -eq 0 ]]; then
  echo "[run-with-retry] ERROR: no command provided after --" >&2
  exit 2
fi

# Build a lookup set for retryable codes
declare -A _RETRY_SET
IFS=',' read -ra _CODE_LIST <<< "$RETRY_CODES"
for _c in "${_CODE_LIST[@]}"; do
  _RETRY_SET["${_c// /}"]="1"
done

# ── helpers ───────────────────────────────────────────────────────────────────
_now_seconds() {
  date +%s
}

_is_retryable() {
  local code="$1"
  [[ -n "${_RETRY_SET[$code]+x}" ]]
}

# ── retry loop ────────────────────────────────────────────────────────────────
START_TIME=$(_now_seconds)
ATTEMPT=0
LAST_EXIT=1

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
  ATTEMPT=$(( ATTEMPT + 1 ))

  # Elapsed check before each attempt
  ELAPSED=$(( $(_now_seconds) - START_TIME ))
  if [[ $ELAPSED -ge $MAX_TOTAL_SECONDS ]]; then
    echo "[run-with-retry] total time limit ${MAX_TOTAL_SECONDS}s exceeded before attempt ${ATTEMPT}/${MAX_ATTEMPTS}; giving up" >&2
    exit "$LAST_EXIT"
  fi

  # Run the command; capture exit code without aborting on failure
  LAST_EXIT=0
  "$@" || LAST_EXIT=$?

  if [[ $LAST_EXIT -eq 0 ]]; then
    echo "[run-with-retry] succeeded on attempt ${ATTEMPT}/${MAX_ATTEMPTS}" >&2
    exit 0
  fi

  # Determine whether this exit code is retryable
  if ! _is_retryable "$LAST_EXIT"; then
    echo "[run-with-retry] attempt ${ATTEMPT}/${MAX_ATTEMPTS} failed with exit ${LAST_EXIT} (non-retryable); aborting" >&2
    exit "$LAST_EXIT"
  fi

  if [[ $ATTEMPT -ge $MAX_ATTEMPTS ]]; then
    break
  fi

  # Exponential backoff: delay * 2^(attempt-1); cap to remaining budget
  BACKOFF=$(( DELAY_SECONDS * (1 << (ATTEMPT - 1)) ))
  ELAPSED=$(( $(_now_seconds) - START_TIME ))
  REMAINING=$(( MAX_TOTAL_SECONDS - ELAPSED ))
  if [[ $BACKOFF -gt $REMAINING ]]; then
    BACKOFF=$REMAINING
  fi
  if [[ $BACKOFF -le 0 ]]; then
    echo "[run-with-retry] total time limit ${MAX_TOTAL_SECONDS}s exceeded after attempt ${ATTEMPT}/${MAX_ATTEMPTS}; giving up" >&2
    exit "$LAST_EXIT"
  fi

  echo "[run-with-retry] attempt ${ATTEMPT}/${MAX_ATTEMPTS} failed with exit ${LAST_EXIT}; waiting ${BACKOFF}s before retry" >&2
  sleep "$BACKOFF"
done

echo "[run-with-retry] giving up after ${ATTEMPT} attempt(s); last exit code: ${LAST_EXIT}" >&2
exit "$LAST_EXIT"
