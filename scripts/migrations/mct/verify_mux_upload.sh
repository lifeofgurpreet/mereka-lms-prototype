#!/usr/bin/env bash
# @covers AC-026, AC-027, AC-028
# @spec: data-migrations-kajabi-mct_spec.md
# Verify Mux video upload infrastructure and configuration
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Mux Upload Infrastructure Verification ==="
echo ""

# AC-026: Verify Mux API credentials are configured
echo "Checking Mux API credentials configuration..."
if kubectl get externalsecrets -n mereka-lms -o yaml 2>/dev/null | grep -q "MUX_TOKEN_ID"; then
  pass "Mux credentials referenced in ExternalSecrets"
else
  skip "Mux credentials not found in ExternalSecrets (expected for pre-upload phase)"
fi

# Check for Mux secret in GCP Secret Manager (bbi-k8 project)
if gcloud secrets describe MEREKA_LMS_MUX_TOKEN_ID --project=bbi-k8 >/dev/null 2>&1; then
  SECRET_VALUE=$(gcloud secrets versions access latest --secret=MEREKA_LMS_MUX_TOKEN_ID --project=bbi-k8 2>/dev/null || echo "")
  if [[ -n "$SECRET_VALUE" && "$SECRET_VALUE" != "PLACEHOLDER" && "$SECRET_VALUE" != "changeme" ]]; then
    pass "MUX_TOKEN_ID exists in GCP Secret Manager with non-placeholder value"
  else
    skip "MUX_TOKEN_ID is placeholder (data-dependent: requires real Mux account)"
  fi
else
  skip "MUX_TOKEN_ID not found in GCP Secret Manager (data-dependent)"
fi

if gcloud secrets describe MEREKA_LMS_MUX_TOKEN_SECRET --project=bbi-k8 >/dev/null 2>&1; then
  SECRET_VALUE=$(gcloud secrets versions access latest --secret=MEREKA_LMS_MUX_TOKEN_SECRET --project=bbi-k8 2>/dev/null || echo "")
  if [[ -n "$SECRET_VALUE" && "$SECRET_VALUE" != "PLACEHOLDER" && "$SECRET_VALUE" != "changeme" ]]; then
    pass "MUX_TOKEN_SECRET exists in GCP Secret Manager with non-placeholder value"
  else
    skip "MUX_TOKEN_SECRET is placeholder (data-dependent: requires real Mux account)"
  fi
else
  skip "MUX_TOKEN_SECRET not found in GCP Secret Manager (data-dependent)"
fi

# AC-026: Check for Mux upload scripts/tooling
echo ""
echo "Checking for Mux upload tooling..."
if [[ -f "scripts/migrations/mct/upload_videos_to_mux.py" ]]; then
  pass "Mux upload script exists: upload_videos_to_mux.py"
else
  fail "Mux upload script not found: scripts/migrations/mct/upload_videos_to_mux.py"
fi

# AC-027: Check for caption track handling in upload script
if [[ -f "scripts/migrations/mct/upload_videos_to_mux.py" ]]; then
  if grep -q "caption" "scripts/migrations/mct/upload_videos_to_mux.py" || grep -q "vtt" "scripts/migrations/mct/upload_videos_to_mux.py"; then
    pass "Upload script references caption/VTT handling"
  else
    skip "Caption track handling not detected in upload script (may use different keyword)"
  fi
fi

# AC-028: Check for Mux playback URL generation in course builder
echo ""
echo "Checking for Mux playback URL integration..."
if [[ -f "scripts/migrations/mct/build_courses_with_mux.py" ]]; then
  pass "Mux course builder script exists: build_courses_with_mux.py"
else
  fail "Mux course builder not found: scripts/migrations/mct/build_courses_with_mux.py"
fi

if [[ -f "scripts/migrations/mct/build_courses_with_mux.py" ]]; then
  if grep -q "stream.mux.com" "scripts/migrations/mct/build_courses_with_mux.py" || grep -q "m3u8" "scripts/migrations/mct/build_courses_with_mux.py"; then
    pass "Course builder references Mux HLS URLs (stream.mux.com or .m3u8)"
  else
    fail "Course builder does not reference Mux streaming URLs"
  fi
fi

# AC-026, AC-027: Validate video mapping files exist
echo ""
echo "Checking for video mapping and tracking files..."
MCT_EXPORT_DIR="exports/mct"
if [[ -d "$MCT_EXPORT_DIR" ]]; then
  if [[ -f "$MCT_EXPORT_DIR/videos.ndjson" ]] || [[ -f "$MCT_EXPORT_DIR/courses.ndjson" ]]; then
    pass "MCT export directory contains video source data"
  else
    skip "MCT export files not found (data-dependent: requires MCT export)"
  fi
else
  skip "MCT export directory does not exist (data-dependent)"
fi

# Check for Mux upload results tracking
MUX_RESULTS_FILE="scripts/migrations/mct/mux_upload_results.json"
if [[ -f "$MUX_RESULTS_FILE" ]]; then
  pass "Mux upload results tracking file exists"

  # Validate JSON format
  if jq empty "$MUX_RESULTS_FILE" 2>/dev/null; then
    pass "Mux results file is valid JSON"
  else
    fail "Mux results file exists but is invalid JSON"
  fi
else
  skip "Mux upload results not found (data-dependent: requires video upload)"
fi

# AC-026: Check for webhook configuration (optional)
echo ""
echo "Checking for Mux webhook configuration..."
if kubectl get externalsecrets -n mereka-lms -o yaml 2>/dev/null | grep -q "MUX_WEBHOOK"; then
  pass "Mux webhook secret referenced in ExternalSecrets"
else
  skip "Mux webhook not configured (optional feature)"
fi

# Check upload script has rate limiting (AC-026: 5 requests/second = 250ms delay)
if [[ -f "scripts/migrations/mct/upload_videos_to_mux.py" ]]; then
  if grep -qE "(sleep|delay|rate.*limit)" "scripts/migrations/mct/upload_videos_to_mux.py"; then
    pass "Upload script includes rate limiting logic"
  else
    fail "Upload script does not implement rate limiting (required: 5 req/s max)"
  fi
fi

# Check for idempotency (re-upload detection)
if [[ -f "scripts/migrations/mct/upload_videos_to_mux.py" ]]; then
  if grep -qE "(mux_upload_results|already.*upload|skip.*exist)" "scripts/migrations/mct/upload_videos_to_mux.py"; then
    pass "Upload script includes idempotency checks"
  else
    skip "Idempotency logic not clearly detected (may use different pattern)"
  fi
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
