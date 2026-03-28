#!/usr/bin/env bash
# @covers AC-SLOT-014
# @spec: mfe-plugin-slots_spec.md
#
# verify-mfe-slot-profile-persistence.sh
# - Source contract checks for account/profile additional field slot wiring
# - Optional runtime persistence roundtrip against /api/user/v1/accounts/<username>
#
# Runtime mode (mutating, opt-in):
#   CHECK_RUNTIME=1 \
#   LMS_BASE_URL=https://academyv2.mereka.io \
#   PROFILE_USERNAME=<username> \
#   API_TOKEN=<token> \
#   API_AUTH_SCHEME="Bearer" \
#   scripts/qa/verify-mfe-slot-profile-persistence.sh
#
# Notes:
# - Runtime mode is disabled by default to avoid unintended mutations.
# - Script tries common Open edX payload shapes for profile updates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN_FILE="$PLUGIN_MAIN"

CHECK_RUNTIME="${CHECK_RUNTIME:-0}"
LMS_BASE_URL="${LMS_BASE_URL:-}"
PROFILE_USERNAME="${PROFILE_USERNAME:-}"
API_TOKEN="${API_TOKEN:-}"
API_AUTH_SCHEME="${API_AUTH_SCHEME:-Bearer}"
REQUEST_TIMEOUT_SECONDS="${REQUEST_TIMEOUT_SECONDS:-20}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $1"; }

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-profile.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN_FILE="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

echo "=== MFE Slot Profile Persistence Verification ==="

if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "Plugin source not found: $PLUGIN_FILE"
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  exit 1
fi

# Source-contract checks (non-mutating)
if rg -qF "org.openedx.frontend.account.additional_profile_fields.v1" "$PLUGIN_FILE" \
  && rg -qF "org.openedx.frontend.profile.additional_profile_fields.v1" "$PLUGIN_FILE"; then
  pass "Account/Profile additional profile field slot IDs are registered"
else
  fail "Account/Profile additional profile field slot IDs missing"
fi

if rg -qF "mereka_additional_profile_fields" "$PLUGIN_FILE" \
  && rg -qF "mereka_profile_additional_fields" "$PLUGIN_FILE" \
  && rg -qF "MerekaAdditionalProfileFields" "$PLUGIN_FILE"; then
  pass "Account/Profile slots bind to MerekaAdditionalProfileFields component"
else
  fail "Slot-to-component binding markers for additional profile fields missing"
fi

if rg -qF "const MerekaLearningShellContextCard = ({" "$PLUGIN_FILE" \
  && rg -qF "const MerekaLearningShellContextMetaItem = ({ label, value }) => (" "$PLUGIN_FILE" \
  && rg -qF "className=\"mereka-additional-profile-fields mereka-progress-certificate-status mereka-shell-panel mb-3\"" "$PLUGIN_FILE" \
  && rg -qF "<MerekaLearningShellContextMetaItem label=\"Organization\" value={variant.brand} />" "$PLUGIN_FILE" \
  && rg -qF "<MerekaLearningShellContextMetaItem label=\"Job title\" value=\"Pending admin sync\" />" "$PLUGIN_FILE" \
  && rg -qF "<MerekaLearningShellContextMetaItem label=\"Department\" value=\"Pending admin sync\" />" "$PLUGIN_FILE"; then
  pass "Additional profile field UI markers present via canonical context-card meta rows"
else
  fail "Additional profile field UI markers missing"
fi

if [[ "$CHECK_RUNTIME" != "1" ]]; then
  warn "Runtime persistence roundtrip skipped (set CHECK_RUNTIME=1 to enable mutating API validation)"
  echo ""
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  [[ "$FAIL" -eq 0 ]]
  exit $?
fi

# Runtime checks (mutating; explicit opt-in)
if [[ -z "$LMS_BASE_URL" || -z "$PROFILE_USERNAME" || -z "$API_TOKEN" ]]; then
  fail "CHECK_RUNTIME=1 requires LMS_BASE_URL, PROFILE_USERNAME, and API_TOKEN"
  echo ""
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  exit 1
fi

ACCOUNT_URL="${LMS_BASE_URL%/}/api/user/v1/accounts/${PROFILE_USERNAME}"
AUTH_HEADER="Authorization: ${API_AUTH_SCHEME} ${API_TOKEN}"

tmpdir="$(mktemp -d -t slot-profile-runtime.XXXXXX)"
trap 'rm -rf "$tmpdir"; cleanup' EXIT

http_get() {
  local url="$1"
  local out_file="$2"
  local code
  code="$(
    curl -sS --connect-timeout "$REQUEST_TIMEOUT_SECONDS" --max-time "$REQUEST_TIMEOUT_SECONDS" \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -o "$out_file" -w "%{http_code}" \
      "$url" || true
  )"
  echo "$code"
}

http_patch() {
  local url="$1"
  local payload="$2"
  local out_file="$3"
  local code
  code="$(
    curl -sS --connect-timeout "$REQUEST_TIMEOUT_SECONDS" --max-time "$REQUEST_TIMEOUT_SECONDS" \
      -X PATCH \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      -o "$out_file" -w "%{http_code}" \
      "$url" || true
  )"
  echo "$code"
}

before_json="$tmpdir/before.json"
after_json="$tmpdir/after.json"
patch_resp="$tmpdir/patch.json"

before_code="$(http_get "$ACCOUNT_URL" "$before_json")"
if [[ "$before_code" == "200" ]]; then
  pass "Runtime precheck: GET $ACCOUNT_URL returned 200"
else
  fail "Runtime precheck: GET $ACCOUNT_URL returned HTTP $before_code"
  echo ""
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  exit 1
fi

suffix="$(date +%s)"
org_val="Mereka QA ${suffix}"
job_val="QA Engineer ${suffix}"
dept_val="Platform QA ${suffix}"

payloads=(
  "{\"profile\":{\"organization\":\"${org_val}\",\"job_title\":\"${job_val}\",\"department\":\"${dept_val}\"}}"
  "{\"profile\":{\"organization\":\"${org_val}\",\"jobTitle\":\"${job_val}\",\"department\":\"${dept_val}\"}}"
  "{\"organization\":\"${org_val}\",\"job_title\":\"${job_val}\",\"department\":\"${dept_val}\"}"
)

patch_ok=0
for payload in "${payloads[@]}"; do
  patch_code="$(http_patch "$ACCOUNT_URL" "$payload" "$patch_resp")"
  if [[ "$patch_code" == "200" || "$patch_code" == "204" ]]; then
    patch_ok=1
    pass "Runtime persistence: PATCH accepted with HTTP $patch_code"
    break
  fi
done

if [[ "$patch_ok" -ne 1 ]]; then
  fail "Runtime persistence: no supported PATCH payload shape accepted by $ACCOUNT_URL"
  echo ""
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  exit 1
fi

after_code="$(http_get "$ACCOUNT_URL" "$after_json")"
if [[ "$after_code" == "200" ]]; then
  pass "Runtime postcheck: GET $ACCOUNT_URL returned 200"
else
  fail "Runtime postcheck: GET $ACCOUNT_URL returned HTTP $after_code"
  echo ""
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  exit 1
fi

if rg -qF "$org_val" "$after_json" && rg -qF "$dept_val" "$after_json"; then
  pass "Runtime persistence: updated profile values are present in readback payload"
else
  fail "Runtime persistence: updated values not found in readback payload"
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
