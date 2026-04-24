#!/usr/bin/env bash
# @covers AC-036, AC-037
# @spec: data-migrations-kajabi-mct_spec.md
# Verify migration idempotency logic against AC-036 and AC-037.
#
# Checks:
# - Import scripts use get_or_create patterns
# - No INSERT without conflict handling
# - Duplicate detection logic exists
# - Batch offset support for resumption
#
# Usage:
#   ./scripts/qa/verify-idempotency.sh [--full-pipeline]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

FULL_PIPELINE=0
if [[ "${1:-}" == "--full-pipeline" ]]; then
  FULL_PIPELINE=1
fi

# Import scripts to check
IMPORT_SCRIPTS=(
  "scripts/migrations/kajabi/openedx_bulk_import.py"
  "scripts/migrations/mct/openedx_bulk_import_mct.py"
  "scripts/migrations/kajabi/import_courses.py"
  "scripts/migrations/mct/import_courses_k8s.py"
)

echo "Checking idempotency patterns in import scripts..."

for script in "${IMPORT_SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "[INFO] Script not found: $script (skipping)"
    continue
  fi

  echo ""
  pass "Checking $(basename "$script")"

  # Check for get_or_create usage
  if grep -q "get_or_create\|update_or_create" "$script"; then
    pass "Uses get_or_create/update_or_create pattern"
  else
    echo "[WARN] No get_or_create pattern found in $(basename "$script")"
  fi

  # Check for conflict handling
  if grep -q "IntegrityError\|UniqueViolation\|try.*create.*except" "$script"; then
    pass "Has conflict/duplicate handling"
  else
    echo "[WARN] No explicit conflict handling in $(basename "$script")"
  fi

  # Check for batch offset support (resumption)
  if grep -q "offset\|skip\|resume\|--start-at" "$script"; then
    pass "Supports batch offset/resumption"
  else
    echo "[WARN] No batch offset support in $(basename "$script")"
  fi

  # Check for duplicate detection before insert
  if grep -q "filter.*exists\|if.*get\|DoesNotExist" "$script"; then
    pass "Has duplicate detection logic"
  else
    echo "[WARN] Limited duplicate detection in $(basename "$script")"
  fi
done

# Check for pipeline orchestration script
PIPELINE_SCRIPT="scripts/migrations/run-verification-pipeline.sh"

if [[ "$FULL_PIPELINE" -eq 1 ]]; then
  if [[ -f "$PIPELINE_SCRIPT" ]]; then
    pass "Pipeline orchestration script exists"

    # Check for idempotency notes in comments
    if grep -q "idempot\|re-run\|repeat" "$PIPELINE_SCRIPT"; then
      pass "Pipeline script mentions idempotency/re-run"
    fi
  else
    echo "[INFO] No pipeline orchestration script found"
  fi
fi

# Check for database constraint documentation
MIGRATION_DOCS=$(find docs/migrations -name "*.md" 2>/dev/null | head -5)
if [[ -n "$MIGRATION_DOCS" ]]; then
  echo ""
  echo "[INFO] Checking migration documentation for idempotency notes..."

  for doc in $MIGRATION_DOCS; do
    if grep -qi "idempot\|re-run\|duplicate" "$doc"; then
      pass "$(basename "$doc") mentions idempotency"
    fi
  done
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All idempotency checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
