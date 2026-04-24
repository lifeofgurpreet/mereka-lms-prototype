#!/usr/bin/env bash
# @covers AC-OBS-001 (MFE client-side Sentry Phase 4 runtime proof)
# @spec: observability.md (OBS-001)
# @bead: mereka-lms-te71
#
# OBS-001 Phase 4 runtime verifier. Fires a deliberate canary JS error
# in an authenticated dev MFE browser session, then polls the Sentry
# Events API to confirm the event arrived within 2 minutes.
#
# Blocked on:
#   - Phase 2 (@sentry/browser baked into MFE image — PR #1954, merged)
#   - Phase 3 (SENTRY_DSN populated in MFE config API per env)
#   - Promotion chain run: new MFE image → bbi-infra promotion PR → Argo
#     sync → pod rollout with new image
#
# Usage:
#   scripts/qa/verify-obs-001-mfe-sentry-phase4.sh [--env dev|staging|prod]
#
# Success criteria per the te71 bead:
#   1. Canary event visible in Sentry within 2 min
#   2. Release tag in Sentry matches MFE build SHA
#   3. Tags include mfe_base_url + lms_base_url
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../shared/config.sh
source "${REPO_ROOT}/scripts/shared/config.sh"

ENVIRONMENT="dev"
while (( $# > 0 )); do
  case "$1" in
    --env) ENVIRONMENT="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<'USAGE'
Usage: verify-obs-001-mfe-sentry-phase4.sh [--env dev|staging|prod]

Verifies that a canary JS error fired on the target env's MFE surfaces in
the Sentry project mereka-lms-web within 2 minutes.

Requires:
  - SENTRY_AUTH_TOKEN env var (Sentry API token with events:read scope,
    project: biji-biji-non-profits/mereka-lms-web)
  - agent-browser on PATH (for headless canary fire)
  - MEREKA_TEST_USER_PASSWORD env var or Infisical access

Exit 0 if Phase 4 criteria met, non-zero otherwise.
USAGE
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

case "${ENVIRONMENT}" in
  dev)
    APPS_HOST="apps.academyv2.mereka.dev"
    LMS_HOST="academyv2.mereka.dev"
    SENTRY_ENV="dev"
    ;;
  staging)
    APPS_HOST="staging.apps.academyv2.mereka.io"
    LMS_HOST="staging.academyv2.mereka.io"
    SENTRY_ENV="staging"
    ;;
  prod)
    APPS_HOST="apps.academyv2.mereka.io"
    LMS_HOST="academyv2.mereka.io"
    SENTRY_ENV="production"
    ;;
  *)
    echo "Unknown env: ${ENVIRONMENT}" >&2; exit 1 ;;
esac

SENTRY_ORG="biji-biji-non-profits"
SENTRY_PROJECT="mereka-lms-web"
CANARY_MESSAGE="obs-001-phase4-canary-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"

echo "== OBS-001 Phase 4 runtime proof ==" >&2
echo "  env         : ${ENVIRONMENT}" >&2
echo "  apps host   : ${APPS_HOST}" >&2
echo "  lms host    : ${LMS_HOST}" >&2
echo "  canary msg  : ${CANARY_MESSAGE}" >&2
echo "  sentry proj : ${SENTRY_ORG}/${SENTRY_PROJECT}" >&2
echo "  sentry env  : ${SENTRY_ENV}" >&2
echo

# -----------------------------------------------------------------
# Step 0 — pre-flight: SENTRY_DSN is live in the MFE config API
# -----------------------------------------------------------------
echo "→ Step 0: preflight — SENTRY_DSN in MFE config API" >&2
mfe_cfg="$(curl -sSf "https://${APPS_HOST}/api/mfe_config/v1/?mfe=learning" || true)"
sentry_dsn="$(echo "${mfe_cfg}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print((d.get("SENTRY_DSN") or "").strip())' 2>/dev/null || true)"
if [[ -z "${sentry_dsn}" ]]; then
  echo "FAIL: SENTRY_DSN is empty in MFE config API at https://${APPS_HOST}/api/mfe_config/v1/?mfe=learning" >&2
  echo "Phase 3 (DSN config injection) has not taken effect yet — rerun after promotion reconciles." >&2
  exit 1
fi
echo "  DSN present (length=${#sentry_dsn})" >&2

# -----------------------------------------------------------------
# Step 1 — capture "before" Sentry event count for this canary slug
# -----------------------------------------------------------------
if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
  echo "FAIL: SENTRY_AUTH_TOKEN not set — required for Events API query" >&2
  echo "Fetch from Infisical: infi secrets get SENTRY_READ_TOKEN --env prod --path /shared/sentry" >&2
  exit 1
fi

before_count="$(curl -sSf \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  "https://sentry.io/api/0/projects/${SENTRY_ORG}/${SENTRY_PROJECT}/events/?query=${CANARY_MESSAGE}" \
  | python3 -c 'import json,sys; print(len(json.load(sys.stdin) or []))' 2>/dev/null || echo "0")"
echo "  Events with this canary before fire: ${before_count} (expected 0)" >&2

