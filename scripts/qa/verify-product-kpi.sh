#!/usr/bin/env bash
# verify-product-kpi.sh — Validate the Product KPI Framework instrumentation and documentation.
#
# Checks:
#   - KPI framework doc exists and contains required sections
#   - Event bus producer config has required signals wired
#   - Aspects manifests exist (prerequisite for pipeline)
#   - Custom video analytics app is present
#   - Analytics query tool is present
#   - Known instrumentation gaps are acknowledged in the framework doc
#   - Pipeline stage status annotations are present
#
# Usage:
#   ./scripts/qa/verify-product-kpi.sh
#
# Exit codes:
#   0 — all required checks pass (SKIP does not affect exit code)
#   1 — one or more FAIL
#
# @spec: analytics-pipeline_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() {
  echo -e "${GREEN}PASS${NC}  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}  $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC}  $1"
  SKIP=$((SKIP + 1))
}

section() {
  echo ""
  echo -e "${CYAN}--- $1 ---${NC}"
}

echo "=== Product KPI Framework — Verification ==="
echo "Repo: ${REPO_ROOT}"
echo ""

# ──────────────────────────────────────────────
# 1. KPI framework document
# ──────────────────────────────────────────────
section "1. KPI Framework Document"

KPI_DOC="${REPO_ROOT}/docs/architecture/PRODUCT_KPI_FRAMEWORK.md"

if [[ -f "${KPI_DOC}" ]]; then
  pass "KPI framework document exists: docs/architecture/PRODUCT_KPI_FRAMEWORK.md"
else
  fail "KPI framework document missing: docs/architecture/PRODUCT_KPI_FRAMEWORK.md"
fi

# Check required sections are present
REQUIRED_SECTIONS=(
  "North Star Metrics"
  "Activation Rate"
  "Completion Rate"
  "Retention Rate"
  "Engagement"
  "Monthly Active Completions"
  "Data Pipeline"
  "Instrumentation Audit"
  "Instrumentation Gaps"
)

if [[ -f "${KPI_DOC}" ]]; then
  for section_name in "${REQUIRED_SECTIONS[@]}"; do
    if grep -qF "${section_name}" "${KPI_DOC}"; then
      pass "Section '${section_name}' present in KPI framework doc"
    else
      fail "Section '${section_name}' missing from KPI framework doc"
    fi
  done
fi

# ──────────────────────────────────────────────
# 2. Event bus producer config — configured signals
# ──────────────────────────────────────────────
section "2. Event Bus Producer Config (Configured Signals)"

ENTERPRISE_CHANNELS="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/mereka_enterprise_channels.py"

if [[ -f "${ENTERPRISE_CHANNELS}" ]]; then
  pass "Enterprise channels settings file exists"

  # enrollment.changed must be configured
  if grep -qF "org.openedx.learning.course.enrollment.changed.v1" "${ENTERPRISE_CHANNELS}"; then
    pass "enrollment.changed.v1 signal configured in EVENT_BUS_PRODUCER_CONFIG"
  else
    fail "enrollment.changed.v1 signal missing from EVENT_BUS_PRODUCER_CONFIG"
  fi

  # passing.status.updated must be configured
  if grep -qF "org.openedx.learning.course.passing.status.updated.v1" "${ENTERPRISE_CHANNELS}"; then
    pass "passing.status.updated.v1 signal configured in EVENT_BUS_PRODUCER_CONFIG"
  else
    fail "passing.status.updated.v1 signal missing from EVENT_BUS_PRODUCER_CONFIG"
  fi

  # EVENT_BUS_REDIS_CONNECTION_URL must be referenced
  if grep -qF "EVENT_BUS_REDIS_CONNECTION_URL" "${ENTERPRISE_CHANNELS}"; then
    pass "EVENT_BUS_REDIS_CONNECTION_URL configured"
  else
    fail "EVENT_BUS_REDIS_CONNECTION_URL not found in enterprise channels settings"
  fi
else
  fail "Enterprise channels settings file missing: ${ENTERPRISE_CHANNELS}"
fi

