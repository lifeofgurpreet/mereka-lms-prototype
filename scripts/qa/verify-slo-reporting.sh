#!/usr/bin/env bash
# @covers AC-024, AC-025, AC-033, AC-034, AC-035, AC-036, AC-042, AC-043, AC-044, AC-045, AC-046
# @spec: slo-sla-service-level-management_spec.md
# Verify SLA reporting infrastructure and procedures.
#
# Checks:
# - Quarterly SLA report template exists with required sections
# - Monthly report distribution process documented
# - SLA breach escalation procedures documented
# - Edge case handling (multi-region latency, cascading failures, notification failures)
# - Timestamp consistency and client-favorable measurement
#
# Usage:
#   ./scripts/qa/verify-slo-reporting.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1" >&2; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; SKIP=$((SKIP + 1)); }

# ── Monthly and Quarterly Reporting Templates ────────────────────

# AC-024: Quarterly SLA report template
SPEC_FILE="specs/slo-sla-service-level-management_spec.md"

if [[ ! -f "$SPEC_FILE" ]]; then
  fail "Spec file missing ($SPEC_FILE)"
  echo -e "\n  Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  exit 1
fi

# Check quarterly report template exists in spec
if grep -q 'Quarterly SLA Compliance Report Template' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-024: Quarterly SLA report template defined in spec"
else
  fail "AC-024: Quarterly SLA report template missing from spec"
fi

# AC-024: Check required sections in quarterly template
QUARTERLY_SECTIONS=(
  "90-Day Availability Trend"
  "Performance Regression Summary"
  "Capacity Planning Recommendations"
  "On-Call Health Metrics"
)

for section in "${QUARTERLY_SECTIONS[@]}"; do
  if grep -q "$section" "$SPEC_FILE" 2>/dev/null; then
    pass "AC-024: Quarterly template includes '$section' section"
  else
    fail "AC-024: Quarterly template missing '$section' section"
  fi
done

# AC-024: Check on-call health metrics specifics
ON_CALL_METRICS=(
  "Total alerts"
  "After-hours pages"
  "Escalations to L2"
  "Mean time to acknowledge"
)

for metric in "${ON_CALL_METRICS[@]}"; do
  if grep -q "$metric" "$SPEC_FILE" 2>/dev/null; then
    pass "AC-024: On-call health metrics include '$metric'"
  else
    fail "AC-024: On-call health metrics missing '$metric'"
  fi
done

# AC-024: Check capacity planning recommendations
if grep -q 'Scaling Recommendations' "$SPEC_FILE" 2>/dev/null && \
   grep -q 'Infrastructure Saturation Trends' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-024: Capacity planning recommendations section present"
else
  fail "AC-024: Capacity planning recommendations section missing"
fi

# AC-025: Monthly report distribution within 5 business days
if grep -q 'within 5 business days of month end' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-025: Monthly report distribution SLA documented (5 business days)"
else
  fail "AC-025: Monthly report distribution SLA not documented"
fi

# AC-025: Standardized report template required
if grep -q 'Monthly SLA Compliance Report Template' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-025: Standardized monthly report template defined"
else
  fail "AC-025: Standardized monthly report template missing"
fi

# Check report generation script exists
REPORT_SCRIPT="scripts/qa/generate-sla-report.sh"
if [[ -f "$REPORT_SCRIPT" ]]; then
  pass "AC-025: SLA report generation script exists ($REPORT_SCRIPT)"
else
  skip "AC-025: SLA report generation script not found (may be in planning)"
fi

# ── SLA Breach Escalation Procedures ─────────────────────────────

# AC-033: SLA breach notification within 1 hour
if grep -q 'within 1 hour of breach detection' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-033: SLA breach notification timeline documented (1 hour)"
else
  fail "AC-033: SLA breach notification timeline missing"
fi

# AC-033: Notification recipients documented
BREACH_RECIPIENTS=(
  "engineering lead"
  "VP/CTO"
  "account manager"
)

for recipient in "${BREACH_RECIPIENTS[@]}"; do
  if grep -qi "$recipient" "$SPEC_FILE" 2>/dev/null; then
    pass "AC-033: SLA breach notifies '$recipient'"
  else
    fail "AC-033: SLA breach notification missing '$recipient'"
  fi
done

# AC-034: Client communication timeline
CLIENT_COMM_TIMELINE=(
  "T+1 hour"
  "T+4 hours"
  "T+24 hours"
  "T+5 business days"
  "T+10 business days"
)

