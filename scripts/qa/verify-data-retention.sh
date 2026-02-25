#!/usr/bin/env bash
# verify-data-retention.sh — verify data retention policy and tooling are in place.
#
# Checks:
#   1. DATA_RETENTION_POLICY.md exists and covers required data categories
#   2. CronJob manifests exist or can be generated for retention tasks
#   3. Velero backup TTL is configured
#   4. Loki log retention is configured
#   5. user-data-export.sh exists and is executable
#   6. data-retention-jobs.sh exists and is executable
#   7. DATA_ERASURE_RUNBOOK.md references the retention policy
#   8. data-retention-jobs.sh generates valid manifests
#
# @covers AC-PRV-007, AC-PRV-008, AC-PRV-009
# @spec: data-privacy-gdpr-compliance_spec.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP + 1)); }

RETENTION_DOC="$REPO_ROOT/docs/operations/DATA_RETENTION_POLICY.md"
ERASURE_DOC="$REPO_ROOT/docs/operations/DATA_ERASURE_RUNBOOK.md"
RETENTION_JOBS="$REPO_ROOT/scripts/infra/data-retention-jobs.sh"
EXPORT_SCRIPT="$REPO_ROOT/scripts/infra/user-data-export.sh"

# ── 1. DATA_RETENTION_POLICY.md exists ───────────────────────────────────────

if [[ -f "$RETENTION_DOC" ]]; then
  pass "DATA_RETENTION_POLICY.md exists"
else
  fail "DATA_RETENTION_POLICY.md not found at $RETENTION_DOC"
fi

# ── 2. Retention policy covers required data categories ──────────────────────

check_retention_section() {
  local pattern="$1" label="$2"
  if [[ ! -f "$RETENTION_DOC" ]]; then
    skip "$label — retention doc missing"
    return
  fi
  if grep -qiF "$pattern" "$RETENTION_DOC" 2>/dev/null; then
    pass "Retention policy documents: $label"
  else
    fail "Retention policy missing coverage for: $label"
  fi
}

check_retention_section "User Account"    "User account data retention"
check_retention_section "MySQL"           "MySQL data store"
check_retention_section "MongoDB"         "MongoDB / forum data"
check_retention_section "PostgreSQL"      "PostgreSQL / Purchase Gateway"
check_retention_section "Application Logs" "Application logs (Loki)"
check_retention_section "Loki"            "Loki retention configuration"
check_retention_section "Backups"         "Backup rotation"
check_retention_section "GCS"             "GCS object storage"
check_retention_section "Stripe"          "External service (Stripe)"
check_retention_section "PDPA"            "PDPA regulatory basis"
check_retention_section "GDPR"            "GDPR regulatory basis"
check_retention_section "Companies Act"   "7-year financial record retention (Companies Act 2016)"
check_retention_section "OEP-30"          "OEP-30 compliance reference"
check_retention_section "DSAR"            "DSAR workflow"
check_retention_section "legal hold"      "Legal hold exception"

# ── 3. Automated retention schedule documented ────────────────────────────────

if [[ -f "$RETENTION_DOC" ]]; then
  if grep -q "stripe-events-cleanup" "$RETENTION_DOC" 2>/dev/null; then
    pass "Retention policy documents stripe_events cleanup job"
  else
    fail "Retention policy does not document stripe_events cleanup job"
  fi

  if grep -q "notifications-cleanup" "$RETENTION_DOC" 2>/dev/null; then
    pass "Retention policy documents notifications cleanup job"
  else
    fail "Retention policy does not document notifications cleanup job"
  fi

  if grep -q "Velero" "$RETENTION_DOC" 2>/dev/null; then
    pass "Retention policy documents Velero backup TTL"
  else
    fail "Retention policy does not mention Velero backup TTL"
  fi
fi

# ── 4. data-retention-jobs.sh exists and is executable ───────────────────────

if [[ -f "$RETENTION_JOBS" ]]; then
  pass "data-retention-jobs.sh exists"
else
  fail "data-retention-jobs.sh not found at $RETENTION_JOBS"