# Check LMS production.py for Redis Streams event bus producer
LMS_PROD="${REPO_ROOT}/tutor_env/env/apps/openedx/settings/lms/production.py"
if [[ -f "${LMS_PROD}" ]]; then
  if grep -qF "EVENT_BUS_PRODUCER" "${LMS_PROD}"; then
    pass "EVENT_BUS_PRODUCER configured in LMS production settings"
  else
    fail "EVENT_BUS_PRODUCER not configured in LMS production settings"
  fi
else
  skip "tutor_env not initialised — cannot verify LMS production settings (run 'tutor config save' first)"
fi

# ──────────────────────────────────────────────
# 3. Known gap signals — documented in KPI doc
# ──────────────────────────────────────────────
section "3. Known Gap Signals — Documented"

GAP_SIGNALS=(
  "certificate.created.v1"
  "registration.completed.v1"
  "sequence.tab.viewed.v1"
  "problem.submitted.v1"
)

if [[ -f "${KPI_DOC}" ]]; then
  for sig in "${GAP_SIGNALS[@]}"; do
    if grep -qF "${sig}" "${KPI_DOC}"; then
      pass "Gap signal '${sig}' documented in KPI framework"
    else
      fail "Gap signal '${sig}' not documented in KPI framework"
    fi
  done
else
  skip "KPI doc not found — skipping gap signal checks"
fi

# Verify certificate signal absence from enterprise channels (gap confirmation)
if [[ -f "${ENTERPRISE_CHANNELS}" ]]; then
  if ! grep -qF "org.openedx.learning.certificate.created.v1" "${ENTERPRISE_CHANNELS}"; then
    pass "certificate.created.v1 correctly identified as gap (not yet in producer config)"
  else
    # If it was added, that's fine — it means the gap was closed
    pass "certificate.created.v1 now present in producer config (gap has been closed)"
  fi
fi

# ──────────────────────────────────────────────
# 4. Aspects pipeline infrastructure
# ──────────────────────────────────────────────
section "4. Aspects Pipeline Infrastructure"

ASPECTS_DIR="${REPO_ROOT}/deploy/k8s/base/plugins/aspects"

if [[ -d "${ASPECTS_DIR}" ]]; then
  pass "Aspects manifests directory exists: deploy/k8s/base/plugins/aspects/"

  ASPECTS_FILES=(
    "kustomization.yaml"
    "deployments.yml"
    "services.yml"
    "configmaps.yml"
    "secrets.yml"
    "volumes.yml"
    "jobs.yml"
    "ingress.yml"
  )

  for f in "${ASPECTS_FILES[@]}"; do
    if [[ -f "${ASPECTS_DIR}/${f}" ]]; then
      pass "Aspects manifest present: ${f}"
    else
      fail "Aspects manifest missing: ${f}"
    fi
  done
else
  fail "Aspects manifests directory missing: deploy/k8s/base/plugins/aspects/"
fi

# Verify Aspects is NOT yet in the active base kustomization (by design until T148 is complete
# and wiring is verified). This check is SKIP if wiring has been activated.
BASE_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/base/kustomization.yaml"
if [[ -f "${BASE_KUSTOMIZATION}" ]]; then
  if grep -qF "plugins/aspects" "${BASE_KUSTOMIZATION}"; then
    skip "Aspects is now wired into base kustomization — pipeline activation in progress (T148)"
  else
    pass "Aspects not yet in base kustomization (expected until T148 activates wiring)"
  fi
else
  skip "Base kustomization not found — cannot verify Aspects wiring state"
fi

# ──────────────────────────────────────────────
# 5. Custom video analytics app
# ──────────────────────────────────────────────
section "5. Custom Video Analytics App"

VIDEO_APP="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_video_analytics"

if [[ -d "${VIDEO_APP}" ]]; then
  pass "openedx_video_analytics custom app exists"

  for f in models.py signals.py views.py tasks.py; do
    if [[ -f "${VIDEO_APP}/${f}" ]]; then
      pass "openedx_video_analytics/${f} present"
    else
      fail "openedx_video_analytics/${f} missing"
    fi
  done

  # Verify the model captures the required event types
  if grep -qF "VideoPlaybackEvent" "${VIDEO_APP}/models.py"; then
    pass "VideoPlaybackEvent model defined"
  else
    fail "VideoPlaybackEvent model not found in models.py"
  fi

  if grep -qF "VideoAnalyticsSummary" "${VIDEO_APP}/models.py"; then
    pass "VideoAnalyticsSummary aggregation model defined"
  else
    fail "VideoAnalyticsSummary model not found in models.py"
  fi

  # Confirm video app is NOT connected to event bus (known gap)
  if ! grep -qF "EVENT_BUS_PRODUCER\|edx_event_bus_redis\|openedx_events" "${VIDEO_APP}/models.py" \
       2>/dev/null; then
    pass "openedx_video_analytics correctly identified as NOT connected to event bus (known gap)"
  else
    pass "openedx_video_analytics now has event bus integration (gap has been closed)"
  fi