for milestone in "${CLIENT_COMM_TIMELINE[@]}"; do
  if grep -q "$milestone" "$SPEC_FILE" 2>/dev/null; then
    pass "AC-034: Client communication timeline includes $milestone"
  else
    fail "AC-034: Client communication timeline missing $milestone"
  fi
done

# AC-034: Postmortem within 5 business days
if grep -q 'postmortem within 5 business days' "$SPEC_FILE" 2>/dev/null || \
   grep -q 'T+5 business days.*postmortem' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-034: Postmortem delivery within 5 business days documented"
else
  fail "AC-034: Postmortem delivery timeline missing"
fi

# AC-035: Remediation plan content
REMEDIATION_PLAN_SECTIONS=(
  "root cause analysis"
  "immediate fixes"
  "long-term improvements"
  "timeline"
)

for section in "${REMEDIATION_PLAN_SECTIONS[@]}"; do
  if grep -qi "$section" "$SPEC_FILE" 2>/dev/null; then
    pass "AC-035: Remediation plan includes '$section'"
  else
    fail "AC-035: Remediation plan missing '$section'"
  fi
done

# AC-035: Remediation plan within 4 hours
if grep -q 'within 4 hours of breach detection' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-035: Remediation plan timeline documented (4 hours)"
else
  fail "AC-035: Remediation plan timeline missing"
fi

# AC-036: Repeat breach escalation (2 consecutive months)
if grep -q '2 consecutive months' "$SPEC_FILE" 2>/dev/null && \
   grep -q 'emergency architecture review' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-036: 2-month consecutive breach triggers architecture review"
else
  fail "AC-036: 2-month consecutive breach escalation missing"
fi

# AC-036: 3-in-6-month breach triggers reliability sprint
if grep -q '3 out of 6 months' "$SPEC_FILE" 2>/dev/null && \
   grep -q 'reliability sprint' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-036: 3-in-6-month breach triggers reliability sprint"
else
  fail "AC-036: 3-in-6-month breach escalation missing"
fi

# ── Edge Cases ───────────────────────────────────────────────────

# AC-042: Multi-region latency measurement
if grep -q 'Asia-Pacific regional probe.*authoritative' "$SPEC_FILE" 2>/dev/null || \
   grep -q 'regional probe closest to the deployment' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-042: Regional latency measurement policy documented (Asia-Pacific authoritative)"
else
  fail "AC-042: Regional latency measurement policy missing"
fi

# AC-042: Regional probe justification
if grep -q 'asia-southeast1' "$SPEC_FILE" 2>/dev/null && \
   grep -q 'Singapore' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-042: Regional deployment location documented (asia-southeast1/Singapore)"
else
  fail "AC-042: Regional deployment location not documented"
fi

# AC-043: Cascading failure attribution
if grep -q 'attributed to MySQL only' "$SPEC_FILE" 2>/dev/null || \
   grep -q 'downtime is attributed to the infrastructure service only' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-043: Cascading failure attribution policy documented"
else
  fail "AC-043: Cascading failure attribution policy missing"
fi

# AC-043: Dependent service budget protection
if grep -q 'dependent services.*budgets are not consumed' "$SPEC_FILE" 2>/dev/null || \
   grep -q 'error budget for dependent services SHOULD NOT be consumed' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-043: Dependent service budget protection documented"
else
  fail "AC-043: Dependent service budget protection missing"
fi

# AC-043: Infrastructure dependency tracking
if grep -q 'infrastructure dependencies' "$SPEC_FILE" 2>/dev/null && \
   grep -q 'attributable downtime' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-043: Infrastructure dependency tracking documented"
else
  fail "AC-043: Infrastructure dependency tracking missing"
fi

# AC-044: Maintenance window notification failure handling
if grep -q 'notification email fails to send' "$SPEC_FILE" 2>/dev/null && \
   grep -q 'operations is alerted within 1 hour' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-044: Notification failure detection within 1 hour"
else
  fail "AC-044: Notification failure detection missing"
fi

# AC-044: Multiple notification channels
NOTIFICATION_CHANNELS=(
  "email"
  "status page"
  "Slack"
)

for channel in "${NOTIFICATION_CHANNELS[@]}"; do
  if grep -qi "$channel" "$SPEC_FILE" 2>/dev/null; then
    pass "AC-044: Notification channel documented: $channel"
  else
    fail "AC-044: Notification channel missing: $channel"
  fi
done

