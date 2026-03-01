#!/usr/bin/env bash
# diagnose-runtime-theme-drift.sh — consolidated runtime-theme drift triage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="$REPO_ROOT/var/qa"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/runtime-theme-drift-diagnose-${TIMESTAMP}.log"

FAILURES=0

run_check() {
  local label="$1"
  shift
  echo "" | tee -a "$LOG_FILE"
  echo "=== ${label} ===" | tee -a "$LOG_FILE"
  if "$@" 2>&1 | tee -a "$LOG_FILE"; then
    echo "PASS: ${label}" | tee -a "$LOG_FILE"
  else
    echo "FAIL: ${label}" | tee -a "$LOG_FILE"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "Runtime theme drift diagnosis started at ${TIMESTAMP}" | tee "$LOG_FILE"

run_check \
  "Prod runtime theme preflight" \
  "$REPO_ROOT/scripts/qa/verify-paragon-runtime.sh" \
  --runtime-url https://apps.academyv2.mereka.io \
  --require-runtime \
  --require-slot-markers

run_check \
  "Dev runtime theme preflight" \
  "$REPO_ROOT/scripts/qa/verify-paragon-runtime.sh" \
  --runtime-url https://apps.academyv2.mereka.dev \
  --require-slot-markers

run_check \
  "GitOps image override parity (infra checkout)" \
  "$REPO_ROOT/scripts/qa/verify-gitops-image-overrides.sh" \
  --check-infra

echo "" | tee -a "$LOG_FILE"
echo "Diagnosis log: $LOG_FILE" | tee -a "$LOG_FILE"

if [[ "$FAILURES" -ne 0 ]]; then
  cat <<EOF | tee -a "$LOG_FILE"

Summary: ${FAILURES} check(s) failed.
Suggested remediation order:
1. Fix app/infra image tag drift so overlays reference the same Open edX + MFE tags:
   - scripts/infra/sync-gitops-prod-image-tags.sh --infra-repo /home/gurpreet/projects/k8s/bbi-infrastructure --apply
2. Sync infra vendored base from this repo when Caddyfile drift is reported:
   - scripts/infra/sync-vendored-mfe-caddyfile.sh --infra-repo /home/gurpreet/projects/k8s/bbi-infrastructure --apply
3. Re-run:
   - make qa-runtime-theme-mode-prod
   - make qa-runtime-theme-mode-dev
   - make qa-phase2-smoke-evidence-prod
EOF
  exit 1
fi

echo "Summary: all runtime-theme drift checks passed." | tee -a "$LOG_FILE"