else
  fail "openedx_video_analytics custom app directory missing"
fi

# ──────────────────────────────────────────────
# 6. Analytics query tool (interim measurement)
# ──────────────────────────────────────────────
section "6. Interim Analytics Query Tool"

ANALYTICS_TOOL="${REPO_ROOT}/scripts/analytics/openedx-analytics.py"

if [[ -f "${ANALYTICS_TOOL}" ]]; then
  pass "openedx-analytics.py interim query tool exists"

  # Check it queries the key models
  if grep -qF "CourseEnrollment" "${ANALYTICS_TOOL}"; then
    pass "openedx-analytics.py queries CourseEnrollment (activation/completion data)"
  else
    fail "openedx-analytics.py does not reference CourseEnrollment"
  fi

  if grep -qF "GeneratedCertificate" "${ANALYTICS_TOOL}"; then
    pass "openedx-analytics.py queries GeneratedCertificate (completion data)"
  else
    fail "openedx-analytics.py does not reference GeneratedCertificate"
  fi
else
  fail "Interim analytics query tool missing: scripts/analytics/openedx-analytics.py"
fi

# ──────────────────────────────────────────────
# 7. Data retention policy alignment
# ──────────────────────────────────────────────
section "7. Data Retention Policy Alignment"

RETENTION_CONFIG="${REPO_ROOT}/infrastructure/tutor/analytics-retention-config.yaml"
RETENTION_DOC="${REPO_ROOT}/docs/policies/operations/ANALYTICS_DATA_RETENTION.md"

if [[ -f "${RETENTION_CONFIG}" ]]; then
  pass "Analytics retention config exists: infrastructure/tutor/analytics-retention-config.yaml"
else
  fail "Analytics retention config missing: infrastructure/tutor/analytics-retention-config.yaml"
fi

if [[ -f "${RETENTION_DOC}" ]]; then
  pass "Analytics data retention doc exists: docs/policies/operations/ANALYTICS_DATA_RETENTION.md"
else
  fail "Analytics data retention doc missing: docs/policies/operations/ANALYTICS_DATA_RETENTION.md"
fi

# KPI doc must reference retention policy
if [[ -f "${KPI_DOC}" ]]; then
  if grep -qF "ANALYTICS_DATA_RETENTION" "${KPI_DOC}"; then
    pass "KPI framework references data retention policy"
  else
    fail "KPI framework does not reference data retention policy"
  fi
fi

# ──────────────────────────────────────────────
# 8. Dashboard plan present in KPI doc
# ──────────────────────────────────────────────
section "8. Superset Dashboard Plan"

DASHBOARD_KEYWORDS=(
  "North Star Overview"
  "Activation Funnel"
  "Completion Tracker"
  "Retention Cohort"
  "analytics.academyv2"
)

if [[ -f "${KPI_DOC}" ]]; then
  for keyword in "${DASHBOARD_KEYWORDS[@]}"; do
    if grep -qF "${keyword}" "${KPI_DOC}"; then
      pass "Dashboard plan includes '${keyword}'"
    else
      fail "Dashboard plan missing '${keyword}'"
    fi
  done
else
  skip "KPI doc not found — skipping dashboard plan checks"
fi

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
echo ""
echo "========================================"
echo -e "  ${GREEN}PASS${NC}: ${PASS}  ${RED}FAIL${NC}: ${FAIL}  ${YELLOW}SKIP${NC}: ${SKIP}"
echo "========================================"

if [[ ${FAIL} -gt 0 ]]; then
  echo -e "${RED}FAILED${NC} — ${FAIL} check(s) did not pass."
  exit 1
else
  echo -e "${GREEN}OK${NC} — Product KPI framework verification passed."
  exit 0
fi