# AC-044: Manual outreach fallback
if grep -q 'manual outreach' "$SPEC_FILE" 2>/dev/null || \
   grep -q 'manual client outreach' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-044: Manual outreach fallback documented"
else
  fail "AC-044: Manual outreach fallback missing"
fi

# AC-045: Transient deployment errors exclusion
if grep -q '< 0.1% of traffic and last < 1 minute' "$SPEC_FILE" 2>/dev/null || \
   grep -q 'deployment-related transient errors' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-045: Transient deployment error exclusion policy documented"
else
  fail "AC-045: Transient deployment error exclusion policy missing"
fi

# AC-045: Exclusion requires documentation
if grep -q 'if documented in monthly report' "$SPEC_FILE" 2>/dev/null || \
   grep -q 'MAY be excluded if documented' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-045: Exclusion documentation requirement present"
else
  fail "AC-045: Exclusion documentation requirement missing"
fi

# AC-046: Timestamp discrepancy handling
if grep -q 'time measurement most favorable to the client' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-046: Client-favorable timestamp policy documented"
else
  fail "AC-046: Client-favorable timestamp policy missing"
fi

# AC-046: Authoritative time source
if grep -q 'authoritative time source' "$SPEC_FILE" 2>/dev/null || \
   grep -q 'single source of truth' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-046: Authoritative time source documented"
else
  fail "AC-046: Authoritative time source missing"
fi

# AC-046: Clock skew detection
if grep -q 'clock skew > 5 seconds' "$SPEC_FILE" 2>/dev/null; then
  pass "AC-046: Clock skew detection threshold documented (5 seconds)"
else
  fail "AC-046: Clock skew detection threshold missing"
fi

# ── Operational Documentation ────────────────────────────────────

# Check SLA reporting runbook
SLA_RUNBOOK="docs/operations/SLA_REPORTING.md"
if [[ -f "$SLA_RUNBOOK" ]]; then
  pass "SLA reporting runbook exists ($SLA_RUNBOOK)"

  # Check monthly report section
  if grep -q 'Monthly Report' "$SLA_RUNBOOK" 2>/dev/null; then
    pass "Runbook: Monthly report section present"
  else
    fail "Runbook: Monthly report section missing"
  fi

  # Check quarterly report section
  if grep -q 'Quarterly Report' "$SLA_RUNBOOK" 2>/dev/null; then
    pass "Runbook: Quarterly report section present"
  else
    fail "Runbook: Quarterly report section missing"
  fi
else
  skip "SLA reporting runbook not found ($SLA_RUNBOOK)"
fi

# Check SLA breach runbook
BREACH_RUNBOOK="docs/operations/SLA_BREACH_RESPONSE.md"
if [[ -f "$BREACH_RUNBOOK" ]]; then
  pass "SLA breach response runbook exists ($BREACH_RUNBOOK)"

  # Check escalation procedures
  if grep -q 'Escalation' "$BREACH_RUNBOOK" 2>/dev/null; then
    pass "Breach runbook: Escalation procedures documented"
  else
    fail "Breach runbook: Escalation procedures missing"
  fi

  # Check client communication
  if grep -q 'Client Communication' "$BREACH_RUNBOOK" 2>/dev/null; then
    pass "Breach runbook: Client communication section present"
  else
    fail "Breach runbook: Client communication section missing"
  fi
else
  skip "SLA breach response runbook not found ($BREACH_RUNBOOK)"
fi

# Check maintenance window policy documentation
MAINTENANCE_DOC="docs/operations/MAINTENANCE_WINDOWS.md"
if [[ -f "$MAINTENANCE_DOC" ]]; then
  pass "Maintenance window policy documentation exists ($MAINTENANCE_DOC)"

  # Check 72-hour advance notice
  if grep -q '72 hour' "$MAINTENANCE_DOC" 2>/dev/null; then
    pass "Maintenance doc: 72-hour advance notice documented"
  else
    fail "Maintenance doc: 72-hour advance notice missing"
  fi

  # Check SLA exclusion
  if grep -q 'SLA exclusion' "$MAINTENANCE_DOC" 2>/dev/null || \
     grep -q 'excluded from SLA' "$MAINTENANCE_DOC" 2>/dev/null; then
    pass "Maintenance doc: SLA exclusion policy documented"
  else
    fail "Maintenance doc: SLA exclusion policy missing"
  fi
else
  skip "Maintenance window documentation not found ($MAINTENANCE_DOC)"
fi

echo
echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[[ "$FAIL" -eq 0 ]]
exit $?