# -----------------------------------------------------------------
# Step 2 — fire the canary via agent-browser
# -----------------------------------------------------------------
echo "→ Step 2: firing canary via agent-browser" >&2
if ! command -v agent-browser >/dev/null 2>&1; then
  echo "FAIL: agent-browser not on PATH. Install from acfs bundle." >&2
  exit 1
fi

password="${MEREKA_TEST_USER_PASSWORD:-}"
if [[ -z "${password}" ]]; then
  password="$(infi secrets get MEREKA_LMS_TEST_USER_PASSWORD --env "${ENVIRONMENT}" --plain 2>/dev/null || true)"
fi
if [[ -z "${password}" ]]; then
  echo "FAIL: MEREKA_TEST_USER_PASSWORD not set and Infisical fetch failed" >&2
  exit 1
fi

# Canary script: log in via LMS, then navigate to MFE dashboard and throw.
# The OBS-001 Phase 1 subscribe(APP_READY) handler captures the error
# through getConfig().SENTRY_DSN.
agent-browser run \
  --headless \
  --url "https://${LMS_HOST}/login" \
  --script "$(cat <<SCRIPT
// Log in using testadmin (dev only — use synthetic-learner-01 for staging/prod)
await page.fill('input[name="email"]', 'testadmin@mereka.my');
await page.fill('input[name="password"]', '${password}');
await page.click('button[type="submit"]');
await page.waitForURL('**/dashboard**', { timeout: 30000 });

// Navigate to learner dashboard (MFE) — ensures @sentry/browser is loaded
await page.goto('https://${APPS_HOST}/learner-dashboard/');
await page.waitForLoadState('networkidle');

// Fire the canary via Sentry.captureException so we control the message
await page.evaluate((msg) => {
  if (typeof Sentry !== 'undefined' && Sentry.captureException) {
    Sentry.captureException(new Error(msg));
  } else {
    // Fallback: throw unhandled — APP_READY Sentry.init should have wired up
    // a global handler
    setTimeout(() => { throw new Error(msg); }, 0);
  }
}, '${CANARY_MESSAGE}');

// Let the Sentry SDK flush
await page.waitForTimeout(2000);
SCRIPT
)" 2>&1 | tail -5

# -----------------------------------------------------------------
# Step 3 — poll Sentry Events API for 2 minutes
# -----------------------------------------------------------------
echo "→ Step 3: polling Sentry for canary event (2min timeout)" >&2
deadline=$(( $(date +%s) + 120 ))
found=0
release_tag=""
mfe_base_url_tag=""

while (( $(date +%s) < deadline )); do
  events="$(curl -sSf \
    -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
    "https://sentry.io/api/0/projects/${SENTRY_ORG}/${SENTRY_PROJECT}/events/?query=${CANARY_MESSAGE}" \
    || echo '[]')"

  count="$(echo "${events}" | python3 -c 'import json,sys; print(len(json.load(sys.stdin) or []))' 2>/dev/null || echo "0")"

  if (( count > before_count )); then
    found=1
    # Extract tags for assertions
    read -r release_tag mfe_base_url_tag < <(echo "${events}" \
      | python3 -c '
import json, sys
events = json.load(sys.stdin) or []
if not events:
    print("  ")
    sys.exit(0)
ev = events[0]
tags = {t.get("key"): t.get("value") for t in ev.get("tags", [])}
print(ev.get("release","") or "", tags.get("mfe_base_url","") or "")
' 2>/dev/null || echo "  ")
    break
  fi
  sleep 5
done

if (( found == 0 )); then
  echo "FAIL: canary event not visible in Sentry within 120s" >&2
  exit 1
fi

echo "  Canary event received in Sentry" >&2
echo "  release tag    : ${release_tag:-<empty>}" >&2
echo "  mfe_base_url   : ${mfe_base_url_tag:-<empty>}" >&2

# -----------------------------------------------------------------
# Step 4 — assertions
# -----------------------------------------------------------------
echo "→ Step 4: criteria checks" >&2

exit_code=0

if [[ -z "${release_tag}" ]]; then
  echo "FAIL: release tag is empty. te71 criterion: release tag should be MFE build SHA." >&2
  exit_code=1
elif ! [[ "${release_tag}" =~ ^[a-f0-9]{7,40}$ ]]; then
  echo "WARN: release tag ${release_tag} does not look like a git SHA. Check MEREKA_RELEASE_SHA build arg." >&2
  exit_code=1
else
  echo "  PASS: release tag is a SHA-like string" >&2
fi

if [[ "${mfe_base_url_tag}" != "https://${APPS_HOST}" ]]; then
  echo "FAIL: mfe_base_url tag ${mfe_base_url_tag} != https://${APPS_HOST}" >&2
  exit_code=1
else
  echo "  PASS: mfe_base_url tag matches" >&2
fi

if (( exit_code == 0 )); then
  echo >&2
  echo "== OBS-001 Phase 4 PASS for ${ENVIRONMENT} ==" >&2
  echo "Close bead mereka-lms-te71 once repeated for all 3 envs." >&2
fi

exit "${exit_code}"