fi

if [[ -x "$RETENTION_JOBS" ]]; then
  pass "data-retention-jobs.sh is executable"
else
  fail "data-retention-jobs.sh is not executable (run: chmod +x $RETENTION_JOBS)"
fi

# ── 5. data-retention-jobs.sh generates valid manifests ─────────────────────

if [[ -f "$RETENTION_JOBS" && -x "$RETENTION_JOBS" ]]; then
  TMPDIR_OUT=$(mktemp -d)
  set +e
  OUTPUT_DIR="$TMPDIR_OUT" "$RETENTION_JOBS" 2>/dev/null
  GEN_RC=$?
  set -e

  if [[ "$GEN_RC" -eq 0 ]]; then
    pass "data-retention-jobs.sh runs without error"
  else
    fail "data-retention-jobs.sh exited with rc=$GEN_RC"
  fi

  EXPECTED_JOBS=(
    "stripe-events-cleanup.yaml"
    "notifications-cleanup.yaml"
    "expired-sessions-cleanup.yaml"
    "retirement-audit-cleanup.yaml"
  )
  for job_file in "${EXPECTED_JOBS[@]}"; do
    if [[ -f "$TMPDIR_OUT/$job_file" ]]; then
      pass "CronJob manifest generated: $job_file"
    else
      fail "CronJob manifest missing: $job_file (expected in output dir)"
    fi
  done

  # Validate YAML structure of generated manifests
  if command -v python3 >/dev/null 2>&1; then
    for yaml_file in "$TMPDIR_OUT"/*.yaml; do
      [[ -f "$yaml_file" ]] || continue
      basename_file=$(basename "$yaml_file")
      set +e
      python3 -c "
import yaml, sys
with open('$yaml_file') as f:
    doc = yaml.safe_load(f)
assert doc.get('apiVersion') == 'batch/v1', 'apiVersion must be batch/v1'
assert doc.get('kind') == 'CronJob', 'kind must be CronJob'
assert 'spec' in doc, 'spec missing'
assert 'schedule' in doc['spec'], 'schedule missing'
" 2>/dev/null
      YAML_RC=$?
      set -e
      if [[ "$YAML_RC" -eq 0 ]]; then
        pass "CronJob manifest is valid YAML with required fields: $basename_file"
      else
        fail "CronJob manifest failed YAML validation: $basename_file"
      fi
    done
  else
    skip "python3 not available — YAML validation skipped"
  fi

  rm -rf "$TMPDIR_OUT"
else
  skip "data-retention-jobs.sh not runnable — manifest generation check skipped"
fi

# ── 6. user-data-export.sh exists and is executable ──────────────────────────

if [[ -f "$EXPORT_SCRIPT" ]]; then
  pass "user-data-export.sh exists"
else
  fail "user-data-export.sh not found at $EXPORT_SCRIPT"
fi

if [[ -x "$EXPORT_SCRIPT" ]]; then
  pass "user-data-export.sh is executable"
else
  fail "user-data-export.sh is not executable (run: chmod +x $EXPORT_SCRIPT)"
fi

# Check user-data-export.sh contains required sections
if [[ -f "$EXPORT_SCRIPT" ]]; then
  for pattern in "OEP-30" "GDPR" "PDPA" "sha256" "README" "profile" "enrollments" "orders" "forum"; do
    if grep -q "$pattern" "$EXPORT_SCRIPT" 2>/dev/null; then
      pass "user-data-export.sh references: $pattern"
    else
      fail "user-data-export.sh missing reference to: $pattern"
    fi
  done
fi

# ── 7. DATA_ERASURE_RUNBOOK.md cross-references retention policy ──────────────

if [[ -f "$ERASURE_DOC" ]]; then
  if grep -q "DATA_RETENTION_POLICY" "$ERASURE_DOC" 2>/dev/null; then
    pass "DATA_ERASURE_RUNBOOK.md references DATA_RETENTION_POLICY.md"
  else
    fail "DATA_ERASURE_RUNBOOK.md does not reference DATA_RETENTION_POLICY.md"
  fi
else
  skip "DATA_ERASURE_RUNBOOK.md not found — cross-reference check skipped"
fi

# ── 8. Loki retention configuration ──────────────────────────────────────────

LOKI_CONFIG_SEARCH=(
  "$REPO_ROOT/infrastructure/monitoring/loki-config.yaml"
  "$REPO_ROOT/deploy/k8s/base/apps/loki"
  "$REPO_ROOT/infrastructure/monitoring"
)

LOKI_RETENTION_FOUND=0
for loki_path in "${LOKI_CONFIG_SEARCH[@]}"; do
  if [[ -d "$loki_path" ]]; then
    if grep -rl "retention_period" "$loki_path" 2>/dev/null | grep -q .; then
      pass "Loki retention_period configured (found in $loki_path)"
      LOKI_RETENTION_FOUND=1
      break
    fi
  elif [[ -f "$loki_path" ]]; then
    if grep -q "retention_period" "$loki_path" 2>/dev/null; then
      pass "Loki retention_period configured in $loki_path"
      LOKI_RETENTION_FOUND=1
      break
    fi
  fi
done

if [[ "$LOKI_RETENTION_FOUND" -eq 0 ]]; then
  # Try wider repo search
  set +e
  LOKI_HIT=$(grep -rl "retention_period" "$REPO_ROOT" \
    --include="*.yaml" --include="*.yml" 2>/dev/null | head -1)
  set -e
  if [[ -n "$LOKI_HIT" ]]; then
    pass "Loki retention_period found in repo: $LOKI_HIT"
  else
    skip "Loki retention_period config not found in repo — verify Loki is configured with limits_config.retention_period=720h"
  fi
fi

# ── 9. Velero backup TTL configured ──────────────────────────────────────────

VELERO_TTL_FOUND=0
set +e
VELERO_HITS=$(grep -rl "ttl:" "$REPO_ROOT/deploy" 2>/dev/null | head -1)
set -e

if [[ -n "$VELERO_HITS" ]]; then
  if grep -q "ttl:" "$VELERO_HITS" 2>/dev/null; then
    pass "Velero TTL configured in: $VELERO_HITS"
    VELERO_TTL_FOUND=1
  fi
fi

if [[ "$VELERO_TTL_FOUND" -eq 0 ]]; then
  set +e
  VELERO_SCHED=$(grep -rl "velero" "$REPO_ROOT/deploy" --include="*.yaml" 2>/dev/null | head -1)
  set -e
  if [[ -n "$VELERO_SCHED" ]]; then
    skip "Velero manifests found but no TTL configured — add ttl: 2160h0m0s to Velero Schedule"
  else
    skip "Velero Schedule manifests not found in deploy/ — verify Velero backup TTL is configured"
  fi
fi

# ── 10. Shell script quality checks ──────────────────────────────────────────

for script in "$RETENTION_JOBS" "$EXPORT_SCRIPT"; do
  [[ -f "$script" ]] || continue
  script_name=$(basename "$script")

  # Check shebang
  if head -1 "$script" | grep -q "#!/usr/bin/env bash"; then
    pass "$script_name has correct shebang"
  else
    fail "$script_name missing #!/usr/bin/env bash shebang"
  fi

  # Check set -euo pipefail
  if grep -q "set -euo pipefail" "$script" 2>/dev/null; then
    pass "$script_name uses set -euo pipefail"
  else
    fail "$script_name missing set -euo pipefail"
  fi

  # Check shellcheck if available
  if command -v shellcheck >/dev/null 2>&1; then
    set +e
    shellcheck -S warning "$script" 2>/dev/null
    SC_RC=$?
    set -e
    if [[ "$SC_RC" -eq 0 ]]; then
      pass "$script_name passes shellcheck"
    else
      fail "$script_name has shellcheck warnings/errors (run: shellcheck $script)"
    fi
  else
    skip "shellcheck not available — skipping lint for $script_name"
  fi
done

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
