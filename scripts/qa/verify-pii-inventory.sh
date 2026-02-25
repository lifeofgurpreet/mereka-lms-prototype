#!/usr/bin/env bash
# verify-pii-inventory.sh — verify PII inventory and erasure runbook completeness
# @covers AC-PRV-001, AC-PRV-002, AC-PRV-003, AC-PRV-004
# @spec: data-privacy-gdpr-compliance_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP + 1)); }

# ── File existence ────────────────────────────────────────────────────────────

PII_DOC="$REPO_ROOT/docs/operations/PII_DATA_INVENTORY.md"
ERASURE_DOC="$REPO_ROOT/docs/operations/DATA_ERASURE_RUNBOOK.md"

if [[ -f "$PII_DOC" ]]; then
  pass "PII_DATA_INVENTORY.md exists"
else
  fail "PII_DATA_INVENTORY.md not found at $PII_DOC"
fi

if [[ -f "$ERASURE_DOC" ]]; then
  pass "DATA_ERASURE_RUNBOOK.md exists"
else
  fail "DATA_ERASURE_RUNBOOK.md not found at $ERASURE_DOC"
fi

# ── Required sections in PII inventory ───────────────────────────────────────

check_section() {
  local doc="$1" pattern="$2" label="$3"
  if grep -qiF "$pattern" "$doc" 2>/dev/null; then
    pass "$label documented in PII inventory"
  else
    fail "$label missing from PII inventory"
  fi
}

check_section "$PII_DOC" "MySQL"         "MySQL data store"
check_section "$PII_DOC" "MongoDB"       "MongoDB data store"
check_section "$PII_DOC" "Redis"         "Redis data store"
check_section "$PII_DOC" "PostgreSQL"    "PostgreSQL (Purchase Gateway) data store"
check_section "$PII_DOC" "Loki"          "Application logs (Loki)"
check_section "$PII_DOC" "GCS"           "GCS file storage"
check_section "$PII_DOC" "HubSpot"       "HubSpot webhook data flow"
check_section "$PII_DOC" "Stripe"        "Stripe external service"
check_section "$PII_DOC" "Meilisearch"   "Meilisearch index"

# ── OEP-30 categories present ─────────────────────────────────────────────────

for category in "DIRECT" "QUASI" "BEHAVIORAL"; do
  if grep -q "$category" "$PII_DOC" 2>/dev/null; then
    pass "OEP-30 category '$category' annotated in inventory"
  else
    fail "OEP-30 category '$category' not found in inventory"
  fi
done

# ── Retention policy documented for each store ───────────────────────────────

retention_stores=("MySQL" "MongoDB" "Redis" "PostgreSQL" "Loki" "GCS" "Firestore")
for store in "${retention_stores[@]}"; do
  # Check that the store section exists AND "retention" or "days" or "years" appears near it
  nearby=$(grep -A 10 "$store" "$PII_DOC" 2>/dev/null || true)
  if echo "$nearby" | grep -qiE "(retention|days|years|lifetime)"; then
    pass "Retention policy documented for $store"
  else
    fail "Retention policy missing for $store in PII inventory"
  fi
done

# ── Erasure runbook sections ──────────────────────────────────────────────────

check_erasure() {
  local pattern="$1" label="$2"
  if grep -qiF "$pattern" "$ERASURE_DOC" 2>/dev/null; then
    pass "Erasure runbook covers: $label"
  else
    fail "Erasure runbook missing: $label"
  fi
}

check_erasure "Open edX Retirement"  "Open edX retirement pipeline"
check_erasure "Purchase Gateway"     "Purchase Gateway anonymization"
check_erasure "Stripe"               "Stripe customer deletion"
check_erasure "Meilisearch"          "Meilisearch re-index"
check_erasure "HubSpot"              "HubSpot CRM contact deletion"
check_erasure "30 days"              "30-day SLA timeline"
check_erasure "Companies Act"        "7-year financial retention legal basis"

# ── Timeline documented ────────────────────────────────────────────────────────

if grep -q "30 days" "$ERASURE_DOC" 2>/dev/null && \
   grep -q "30 days" "$PII_DOC" 2>/dev/null; then
  pass "30-day erasure SLA mentioned in both documents"
else
  fail "30-day erasure SLA missing from one or both documents"
fi

# ── Known gaps section exists ─────────────────────────────────────────────────

if grep -q "Known Gaps" "$PII_DOC" 2>/dev/null; then
  pass "Known gaps section present in PII inventory"
else
  fail "Known gaps section missing from PII inventory"
fi

if grep -q "Known Gaps" "$ERASURE_DOC" 2>/dev/null; then
  pass "Known gaps section present in erasure runbook"
else
  fail "Known gaps section missing from erasure runbook"
fi

# ── Custom services verified ──────────────────────────────────────────────────

PG_MODELS_DIR="$REPO_ROOT/services/purchase-gateway/app/models"
if [[ -d "$PG_MODELS_DIR" ]]; then
  # Verify each model is mentioned in the PII inventory
  for model_file in order.py entitlement.py stripe_event.py subscription.py; do
    table=$(grep "__tablename__" "$PG_MODELS_DIR/$model_file" 2>/dev/null | head -1 | \
            sed 's/.*"\(.*\)".*/\1/')
    if [[ -n "$table" ]] && grep -q "$table" "$PII_DOC" 2>/dev/null; then
      pass "Purchase Gateway table '$table' documented in PII inventory"
    else
      fail "Purchase Gateway table '$table' (from $model_file) not found in PII inventory"
    fi
  done
else
  skip "purchase-gateway models directory not found — skipping model coverage check"
fi

HUBSPOT_FUNC="$REPO_ROOT/services/hubspot-webhook/functions/index.js"
if [[ -f "$HUBSPOT_FUNC" ]]; then
  if grep -q "Firestore" "$PII_DOC" 2>/dev/null; then
    pass "HubSpot webhook Firestore storage documented in PII inventory"
  else
    fail "HubSpot webhook Firestore storage not documented in PII inventory"
  fi
else
  skip "hubspot-webhook functions not found — skipping check"
fi

# ── GDPR compliance doc cross-reference ──────────────────────────────────────

GDPR_DOC="$REPO_ROOT/docs/operations/GDPR_COMPLIANCE.md"
if [[ -f "$GDPR_DOC" ]]; then
  pass "GDPR_COMPLIANCE.md exists (referenced by erasure runbook)"
else
  skip "GDPR_COMPLIANCE.md not found — check cross-references"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"
echo "Results: PASS=$PASS  FAIL=$FAIL  SKIP=$SKIP"
echo "────────────────────────────────────────"

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL — $FAIL check(s) failed"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
